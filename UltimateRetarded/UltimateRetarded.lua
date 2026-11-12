UltimateRetarded = { 
    ADDON_NAME = "UltimateRetarded",
    log = true  and function(msg) d("[UltimateRetarded]: "        .. msg) end or function() end,
    dbg = false and function(msg) d("[UltimateRetarded][DEBUG]: " .. msg) end or function() end,
    err = true  and function(msg) d("[UltimateRetarded][ERROR]: " .. msg) end or function() end,
	last = 0,
	--notified = true,
	BUFF_DURATION = 8000,
	inCombat      = IsUnitInCombat("player")
}

function UltimateRetarded:saveGuiPosition()
	self.savedVariables.position.left = math.floor(UltimateRetarded_Timer:GetLeft())
	self.savedVariables.position.top  = math.floor(UltimateRetarded_Timer:GetTop())	
end

function UltimateRetarded:Initialize()
	self.savedVariables = ZO_SavedVars:NewAccountWide("UltimateRetardedPosition", 1, nil, { position = { top = 0, left = 0 }, showOOC = true })
	
	local LAM2 = LibAddonMenu2
	LAM2:RegisterAddonPanel(self.ADDON_NAME  .. "_LAM_PANEL", { type = "panel", name = self.ADDON_NAME })
	LAM2:RegisterOptionControls(self.ADDON_NAME .. "_LAM_PANEL", {
		[1] = {
			type = "checkbox",
			name = "show outside of combat",
			tooltip = "hides locked items from inventory window",
			getFunc = function() return self.savedVariables.showOOC end,
			setFunc = function(value) 
				self.savedVariables.showOOC = value 
				UltimateRetarded_Timer:SetHidden(not value and not self.inCombat)
			end
		},
		[2] = {
			type = "button",
			name = "Unlock timer position",
			func = function() 
				UltimateRetarded_Timer:SetMovable(true)
				UltimateRetarded_Timer:SetMouseEnabled(true)
			end
		},
		[3] = {
			type = "button",
			name = "Lock & save timer position",
			func = function() 
				UltimateRetarded_Timer:SetMouseEnabled(false)
				UltimateRetarded_Timer:SetMovable(false)
				self.savedVariables.position.left = math.floor(UltimateRetarded_Timer:GetLeft())
				self.savedVariables.position.top  = math.floor(UltimateRetarded_Timer:GetTop())	
			end
		},
		[4] = {
			type = "button",
			name = "Reset position",
			func = function()
				UltimateRetarded_Timer:ClearAnchors()
				UltimateRetarded_Timer:SetAnchor(TOPLEFT, GUI_ROOT, TOPLEFT, 700, 700)
				self.savedVariables.position.left = math.floor(UltimateRetarded_Timer:GetLeft())
				self.savedVariables.position.top  = math.floor(UltimateRetarded_Timer:GetTop())	
			end
		},
	})
	
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
		self.inCombat = inCombat
		if inCombat then UltimateRetarded_Timer:SetHidden(false) end
	end)
	
	EVENT_MANAGER:RegisterForEvent(self.ADDON_NAME, EVENT_COMBAT_EVENT, 
		function(_, result, _, _, _, abilityActionSlotType, _, sourceType, _, targetType, _, _, _, _, _, _, _, _)
			local isDodge = targetType == COMBAT_UNIT_TYPE_PLAYER and result == ACTION_RESULT_DODGED
			local isBlock = targetType == COMBAT_UNIT_TYPE_PLAYER and result == ACTION_RESULT_BLOCKED_DAMAGE
			local isLightHeavyAtack = sourceType == COMBAT_UNIT_TYPE_PLAYER and (abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK or abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK)
			local attackHit = result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE
			if (isDodge or isBlock or (isLightHeavyAtack and attackHit)) then 
				self.last = GetGameTimeMilliseconds()
				UltimateRetarded_Timer:SetHidden(false)
				--self.notified = false
			end
		end)
	
	EVENT_MANAGER:RegisterForUpdate(self.ADDON_NAME, 100, function()
		local timePassed = GetGameTimeMilliseconds() - self.last
		local timeLeft = self.BUFF_DURATION - math.min(timePassed, self.BUFF_DURATION)
		local seconds = math.ceil(timeLeft/1000)
		UltimateRetarded_Timer:SetText(seconds)
		if not self.savedVariables.showOOC and seconds == 0 and not self.inCombat then
			UltimateRetarded_Timer:SetHidden(true)
		end
		--if timeLeft < 0 and not self.notified then 
		--	self.notified = true
		--end
	end)
	
	UltimateRetarded_Timer:ClearAnchors()
	if self.savedVariables.position.top == nil and self.savedVariables.position.left == nil then
		UltimateRetarded_Timer:SetAnchor(TOPLEFT, GUI_ROOT, TOPLEFT, 700, 700)
	else
		UltimateRetarded_Timer:SetAnchor(TOPLEFT, GUI_ROOT, TOPLEFT, self.savedVariables.position.left, self.savedVariables.position.top)
	end
	
	UltimateRetarded_Timer:SetHidden(not self.savedVariables.showOOC and not self.inCombat)
end

EVENT_MANAGER:RegisterForEvent(UltimateRetarded.ADDON_NAME, EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
    if addOnName ~= UltimateRetarded.ADDON_NAME then return end 
    EVENT_MANAGER:UnregisterForEvent(UltimateRetarded.ADDON_NAME, EVENT_ADD_ON_LOADED)
    UltimateRetarded:Initialize()
end)
