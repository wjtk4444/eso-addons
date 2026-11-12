-- LootLogMail
--
-- LootLog only listens for EVENT_LOOT_RECEIVED, which never fires for items
-- taken out of mail, so mail loot (including system mail payouts) doesn't
-- get logged at all today. This addon bridges that gap.
--
-- Unlike LootLogCraft (which logs every material regardless of
-- notability, matching how LootLog logs all world loot), mail only logs
-- NOTABLE attachments to history at all. This is deliberate: routine mail
-- (guild store sale/purchase confirmations above all) would otherwise
-- flood the history with entries nobody wants to look at again.
--
-- There are two ways the base game takes mail attachments (verified against
-- the live ESO UI source + ESOUIDocumentation for API 101051, 2026-11):
--
-- 1. Per mail: the "Take" keybind on an opened mail ->
--    ZO_MailInboxShared_TakeAll(mailId) -> TakeMailAttachments(mailId,
--    deleteOnClaim). Completion: EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS
--    (mailId). That event only says *which* mail - not what was in it - so
--    each mail's attachments are snapshotted (GetAttachedItemInfo/
--    GetAttachedItemLink) as soon as it becomes readable (EVENT_MAIL_READABLE,
--    which fires when you select it), cached by mailId, and consumed when the
--    take succeeds. This path works.
--
-- 2. Per category: the "Take All (System)" / "Take All (Player)" keybind ->
--    MAIL_CONFIRM_TAKE_ALL dialog -> TakeAllMailAttachmentsInCategory(
--    category, deleteOnClaim). ONE server request for every mail in the
--    category, most of which were never opened, so there's no
--    EVENT_MAIL_READABLE / attachment snapshot for them. Completion:
--    EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE(result, category,
--    headersRemoved) - not a per-mail event. Before 1.4.0 this addon didn't
--    know this path existed at all (an earlier version assumed bulk takes
--    went through TakeMailAttachedItems, which nothing in the base game even
--    calls any more), which is why hireling mail taken with "Take All
--    (System)" never logged anything.
--
--    Fix: TakeAllMailAttachmentsInCategory is wrapped, a snapshot of the bags
--    is taken right before the request goes out, and once the response has
--    arrived and the inventory has stopped changing, the bag diff is what
--    was received (same approach LootLogCraft uses for crafting results).
--    There's no per-mail subject to show for these - nothing was read.
--
-- The per-mail take functions (TakeMailAttachments and the older
-- TakeMailAttachedItems, in case some other addon still calls it) are also
-- wrapped, so that a per-mail take of a mail that was somehow never read
-- (no snapshot) falls back to the same bag diff instead of being dropped.
--
-- Gains already accounted for by the snapshot path during a bag-diff window
-- are subtracted out of the diff, so a mixed burst (e.g. the server also
-- firing per-mail success events for an opened mail during a category take)
-- doesn't double-count.

local ADDON_NAME = "LootLogMail"
local DEBOUNCE_NAME = ADDON_NAME .. "BulkDebounce"
local DEBOUNCE_MS = 500
-- If a category take's response never arrives (shouldn't happen, but the
-- request is server-side), finalize anyway after this long so the batch
-- can't linger and swallow unrelated gains later.
local SAFETY_TIMEOUT_NAME = ADDON_NAME .. "BulkSafety"
local SAFETY_TIMEOUT_MS = 15000

-- keyed by zo_getSafeId64Key(mailId) -> { subject = string, items = { { link = itemLink, quantity = n }, ... } }
local pendingMail = {}

-- Bag-diff batch for attachments taken without a cached snapshot.
-- {
--   before = { [itemLink] = totalCount, ... },
--   consumedByKnownMail = { [itemLink] = qty, ... },
--   awaitingCategoryResponse = number of category take requests still unanswered,
--   source = string shown in the chat note,
-- } or nil
local bulkPending = nil

