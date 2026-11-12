-- Mail: notable items and gold taken from mail, one chat line per mail:
--   (Mail) Woodworker Hireling: 1x [Rosin]
--   (Mail) Item Sold | 1x [Dreugh Wax] | 10,000 gold
--
-- Only notable items are written to the LootLog history. Routine mail would otherwise flood
-- it. Gold can't go into the history (LootLog only stores items), so it only appears in chat.
--
-- Every take is handled as a batch: the mails' contents are recorded right before the take,
-- the bags and the gold are snapshotted, and once the take has finished and the inventory is
-- quiet, the actual gains are handed out to the mails in order. So a partial take (full bags)
-- only logs what really arrived, and nothing is counted twice.
--
-- - One mail ("Take"): TakeMailAttachments(mailId, deleteOnClaim). The mail is open, so its
--   attachments are readable. Finished by EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS / _MONEY_SUCCESS.
-- - A category ("Take All (System)" / "Take All (Player)"):
--   TakeAllMailAttachmentsInCategory(category, deleteOnClaim). Mail headers (sender, subject,
--   gold) are always known, but attachments only after the mail has been read. So the take is
--   held back while the unread mails are read one by one (the server allows one read request
--   at a time), then sent. Finished by EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE.
--   Items from mails that couldn't be read in time are logged together under "Take All".
--
-- Guild store "Item Sold" mails contain only gold. The sold item is looked up in the guild
-- history (LibHistoire), matched by time and amount the same way AwesomeGuildStore does it.

local LLE = LootLogExtras
local NAME = LLE.ADDON_NAME .. "Mail"
local DEBOUNCE_NAME = NAME .. "Debounce"
-- If a take is never answered, finalize anyway so the batch can't swallow unrelated gains.
local SAFETY_TIMEOUT_NAME = NAME .. "Safety"
local SAFETY_TIMEOUT_MS = 15000
-- Reading mails before Take All
local READ_TIMEOUT_NAME = NAME .. "ReadTimeout"
local READ_TIMEOUT_MS = 1500
local READ_ALL_TIMEOUT_MS = 20000
-- Guild history lookup for "Item Sold" mails
local SALE_TIME_MARGIN_S = 10
local SALE_LOOKUP_TIMEOUT_MS = 10000

local function IsActive()
    return LLE.IsEnabled("logMail") or LLE.IsEnabled("logGold")
end

local function Protected(label, func, ...)
    local ok, err = pcall(func, ...)
    if not ok then
        LLE.Msg("%s error: %s", label, tostring(err))
    end
end

--------------------------------------------------------------------------------
-- Mail contents
--------------------------------------------------------------------------------

