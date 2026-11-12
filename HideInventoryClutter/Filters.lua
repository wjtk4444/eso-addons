function HideInventoryClutter:isCraftingMaterial(slot) 
    if not self.savedVariables.materialsEnabled then return false end
	local b, i = slot.bagId, slot.slotIndex
    return GetItemFilterTypeInfo(b, i) == ITEMFILTERTYPE_CRAFTING or GetItemType(b, i) == ITEMTYPE_LURE 
end

function HideInventoryClutter:isWorthDeconstructing(slot)
    if not self.savedVariables.deconstructionEnabled then return true end
	local b, i = slot.bagId, slot.slotIndex
    --return GetItemQuality(b, i) >= ITEM_QUALITY_ARTIFACT 
	local itemLink = GetItemLink(b, i)
	if IsItemLinkCrafted(itemLink) then return false end
	local deconValue = LibDeconValue:GetDeconValue(itemLink, self.savedVariables.deconstructionValueMinMatPrice)
	local vendorValue = LibDeconValue:GetVendorValue(itemLink)
	return deconValue > vendorValue * self.savedVariables.deconstructionValueMultiplier + self.savedVariables.deconstructionValueMinDifference
end

local ITEMTYPES_NOT_FOR_SALE = {
	[ITEMTYPE_FURNISHING			] = true,
	[ITEMTYPE_RECIPE    			] = true,
	[ITEMTYPE_RACIAL_STYLE_MOTIF	] = true,
	[ITEMTYPE_FISH					] = true,
--	[ITEMTYPE_CRAFTED_ABILITY_SCRIPT] = true,
}

local SPECIALIZED_ITEMTYPES_NOT_FOR_SALE = {
	[SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT] = true,
}

function HideInventoryClutter:isWorthSelling(slot)
	local b, i = slot.bagId, slot.slotIndex
	if GetItemSellInformation(b, i) == ITEM_SELL_INFORMATION_CANNOT_SELL then return false end
	local itemType, specalizedItemType = GetItemType(b, i) 
    if itemType == ITEMTYPE_TREASURE then return true end
	if ITEMTYPES_NOT_FOR_SALE[itemType] then return false end
	if SPECIALIZED_ITEMTYPES_NOT_FOR_SALE[specalizedItemType] then return false end
	if self:isCraftingMaterial(slot) then return false end
	if IsItemLinkCrafted(GetItemLink(b, i)) and not self:isConsumable(slot) then return false end
	-- with the deconstruction filter off isWorthDeconstructing() returns true for everything
	if not self.savedVariables.deconstructionEnabled then return true end
	return not self:isWorthDeconstructing(slot)
end

local CONSUMABLE_ITEMTYPES = {
	[ITEMTYPE_FOOD  ] = true,
	[ITEMTYPE_DRINK ] = true,
	[ITEMTYPE_POTION] = true,
	[ITEMTYPE_POISON] = true,
}

local EXTRA_CONSUMABLES = {
	[30357 ] = true, -- Lockpick
	[44879 ] = true, -- Grand Repair Kit
	[33271 ] = true, -- Soul Gem
}

function HideInventoryClutter:isConsumable(slot)
    if not self.savedVariables.consumablesEnabled then return false end
	local b, i = slot.bagId, slot.slotIndex
    
	if IsItemStolen(b, i) then return false end

	if CONSUMABLE_ITEMTYPES[GetItemType(b, i)] then return true end
    return EXTRA_CONSUMABLES[GetItemId(b, i)] ~= nil
end

function HideInventoryClutter:isLocked(slot)
    if not self.savedVariables.lockedEnabled then return false end
	
	local b, i = slot.bagId, slot.slotIndex
	return CanItemBePlayerLocked(b, i) and IsItemPlayerLocked(b, i)
end

function HideInventoryClutter:isEitherTradeableGearOrDifferentItemType(slot)
	local b, i = slot.bagId, slot.slotIndex
	local itemType = GetItemType(b, i)
	if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON then
		return IsItemBoPAndTradeable(b, i) or self:isConsumable(slot)
	end
	return true
end