-- Wrapped in pcall per-bag, same reasoning as LootLogCraft: if BAG_VIRTUAL
-- (the Craft Bag) doesn't scan the way BAG_BACKPACK does, we want a
-- visible diagnostic rather than a silently wrong/empty result. Craft
-- materials can arrive via mail too (e.g. a hireling), and with ESO+
-- those route into the Craft Bag instead of the backpack.
local function ScanBagSafely( snapshot, bagId )
    local ok, err = pcall(function()
        for slotIndex in ZO_IterateBagSlots(bagId) do
            local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
            if (itemLink and itemLink ~= "") then
                local _, stackCount = GetItemInfo(bagId, slotIndex)
                if (stackCount and stackCount > 0) then
                    snapshot[itemLink] = (snapshot[itemLink] or 0) + stackCount
                end
            end
        end
    end)

    if (not ok) then
        LootLog.Msg(string.format("LootLogMail: couldn't scan bag %s (%s)", tostring(bagId), tostring(err)))
    end
end

local function SnapshotOwnedMaterials()
    local snapshot = {}
    ScanBagSafely(snapshot, BAG_BACKPACK)
    ScanBagSafely(snapshot, BAG_VIRTUAL)
    return snapshot
end

-- LootLog.IsItemNotable's generic quality-threshold path (the only path
-- available to mail, which has no lootType to special-case on) looks at
-- an item's FUNCTIONAL quality, which for recipes/motifs/furnishing
-- plans/scribing scripts has nothing to do with the quality COLOR the
-- item is displayed in - so it can't tell whether a recipe/motif is worth
-- a note (whether it's already known).
--
-- LibCharacterKnowledge (optional dependency) tracks exactly that. If it's
-- present, anything it says isn't known yet is treated as notable,
-- regardless of display color. This is additive to LootLog's own check,
-- never a replacement for it, and silently does nothing if the library
-- isn't installed.
local function IsItemNotableExtended( itemLink )
    local ok, notable = pcall(LootLog.IsItemNotable, itemLink)
    if (not ok) then
        LootLog.Msg(string.format("LootLogMail: IsItemNotable error: %s", tostring(notable)))
        notable = false
    end

    if (not notable and LibCharacterKnowledge) then
        local ok2, unknown = pcall(function()
            local category = LibCharacterKnowledge.GetItemCategory(itemLink)
            if (category == LibCharacterKnowledge.ITEM_CATEGORY_NONE) then return false end
            return LibCharacterKnowledge.GetItemKnowledgeForCharacter(itemLink) ~= LibCharacterKnowledge.KNOWLEDGE_KNOWN
        end)
        if (ok2 and unknown) then notable = true end
    end

    return notable
end

-- Every handler below is pcall-wrapped and reports failures to chat instead
-- of silently doing nothing, so if something IS throwing, it becomes
-- visible instead of indistinguishable from "nothing happened."

local function DoOnMailReadable( mailId )
    local _, _, subject, _, _, fromSystem, _, _, numAttachments = GetMailItemInfo(mailId)
    numAttachments = numAttachments or 0

    if (numAttachments == 0) then return end

    local items = {}
    for i = 1, numAttachments do
        local _, stack = GetAttachedItemInfo(mailId, i)
        local link = GetAttachedItemLink(mailId, i, LINK_STYLE_DEFAULT)

        if (link and link ~= "") then
            table.insert(items, { link = link, quantity = stack or 1 })
        end
    end

    if (#items > 0) then
        pendingMail[zo_getSafeId64Key(mailId)] = { subject = subject, fromSystem = fromSystem, items = items }
    end
end

local function OnMailReadable( eventCode, mailId )
    local ok, err = pcall(DoOnMailReadable, mailId)
    if (not ok) then
        LootLog.Msg(string.format("LootLogMail: OnMailReadable error: %s", tostring(err)))
    end
end

-- LootLog.LogItem's own chat line for an item is gated by LootLog.vars.chatMode,
-- independent of our own note below. For items we've already named in our
-- note, that would mean the same item printed twice whenever chatMode
-- happens to also cover it. Rather than predict chatMode, force it off for
-- just this one call - history/Mats/etc. are untouched, only LogItem's own
-- "if (...) LootLog.Msg(...)" branch is skipped - then restore it
-- immediately, even if LogItem errors.
local function LogItemWithoutDuplicateChat( itemLink, quantity, notable )
    local savedChatMode = LootLog.vars.chatMode
    LootLog.vars.chatMode = 0

    local ok, err = pcall(LootLog.LogItem, itemLink, quantity, notable, nil)

    LootLog.vars.chatMode = savedChatMode

    if (not ok) then
        LootLog.Msg(string.format("LootLogMail: LogItem error: %s", tostring(err)))
    end
end

-- Finalizes the bag diff for attachments taken without going through the
-- per-mail snapshot path (see the top comment).
local function FinalizeBulkMailTake()
    EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
    EVENT_MANAGER:UnregisterForUpdate(SAFETY_TIMEOUT_NAME)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

    if (not bulkPending) then return end

    local pending = bulkPending
    bulkPending = nil

    local after = SnapshotOwnedMaterials()

    local gains = {}
    local anyNotable = false

    for itemLink, afterCount in pairs(after) do
        local delta = (afterCount - (pending.before[itemLink] or 0)) - (pending.consumedByKnownMail[itemLink] or 0)
        if (delta > 0) then
            local notable = IsItemNotableExtended(itemLink)
            table.insert(gains, { itemLink = itemLink, delta = delta, notable = notable })
            if (notable) then anyNotable = true end
        end
    end

    if (anyNotable) then
        local parts = {}
        for _, gain in ipairs(gains) do
            if (gain.notable) then
                table.insert(parts, string.format("%s x%d", gain.itemLink, gain.delta))
            end
        end
        LootLog.Msg(string.format("From mail (%s): %s", pending.source, table.concat(parts, ", ")))
    end

    -- Notable only - see the top comment.
    for _, gain in ipairs(gains) do
        if (gain.notable) then
            LogItemWithoutDuplicateChat(gain.itemLink, gain.delta, gain.notable)
        end
    end
end

-- (Re)arms the finalize timer, unless a category take is still waiting for
-- its server response - in that case the response handler arms it.
local function ScheduleBulkFinalize()
    if (bulkPending and bulkPending.awaitingCategoryResponse == 0) then
        EVENT_MANAGER:RegisterForUpdate(DEBOUNCE_NAME, DEBOUNCE_MS, FinalizeBulkMailTake)
    end
end

local function OnBulkInventoryUpdate()
    -- Items from a take can trickle in as several slot updates; keep pushing
    -- the finalize back until the inventory has been quiet for DEBOUNCE_MS.
    ScheduleBulkFinalize()
end

local function BeginBulkMailTake( source )
    if (not bulkPending) then
        bulkPending = {
            before = SnapshotOwnedMaterials(),
            consumedByKnownMail = {},
            awaitingCategoryResponse = 0,
            source = source,
        }
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBulkInventoryUpdate)
    elseif (bulkPending.source ~= source) then
        bulkPending.source = "Take All"
    end
    EVENT_MANAGER:RegisterForUpdate(SAFETY_TIMEOUT_NAME, SAFETY_TIMEOUT_MS, FinalizeBulkMailTake)
end

local function DoOnMailTakeAttachedItemSuccess( mailId )
    local key = zo_getSafeId64Key(mailId)
    local snapshot = pendingMail[key]

    if (not snapshot) then
        -- No cached snapshot - taken blind; the bag-diff fallback (if one is
        -- running) covers it. Just keep it from finalizing too early.
        ScheduleBulkFinalize()
        return
    end

    -- Clear immediately so a second firing for this same mailId (whatever
    -- the actual per-mail/per-item cadence turns out to be) is a no-op.
    pendingMail[key] = nil

    local anyNotable = false
    for _, item in ipairs(snapshot.items) do
        item.notable = IsItemNotableExtended(item.link)
        if (item.notable) then anyNotable = true end
    end

    if (anyNotable) then
        -- Names the notable items itself (rather than relying on LogItem's
        -- own chatMode-dependent line), see LogItemWithoutDuplicateChat.
        local parts = {}
        for _, item in ipairs(snapshot.items) do
            if (item.notable) then
                table.insert(parts, string.format("%s x%d", item.link, item.quantity))
            end
        end
        LootLog.Msg(string.format("From mail (%s): %s", (snapshot.subject ~= "") and snapshot.subject or "no subject", table.concat(parts, ", ")))
    end

    -- Notable only - see the top comment.
    for _, item in ipairs(snapshot.items) do
        if (item.notable) then
            LogItemWithoutDuplicateChat(item.link, item.quantity, item.notable)
        end
    end

    -- If a bag-diff batch is running at the same time, record what this known
    -- mail contributed so FinalizeBulkMailTake doesn't count it a second time.
    if (bulkPending) then
        for _, item in ipairs(snapshot.items) do
            bulkPending.consumedByKnownMail[item.link] = (bulkPending.consumedByKnownMail[item.link] or 0) + item.quantity
        end
        ScheduleBulkFinalize()
    end
end

local function OnMailTakeAttachedItemSuccess( eventCode, mailId )
    local ok, err = pcall(DoOnMailTakeAttachedItemSuccess, mailId)
    if (not ok) then
        LootLog.Msg(string.format("LootLogMail: OnMailTakeAttachedItemSuccess error: %s", tostring(err)))
    end
end

local function OnTakeAllInCategoryResponse( eventCode, result, category, headersRemoved )
    local ok, err = pcall(function()
        if (not bulkPending) then return end
        bulkPending.awaitingCategoryResponse = zo_max(0, bulkPending.awaitingCategoryResponse - 1)
        -- Finalize regardless of result: a failure partway through (e.g. bags
        -- full) can still have delivered some items, and the diff is truthful
        -- either way - a total failure just diffs to nothing.
        ScheduleBulkFinalize()
    end)
    if (not ok) then
        LootLog.Msg(string.format("LootLogMail: OnTakeAllInCategoryResponse error: %s", tostring(err)))
    end
end

local function OnMailboxClosed( eventCode )
    -- Housekeeping: drop any snapshots for mail that was opened but never
    -- taken, so they don't linger for the rest of the session.
    ZO_ClearTable(pendingMail)
end

-- The take functions are ordinary global API functions, always available
-- regardless of addon load order, so they're wrapped immediately rather
-- than waiting for EVENT_ADD_ON_LOADED. The base game's own callers (the
-- MAIL_CONFIRM_TAKE_ALL dialog and ZO_MailInboxShared_TakeAll) look them up
-- by global name at call time, so the wrap is always seen.

