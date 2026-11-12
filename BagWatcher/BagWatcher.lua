EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= "BagWatcher" then return end
	
	WINDOW_MANAGER:CreateControl("BagWatcher_BagSpace", ZO_PerformanceMeters, CT_LABEL)
	BagWatcher_BagSpace:SetDimensions(75, 40)
	BagWatcher_BagSpace:ClearAnchors()
	BagWatcher_BagSpace:SetAnchor(LEFT, ZO_PerformanceMetersLatencyMeter, RIGHT, -10, 0)
	BagWatcher_BagSpace:SetFont("ZoFontWinT2")
	BagWatcher_BagSpace:SetColor(1, 1, 1, 1)
	BagWatcher_BagSpace:SetHorizontalAlignment(0)
	BagWatcher_BagSpace:SetVerticalAlignment(1)
	BagWatcher_BagSpace:SetText("")
	BagWatcher_BagSpace:SetMouseEnabled(true)
	BagWatcher_BagSpace:SetHandler("OnMouseEnter", function(control) ZO_Tooltips_ShowTextTooltip(ZO_PerformanceMeters, LEFT, "Available bag space") end)
	BagWatcher_BagSpace:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
	
	ZO_PerformanceMeters:SetWidth(200)
	ZO_PerformanceMetersBg:SetWidth(335)
	ZO_PerformanceMetersFramerateMeter:ClearAnchors()
	ZO_PerformanceMetersFramerateMeter:SetAnchor(LEFT, ZO_PerformanceMeters, LEFT, 20, 0)
	ZO_PerformanceMetersLatencyMeter:ClearAnchors()
	ZO_PerformanceMetersLatencyMeter:SetAnchor(LEFT, ZO_PerformanceMetersFramerateMeter, RIGHT, -3, 0)
	
	local function OnBagSpace()
		local free = GetNumBagFreeSlots(BAG_BACKPACK)
		local color
		if free > 50 then
			color = "|cFFFFFF"
		elseif free > 15 then
			color = "|cFFdd22"
		else
			color = "|cFF2222"
		end
		BagWatcher_BagSpace:SetText("|t16:16:/esoui/art/tooltips/icon_bag.dds|t " .. color .. free .. "|r")
	end
	
	local EVENTS = {
		EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		EVENT_INVENTORY_ITEM_DESTROYED,
		EVENT_INVENTORY_ITEM_USED, 
		EVENT_INVENTORY_FULL_UPDATE,
		EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		EVENT_LOOT_RECEIVED,
	}
	
	for _, event in ipairs(EVENTS) do
		EVENT_MANAGER:RegisterForEvent("BagWatcher", event, OnBagSpace)
		EVENT_MANAGER:AddFilterForEvent("BagWatcher", event, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	end
	
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_LOOT_RECEIVED,				OnBagSpace)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_CLOSE_BANK,					OnBagSpace)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_CLOSE_GUILD_BANK,			OnBagSpace)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_CLOSE_STORE,					OnBagSpace)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_ITEM_USED,			OnBagSpace)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_ITEM_DESTROYED,	OnBagSpace)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBagSpace)
	--EVENT_MANAGER:AddFilterForEvent("BagWatcher", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_ITEM_DESTROYED, self.utils.Bind(self, self.OnInventoryItemDestroyed))
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_ITEM_USED, self.utils.Bind(self, self.OnInventoryItemUsed))
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_FULL_UPDATE, self.utils.Bind(self, self.OnInventoryFullUpdate))
	--EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, self.utils.Bind(self, self.OnInventorySingleSlotUpdate))
	
	
	local PERFORMANCE_METERS_SetLatency = PERFORMANCE_METERS.SetLatency
	local r, g, b, a = 204/255, 204/255, 170/255, 1
	function PERFORMANCE_METERS:SetLatency(latency)
		PERFORMANCE_METERS_SetLatency(PERFORMANCE_METERS, latency)
		ZO_PerformanceMetersLatencyMeterBars:SetColor(r, g, b, a)
	end
		
	OnBagSpace()
end)