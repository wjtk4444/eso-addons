HideInventoryClutter = { 
	name = "HideInventoryClutter"
}

function HideInventoryClutter:isConsumable(slot)
	if IsItemStolen(slot.bagId, slot.slotIndex) then return false end

	if not self.EXTRA_CONSUMABLES then
		self.EXTRA_CONSUMABLES = {
			[30357 ] = true, -- Lockpick
			[44879 ] = true, -- Grand Repair Kit
			[33271 ] = true, -- Soul Gem
			--[64537 ] = true, -- Crown Experience Scroll, 50%
			--[94441 ] = true, -- Grand Gold Coast Experience Scroll
		}
	end
	
	if not self.CONSUMABLE_ITEMTYPES then 
		self.CONSUMABLE_ITEMTYPES = {
			[ITEMTYPE_FOOD  ] = true,
			[ITEMTYPE_DRINK ] = true,
			[ITEMTYPE_POTION] = true,
			[ITEMTYPE_POISON] = true,
		}
	end
	
	if self.EXTRA_CONSUMABLES[GetItemId(slot.bagId, slot.slotIndex)] then return true end
	
	local itemType = GetItemType(slot.bagId, slot.slotIndex) -- returns: itemType, specializedItemType
	return self.CONSUMABLE_ITEMTYPES[itemType] ~= nil
end

function HideInventoryClutter:isLocked(slot)
	return CanItemBePlayerLocked(slot.bagId, slot.slotIndex) and IsItemPlayerLocked(slot.bagId, slot.slotIndex)
end

--------------------------------------------------------------------------------

function HideInventoryClutter:initialize()	
	self.consumablesVisible = true
	self.lockedVisible = true
	self.movableIcon = false
	self.bankOpen = false
	self.storeOpen = false
	self.libFilters = LibFilters3
	self.libFilters:InitializeLibFilters()
	
	local savedVariables = ZO_SavedVars:NewAccountWide('HideInventoryClutterPosition', 1, nil, { 
			positionConsumable = { top = 200, left = 200 },
			positionLocked     = { top = 200, left = 300 },
		})
		
	self.positionConsumable = savedVariables.positionConsumable
	self.positionLocked     = savedVariables.positionLocked

	HideInventoryClutter_ConsumablesButton:SetAlpha(1)
	HideInventoryClutter_ConsumablesButton:ClearAnchors()
	HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
		self.positionConsumable.left, self.positionConsumable.top)
	
	HideInventoryClutter_LockedButton:SetAlpha(1)
	HideInventoryClutter_LockedButton:ClearAnchors()
	HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
		self.positionLocked.left, self.positionLocked.top)

	self.LOCKED_FILTERS = {
		[LF_BANK_DEPOSIT       ] = function(s) return not self:isLocked(s) end,
		[LF_HOUSE_BANK_DEPOSIT ] = function(s) return not self:isLocked(s) end,
		[LF_BANK_WITHDRAW      ] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_HOUSE_BANK_WITHDRAW] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_INVENTORY          ] = function(s) return not self:isLocked(s) end,
	}
	
	self.CONSUMABLE_FILTERS = {
		[LF_BANK_DEPOSIT       ] = function(s) return not self:isConsumable(s) end,
		[LF_HOUSE_BANK_DEPOSIT ] = function(s) return not self:isConsumable(s) end,
		[LF_BANK_WITHDRAW      ] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_HOUSE_BANK_WITHDRAW] = function(s) return true end, -- temporary countermeasure to libFilters bug
		[LF_VENDOR_SELL        ] = function(s) return not self:isConsumable(s) end,
		[LF_MAIL_SEND          ] = function(s) return not self:isConsumable(s) end,
		[LF_TRADE              ] = function(s) return not self:isConsumable(s) end,
		[LF_INVENTORY          ] = function(s) return not self:isConsumable(s) end,
	}
		
	local onShowPlayerInventory = ZO_PlayerInventory:GetHandler("OnShow")
	ZO_PlayerInventory:SetHandler("OnShow", function(...)
		HideInventoryClutter_ConsumablesButton:SetHidden(false)
		HideInventoryClutter_LockedButton:SetHidden(false)

		if onShowPlayerInventory then onShowPlayerInventory(...) end
    end)
	
	local onHidePlayerInventory = ZO_PlayerInventory:GetHandler("OnHide")
	ZO_PlayerInventory:SetHandler("OnHide", function(...)
		if not (self.bankOpen or self.storeOpen) then
			HideInventoryClutter_ConsumablesButton:SetHidden(true)
			HideInventoryClutter_LockedButton:SetHidden(true)
		end
			
		if onHidePlayerInventory then onHidePlayerInventory(...) end
    end)	
	
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_OPEN_BANK, function()
			self.bankOpen = true
			HideInventoryClutter_ConsumablesButton:SetHidden(false)
			HideInventoryClutter_LockedButton:SetHidden(false)
		end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CLOSE_BANK, function()
			self.bankOpen = false
			HideInventoryClutter_ConsumablesButton:SetHidden(true)
			HideInventoryClutter_LockedButton:SetHidden(true)
		end)
		
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_OPEN_STORE, function()
			self.storeOpen = true
			HideInventoryClutter_ConsumablesButton:SetHidden(false)
			HideInventoryClutter_LockedButton:SetHidden(false)
		end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CLOSE_STORE, function()
			self.storeOpen = false
			HideInventoryClutter_ConsumablesButton:SetHidden(true)
			HideInventoryClutter_LockedButton:SetHidden(true)
		end)

	self:toggleLocked()
	self:toggleConsumables()
	
	SLASH_COMMANDS['/hideinventorycluttertogglemoveicons'] = function() 
			self.movableIcon = not self.movableIcon
			d('[HideInventoryClutter]: Icons ' .. (self.movableIcon and 'un' or '') .. 'locked!')
			HideInventoryClutter_ConsumablesButton:SetMovable(self.movableIcon)
			HideInventoryClutter_LockedButton:SetMovable(self.movableIcon)
		end
