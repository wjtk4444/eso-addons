-- Mail: notable items and gold taken from mail, one chat line per mail:
--   (Mail) Woodworker Hireling: 1x [Rosin]
--   (Mail) Item Sold 1x [Dreugh Wax] for 10,000 gold
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
-- Guild store "Item Sold" mails carry only gold, but their text names the sold item as an item
-- link ("An item you listed has sold. (<item>)"). The text is readable once the mail has been
-- read, so sale mails are read before a Take All too. With AwesomeGuildStore the text is its
-- own ("You sold 1x <item> to @buyer for ..."): it wraps ReadMail and fills the sale in from
-- the guild history once the mail has been shown.
--
-- The text can lose the item again later ("(Data not available)"), so a sale is remembered as
-- soon as a text names it: whenever the mail is read or shown in the mail window. If the item
-- is still unknown when the gold arrives, it is looked up in the guild history (LibHistoire),
-- matched by time and amount like AwesomeGuildStore does it.

local LLE = LootLogExtras
local NAME = LLE.ADDON_NAME .. "Mail"
local DEBOUNCE_NAME = NAME .. "Debounce"
-- If a take is never answered, finalize anyway so the batch can't swallow unrelated gains.
local SAFETY_TIMEOUT_NAME = NAME .. "Safety"
local SAFETY_TIMEOUT_MS = 15000
-- Reading mails before Take All
local READ_TIMEOUT_NAME = NAME .. "ReadTimeout"
local READ_TIMEOUT_MS = 3000
local READ_GAP_MS = 50
local READ_RETRY_MS = 200
-- How often a sale mail whose text still says "(Data not available)" is read again.
local SALE_TEXT_RETRIES = 5
-- Overall limit for the reads before a Take All: a base plus a share per unread mail, capped.
local READ_ALL_BASE_MS = 5000
local READ_ALL_PER_MAIL_MS = 2500
local READ_ALL_MAX_MS = 60000
-- Guild history lookup for sales whose item the mail text didn't give
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
-- Guild store sales
--------------------------------------------------------------------------------

local function IsPossibleSale(mail)
    return mail.fromSystem and mail.numAttachments == 0 and mail.money > 0
end

-- The sold item from the mail text ("An item you listed has sold. (<item>)"): the first item
-- link in it, or if there is none, the text in the parentheses. A count is taken from "x<n>"
-- right after the item, if the text has one.
--
-- The game fills the item into the text when the mail is read. When it can't (the data isn't
-- there at that moment), it puts "(Data not available)" (SI_MAIL_PARAM_NOT_FOUND) in its place,
-- even for a mail that showed the item fine when opened earlier. Such a text counts as not
-- read yet: the mail is read again before the Take All, and the placeholder is never logged.
local function GetMailBody(mailId)
    if not IsReadMailInfoReady(mailId) then return nil end
    local body = ReadMail(mailId)
    if type(body) ~= "string" or body == "" then return nil end
    return body
end

local paramNotFound = nil
local function HasMissingParam(body)
    if not paramNotFound then
        -- Without the parentheses, so the check doesn't depend on how they are written.
        paramNotFound = GetString(SI_MAIL_PARAM_NOT_FOUND):gsub("^%s*[%(（]", ""):gsub("[%)）]%s*$", "")
    end
    return paramNotFound ~= "" and body:find(paramNotFound, 1, true) ~= nil
end

local function IsSaleTextReady(mailId)
    local body = GetMailBody(mailId)
    return body ~= nil and not HasMissingParam(body)
end

