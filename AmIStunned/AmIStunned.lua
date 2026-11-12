AmIStunned = {}

AmIStunned.name = "AmIStunned"
AmIStunned.blockingUpdateInterval  = 1000/60
AmIStunned.randomArtificialDelay   = 1000
AmIStunned.lastStunNotification    = GetFrameTimeMilliseconds()
AmIStunned.lastStunNotificationRem = GetFrameTimeMilliseconds() - 10000
AmIStunned.unlockedUI = false
AmIStunned.blocking = false
AmIStunned.rooted   = false
AmIStunned.stunned  = false
AmIStunned.moving   = 0
AmIStunned.canCast  = ActionSlotHasStatusEffectFailure(1)
AmIStunned.blockingText = "BLOCKING"
AmIStunned.rootedText   = "ROOTED"
AmIStunned.stunnedText  = "STUNNED"
AmIStunned.blockingColor = {0.0, 1.0, 0.0, 1.0}
AmIStunned.rootedColor   = {1.0, 0.7, 0.1, 1.0}
AmIStunned.stunnedColor  = {1.0, 0.0, 0.0, 1.0}
AmIStunned.inCombat      = IsUnitInCombat("player")

-----------------------------------------------------------------------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------------------------------------------------------------------

function AmIStunned.OnAddOnLoaded(event, addonName)
	if addonName ~= AmIStunned.name then
		return
	end
	
	EVENT_MANAGER:UnregisterForEvent(AmIStunned.name, EVENT_ADD_ON_LOADED)
	
	AmIStunned.InitializeMenu()
	
	AmIStunned.savedVariables = ZO_SavedVars:NewAccountWide("AmIStunnedSavedVariables", 1, nil, {})
	AmIStunned.RestorePosition()
	
	EVENT_MANAGER:RegisterForUpdate(AmIStunned.name .. "TickUpdate", AmIStunned.blockingUpdateInterval, AmIStunned.UpdateBlock)
	
	--EVENT_MANAGER:RegisterForEvent(AmIStunned.name .. '_ssc', EVENT_PLAYER_STUNNED_STATE_CHANGED, AmIStunned.OnPlayerStunState)
	EVENT_MANAGER:RegisterForEvent(AmIStunned.name .. '_dact',  EVENT_DISPLAY_ACTIVE_COMBAT_TIP, AmIStunned.OnShowCombatTip)
	EVENT_MANAGER:RegisterForEvent(AmIStunned.name .. '_ract',  EVENT_REMOVE_ACTIVE_COMBAT_TIP, AmIStunned.OnRemoveCombatTip)
	EVENT_MANAGER:RegisterForEvent(AmIStunned.name .. '_cs',    EVENT_PLAYER_COMBAT_STATE, AmIStunned.OnCombatStateChange)
	EVENT_MANAGER:RegisterForEvent(AmIStunned.name .. '_eassu', EVENT_ACTION_SLOT_STATE_UPDATED, AmIStunned.OnSlotStateUpdated)	
	
	SetSetting(SETTING_TYPE_ACTIVE_COMBAT_TIP, 0, 2)
	if AmIStunned.savedVariables.hideCombatTips then
		ZO_ActiveCombatTips:SetHidden(true)
	end	
end

function AmIStunned.OnSlotStateUpdated(_, slotIndex)
	if slotIndex ~= 1 then return end
	AmIStunned.canCast = not ActionSlotHasStatusEffectFailure(1)
end

function AmIStunned.OnCombatStateChange(_, inCombat)
	AmIStunned.inCombat = inCombat
	if not inCombat then
		AmIStunned.rooted = false
		AmIStunned.stunned = false
	end
	AmIStunned.UpdateUI()
end

-------------------------------------------------------------------------------------------------------------------------
---- STUN & ROOT
-------------------------------------------------------------------------------------------------------------------------

-- THIS is just for debugging
--local last = 0
--function log(what) 
--	local now = GetFrameTimeMilliseconds()
--	d(what .. now  .. "+" .. (now - last))
--	last = now
--end

