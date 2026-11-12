-- Trade: what the other player gave you in a completed trade, as one chat line:
--   (Trade) @friend: 1x [Dreugh Wax], 2x [Tempering Alloy], 10,000 gold
--
-- Every received item goes into the LootLog history (marked notable or not, like loot).
-- Gold only appears in chat, since LootLog's history stores items only.
--
-- The other side's offer can change until both players confirm, and the trade window's
-- contents are gone by the time EVENT_TRADE_SUCCEEDED fires, so the offer is re-read on
-- every change and the last version is logged on success.

local LLE = LootLogExtras
local NAME = LLE.ADDON_NAME .. "Trade"

local partner = nil -- display name (or character name) of the other player
local offer = nil   -- { items = { { itemLink, quantity } }, money }

local function ReadOffer()
    local items = {}
    for i = 1, TRADE_NUM_SLOTS do
        local _, _, stack = GetTradeItemInfo(TRADE_THEM, i)
        if stack and stack > 0 then
            local itemLink = GetTradeItemLink(TRADE_THEM, i, LINK_STYLE_DEFAULT)
            if itemLink and itemLink ~= "" then
                items[#items + 1] = { itemLink = itemLink, quantity = stack }
            end
        end
    end
    offer = { items = items, money = GetTradeMoneyOffer(TRADE_THEM) or 0 }
end

local function OnOfferChanged(_, who)
    if who == nil or who == TRADE_THEM then
        ReadOffer()
    end
end

local function SetPartner(_, characterName, displayName)
    if displayName and displayName ~= "" then
        partner = displayName
    elseif characterName and characterName ~= "" then
        partner = zo_strformat(SI_PLAYER_NAME, characterName)
    end
end

local function OnTradeSucceeded()
    local received = offer
    offer = nil
    if not received then return end

    local ok, err = pcall(function()
        local parts = {}
        if LLE.IsEnabled("logTrade") then
            for _, item in ipairs(received.items) do
                item.notable = LLE.IsItemNotable(item.itemLink)
                LLE.LogItemQuietly(item.itemLink, item.quantity, item.notable)
                parts[#parts + 1] = LLE.FormatItem(item.itemLink, item.quantity)
            end
        end
        if LLE.IsEnabled("logGold") and received.money > 0 then
            parts[#parts + 1] = LLE.FormatGold(received.money)
        end
        if #parts > 0 then
            LootLog.Msg(string.format("(Trade) %s: %s", partner or "trade", table.concat(parts, ", ")))
        end
    end)
    if not ok then
        LLE.Msg("trade error: %s", tostring(err))
    end
end

local function OnTradeEnded()
    offer = nil
end

function LLE.InitializeTrade()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_INVITE_CONSIDERING, SetPartner)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_INVITE_WAITING, SetPartner)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_INVITE_ACCEPTED, function() offer = { items = {}, money = 0 } end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_ITEM_ADDED, OnOfferChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_ITEM_REMOVED, OnOfferChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_ITEM_UPDATED, OnOfferChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_MONEY_CHANGED, OnOfferChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_CONFIRMATION_CHANGED, function() ReadOffer() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_SUCCEEDED, OnTradeSucceeded)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_CANCELED, OnTradeEnded)
    -- A failed accept (e.g. not enough gold) doesn't end the trade.
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TRADE_FAILED, function() ReadOffer() end)
end