-- { mailId, sender, subject, fromSystem, money, items = { { itemLink, quantity } } or nil
--   when the attachments aren't readable, receivedAt }
local function CaptureMail(mailId)
    local senderDisplayName, _, subject, _, _, fromSystem, fromCS, _, numAttachments, attachedMoney, codAmount, _, secsSinceReceived, category = GetMailItemInfo(mailId)
    local mail =
    {
        mailId = mailId,
        sender = senderDisplayName or "",
        subject = subject or "",
        fromSystem = fromSystem or fromCS,
        numAttachments = numAttachments or 0,
        money = attachedMoney or 0,
        cod = codAmount or 0,
        category = category,
        receivedAt = GetTimeStamp() - (secsSinceReceived or 0),
    }
    if mail.numAttachments == 0 then
        mail.items = {}
    elseif IsReadMailInfoReady(mailId) then
        mail.items = {}
        for i = 1, mail.numAttachments do
            local _, stack = GetAttachedItemInfo(mailId, i)
            local itemLink = GetAttachedItemLink(mailId, i, LINK_STYLE_DEFAULT)
            if itemLink and itemLink ~= "" then
                mail.items[#mail.items + 1] = { itemLink = itemLink, quantity = stack or 1 }
            end
        end
    end
    return mail
end

local function GetLabel(mail)
    if mail.label then return mail.label end
    if mail.sender ~= "" then return mail.sender end
    return mail.subject ~= "" and mail.subject or "no subject"
end

--------------------------------------------------------------------------------
-- Guild store sales (LibHistoire)
--------------------------------------------------------------------------------

local function IsPossibleSale(mail)
    return mail.fromSystem and mail.numAttachments == 0 and mail.money > 0
end

-- callback(salesByMail) with salesByMail[mail] = sale for the mails that could be matched.
local function FindSales(mails, callback)
    local lib = LibHistoire
    if not lib or #mails == 0 then
        callback({})
        return
    end

    local done = false
    local function Finish(result)
        if done then return end
        done = true
        callback(result)
    end
    zo_callLater(function() Finish({}) end, SALE_LOOKUP_TIMEOUT_MS)

    local minTime, maxTime = math.huge, 0
    for _, mail in ipairs(mails) do
        minTime = zo_min(minTime, mail.receivedAt)
        maxTime = zo_max(maxTime, mail.receivedAt)
    end

    lib:OnReady(function()
        local me = UndecorateDisplayName(GetDisplayName())
        local events = {}
        local running = 0

        local function Match()
            local salesByMail, used = {}, {}
            for _, mail in ipairs(mails) do
                local best, bestDiff
                for _, sale in ipairs(events) do
                    if not used[sale.eventId] then
                        local listingFee, _, profit = GetTradingHousePostPriceInfo(sale.price)
                        if mail.money == profit + listingFee then
                            local diff = math.abs(sale.time - mail.receivedAt)
                            if not bestDiff or diff < bestDiff then
                                best, bestDiff = sale, diff
                            end
                        end
                    end
                end
                if best then
                    used[best.eventId] = true
                    salesByMail[mail] = best
                end
            end
            Finish(salesByMail)
        end

        -- Counted before starting, in case a processor finishes right away.
        running = 1
        local function OneDone()
            running = running - 1
            if running == 0 then Match() end
        end
        for i = 1, GetNumGuilds() do
            local guildId = GetGuildId(i)
            if DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_TRADING_HOUSE) then
                local processor = lib:CreateGuildHistoryProcessor(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, LLE.ADDON_NAME)
                running = running + 1
                local started = processor and processor:StartIteratingTimeRange(
                    minTime - SALE_TIME_MARGIN_S, maxTime + SALE_TIME_MARGIN_S + 1,
                    function(event)
                        local info = event:GetEventInfo()
                        if info.eventType == GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD and info.sellerDisplayName == me then
                            events[#events + 1] =
                            {
                                eventId = info.eventId,
                                time = info.timestampS,
                                itemLink = info.itemLink,
                                quantity = info.quantity,
                                price = info.price,
                            }
                        end
                    end,
                    OneDone)
                if not started then
                    running = running - 1
                end
            end
        end
        OneDone()
    end)
end

--------------------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------------------

-- items: what actually arrived from this mail; money: gold that actually arrived.
-- Returns true if a chat line was written right away (or will be, for a sale lookup).
local function LogMail(mail, items, money, sale)
    local notable = {}
    if LLE.IsEnabled("logMail") then
        notable = LLE.FilterNotable(items)
        for _, item in ipairs(notable) do
            LLE.LogItemQuietly(item.itemLink, item.quantity, true)
        end
    end
    local showGold = LLE.IsEnabled("logGold") and money > 0

    if sale and showGold then
        LootLog.Msg(string.format("(Mail) %s | %s | %s", mail.subject ~= "" and mail.subject or GetLabel(mail),
            LLE.FormatItem(sale.itemLink, sale.quantity), LLE.FormatGold(money)))
        return
    end

    local parts = {}
    for _, item in ipairs(notable) do
        parts[#parts + 1] = LLE.FormatItem(item.itemLink, item.quantity)
    end
    if showGold then
        parts[#parts + 1] = LLE.FormatGold(money)
    end
    if #parts > 0 then
        LootLog.Msg(string.format("(Mail) %s: %s", GetLabel(mail), table.concat(parts, ", ")))
    end
end

--------------------------------------------------------------------------------
-- Batches
--------------------------------------------------------------------------------

-- { mails = { mail, ... }, seen = { [mailKey] = true }, before = snapshot, moneyBefore,
--   awaitingResponses, source }
local batch = nil

local function FinalizeBatch()
    EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
    EVENT_MANAGER:UnregisterForUpdate(SAFETY_TIMEOUT_NAME)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_MONEY_UPDATE)
    if not batch then return end

    local current = batch
    batch = nil

    local remaining = {}
    for _, gain in ipairs(LLE.DiffSnapshots(current.before, LLE.SnapshotOwnedItems())) do
        remaining[gain.itemLink] = gain.quantity
    end
    local moneyLeft = zo_max(0, GetCurrentMoney() - current.moneyBefore)

    local results, sales = {}, {}
    for _, mail in ipairs(current.mails) do
        local taken = {}
        for _, item in ipairs(mail.items or {}) do
            local quantity = zo_min(item.quantity, remaining[item.itemLink] or 0)
            if quantity > 0 then
                taken[#taken + 1] = { itemLink = item.itemLink, quantity = quantity }
                remaining[item.itemLink] = remaining[item.itemLink] - quantity
            end
        end
        local money = zo_min(mail.money, moneyLeft)
        moneyLeft = moneyLeft - money
        if #taken > 0 or money > 0 then
            results[#results + 1] = { mail = mail, items = taken, money = money }
            if IsPossibleSale(mail) and money == mail.money then
                sales[#sales + 1] = mail
            end
        end
    end

    -- Whatever couldn't be matched to a mail (mails that couldn't be read in time)
    local leftovers = {}
    for itemLink, quantity in pairs(remaining) do
        if quantity > 0 then
            leftovers[#leftovers + 1] = { itemLink = itemLink, quantity = quantity }
        end
    end
    if #leftovers > 0 or moneyLeft > 0 then
        results[#results + 1] = { mail = { label = current.source, sender = "", subject = "" }, items = leftovers, money = moneyLeft }
    end

    -- Everything except the sales right away; the sales once the guild history has answered.
    local lookupSales = #sales > 0 and LLE.IsEnabled("logGold")
    local isSale = {}
    if lookupSales then
        for _, mail in ipairs(sales) do isSale[mail] = true end
    end
    for _, result in ipairs(results) do
        if not isSale[result.mail] then
            Protected("LogMail", LogMail, result.mail, result.items, result.money)
        end
    end
    if lookupSales then
        FindSales(sales, function(salesByMail)
            for _, result in ipairs(results) do
                if isSale[result.mail] then
                    Protected("LogMail", LogMail, result.mail, result.items, result.money, salesByMail[result.mail])
                end
            end
        end)
    end
end

-- (Re)arms the final diff, unless a category take is still waiting for its response.
local function ScheduleFinalize()
    if batch and batch.awaitingResponses == 0 then
        EVENT_MANAGER:RegisterForUpdate(DEBOUNCE_NAME, LLE.DEBOUNCE_MS, FinalizeBatch)
    end
end

local function AddToBatch(mails, source)
    if not batch then
        batch =
        {
            mails = {},
            seen = {},
            before = LLE.SnapshotOwnedItems(),
            moneyBefore = GetCurrentMoney(),
            awaitingResponses = 0,
            source = source,
        }
        -- Items and gold arrive as several updates; keep pushing the diff back until it's quiet.
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ScheduleFinalize)
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_MONEY_UPDATE, ScheduleFinalize)
    elseif batch.source ~= source then
        batch.source = "Take All"
    end
    for _, mail in ipairs(mails) do
        local key = zo_getSafeId64Key(mail.mailId)
        if not batch.seen[key] then
            batch.seen[key] = true
            batch.mails[#batch.mails + 1] = mail
        end
    end
    EVENT_MANAGER:RegisterForUpdate(SAFETY_TIMEOUT_NAME, SAFETY_TIMEOUT_MS, FinalizeBatch)
end

--------------------------------------------------------------------------------
-- Take All: read the category's mails first
--------------------------------------------------------------------------------

local readQueue = nil -- { ids, index, onDone, deadline } while reading before a Take All

local function ReadNext()
    EVENT_MANAGER:UnregisterForUpdate(READ_TIMEOUT_NAME)
    local queue = readQueue
    if not queue then return end

    queue.index = queue.index + 1
    local mailId = queue.ids[queue.index]
    if not mailId or GetFrameTimeMilliseconds() > queue.deadline then
        readQueue = nil
        queue.onDone()
        return
    end

    if IsReadMailInfoReady(mailId) then
        ReadNext()
        return
    end
    local result = RequestReadMail(mailId)
    if result == REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED then
        ReadNext()
    elseif result == REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED or result == REQUEST_READ_MAIL_RESULT_ALREADY_REQUESTED
        or result == REQUEST_READ_MAIL_RESULT_ANOTHER_REQUEST_PENDING then
        -- EVENT_MAIL_READABLE moves on; the timeout makes sure a lost answer can't stall it.
        queue.waitingFor = mailId
        EVENT_MANAGER:RegisterForUpdate(READ_TIMEOUT_NAME, READ_TIMEOUT_MS, ReadNext)
    else
        ReadNext()
    end
end

local function OnMailReadable(_, mailId)
    if readQueue and readQueue.waitingFor and AreId64sEqual(readQueue.waitingFor, mailId) then
        readQueue.waitingFor = nil
        ReadNext()
    end
end

local function GetMailsInCategory(category)
    local mails = {}
    for mailId in ZO_GetNextMailIdIter do
        local mail = CaptureMail(mailId)
        if mail.category == category and mail.cod == 0 and (mail.numAttachments > 0 or mail.money > 0) then
            mails[#mails + 1] = mail
        end
    end
    return mails
end

local function StartCategoryTake(original, category, deleteOnClaim)
    local source = (category == MAIL_CATEGORY_SYSTEM_MAIL and "Take All (System)")
        or (category == MAIL_CATEGORY_PLAYER_MAIL and "Take All (Player)")
        or "Take All"
    Protected("Take All", function()
        -- Recapture now that the reads are done.
        AddToBatch(GetMailsInCategory(category), source)
        batch.awaitingResponses = batch.awaitingResponses + 1
        -- No diff before the server has answered; the response re-arms it.
        EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
    end)
    return original(category, deleteOnClaim)
end

do
    local original = TakeAllMailAttachmentsInCategory
    if type(original) == "function" then
        TakeAllMailAttachmentsInCategory = function(category, deleteOnClaim, ...)
            if not IsActive() or readQueue then
                return original(category, deleteOnClaim, ...)
            end

            local unread = {}
            local ok = pcall(function()
                for _, mail in ipairs(GetMailsInCategory(category)) do
                    if not mail.items then
                        unread[#unread + 1] = mail.mailId
                    end
                end
            end)
            if not ok or #unread == 0 then
                return StartCategoryTake(original, category, deleteOnClaim)
            end

            if #unread > 3 then
                LootLog.Msg(string.format("(Mail) Reading %d mails before Take All...", #unread))
            end
            readQueue =
            {
                ids = unread,
                index = 0,
                deadline = GetFrameTimeMilliseconds() + READ_ALL_TIMEOUT_MS,
                onDone = function() StartCategoryTake(original, category, deleteOnClaim) end,
            }
            ReadNext()
        end
    end
end

--------------------------------------------------------------------------------
-- Single mail
--------------------------------------------------------------------------------

local function WrapSingleMailTake(functionName)
    local original = _G[functionName]
    if type(original) ~= "function" then return end

    _G[functionName] = function(mailId, ...)
        if IsActive() then
            Protected(functionName .. " hook", function()
                AddToBatch({ CaptureMail(mailId) }, "unread mail")
            end)
        end
        return original(mailId, ...)
    end
end

WrapSingleMailTake("TakeMailAttachments")
-- No longer used by the game, but other addons may still call them.
WrapSingleMailTake("TakeMailAttachedItems")
WrapSingleMailTake("TakeMailAttachedMoney")

--------------------------------------------------------------------------------

local function OnTakeAllResponse()
    if not batch then return end
    batch.awaitingResponses = zo_max(0, batch.awaitingResponses - 1)
    -- Finalize whatever the result: a partial take (full bags) still delivered something,
    -- and a complete failure just diffs to nothing.
    ScheduleFinalize()
end

function LLE.InitializeMail()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_READABLE, OnMailReadable)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, ScheduleFinalize)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS, ScheduleFinalize)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnTakeAllResponse)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_CLOSE_MAILBOX, function()
        -- Closing the mailbox mid-read: send the Take All with what we have.
        if readQueue then
            readQueue.deadline = 0
            ReadNext()
        end
    end)
end
