HideInventoryClutter = { 
	ADDON_NAME = "HideInventoryClutter",
	activeMenu = LF_INVENTORY,
	log = true  and function(msg) d("[HideInventoryClutter]: "        .. msg) end or function() end,
	dbg = false and function(msg) d("[HideInventoryClutter][DEBUG]: " .. msg) end or function() end,
	err = true  and function(msg) d("[HideInventoryClutter][ERROR]: " .. msg) end or function() end,
}

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
	if not self.savedVariables.deconstructionEnabled then return true end

	if GetItemType(b, i) == ITEMTYPE_TREASURE then
		return true
	end

	local itemType = GetItemType(b, i)
	if itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON then
		if not IsItemLinkCrafted(GetItemLink(b, i)) then
			return self.lockedVisible
		else
			return true
		end
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
	
	return true
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

--------------------------------------------------------------------------------

function HideInventoryClutter:toggleConsumables()
	if self.movableIcon then
		self.log("Toggle is disabled when icons are unlocked!")
		return
	end
	self.consumablesVisible = not self.consumablesVisible
	self.libFilters:RequestUpdate(self.activeMenu)
	HideInventoryClutter_ConsumablesButton:SetAlpha(self.consumablesVisible and 1 or 0.3)
	self.dbg("toggle consumables -> " .. tostring(self.consumablesVisible))
end

function HideInventoryClutter:toggleLocked(filter)
	if self.movableIcon then
		self.log("Toggle is disabled when icons are unlocked!")
		return
	end
	
	self.lockedVisible = not self.lockedVisible
	self.libFilters:RequestUpdate(self.activeMenu)
	HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
	self.dbg("toggle locked -> " .. tostring(self.lockedVisible))
end

--------------------------------------------------------------------------------

function HideInventoryClutter:saveGuiPosition()
	self.savedVariables.positionConsumable.left = math.floor(HideInventoryClutter_ConsumablesButton:GetLeft())
	self.savedVariables.positionConsumable.top  = math.floor(HideInventoryClutter_ConsumablesButton:GetTop())	
	
	self.savedVariables.positionLocked.left = math.floor(HideInventoryClutter_LockedButton:GetLeft())
	self.savedVariables.positionLocked.top  = math.floor(HideInventoryClutter_LockedButton:GetTop())		
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

--------------------------------------------------------------------------------

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

function HideInventoryClutter:initalize()
	self.consumablesVisible = false
	self.lockedVisible = false
	self.movableIcon = false
	self.buttonsVisible = false
	self.libFilters = LibFilters3
	self.libFilters:InitializeLibFilters()
	
	self.savedVariables = ZO_SavedVars:NewAccountWide("HideInventoryClutterPosition", 2, nil, { 
			positionLocked     = { top = nil, left = nil },
			positionConsumable = { top = nil, left = nil },
			lockedEnabled = true,
			consumablesEnabled = true,
			materialsEnabled = true,
			deconstructionEnabled = true,
		})

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

	local lockedFilters = {
		[LF_BANK_DEPOSIT         ] = function(s) return not self:isLocked(s) end,
		[LF_HOUSE_BANK_DEPOSIT   ] = function(s) return not self:isLocked(s) end,
		[LF_INVENTORY            ] = function(s) return not self:isLocked(s) end,
		[LF_VENDOR_SELL          ] = function(s) return self:isWorthSelling(s.bagId, s.slotIndex) end,
		[LF_SMITHING_DECONSTRUCT ] = function(b, i) return self:isWorthDeconstructing(b, i) end,
		[LF_JEWELRY_DECONSTRUCT  ] = function(b, i) return self:isWorthDeconstructing(b, i) end,
		[LF_ENCHANTING_EXTRACTION] = function(b, i) return self:isWorthDeconstructing(b, i) end,
	}
	
	local consumableFilters = {
		[LF_BANK_DEPOSIT         ] = function(s) return not self:isConsumable(s) end,
		[LF_HOUSE_BANK_DEPOSIT   ] = function(s) return not self:isConsumable(s) end,
		[LF_GUILDBANK_DEPOSIT    ] = function(s) return not self:isConsumable(s) end,
		[LF_VENDOR_SELL          ] = function(s) return not self:isConsumable(s) end,
		[LF_MAIL_SEND            ] = function(s) return not self:isConsumable(s) end,
		[LF_TRADE                ] = function(s) return not self:isConsumable(s) end,
		[LF_INVENTORY            ] = function(s) return not self:isConsumable(s) end,
		[LF_GUILDSTORE_SELL      ] = function(s) return not self:isConsumable(s) end,
	}
	
	self:SetupFilters(lockedFilters, "locked")
	self:SetupFilters(consumableFilters, "consumable")
	
	local isWorthToDecon = function(b, i) return self:isWorthDeconstructing(b, i) end
	self:SetupDeconFilter(LF_SMITHING_DECONSTRUCT,  "all",        isWorthToDecon)
	self:SetupDeconFilter(LF_SMITHING_DECONSTRUCT,  "armor",      isWorthToDecon)
	self:SetupDeconFilter(LF_SMITHING_DECONSTRUCT,  "weapons",    isWorthToDecon)
	self:SetupDeconFilter(LF_JEWELRY_DECONSTRUCT,   "jewelry",    isWorthToDecon)
	self:SetupDeconFilter(LF_ENCHANTING_EXTRACTION, "enchanting", isWorthToDecon)
