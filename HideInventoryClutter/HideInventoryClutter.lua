HideInventoryClutter = { 
	name = "HideInventoryClutter"
}

function HideInventoryClutter:initialize()	
	self.enabled = false
	self.movableIcon = false
	self.bankOpen = false
	self.libFilters = LibFilters3
	self.libFilters:InitializeLibFilters()
	
	local savedVariables = ZO_SavedVars:NewAccountWide('HideInventoryClutterPosition', 1, nil, { position = { top = 200, left = 200 } })
	self.position = savedVariables.position

	HideInventoryClutterButton:ClearAnchors()
	HideInventoryClutterButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.position.left, self.position.top)

	self.FILTERS = {
		--[LF_BANK_DEPOSIT       ] = function(s) return not (self:isLocked(s) or self:isClutter(s)) end,
		--[LF_HOUSE_BANK_DEPOSIT ] = function(s) return not (self:isLocked(s) or self:isClutter(s)) end,
		--[LF_BANK_WITHDRAW      ] = function(s) return false end, -- temporary countermeasure to libFilters bug
		--[LF_HOUSE_BANK_WITHDRAW] = function(s) return false end, -- temporary countermeasure to libFilters bug
		--[LF_VENDOR_SELL        ] = function(s) return not self:isClutter(s) end,
		[LF_INVENTORY          ] = function(s) return not self:isLocked(s) end,
	}
	
	self.CLUTTER = {
		[30357] = true, -- Lockpick
		[44879] = true, -- Grand Repair Kit
		[33271] = true, -- Soul Gem
		[64710] = true, -- Crown Tri-Restoration Potion
	}
	
	local onShowPlayerInventory = ZO_PlayerInventory:GetHandler("OnShow")
	ZO_PlayerInventory:SetHandler("OnShow", function(...)
		HideInventoryClutterButton:SetHidden(false)
		if onShowPlayerInventory then onShowPlayerInventory(...) end
    end)
	
	local onHidePlayerInventory = ZO_PlayerInventory:GetHandler("OnHide")
	ZO_PlayerInventory:SetHandler("OnHide", function(...)
		if not self.bankOpen then HideInventoryClutterButton:SetHidden(true) end
		if onHidePlayerInventory then onHidePlayerInventory(...) end
    end)	
	
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_OPEN_BANK, function()
			self.bankOpen = true
			HideInventoryClutterButton:SetHidden(false) 
		end)
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CLOSE_BANK, function()
			self.bankOpen = false
			HideInventoryClutterButton:SetHidden(true) 
		end)

	self:toggleAll()
	
	SLASH_COMMANDS['/hideinventorycluttertogglemoveicon'] = function() 
			self.movableIcon = not self.movableIcon
			d('[HideInventoryClutter]: Icon ' .. (self.movableIcon and 'un' or '') .. 'locked!')
			HideInventoryClutterButton:SetMovable(self.movableIcon)
		end
end
	
function HideInventoryClutter:getTooltipText()
	return "Inventory clutter " .. (self.enabled and "hidden" or "visible") .. ".\n" ..
		"Run '/hideinventorycluttertogglemoveicon' in chat to unlock/lock moving of this icon"
end
	
function HideInventoryClutter:isConsumable(slot)
	return GetItemFilterTypeInfo(slot.bagId, slot.slotIndex) == ITEMFILTERTYPE_CONSUMABLE
end

function HideInventoryClutter:isClutter(slot)
	local itemLink = GetItemLink(slot.bagId, slot.slotIndex, LINK_STYLE_BRACKETS)
	if self.CLUTTER[GetItemLinkItemId(itemLink)] then return true end
	-- crafted food and potions
	return IsItemLinkCrafted(itemLink) and self:isConsumable(slot)
end

function HideInventoryClutter:isLocked(slot)
	return CanItemBePlayerLocked(slot.bagId, slot.slotIndex) and IsItemPlayerLocked(slot.bagId, slot.slotIndex)
end

function HideInventoryClutter:toggleAll()
	for menu, filter in pairs(self.FILTERS) do
		if self.enabled then
			self.libFilters:UnregisterFilter(self.name .. tostring(menu), menu)
		else
			self.libFilters:RegisterFilter(self.name .. tostring(menu), menu, filter)
		end
		self.libFilters:RequestUpdate(menu)
	end
	self.enabled = not self.enabled
end

function HideInventoryClutter:saveGuiPosition()
	self.position.left = math.floor(HideInventoryClutterButton:GetLeft())
	self.position.top = math.floor(HideInventoryClutterButton:GetTop())	
end

EVENT_MANAGER:RegisterForEvent(HideInventoryClutter.name, EVENT_ADD_ON_LOADED, function() 
        EVENT_MANAGER:UnregisterForEvent(HideInventoryClutter.name, EVENT_ADD_ON_LOADED)
		HideInventoryClutter:initialize()
    end)


