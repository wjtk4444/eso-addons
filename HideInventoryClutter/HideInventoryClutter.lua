HideInventoryClutter = { 
	ADDON_NAME = "HideInventoryClutter",
	log = true  and function(msg) d("[HideInventoryClutter]: "        .. msg) end or function() end,
	dbg = true  and function(msg) d("[HideInventoryClutter][DEBUG]: " .. msg) end or function() end,
	err = true  and function(msg) d("[HideInventoryClutter][ERROR]: " .. msg) end or function() end,
}

function HideInventoryClutter:isCraftingMaterial(slot) 
	if not self.savedVariables.materialsEnabled then return false end
	return GetItemFilterTypeInfo(slot.bagId, slot.slotIndex) == ITEMFILTERTYPE_CRAFTING 
		or GetItemType(slot.bagId, slot.slotIndex) == ITEMTYPE_LURE
end

function HideInventoryClutter:isWorthDeconstructing(b, i)
	if not self.savedVariables.deconstructionEnabled then return true end

	local itemType = GetItemType(b, i)
	if itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
		return not IsItemLinkCrafted(GetItemLink(b, i))
	end
	
	local quality = GetItemQuality(b, i)
	if GetItemFilterTypeInfo(b, i) == ITEMFILTERTYPE_JEWELRY then 
		return quality >= ITEM_QUALITY_MAGIC
	end

	return quality >= ITEM_QUALITY_ARTIFACT
end

function HideInventoryClutter:isConsumable(slot)
	if not self.savedVariables.consumablesEnabled then return false end
	
	if IsItemStolen(slot.bagId, slot.slotIndex) then return false end

	if self.EXTRA_CONSUMABLES[GetItemId(slot.bagId, slot.slotIndex)] then return true end
	
	local itemType = GetItemType(slot.bagId, slot.slotIndex) -- returns: itemType, specializedItemType
	return self.CONSUMABLE_ITEMTYPES[itemType] ~= nil
end

function HideInventoryClutter:isLocked(slot)
	if not self.savedVariables.lockedEnabled then return false end
	return CanItemBePlayerLocked(slot.bagId, slot.slotIndex) and IsItemPlayerLocked(slot.bagId, slot.slotIndex)
end

--------------------------------------------------------------------------------

function HideInventoryClutter:toggleConsumables()
	if self.movableIcon then
		self.log("Toggle is disabled when icons are unlocked " .. (self.movableIcon and "un" or "") .. "locked!")
		return
	end

	for menu, filter in pairs(self.CONSUMABLE_FILTERS) do
		if self.consumablesVisible then
			self.libFilters:RegisterFilter(self.ADDON_NAME .. "consumables" .. tostring(menu), menu, filter)
		else
			self.libFilters:UnregisterFilter(self.ADDON_NAME .. "consumables" .. tostring(menu), menu)
		end
		self.libFilters:RequestUpdate(menu)
	end
	self.consumablesVisible = not self.consumablesVisible
	
	HideInventoryClutter_ConsumablesButton:SetAlpha(self.consumablesVisible and 1 or 0.3)
end

function HideInventoryClutter:toggleLocked()
	if self.movableIcon then
		self.log("Toggle is disabled when icons are unlocked " .. (self.movableIcon and "un" or "") .. "locked!")
		return
	end

	for menu, filter in pairs(self.LOCKED_FILTERS) do
		if self.lockedVisible then		
			self.libFilters:RegisterFilter(self.ADDON_NAME .. "locked" .. tostring(menu), menu, filter)
		else
			self.libFilters:UnregisterFilter(self.ADDON_NAME .. "locked" .. tostring(menu), menu)
		end
		self.libFilters:RequestUpdate(menu)
	end
	self.lockedVisible = not self.lockedVisible
	
	HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
end

--------------------------------------------------------------------------------

function HideInventoryClutter:saveGuiPosition()
	self.savedVariables.positionConsumable.left = math.floor(HideInventoryClutter_ConsumablesButton:GetLeft())
	self.savedVariables.positionConsumable.top  = math.floor(HideInventoryClutter_ConsumablesButton:GetTop())	
	
	self.savedVariables.positionLocked.left = math.floor(HideInventoryClutter_LockedButton:GetLeft())
	self.savedVariables.positionLocked.top  = math.floor(HideInventoryClutter_LockedButton:GetTop())	
end

function HideInventoryClutter:getTooltipTextClutter()
	return "Consumables " .. (self.consumablesVisible and "visible" or "hidden")
end

function HideInventoryClutter:getTooltipTextLocked()
	return "Locked items " .. (self.lockedVisible and "visible" or "hidden")
end

--------------------------------------------------------------------------------