function AmIStunned.OnShowCombatTip(_, tipType)
	if tipType == 19 and not AmIStunned.rooted then 
		--log("+Rooted TIP @")
		AmIStunned.rooted = true
		AmIStunned.UpdateUI()
	elseif tipType == 18 and not AmIStunned.stunned and ActionSlotHasStatusEffectFailure(1) then 
		if GetFrameTimeMilliseconds() - AmIStunned.lastStunNotificationRem > 0 then
			--AmIStunned.lastStunNotification = GetFrameTimeMilliseconds()
			--log("+Stunned TIP @")
			AmIStunned.stunned = true
			if AmIStunned.inCombat or AmIStunned.showOutsideOfCombat then 
				PlaySound(SOUNDS.DEATH_RECAP_KILLING_BLOW_SHOWN)
				AmIStunned.UpdateUI()				
			end
		end
	end
end

function AmIStunned.OnRemoveCombatTip(_, tipType, result)
	if tipType == 19 and AmIStunned.rooted then
		--log("-Rooted TIP @")
		AmIStunned.rooted = false
		AmIStunned.UpdateUI()
	elseif tipType == 18 and result == ACTIVE_COMBAT_TIP_RESULT_SUCCESS and AmIStunned.stunned then
		AmIStunned.lastStunNotificationRem = GetFrameTimeMilliseconds()
		--log("-Stunned TIP @")
		AmIStunned.stunned = false
		AmIStunned.UpdateUI()
	end
end

-----------------------------------------------------------------------------------------------------------------------
-- BLOCKING (okay actually now its everything not just blocking)
-----------------------------------------------------------------------------------------------------------------------

function AmIStunned.UpdateBlock() 
	if AmIStunned.rooted and IsPlayerMoving() then
		-- this seems to be ping dependant? maybe?
		if AmIStunned.moving < 3 then
			AmIStunned.moving = AmIStunned.moving + 1
		else
			--log("-Rooted IPM @")
			AmIStunned.rooted = false
			AmIStunned.lastStunNotificationRem = GetFrameTimeMilliseconds()
			AmIStunned.UpdateUI()
			AmIStunned.moving = 0
		end
	end
	
	if AmIStunned.stunned and AmIStunned.canCast then
		--log("-Stunned IPS @")
		AmIStunned.stunned = false
		AmIStunned.lastStunNotificationRem = GetFrameTimeMilliseconds()
		AmIStunned.UpdateUI()
	end

	local noRecovery
	if AmIStunned.inCombat then
		noRecovery = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS) == 0 or 
					 GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS) == 0
	elseif AmIStunned.savedVariables.showOutsideOfCombat then
		noRecovery = GetPlayerStat(STAT_STAMINA_REGEN_IDLE, STAT_BONUS_OPTION_APPLY_BONUS) == 0 or
					 GetPlayerStat(STAT_MAGICKA_REGEN_IDLE, STAT_BONUS_OPTION_APPLY_BONUS) == 0
	else
		return
	end

	local blocking = noRecovery and IsBlockActive() and not (IsShiftKeyDown() and IsPlayerMoving())

	if blocking ~= AmIStunned.blocking then
		AmIStunned.blocking = blocking
		AmIStunned.UpdateUI()
	end
end

-----------------------------------------------------------------------------------------------------------------------
-- STUN (obosolete?)
-----------------------------------------------------------------------------------------------------------------------

-- removes the "STUNNED" text when the stun ends without player interaction (combat tip takes longer to fade)
--function AmIStunned.OnPlayerStunState(_, stunned)
--	if not stunned then
--		log("-Stunned EV @")
--		--AmIStunned.stunned = false
--		--AmIStunned.lastStunNotificationRem = GetFrameTimeMilliseconds()
--		--AmIStunned.UpdateUI()
--	else
--		log("+Stunned EV @")
--	end
--end

-----------------------------------------------------------------------------------------------------------------------
-- ON-SCREEN NOTIFICATIONS
-----------------------------------------------------------------------------------------------------------------------