local function GetSaleFromMailText(mailId)
    local body = GetMailBody(mailId)
    if not body then return nil end
    if LLE.debugSales and not body:find("|H%d:item:") then
        LLE.Msg("sale mail text: %s", (body:gsub("|", "||")))
    end
    if HasMissingParam(body) then return nil end

    local before, itemLink, rest = body:match("^(.-)(|H%d:item:[^|]+|h[^|]*|h)(.*)$")
    if itemLink then
        -- "<item> x3" in the game's text, "3x <item>" in AwesomeGuildStore's (with color codes).
        local quantity = tonumber(rest:match("^%s*[xX]%s*(%d+)"))
        if not quantity then
            before = before:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
            quantity = tonumber(before:match("(%d+)%s*[xX]%s*$"))
        end
        return { itemLink = itemLink, quantity = quantity }
    end

    local text = body:match("%(([^()]+)%)")
    if text then
        text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
        local name, count = text:match("^(.-)%s*[xX]%s*(%d+)%s*$")
        return { name = (name or text):match("^%s*(.-)%s*$"), quantity = tonumber(count) }
    end
end

-- Sales a mail text has named so far, by mail. Kept until the mail is gone: a later read may
-- only give "(Data not available)".
local knownSales = {}

-- The sale from the mail's text if it names one now, else what an earlier text named.
local function RememberSale(mailId)
    local key = zo_getSafeId64Key(mailId)
    local known = knownSales[key]
    if known and known.itemLink then return known end

    local _, _, _, _, _, fromSystem, fromCS, _, numAttachments, attachedMoney = GetMailItemInfo(mailId)
    if not ((fromSystem or fromCS) and numAttachments == 0 and (attachedMoney or 0) > 0) then
        return known
    end
    local sale = GetSaleFromMailText(mailId)
    if sale and (sale.itemLink or not known) then
        knownSales[key] = sale
        return sale
    end
    return known
end

-- A sale mail needs no more reads once its item is known or its text is complete.
local function IsSaleResolved(mailId)
    return RememberSale(mailId) ~= nil or IsSaleTextReady(mailId)
end

-- Guild history events already matched to a mail this session, so two sales of the same
-- amount close together don't both get the same item.
local usedSaleEvents = {}

-- Looks the sold items up in the guild history, for sale mails whose text never named the item.
-- callback(salesByMail) with salesByMail[mail] = { itemLink, quantity } for the matched mails.
local function FindSalesInGuildHistory(mails, callback)
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

        local function Match()
            local salesByMail = {}
            for _, mail in ipairs(mails) do
                local best, bestDiff
                for _, event in ipairs(events) do
                    if not usedSaleEvents[event.eventId] then
                        local listingFee, _, profit = GetTradingHousePostPriceInfo(event.price)
                        if mail.money == profit + listingFee then
                            local diff = math.abs(event.time - mail.receivedAt)
                            if not bestDiff or diff < bestDiff then
                                best, bestDiff = event, diff
                            end
                        end
                    end
                end
                if best then
                    usedSaleEvents[best.eventId] = true
                    salesByMail[mail] = { itemLink = best.itemLink, quantity = best.quantity }
                end
            end
            Finish(salesByMail)
        end

        -- Counted before starting, in case a processor finishes right away.
        local running = 1
        local function OneDone()
            running = running - 1
            if running == 0 then
                Protected("guild history match", Match)
            end
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
-- Mail contents
--------------------------------------------------------------------------------

