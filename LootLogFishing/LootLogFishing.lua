-- NOTE: Since LootLog 4.7.3 (2025/02/03), LootLog.IsItemNotable() already
-- treats SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH as notable on its own,
-- so this hook no longer changes any behavior against a current LootLog.
-- Left in place (and kept dependency-safe below) in case this is ever run
-- against an older LootLog version that predates that change.

local originalCallback = LootLog.IsItemNotable

if (type(originalCallback) == "function") then
	LootLog.IsItemNotable = function ( itemLink, itemId )
		local itemType, specializedItemType = GetItemLinkItemType(itemLink)
		if specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH then
			return true
		end

		return originalCallback(itemLink, itemId)
	end
end
