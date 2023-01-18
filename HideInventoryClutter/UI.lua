function HideInventoryClutter:initializeUI()
	HideInventoryClutter_ConsumablesButton:SetAlpha(0.3)
	HideInventoryClutter_ConsumablesButton:ClearAnchors()
	if self.savedVariables.positionConsumable.top == nil and self.savedVariables.positionConsumable.left == nil then
		HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 282, 9)
	else
		HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
		self.savedVariables.positionConsumable.left, self.savedVariables.positionConsumable.top)
	end
	
	HideInventoryClutter_LockedButton:SetAlpha(0.3)
	HideInventoryClutter_LockedButton:ClearAnchors()
	if self.savedVariables.positionLocked.top == nil and self.savedVariables.positionLocked.left == nil then
		HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 300, 0)
	else
		HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
			self.savedVariables.positionLocked.left, self.savedVariables.positionLocked.top)
	end
end

function HideInventoryClutter:getTooltipTextConsumables()
	if self.activeMenu == LF_SMITHING_DECONSTRUCT or self.activeMenu == LF_JEWELRY_DECONSTRUCT or self.activeMenu == LF_ENCHANTING_EXTRACTION then
		return "This filter doesn't affect deconstruction menu"
	end

	return "Consumables " .. (self.consumablesVisible and "visible" or "hidden")
end

function HideInventoryClutter:getTooltipTextLocked()
	if self.activeMenu == LF_INVENTORY or self.activeMenu == LF_BANK_DEPOSIT or self.activeMenu == LF_HOUSE_BANK_DEPOSIT then
		return "Locked items " .. (self.lockedVisible and "visible" or "hidden")
	elseif self.activeMenu == LF_VENDOR_SELL then
		return "Items not worth selling " .. (self.lockedVisible and "visible" or "hidden")
	elseif self.activeMenu == LF_SMITHING_DECONSTRUCT or self.activeMenu == LF_JEWELRY_DECONSTRUCT or self.activeMenu == LF_ENCHANTING_EXTRACTION then
		return "Items not worth deconstructing " .. (self.lockedVisible and "visible" or "hidden")
	end
end

function HideInventoryClutter:showButtons()
	self.buttonsVisible = true
	HideInventoryClutter_ConsumablesButton:SetHidden(false)
	HideInventoryClutter_LockedButton:SetHidden(false)
	self.dbg("buttons -> " .. tostring(self.buttonsVisible))
end

function HideInventoryClutter:hideButtons()
	self.buttonsVisible = false
	HideInventoryClutter_ConsumablesButton:SetHidden(true)
	HideInventoryClutter_LockedButton:SetHidden(true)
	self.dbg("buttons -> " .. tostring(self.buttonsVisible))
end