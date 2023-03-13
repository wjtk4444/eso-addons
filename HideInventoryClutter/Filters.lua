function HideInventoryClutter:isCraftingMaterial(slot) 
    if not self.savedVariables.materialsEnabled then return false end
    if GetItemFilterTypeInfo(slot.bagId, slot.slotIndex) == ITEMFILTERTYPE_CRAFTING or GetItemType(slot.bagId, slot.slotIndex) == ITEMTYPE_LURE then
        return not self.lockedVisible
    end
    
    return false
end

function HideInventoryClutter:isWorthDeconstructing(b, i)
    if not self.savedVariables.deconstructionEnabled then return true end

    if GetItemType(b, i) == ITEMTYPE_TREASURE then
        return self.lockedVisible
    end

    local itemType = GetItemType(b, i)
    if itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
        if not IsItemLinkCrafted(GetItemLink(b, i)) then
            return true
        else
            return self.lockedVisible
        end
    end
    
    local quality = GetItemQuality(b, i)
    if GetItemFilterTypeInfo(b, i) == ITEMFILTERTYPE_JEWELRY then 
        if quality >= ITEM_QUALITY_MAGIC then
            return true
        else
            return self.lockedVisible
        end
    end

    if quality >= ITEM_QUALITY_ARTIFACT then
        return true
    end
    
    return self.lockedVisible
end

function HideInventoryClutter:isWorthSelling(b, i)
    if self:isCraftingMaterial({bagId = b, slotIndex = i}) then return self.lockedVisible end

    if GetItemType(b, i) == ITEMTYPE_TREASURE then
        return true
    end

    local itemType = GetItemType(b, i)
    if itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
        return self.lockedVisible
    end
    
    local quality = GetItemQuality(b, i)
    if GetItemFilterTypeInfo(b, i) == ITEMFILTERTYPE_JEWELRY then 
        if quality >= ITEM_QUALITY_MAGIC then
            return self.lockedVisible
        else
            return true
        end
    end

    if quality >= ITEM_QUALITY_ARTIFACT then
        return self.lockedVisible
    end
    
    return not self:isWorthDeconstructing(b, i)
end

function HideInventoryClutter:isConsumable(slot)
    if not self.savedVariables.consumablesEnabled then return false end
    
    if IsItemStolen(slot.bagId, slot.slotIndex) then return false end

    if self.EXTRA_CONSUMABLES[GetItemId(slot.bagId, slot.slotIndex)] then return not self.consumablesVisible end
    
    local itemType = GetItemType(slot.bagId, slot.slotIndex)
    if self.CONSUMABLE_ITEMTYPES[itemType] ~= nil then
        return not self.consumablesVisible
    end
    
    return false
end

function HideInventoryClutter:isLocked(slot)
    if not self.savedVariables.lockedEnabled then return false end
    if CanItemBePlayerLocked(slot.bagId, slot.slotIndex) and IsItemPlayerLocked(slot.bagId, slot.slotIndex) then
        return not self.lockedVisible
    end
    
    return false
end