-- { mailId, sender, subject, fromSystem, money, items = { { itemLink, quantity } } or nil
--   when the attachments aren't readable, sale = { itemLink, quantity } for "Item Sold" mails,
--   needsRead (a sale mail whose text isn't readable yet), receivedAt }
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
    if IsPossibleSale(mail) then
        mail.sale = RememberSale(mailId)
        mail.needsRead = not IsSaleResolved(mailId)
    end
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

-- System mail (hirelings, rewards, the guild store) by its subject, player mail by sender.
local function GetLabel(mail)
    if mail.label then return mail.label end
    if mail.fromSystem and mail.subject ~= "" then return mail.subject end
    if mail.sender ~= "" then return mail.sender end
    return mail.subject ~= "" and mail.subject or "no subject"
end


--------------------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------------------

-- items: what actually arrived from this mail; money: gold that actually arrived.
-- Returns true if a chat line was written right away (or will be, for a sale lookup).
-- Gold is only logged for player mail and guild store sales; gold that comes with system
-- mail (quest rewards, hirelings, ...) is left out.
local ITEM_SOLD_SUBJECT = "Item Sold"
local function IsGoldLogged(mail, sale)
    return not mail.fromSystem or sale ~= nil or mail.subject == ITEM_SOLD_SUBJECT
end

local function LogMail(mail, items, money, sale)
    local notable = {}
    if LLE.IsEnabled("logMail") then
        notable = LLE.FilterNotable(items)
        for _, item in ipairs(notable) do
            LLE.LogItemQuietly(item.itemLink, item.quantity, true)
        end
    end
    local showGold = LLE.IsEnabled("logGold") and money > 0 and IsGoldLogged(mail, sale)

    -- "(Mail) Item Sold 1x [item] for 10,000 gold", or without the item if it stayed unknown.
    if showGold and (sale or IsPossibleSale(mail)) then
        local saleLabel = mail.subject ~= "" and mail.subject or GetLabel(mail)
        if sale then
            LootLog.Msg(string.format("(Mail) %s %s for %s", saleLabel,
                sale.itemLink and LLE.FormatItem(sale.itemLink, sale.quantity)
                    or (sale.quantity and string.format("%dx %s", sale.quantity, sale.name) or sale.name),
                LLE.FormatGold(money)))
        else
            LootLog.Msg(string.format("(Mail) %s for %s", saleLabel, LLE.FormatGold(money)))
        end
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

local CloseDeferredMailbox

local function FinalizeBatch()
    if CloseDeferredMailbox then CloseDeferredMailbox() end
    EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
    EVENT_MANAGER:UnregisterForUpdate(SAFETY_TIMEOUT_NAME)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_MONEY_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(DEBOUNCE_NAME, EVENT_LOOT_RECEIVED)
    if not batch then return end

    local current = batch
    batch = nil

    local remaining = {}
    for _, gain in ipairs(LLE.DiffSnapshots(current.before, LLE.SnapshotOwnedItems())) do
        remaining[gain.itemLink] = gain.quantity
    end
    -- Not from mail: LootLog has its own line for those.
    for itemLink, quantity in pairs(remaining) do
        local itemId = GetItemLinkItemId(itemLink)
        local looted = current.lootedById[itemId]
        if looted and looted > 0 then
            local skip = zo_min(looted, quantity)
            remaining[itemLink] = quantity - skip
            current.lootedById[itemId] = looted - skip
        end
    end
    local moneyLeft = zo_max(0, GetCurrentMoney() - current.moneyBefore - current.otherMoney)

    local results = {}
    for _, mail in ipairs(current.mails) do
        local taken = {}
        for _, item in ipairs(mail.items or {}) do
            local wanted = item.quantity
            -- The attachment's link and the link of the same item in the bag don't always
            -- match exactly (some link fields differ), so fall back to the item id.
            local candidates = { item.itemLink }
            local itemId = GetItemLinkItemId(item.itemLink)
            for itemLink, quantity in pairs(remaining) do
                if quantity > 0 and itemLink ~= item.itemLink and GetItemLinkItemId(itemLink) == itemId then
                    candidates[#candidates + 1] = itemLink
                end
            end
            for _, itemLink in ipairs(candidates) do
                local quantity = zo_min(wanted, remaining[itemLink] or 0)
                if quantity > 0 then
                    taken[#taken + 1] = { itemLink = itemLink, quantity = quantity }
                    remaining[itemLink] = remaining[itemLink] - quantity
                    wanted = wanted - quantity
                end
                if wanted == 0 then break end
            end
        end
        local money = zo_min(mail.money, moneyLeft)
        moneyLeft = moneyLeft - money
        if #taken > 0 or money > 0 then
            results[#results + 1] = { mail = mail, items = taken, money = money }
        end
    end

    -- Whatever couldn't be matched to a mail (mails that couldn't be read in time)
    local leftovers = {}
    for itemLink, quantity in pairs(remaining) do
        if quantity > 0 then
            leftovers[#leftovers + 1] = { itemLink = itemLink, quantity = quantity }
        end
    end
    if LLE.debugSales then
        local unreadable, unreadSales = 0, 0
        for _, mail in ipairs(current.mails) do
            if not mail.items then unreadable = unreadable + 1 end
            if IsPossibleSale(mail) and not mail.sale then unreadSales = unreadSales + 1 end
        end
        LLE.Msg("mail batch: %d mail(s), %d with unreadable attachments, %d sale(s) without item, %d item(s) not matched to a mail",
            #current.mails, unreadable, unreadSales, #leftovers)
        for _, item in ipairs(leftovers) do
            LLE.Msg("  not matched: %s x%d", item.itemLink, item.quantity)
        end
    end
    if #leftovers > 0 or moneyLeft > 0 then
        -- If the mails that couldn't be read all have the same subject (20 "Rewards for the
        -- Worthy!" mails), label the rest with it instead of "Take All".
        local label, subject, count = current.source, nil, 0
        for _, mail in ipairs(current.mails) do
            if not mail.items then
                count = count + 1
                if subject == nil then
                    subject = mail.subject
                elseif subject ~= mail.subject then
                    subject = false
                end
            end
        end
        if subject and subject ~= "" then
            label = count > 1 and string.format("%s (%d mails)", subject, count) or subject
        end
        results[#results + 1] = { mail = { label = label, sender = "", subject = "" }, items = leftovers, money = moneyLeft }
    end

    -- Sales whose item no mail text named: look them up in the guild history first, and keep
    -- all lines of the batch in order until it has answered.
    local unknownSales = {}
    if LLE.IsEnabled("logGold") then
        for _, result in ipairs(results) do
            local mail = result.mail
            if not mail.sale and IsPossibleSale(mail) and result.money == mail.money then
                unknownSales[#unknownSales + 1] = mail
            end
        end
    end

    local function LogResults(salesByMail)
        if LLE.debugSales and #unknownSales > 0 then
            local found = 0
            for _ in pairs(salesByMail) do found = found + 1 end
            LLE.Msg("guild history: %d of %d sale(s) found", found, #unknownSales)
        end
        for _, result in ipairs(results) do
            Protected("LogMail", LogMail, result.mail, result.items, result.money,
                result.mail.sale or salesByMail[result.mail])
        end
    end

    if #unknownSales > 0 then
        local ok = pcall(FindSalesInGuildHistory, unknownSales, LogResults)
        if not ok then LogResults({}) end
    else
        LogResults({})
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
            -- Gains during the batch that didn't come from mail: a container opened right away
            -- (AutoUnbox, Unboxer) or anything looted meanwhile. LootLog logs those itself.
            lootedById = {},
            otherMoney = 0,
        }
        -- Items and gold arrive as several updates; keep pushing the diff back until it's quiet.
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ScheduleFinalize)
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_MONEY_UPDATE, function(_, newMoney, oldMoney, reason)
            if batch and CURRENCY_CHANGE_REASON_MAIL and reason ~= CURRENCY_CHANGE_REASON_MAIL then
                batch.otherMoney = batch.otherMoney + ((newMoney or 0) - (oldMoney or 0))
            end
            ScheduleFinalize()
        end)
        EVENT_MANAGER:RegisterForEvent(DEBOUNCE_NAME, EVENT_LOOT_RECEIVED, function(_, _, itemLink, quantity, _, lootType, isSelf, _, _, itemId)
            if batch and isSelf and lootType == LOOT_TYPE_ITEM then
                itemId = itemId or GetItemLinkItemId(itemLink)
                if itemId then
                    batch.lootedById[itemId] = (batch.lootedById[itemId] or 0) + (quantity or 1)
                end
            end
        end)
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

-- { ids, index, onDone, deadline, waitingFor } while reading before a Take All.
--
-- The server answers one read request at a time and refuses a Take All ("Action failed, try
-- again later") while a read is still pending, so: each read is waited for (EVENT_MAIL_READABLE),
-- a short gap is left between reads, a read the UI or another addon has pending is retried
-- instead of skipped, and the Take All is only sent once nothing is pending.
local readQueue = nil

-- Closing the mail window while the mails are still being read doesn't end the reading: the
-- mailbox stays open behind the scenes until the Take All has been answered, then closes.
local closeDeferred = false

-- The game's loot history (bottom right) only lists new items in a few scenes, the mail
-- window among them, not on the plain HUD. When the window was closed before the Take All
-- went out, the loot history is shown on the HUD for a while so the items still appear.
local LOOT_HISTORY_ON_HUD_MS = 8000

local function ShowLootHistoryOnHud()
    if IsInGamepadPreferredMode() or not KEYBOARD_LOOT_HISTORY_FRAGMENT then return end
    local sceneName = SCENE_MANAGER:GetCurrentSceneName()
    if sceneName ~= "hud" and sceneName ~= "hudui" then return end
    -- Only when it isn't showing items anyway; hiding the fragment again later puts it back
    -- into exactly this state.
    if not (LOOT_HISTORY_KEYBOARD and LOOT_HISTORY_KEYBOARD.hidden) then return end
    SCENE_MANAGER:AddFragment(KEYBOARD_LOOT_HISTORY_FRAGMENT)
    zo_callLater(function()
        SCENE_MANAGER:RemoveFragment(KEYBOARD_LOOT_HISTORY_FRAGMENT)
    end, LOOT_HISTORY_ON_HUD_MS)
end

local function FinishReading()
    local queue = readQueue
    readQueue = nil
    EVENT_MANAGER:UnregisterForUpdate(READ_TIMEOUT_NAME)
    if queue and LLE.debugSales then
        LLE.Msg("read %d of %d mail(s) in %.1f s, %d read(s) timed out%s", zo_min(queue.index, #queue.ids), #queue.ids,
            (GetFrameTimeMilliseconds() - queue.startedAt) / 1000, queue.timeouts,
            GetFrameTimeMilliseconds() > queue.deadline and ", stopped at the time limit" or "")
    end
    if queue then
        if closeDeferred then
            ShowLootHistoryOnHud()
        end
        queue.onDone()
    end
end

local function ScheduleRead(delayMs, func)
    EVENT_MANAGER:UnregisterForUpdate(READ_TIMEOUT_NAME)
    EVENT_MANAGER:RegisterForUpdate(READ_TIMEOUT_NAME, delayMs, function()
        EVENT_MANAGER:UnregisterForUpdate(READ_TIMEOUT_NAME)
        func()
    end)
end

local ReadNext

local function ReadCurrent()
    local queue = readQueue
    if not queue then return end
    local mailId = queue.ids[queue.index]
    local overDeadline = GetFrameTimeMilliseconds() > queue.deadline

    if not mailId or overDeadline then
        -- Let a read that is still on its way finish before the Take All goes out.
        if queue.waitingFor and not queue.finalWait then
            queue.finalWait = true
            ScheduleRead(READ_TIMEOUT_MS, FinishReading)
        elseif not queue.waitingFor then
            FinishReading()
        end
        return
    end

    local readable = IsReadMailInfoReady(mailId)
    if readable and (not queue.sales[zo_getSafeId64Key(mailId)] or IsSaleResolved(mailId)) then
        ReadNext()
        return
    end
    local result = RequestReadMail(mailId)
    if result == REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED then
        -- A sale text that still has no item: try a few more times, then move on.
        if queue.sales[zo_getSafeId64Key(mailId)] and not IsSaleResolved(mailId) and queue.saleRetries < SALE_TEXT_RETRIES then
            queue.saleRetries = queue.saleRetries + 1
            ScheduleRead(READ_RETRY_MS, ReadCurrent)
            return
        end
        queue.saleRetries = 0
        ReadNext()
    elseif result == REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED or result == REQUEST_READ_MAIL_RESULT_ALREADY_REQUESTED then
        -- EVENT_MAIL_READABLE moves on; the timeout makes sure a lost answer can't stall it.
        queue.waitingFor = mailId
        ScheduleRead(READ_TIMEOUT_MS, function()
            queue.waitingFor = nil
            queue.timeouts = queue.timeouts + 1
            ReadNext()
        end)
    elseif result == REQUEST_READ_MAIL_RESULT_ANOTHER_REQUEST_PENDING then
        -- Someone else's read (e.g. the mail shown in the inbox): try this one again shortly.
        ScheduleRead(READ_RETRY_MS, ReadCurrent)
    else
        ReadNext()
    end
end

ReadNext = function()
    local queue = readQueue
    if not queue then return end
    queue.index = queue.index + 1
    queue.saleRetries = 0
    if queue.index == 1 then
        ReadCurrent()
    else
        ScheduleRead(READ_GAP_MS, ReadCurrent)
    end
end

local function OnMailReadable(_, mailId)
    Protected("RememberSale", RememberSale, mailId)
    local queue = readQueue
    if queue and queue.waitingFor and AreId64sEqual(queue.waitingFor, mailId) then
        queue.waitingFor = nil
        if queue.finalWait then
            FinishReading()
        elseif queue.sales[zo_getSafeId64Key(mailId)] and not IsSaleResolved(mailId)
            and queue.saleRetries < SALE_TEXT_RETRIES then
            -- Read, but the sale text has no item yet: give it a moment.
            queue.saleRetries = queue.saleRetries + 1
            ScheduleRead(READ_RETRY_MS, ReadCurrent)
        else
            ReadNext()
        end
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
            if not IsActive() then
                return original(category, deleteOnClaim, ...)
            end
            -- A second click while the mails are still being read: the take is already queued,
            -- and sending another one now would only be refused by the server.
            if readQueue then
                return
            end

            local unread, sales = {}, {}
            local ok = pcall(function()
                for _, mail in ipairs(GetMailsInCategory(category)) do
                    if not mail.items or mail.needsRead then
                        unread[#unread + 1] = mail.mailId
                    end
                    if IsPossibleSale(mail) then
                        sales[zo_getSafeId64Key(mail.mailId)] = true
                    end
                end
            end)
            if not ok or #unread == 0 then
                return StartCategoryTake(original, category, deleteOnClaim)
            end

            readQueue =
            {
                ids = unread,
                index = 0,
                deadline = GetFrameTimeMilliseconds() + zo_min(READ_ALL_MAX_MS, READ_ALL_BASE_MS + READ_ALL_PER_MAIL_MS * #unread),
                startedAt = GetFrameTimeMilliseconds(),
                timeouts = 0,
                sales = sales,
                saleRetries = 0,
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

CloseDeferredMailbox = function()
    if closeDeferred and not readQueue then
        closeDeferred = false
        CloseMailbox()
    end
end

local function OnTakeAllResponse()
    zo_callLater(CloseDeferredMailbox, 500)
    if not batch then return end
    batch.awaitingResponses = zo_max(0, batch.awaitingResponses - 1)
    -- Finalize whatever the result: a partial take (full bags) still delivered something,
    -- and a complete failure just diffs to nothing.
    ScheduleFinalize()
end

function LLE.InitializeMail()
    local function ToggleDebug()
        LLE.debugSales = not LLE.debugSales
        LLE.Msg("mail batch details %s", LLE.debugSales and "on" or "off")
    end
    SLASH_COMMANDS["/lledebug"] = ToggleDebug
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_READABLE, OnMailReadable)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, ScheduleFinalize)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS, ScheduleFinalize)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnTakeAllResponse)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MAIL_REMOVED, function(_, mailId)
        knownSales[zo_getSafeId64Key(mailId)] = nil
    end)
    -- The mail shown in the mail window. AwesomeGuildStore refreshes it through here once its
    -- guild history lookup is done, so its text is caught as well.
    if type(ZO_MailInboxShared_UpdateInbox) == "function" then
        SecurePostHook("ZO_MailInboxShared_UpdateInbox", function(mailData)
            if mailData and mailData.mailId and IsActive() then
                Protected("RememberSale", RememberSale, mailData.mailId)
            end
        end)
    end
    ZO_PreHook("CloseMailbox", function()
        if readQueue then
            closeDeferred = true
            return true
        end
    end)
end