function AmIStunned.UpdateUI()
	--d(AmIStunned.stunned and 'stunned' or 'not stunned')

	if AmIStunned.unlockedUI then
		AmIStunnedIndicator:SetHidden(false)
		AmIStunnedLabel:SetText("UI UNLOCKED")
		AmIStunnedLabel:SetColor(1, 1, 1, 1)
		return
	end
	
	if not AmIStunned.inCombat and not AmIStunned.savedVariables.showOutsideOfCombat then
		AmIStunnedIndicator:SetHidden(true)	
		return
	end
	
	local text, color
	if AmIStunned.stunned then
		text = AmIStunned.stunnedText
		color = AmIStunned.stunnedColor			-- Stunned				=> STUNNED	
	elseif AmIStunned.blocking then
		text = AmIStunned.blockingText
		if not AmIStunned.rooted then
			color = AmIStunned.blockingColor   	-- Blocking				=> BLOCKING 
		else
			color = AmIStunned.rootedColor		-- Blocking and Rooted	=> BLOCKING (different color)
		end
	elseif AmIStunned.rooted then
		text = AmIStunned.rootedText
		color = AmIStunned.rootedColor			-- Rooted				=> ROOTED
	else
		AmIStunnedIndicator:SetHidden(true)		-- None
		return
	end

	AmIStunnedIndicator:SetHidden(false)
	AmIStunnedLabel:SetText(text)
	AmIStunnedLabel:SetColor(color[1], color[2], color[3], color[4])
end

-----------------------------------------------------------------------------------------------------------------------
-- SETTINGS
-----------------------------------------------------------------------------------------------------------------------

function AmIStunned.InitializeMenu()
	local menuOptions = {
		type				= "panel",
		name				= AmIStunned.name,
		displayName	 		= AmIStunned.name,
		author				= AmIStunned.author,
		version				= AmIStunned.version,
	}

	local dataTable = {
		{
			type = "description",
			text = "Me stunned or who?",
		},
		{
			type = "divider",
		},
		{
			type    = "checkbox",
			name    = "Hide Active Combat Tips",
			tooltip = "Active Combat Tips are required for this addon to work and enabled automatically by this addon. You can make them hidden (but still enabled) by using this setting.",
			getFunc = function() return AmIStunned.savedVariables.hideCombatTips end,
			setFunc = function(newValue) 
				AmIStunned.savedVariables.hideCombatTips = newValue
				ZO_ActiveCombatTips:SetHidden(newValue)
			end,
		},
		{
			type    = "checkbox",
			name    = "Show outside of combat",
			getFunc = function() return AmIStunned.savedVariables.showOutsideOfCombat end,
			setFunc = function(newValue) 
				AmIStunned.savedVariables.showOutsideOfCombat = newValue
				AmIStunned.UpdateUI()
			end,
		},
		{
			type    = "checkbox",
			name    = "Unlock UI (to move it)",
			default = false,
			getFunc = function() return AmIStunned.unlockedUI end,
			setFunc = function(newValue) 
				AmIStunned.unlockedUI = newValue
				AmIStunned.UpdateUI()
			end,
		},
		{
			type    = "button",
			name    = "Reset to default position",
			func 	= function() AmIStunned.ResetPosition()  end,
		},
	}

	LAM = LibAddonMenu2
	LAM:RegisterAddonPanel(AmIStunned.name .. "Options", menuOptions)
	LAM:RegisterOptionControls(AmIStunned.name .. "Options", dataTable)
end

function AmIStunned.OnIndicatorMoveStop()
	AmIStunned.savedVariables.left = AmIStunnedIndicator:GetLeft()
	AmIStunned.savedVariables.top = AmIStunnedIndicator:GetTop()
end

function AmIStunned.ResetPosition()
	AmIStunnedIndicator:ClearAnchors()
	AmIStunnedIndicator:SetAnchor(BOTTOM, GuiRoot, CENTER, 0, -4)
	AmIStunned.OnIndicatorMoveStop()
end

function AmIStunned.RestorePosition()
	local left = AmIStunned.savedVariables.left
	local top = AmIStunned.savedVariables.top
	if left ~= nil and top ~= nil and left > 0 and top > 0 then
		if AmIStunnedIndicator:GetAnchor() ~= nil then
			AmIStunnedIndicator:ClearAnchors()
		end
		AmIStunnedIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
	else
		AmIStunned.ResetPosition()
	end
end

EVENT_MANAGER:RegisterForEvent(AmIStunned.name, EVENT_ADD_ON_LOADED, AmIStunned.OnAddOnLoaded)