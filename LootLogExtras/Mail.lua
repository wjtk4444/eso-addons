-- Mail: notable items taken from mail attachments, including system mail
-- (hirelings, rewards, refunds).
--
-- Only notable attachments are written to the history. Routine mail (guild store sale and
-- purchase confirmations above all) would otherwise flood it.
--
-- The game takes attachments in two ways:
--
-- 1. One mail: "Take" on an opened mail -> TakeMailAttachments(mailId, deleteOnClaim),
--    completed by EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS(mailId). The event only says which
--    mail, not what was in it, so each mail's attachments are recorded when it becomes
--    readable (EVENT_MAIL_READABLE, i.e. when it is selected) and used when the take succeeds.
--
-- 2. A whole category: "Take All (System)" / "Take All (Player)" ->
--    TakeAllMailAttachmentsInCategory(category, deleteOnClaim). One server request for
--    mails that were mostly never opened, answered by
--    EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE. Here the bags are snapshotted
--    before the request and diffed once the response has arrived and the inventory is quiet.
--
-- A single take of a mail that was never read (no recorded attachments) falls back to the
-- bag diff as well. Gains already logged through path 1 during a bag diff are subtracted
-- from it, so nothing is counted twice.

local LLE = LootLogExtras
local DEBOUNCE_NAME = LLE.ADDON_NAME .. "MailDebounce"
-- If a category take is never answered, finalize anyway so the diff can't swallow
-- unrelated gains later.
local SAFETY_TIMEOUT_NAME = LLE.ADDON_NAME .. "MailSafety"
local SAFETY_TIMEOUT_MS = 15000

-- zo_getSafeId64Key(mailId) -> { subject, items = { { itemLink, quantity }, ... } }
local readMail = {}

-- { before, alreadyCounted, awaitingResponses, source } or nil
local bulk = nil

local function Protected(label, func, ...)
    local ok, err = pcall(func, ...)
    if not ok then
        LLE.Msg("%s error: %s", label, tostring(err))
    end
end

local function LogNotable(source, gains)
    local notableText = LLE.DescribeNotable(gains)
    if not notableText then return end

    LootLog.Msg(string.format("From mail (%s): %s", source, notableText))
    for _, gain in ipairs(gains) do
        if gain.notable then
            LLE.LogItemQuietly(gain.itemLink, gain.quantity, true)
        end
    end
end

local function FinalizeBulkTake()
    EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
    EVENT_MANAGER:UnregisterForUpdate(SAFETY_TIMEOUT_NAME)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    if not bulk then return end

    local batch = bulk
    bulk = nil
    LogNotable(batch.source, LLE.DiffSnapshots(batch.before, LLE.SnapshotOwnedItems(), batch.alreadyCounted))
end

-- (Re)arms the final diff, unless a category take is still waiting for its response.
local function ScheduleBulkFinalize()
    if bulk and bulk.awaitingResponses == 0 then
        EVENT_MANAGER:RegisterForUpdate(DEBOUNCE_NAME, LLE.DEBOUNCE_MS, FinalizeBulkTake)
    end
end

local function BeginBulkTake(source)
    if not bulk then
        bulk =
        {
            before = LLE.SnapshotOwnedItems(),
            alreadyCounted = {},
            awaitingResponses = 0,
            source = source,
        }
        -- Items arrive as several slot updates; keep pushing the diff back until it is quiet.
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ScheduleBulkFinalize)
    elseif bulk.source ~= source then
        bulk.source = "Take All"
    end
    EVENT_MANAGER:RegisterForUpdate(SAFETY_TIMEOUT_NAME, SAFETY_TIMEOUT_MS, FinalizeBulkTake)
end

local function OnMailReadable(_, mailId)
    if not LLE.IsEnabled("logMail") then return end
    Protected("OnMailReadable", function()
        local _, _, subject, _, _, _, _, _, numAttachments = GetMailItemInfo(mailId)
        if not numAttachments or numAttachments == 0 then return end

        local items = {}
        for i = 1, numAttachments do
            local _, stack = GetAttachedItemInfo(mailId, i)
            local itemLink = GetAttachedItemLink(mailId, i, LINK_STYLE_DEFAULT)
            if itemLink and itemLink ~= "" then
                items[#items + 1] = { itemLink = itemLink, quantity = stack or 1 }
            end
        end
        if #items > 0 then
            readMail[zo_getSafeId64Key(mailId)] = { subject = subject, items = items }
        end
    end)
end

local function OnTakeAttachedItemSuccess(_, mailId)
    Protected("OnTakeAttachedItemSuccess", function()
        local key = zo_getSafeId64Key(mailId)
        local mail = readMail[key]
        if not mail then
            -- Taken without being read; the bag diff covers it.
            ScheduleBulkFinalize()
            return
        end
        readMail[key] = nil -- a repeated event for the same mail is a no-op

        LogNotable(mail.subject ~= "" and mail.subject or "no subject", mail.items)

        if bulk then
            for _, item in ipairs(mail.items) do
                bulk.alreadyCounted[item.itemLink] = (bulk.alreadyCounted[item.itemLink] or 0) + item.quantity
            end
            ScheduleBulkFinalize()
        end
    end)
end

local function OnTakeAllInCategoryResponse()
    Protected("OnTakeAllInCategoryResponse", function()
        if not bulk then return end
        bulk.awaitingResponses = zo_max(0, bulk.awaitingResponses - 1)
        -- Finalize whatever the result: a partial take (full bags) still delivered something,
        -- and a complete failure just diffs to nothing.
        ScheduleBulkFinalize()
    end)
end

-- Plain global API functions, wrapped right away. The game's callers look them up by
-- global name at call time.

local function WrapSingleMailTake(functionName)
    local original = _G[functionName]
    if type(original) ~= "function" then return end

    _G[functionName] = function(mailId, ...)
        if LLE.IsEnabled("logMail") then
            Protected(functionName .. " hook", function()
                if not readMail[zo_getSafeId64Key(mailId)] then
                    BeginBulkTake("unread mail")
                    ScheduleBulkFinalize()
                end
            end)
        end
        return original(mailId, ...)
    end
end

WrapSingleMailTake("TakeMailAttachments")
WrapSingleMailTake("TakeMailAttachedItems") -- no longer used by the game, but other addons may

do
    local original = TakeAllMailAttachmentsInCategory
    if type(original) == "function" then
        TakeAllMailAttachmentsInCategory = function(category, ...)
            if LLE.IsEnabled("logMail") then
                Protected("TakeAllMailAttachmentsInCategory hook", function()
                    local source = (category == MAIL_CATEGORY_SYSTEM_MAIL and "Take All (System)")
                        or (category == MAIL_CATEGORY_PLAYER_MAIL and "Take All (Player)")
                        or "Take All"
                    BeginBulkTake(source)
                    bulk.awaitingResponses = bulk.awaitingResponses + 1
                    -- No diff before the server has answered; the response re-arms it.
                    EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
                end)
            end
            return original(category, ...)
        end
    end
end

function LLE.InitializeMail()
    local name = LLE.ADDON_NAME .. "Mail"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MAIL_READABLE, OnMailReadable)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, OnTakeAttachedItemSuccess)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnTakeAllInCategoryResponse)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MAIL_CLOSE_MAILBOX, function()
        ZO_ClearTable(readMail) -- opened but never taken
    end)
end
