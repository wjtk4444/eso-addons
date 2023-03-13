local originalCallback = LootLog.IsItemNotable
LootLog.IsItemNotable = function ( itemLink, itemId )
	local itemType, specializedItemType = GetItemLinkItemType(itemLink)
	if specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH then
		return true
	end
	
	return originalCallback(itemLink, itemId)
end