end

--------------------------------------------------------------------------------

function HideInventoryClutter:toggleConsumables()
	for menu, filter in pairs(self.CONSUMABLE_FILTERS) do
		if self.consumablesVisible then
			self.libFilters:RegisterFilter(self.name .. 'consumables' .. tostring(menu), menu, filter)
		else
			self.libFilters:UnregisterFilter(self.name .. 'consumables' .. tostring(menu), menu)
		end
		self.libFilters:RequestUpdate(menu)
	end
	self.consumablesVisible = not self.consumablesVisible
	
	HideInventoryClutter_ConsumablesButton:SetAlpha(self.consumablesVisible and 1 or 0.3)
end

function HideInventoryClutter:toggleLocked()
	for menu, filter in pairs(self.LOCKED_FILTERS) do
		if self.lockedVisible then		
			self.libFilters:RegisterFilter(self.name .. 'locked' .. tostring(menu), menu, filter)
		else
			self.libFilters:UnregisterFilter(self.name .. 'locked' .. tostring(menu), menu)
		end
		self.libFilters:RequestUpdate(menu)
	end
	self.lockedVisible = not self.lockedVisible
	
	HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
end

--------------------------------------------------------------------------------

function HideInventoryClutter:saveGuiPosition()
	self.positionConsumable.left = math.floor(HideInventoryClutter_ConsumablesButton:GetLeft())
	self.positionConsumable.top  = math.floor(HideInventoryClutter_ConsumablesButton:GetTop())	
	
	self.positionLocked.left = math.floor(HideInventoryClutter_LockedButton:GetLeft())
	self.positionLocked.top  = math.floor(HideInventoryClutter_LockedButton:GetTop())	
end

function HideInventoryClutter:getTooltipTextClutter()
	return "Consumables " .. (self.consumablesVisible and "visible" or "hidden") .. ".\n" ..
		"Run '/hideinventorycluttertogglemoveicons' in chat to unlock/lock icon positions"
end

function HideInventoryClutter:getTooltipTextLocked()
	return "Locked items " .. (self.lockedVisible and "visible" or "hidden") .. ".\n" ..
		"Run '/hideinventorycluttertogglemoveicons' in chat to unlock/lock icon positions"
end

--------------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(HideInventoryClutter.name, EVENT_ADD_ON_LOADED, function() 
        EVENT_MANAGER:UnregisterForEvent(HideInventoryClutter.name, EVENT_ADD_ON_LOADED)
		HideInventoryClutter:initialize()
    end)