function HideInventoryClutter:showButtons()
	self.buttonsVisible = true
	HideInventoryClutter_ConsumablesButton:SetHidden(false)
	HideInventoryClutter_LockedButton:SetHidden(false)
end

function HideInventoryClutter:hideButtons()
	self.buttonsVisible = false
	HideInventoryClutter_ConsumablesButton:SetHidden(true)
	HideInventoryClutter_LockedButton:SetHidden(true)
end

function HideInventoryClutter:initalize()
	self.consumablesVisible = true
	self.lockedVisible = true
	self.movableIcon = false
	self.buttonsVisible = false
	self.libFilters = LibFilters3
	self.libFilters:InitializeLibFilters()
	
	self.savedVariables = ZO_SavedVars:NewAccountWide("HideInventoryClutterPosition", 1, nil, { 
			positionLocked     = { top = 820, left = 1361 },
			positionConsumable = { top = 811, left = 1379 },
			lockedEnabled = true,
			consumablesEnabled = true,
			materialsEnabled = true,
			deconstructionEnabled = true,
		})

	HideInventoryClutter_ConsumablesButton:SetAlpha(1)
	HideInventoryClutter_ConsumablesButton:ClearAnchors()
	HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
		self.savedVariables.positionConsumable.left, self.savedVariables.positionConsumable.top)
	
	HideInventoryClutter_LockedButton:SetAlpha(1)
	HideInventoryClutter_LockedButton:ClearAnchors()
	HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
		self.savedVariables.positionLocked.left, self.savedVariables.positionLocked.top)

	self.CONSUMABLE_ITEMTYPES = {
		[ITEMTYPE_FOOD  ] = true,
		[ITEMTYPE_DRINK ] = true,
		[ITEMTYPE_POTION] = true,
		[ITEMTYPE_POISON] = true,
	}

	self.EXTRA_CONSUMABLES = {
		[30357 ] = true, -- Lockpick
		[44879 ] = true, -- Grand Repair Kit
		[33271 ] = true, -- Soul Gem
		[121550] = true, -- Scroll of Pelinal's Ferocity
	}

	self.LOCKED_FILTERS = {
		[LF_BANK_DEPOSIT        ] = function(s) return not self:isLocked(s) end,
		[LF_HOUSE_BANK_DEPOSIT  ] = function(s) return not self:isLocked(s) end,
		[LF_BANK_WITHDRAW       ] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_HOUSE_BANK_WITHDRAW ] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_INVENTORY           ] = function(s) return not self:isLocked(s) end,
		[LF_VENDOR_SELL         ] = function(s) 
				if self.savedVariables.deconstructionEnabled then
					return not self:isCraftingMaterial(s) and not self:isWorthDeconstructing(s.bagId, s.slotIndex)
				else
					return not self:isCraftingMaterial(s)
				end
			end,
		[LF_SMITHING_DECONSTRUCT] = function(b, i) return self:isWorthDeconstructing(b, i) end,
		[LF_JEWELRY_DECONSTRUCT ] = function(b, i) return self:isWorthDeconstructing(b, i) end,
	}
	
	self.CONSUMABLE_FILTERS = {
		[LF_BANK_DEPOSIT        ] = function(s) return not self:isConsumable(s) end,
		[LF_HOUSE_BANK_DEPOSIT  ] = function(s) return not self:isConsumable(s) end,
		[LF_GUILDBANK_WITHDRAW  ] = function(s) return not self:isConsumable(s) end,
		[LF_GUILDBANK_DEPOSIT   ] = function(s) return not self:isConsumable(s) end,
		[LF_BANK_WITHDRAW       ] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_HOUSE_BANK_WITHDRAW ] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_VENDOR_SELL         ] = function(s) return not self:isConsumable(s) end,
		[LF_MAIL_SEND           ] = function(s) return not self:isConsumable(s) end,
		[LF_TRADE               ] = function(s) return not self:isConsumable(s) end,
		[LF_INVENTORY           ] = function(s) return not self:isConsumable(s) end,
		[LF_GUILDSTORE_SELL     ] = function(s) return not self:isConsumable(s) end,
	}

	local onShowPlayerInventory = ZO_PlayerInventory:GetHandler("OnShow")
	ZO_PlayerInventory:SetHandler("OnShow", function(...)
		self:showButtons()
		if onShowPlayerInventory then onShowPlayerInventory(...) end
    end)
	
	local onHidePlayerInventory = ZO_PlayerInventory:GetHandler("OnHide")
	ZO_PlayerInventory:SetHandler("OnHide", function(...)
		--if not self.buttonsVisible then 
		self:hideButtons()
		--end
		if onHidePlayerInventory then onHidePlayerInventory(...) end
    end)	
	
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_OPEN_BANK,  function() self:showButtons() end)
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_CLOSE_BANK, function() self:hideButtons() end)
		
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_OPEN_STORE,  function() self:showButtons() end)
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_CLOSE_STORE, function() self:hideButtons() end)

	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT, function() self:showButtons() end)
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_END_CRAFTING_STATION_INTERACT, function() self:hideButtons() end)
	
	self:toggleLocked()
	self:toggleConsumables()
