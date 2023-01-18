HideInventoryClutter = { 
	ADDON_NAME = "HideInventoryClutter",
	activeMenu = LF_INVENTORY,
	log = true  and function(msg) d("[HideInventoryClutter]: "        .. msg) end or function() end,
	dbg = false and function(msg) d("[HideInventoryClutter][DEBUG]: " .. msg) end or function() end,
	err = true  and function(msg) d("[HideInventoryClutter][ERROR]: " .. msg) end or function() end,
}

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

function HideInventoryClutter:initalize()
	self.consumablesVisible = false
	self.lockedVisible = false
	self.movableIcon = false
	self.buttonsVisible = false
	self.libFilters = LibFilters3
	self.libFilters:InitializeLibFilters()
	self:setupSavedVars()
		
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
	
	self:initializeUI()
	self:buildLAM2Menu()
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
			self.dbg("shown -> " .. tostring(name))
		end
		
		local callbackHidden = function (callbackName, filterType, _, _, _, _, _)
			self.libFilters:UnregisterFilter(self.ADDON_NAME .. name .. menu, menu)
			self:hideButtons()
			self.dbg("hidden -> " .. tostring(name))
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
			self.dbg("activeMenu -> " .. tostring(self.activeMenu))
			self:showButtons()
			self.dbg("shown -> decon " .. tostring(scope))
		end)
	CALLBACK_MANAGER:RegisterCallback(nameHidden, function (...)
			self.libFilters:UnregisterFilter(self.ADDON_NAME .. "decon" .. scope, menu)
			self:hideButtons()
			self.dbg("hidden -> decon " .. tostring(scope))
		end)
end

EVENT_MANAGER:RegisterForEvent(HideInventoryClutter.ADDON_NAME, EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
	if addOnName ~= HideInventoryClutter.ADDON_NAME then return end 
	EVENT_MANAGER:UnregisterForEvent(HideInventoryClutter.ADDON_NAME, EVENT_ADD_ON_LOADED)
	HideInventoryClutter:initalize()
end)