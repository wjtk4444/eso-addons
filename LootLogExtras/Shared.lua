-- Shared helpers for the LootLogExtras modules.

LootLogExtras = {}
local LLE = LootLogExtras

LLE.ADDON_NAME = "LootLogExtras"
LLE.DEBOUNCE_MS = 500

LLE.defaults =
{
    logCrafting = true,
    logMail = true,
    logTrade = true,
    logGold = true,
    unknownKnowledgeIsNotable = true,
}

-- nil until EVENT_ADD_ON_LOADED. The global function wrappers below can in theory run
-- before that (another addon calling them during load), so they check IsEnabled.
LLE.sv = nil

function LLE.IsEnabled(settingKey)
    return LLE.sv ~= nil and LLE.sv[settingKey] == true
end

function LLE.Msg(format, ...)
    LootLog.Msg("LootLogExtras: " .. string.format(format, ...))
end

-- Total count per item link in the backpack and the Craft Bag. With ESO Plus, materials
-- go straight into the Craft Bag (BAG_VIRTUAL); ZO_IterateBagSlots handles it like any bag.
-- Without ESO Plus the Craft Bag is simply empty.
function LLE.SnapshotOwnedItems()
    local snapshot = {}
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_VIRTUAL }) do
        local ok, err = pcall(function()
            for slotIndex in ZO_IterateBagSlots(bagId) do
                local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
                if itemLink and itemLink ~= "" then
                    local _, stackCount = GetItemInfo(bagId, slotIndex)
                    if stackCount and stackCount > 0 then
                        snapshot[itemLink] = (snapshot[itemLink] or 0) + stackCount
                    end
                end
            end
        end)
        if not ok then
            LLE.Msg("couldn't scan bag %s (%s)", tostring(bagId), tostring(err))
        end
    end
    return snapshot
end

-- Items gained between two snapshots: { { itemLink, quantity }, ... }.
-- alreadyCounted ([itemLink] = quantity) is subtracted, for gains logged some other way.
function LLE.DiffSnapshots(before, after, alreadyCounted)
    local gains = {}
    for itemLink, afterCount in pairs(after) do
        local delta = afterCount - (before[itemLink] or 0) - (alreadyCounted and alreadyCounted[itemLink] or 0)
        if delta > 0 then
            gains[#gains + 1] = { itemLink = itemLink, quantity = delta }
        end
    end
    return gains
end

-- LootLog.IsItemNotable, plus: anything LibCharacterKnowledge reports as not yet known
-- (recipes, motifs, furnishing plans, scribing scripts) is notable too. LootLog's own check
-- looks at an item's functional quality, which for those items has nothing to do with the
-- color they are shown in, so an unknown green recipe would not count as notable.
function LLE.IsItemNotable(itemLink)
    local ok, notable = pcall(LootLog.IsItemNotable, itemLink)
    if not ok then
        LLE.Msg("IsItemNotable error: %s", tostring(notable))
        notable = false
    end

    if not notable and LibCharacterKnowledge and LLE.IsEnabled("unknownKnowledgeIsNotable") then
        local ok2, unknown = pcall(function()
            local category = LibCharacterKnowledge.GetItemCategory(itemLink)
            if category == LibCharacterKnowledge.ITEM_CATEGORY_NONE then
                return false
            end
            return LibCharacterKnowledge.GetItemKnowledgeForCharacter(itemLink) ~= LibCharacterKnowledge.KNOWLEDGE_KNOWN
        end)
        if ok2 and unknown then
            notable = true
        end
    end

    return notable
end

-- LootLog.LogItem prints its own chat line depending on LootLog's chat mode setting.
-- Items already named in our own chat note would then be printed twice, so the chat mode is
-- switched off for this one call (history is still written) and restored right after.
function LLE.LogItemQuietly(itemLink, quantity, notable)
    local savedChatMode = LootLog.vars.chatMode
    LootLog.vars.chatMode = 0
    local ok, err = pcall(LootLog.LogItem, itemLink, quantity, notable, nil)
    LootLog.vars.chatMode = savedChatMode
    if not ok then
        LLE.Msg("LogItem error: %s", tostring(err))
    end
end

-- Marks each gain notable or not; returns "link xN, link xN" for the notable ones, or nil.
function LLE.DescribeNotable(gains)
    local parts = {}
    for _, gain in ipairs(gains) do
        gain.notable = LLE.IsItemNotable(gain.itemLink)
        if gain.notable then
            parts[#parts + 1] = string.format("%s x%d", gain.itemLink, gain.quantity)
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

-- "10,000 gold"
function LLE.FormatGold(amount)
    return ZO_CommaDelimitNumber(amount) .. " gold"
end

-- "1x [Rosin]"
function LLE.FormatItem(itemLink, quantity)
    return string.format("%dx %s", quantity, itemLink)
end

-- Keeps the notable ones of { { itemLink, quantity }, ... } (sets .notable on every entry).
function LLE.FilterNotable(items)
    local notable = {}
    for _, item in ipairs(items) do
        item.notable = LLE.IsItemNotable(item.itemLink)
        if item.notable then
            notable[#notable + 1] = item
        end
    end
    return notable
end