end

function HideInventoryClutter:buildMenu()
    local LAM2 = LibAddonMenu2
	LAM2:RegisterAddonPanel(self.ADDON_NAME  .. "_LAM_PANEL", { type = "panel", name = "Hide Inventory Clutter" })
	local controls = {
		[1] = {
			type = "description",
			width = "full",
			text = 
[[An addon that hides inventory clutter, namely locked items and common consumbles.
See available filters below (hover over them to get a short description).
Check addon's website or see README.md file in addon folder to learn the details.
Full list of affected consumables:
- lockpicks
- grand repair kits
- soul gems
- buff food / drinks
- potions
- poisons]]
		},
		[2] = {
			type = "button",
			name = "toggle lock / unlock icon position",
			func = function() 
				self.movableIcon = not self.movableIcon
				self.log("Icons " .. (self.movableIcon and "un" or "") .. "locked!")
				HideInventoryClutter_ConsumablesButton:SetMovable(self.movableIcon)
				HideInventoryClutter_LockedButton:SetMovable(self.movableIcon)

				if self.movableIcon then
					HideInventoryClutter_LockedButton:SetAlpha(1)
					HideInventoryClutter_LockedButton:SetHidden(false)
					HideInventoryClutter_ConsumablesButton:SetAlpha(1)
					HideInventoryClutter_ConsumablesButton:SetHidden(false)
				else
					HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
					HideInventoryClutter_LockedButton:SetHidden(true)
					HideInventoryClutter_ConsumablesButton:SetAlpha(self.lockedVisible and 1 or 0.3)
					HideInventoryClutter_ConsumablesButton:SetHidden(true)
				end
			end
		},
		[3] = {
			type = "button",
			name = "reset position",
			func = function()
				if not self.movableIcon then
					self.log("Icons " .. (self.movableIcon and "un" or "") .. "locked!")
				end

				self.savedVariables.positionConsumable.top  = 811 
				self.savedVariables.positionConsumable.left = 1379 
				HideInventoryClutter_ConsumablesButton:ClearAnchors()
				HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
					self.savedVariables.positionConsumable.left, self.savedVariables.positionConsumable.top)
				
				self.savedVariables.positionLocked.top  = 820 	
				self.savedVariables.positionLocked.left = 1361 
				HideInventoryClutter_LockedButton:ClearAnchors()
				HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
					self.savedVariables.positionLocked.left, self.savedVariables.positionLocked.top)

				self:saveGuiPosition()
			end
		},
		[4] = {
			type = "checkbox",
			name = "Locked items filter",
			tooltip = "hides locked items from inventory window",
			getFunc = function() return self.savedVariables.lockedEnabled end,
			setFunc = function(value) 
				self.savedVariables.lockedEnabled = value 
				self:toggleLocked()
				self:toggleLocked()
			end
		},
		[5] = {
			type = "checkbox",
			name = "Consumables filter",
			tooltip = "hides common consumables from inventory and merchant sell window",
			getFunc = function() return self.savedVariables.consumablesEnabled end,
			setFunc = function(value) 
				self.savedVariables.consumablesEnabled = value
				self:toggleConsumables()
				self:toggleConsumables()
			end
		},
		[6] = {
			type = "checkbox",
			name = "Materials filter",
			tooltip = "hides materials from merchant sell window",
			getFunc = function() return self.savedVariables.materialsEnabled end,
			setFunc = function(value) self.savedVariables.materialsEnabled = value end
		},
		[7] = {
			type = "checkbox",
			name = "Deconstruction filter",
			tooltip = "hides items not worth deconstructing from deconstruction window and items worth deconstucting from merchant window",
			getFunc = function() return self.savedVariables.deconstructionEnabled end,
			setFunc = function(value) self.savedVariables.deconstructionEnabled = value end
		},
	}
	LAM2:RegisterOptionControls(self.ADDON_NAME .. "_LAM_PANEL", controls)
end

EVENT_MANAGER:RegisterForEvent(HideInventoryClutter.ADDON_NAME, EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
	if addOnName ~= HideInventoryClutter.ADDON_NAME then return end 
	EVENT_MANAGER:UnregisterForEvent(HideInventoryClutter.ADDON_NAME, EVENT_ADD_ON_LOADED)
	HideInventoryClutter:initalize()
	HideInventoryClutter:buildMenu()
end)