end

function HideInventoryClutter:SetupFilters(filters, name)
	for menu, filter in pairs(filters) do
		local nameShown  = self.libFilters:RegisterCallbackName(self.ADDON_NAME .. name, menu, true)
		local nameHidden = self.libFilters:RegisterCallbackName(self.ADDON_NAME .. name, menu, false)
		
		local callbackShown = function (callbackName, filterType, _, _, _, _, _)
			if not self.libFilters:IsFilterRegistered(self.ADDON_NAME .. name .. menu, menu) then
				self.libFilters:RegisterFilter(self.ADDON_NAME .. name .. menu, menu, filters[menu])
				self.libFilters:RequestUpdate(menu)
			end
			self.activeMenu = menu
			self.dbg("activeMenu -> " .. tostring(self.activeMenu))
			self:showButtons()
			self.dbg("shown -> " .. tostring(self.name))
		end
		
		local callbackHidden = function (callbackName, filterType, _, _, _, _, _)
			self.libFilters:UnregisterFilter(self.ADDON_NAME .. name .. menu, menu)
			self:hideButtons()
			self.dbg("hidden -> " .. tostring(self.name))
		end
		
		CALLBACK_MANAGER:RegisterCallback(nameShown, callbackShown)
		CALLBACK_MANAGER:RegisterCallback(nameHidden, callbackHidden)
	end
end

function HideInventoryClutter:SetupDeconFilter(menu, scope, filter)
	local nameShown  = self.libFilters:RegisterCallbackName(self.ADDON_NAME .. "decon", menu, true,  nil, scope)
	local nameHidden = self.libFilters:RegisterCallbackName(self.ADDON_NAME .. "decon", menu, false, nil, scope)
		
	CALLBACK_MANAGER:RegisterCallback(nameShown, function (...)
			if not self.libFilters:IsFilterRegistered(self.ADDON_NAME .. "decon" .. scope, menu) then
				self.libFilters:RegisterFilter(self.ADDON_NAME .. "decon" .. scope, menu, filter)
				self.libFilters:RequestUpdate(menu)
			end
			self.activeMenu = menu
			self:showButtons()
		end)
	CALLBACK_MANAGER:RegisterCallback(nameHidden, function (...)
			self.libFilters:UnregisterFilter(self.ADDON_NAME .. "decon" .. scope, menu)
			self:hideButtons()
		end)
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
			name = "Unlock icon position",
			func = function() 
				self.movableIcon = true
				HideInventoryClutter_ConsumablesButton:SetMovable(true)
				HideInventoryClutter_LockedButton:SetMovable(true)

				HideInventoryClutter_LockedButton:SetAlpha(1)
				HideInventoryClutter_LockedButton:SetHidden(false)
				HideInventoryClutter_ConsumablesButton:SetAlpha(1)
				HideInventoryClutter_ConsumablesButton:SetHidden(false)
				
				self.log("Icons unlocked.")
			end
		},
		[3] = {
			type = "button",
			name = "Reset position",
			func = function()
				HideInventoryClutter_LockedButton:ClearAnchors()
				HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 282, 9)
					
				HideInventoryClutter_ConsumablesButton:ClearAnchors()
				HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 300, 0)

				self:saveGuiPosition()
				self.log("Icons position restored to default and saved.")
			end
		},
		[4] = {
			type = "button",
			name = "Save new position",
			func = function()
				self.movableIcon = false
				HideInventoryClutter_ConsumablesButton:SetMovable(false)
				HideInventoryClutter_LockedButton:SetMovable(false)
				HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
				HideInventoryClutter_LockedButton:SetHidden(true)
				HideInventoryClutter_ConsumablesButton:SetAlpha(self.lockedVisible and 1 or 0.3)
				HideInventoryClutter_ConsumablesButton:SetHidden(true)

				self:saveGuiPosition()
				self.log("Icons locked, new position saved.")
			end
		},
		[5] = {
			type = "checkbox",
			name = "Locked items filter",
			tooltip = "hides locked items from inventory window",
			getFunc = function() return self.savedVariables.lockedEnabled end,
			setFunc = function(value) self.savedVariables.lockedEnabled = value end
		},
		[6] = {
			type = "checkbox",
			name = "Consumables filter",
			tooltip = "hides common consumables from inventory and merchant sell window",
			getFunc = function() return self.savedVariables.consumablesEnabled end,
			setFunc = function(value) self.savedVariables.consumablesEnabled = value end
		},
		[7] = {
			type = "checkbox",
			name = "Materials filter",
			tooltip = "hides materials from merchant sell window",
			getFunc = function() return self.savedVariables.materialsEnabled end,
			setFunc = function(value) self.savedVariables.materialsEnabled = value end
		},
		[8] = {
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