local function WrapPerMailTake( functionName )
    local original = _G[functionName]
    if (type(original) ~= "function") then return end

    _G[functionName] = function( mailId, ... )
        local ok, err = pcall(function()
            if (not pendingMail[zo_getSafeId64Key(mailId)]) then
                BeginBulkMailTake("unread mail")
                ScheduleBulkFinalize()
            end
        end)
        if (not ok) then
            LootLog.Msg(string.format("LootLogMail: %s hook error: %s", functionName, tostring(err)))
        end

        return original(mailId, ...)
    end
end

WrapPerMailTake("TakeMailAttachments")
WrapPerMailTake("TakeMailAttachedItems")

do
    local original = TakeAllMailAttachmentsInCategory
    if (type(original) == "function") then
        TakeAllMailAttachmentsInCategory = function( category, ... )
            local ok, err = pcall(function()
                local source = (category == MAIL_CATEGORY_SYSTEM_MAIL) and "Take All (System)"
                    or (category == MAIL_CATEGORY_PLAYER_MAIL) and "Take All (Player)"
                    or "Take All"
                BeginBulkMailTake(source)
                bulkPending.awaitingCategoryResponse = bulkPending.awaitingCategoryResponse + 1
                -- Don't finalize on inventory updates until the server has
                -- answered - the response handler re-arms the timer.
                EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
            end)
            if (not ok) then
                LootLog.Msg(string.format("LootLogMail: TakeAllMailAttachmentsInCategory hook error: %s", tostring(err)))
            end

            return original(category, ...)
        end
    end
end

local function OnAddOnLoaded( eventCode, addonName )
    if (addonName ~= ADDON_NAME) then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MAIL_READABLE, OnMailReadable)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, OnMailTakeAttachedItemSuccess)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnTakeAllInCategoryResponse)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MAIL_CLOSE_MAILBOX, OnMailboxClosed)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
