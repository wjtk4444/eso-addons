local addonDefaults = {
	powerType = POWERTYPE_STAMINA,
	playSound = false,
	zeroRegenColor = {0.38, 0.44, 0.38, 1},
}

local MTT = {}
SchrodisTickTracker = MTT

MTT.updateName = "SchrodisTickTracker"

local translateOffsetY = 1

function MTT.Initialize(control)
	MTT.SV = addonDefaults

	MTT.control = control
	MTT.defaultStamBar = ZO_PlayerAttributeStamina
	MTT.defaultMagBar = ZO_PlayerAttributeMagicka
	MTT.defaultHpBar = ZO_PlayerAttributeHealth
	if MTT.SV.powerType == POWERTYPE_STAMINA then
		MTT.defaultBar = MTT.defaultStamBar
	elseif MTT.SV.powerType == POWERTYPE_MAGICKA then
		MTT.defaultBar = MTT.defaultMagBar
	elseif MTT.SV.powerType == POWERTYPE_HEALTH then
		MTT.defaultBar = MTT.defaultHpBar
	end

	MTT.arrow = SchrodiEdgeContainer
	MTT.arrowTexture1 = MTT.arrow:GetNamedChild('SchrodiEdge1')
	MTT.tickAmountLabel = SchrodiTickAmount
	MTT.previousPower = GetUnitPower('player', MTT.SV.powerType)

	MTT.SetupEvents()
	MTT.SetupControls()
end

function MTT.SetupEvents()
	EVENT_MANAGER:RegisterForUpdate(MTT.updateName, 10, MTT.OnTickUpdate)
	EVENT_MANAGER:RegisterForEvent(MTT.updateName .. "Power", EVENT_POWER_UPDATE, MTT.OnPowerUpdate)
	EVENT_MANAGER:AddFilterForEvent(MTT.updateName .. "Power", EVENT_POWER_UPDATE,
		REGISTER_FILTER_UNIT_TAG, "player")
end

function MTT.GetTranslateDistance()
	local distance = MTT.defaultBar:GetWidth() - MTT.arrow:GetWidth() - MTT.arrow.anchorOffsetX
	if MTT.SV.powerType == POWERTYPE_MAGICKA then
		distance = -distance
	end
	return distance
end

function MTT.SetupControls()
	local side
	local anchorOffsetX
	if MTT.SV.powerType == POWERTYPE_STAMINA then
		MTT.defaultBar = MTT.defaultStamBar
		MTT.arrowTexture1:SetTextureCoords(1, 0, 0, 1)
		side = LEFT
		anchorOffsetX = 0
	elseif MTT.SV.powerType == POWERTYPE_MAGICKA then
		MTT.defaultBar = MTT.defaultMagBar
		MTT.arrowTexture1:SetTextureCoords(0, 1, 0, 1)
		side = RIGHT
		anchorOffsetX = 5
	elseif MTT.SV.powerType == POWERTYPE_HEALTH then
		MTT.defaultBar = MTT.defaultHpBar
		MTT.arrowTexture1:SetTextureCoords(0, 1, 0, 1)
		side = LEFT
		anchorOffsetX = 0
	end

	if MTT.arrow.animDataTick and MTT.arrow.animDataTick:IsPlaying() then MTT.arrow.animDataTick:Stop() end
	local w, h = MTT.defaultBar:GetDimensions()
	MTT.arrow:SetParent(MTT.defaultBar)
	MTT.arrow:ClearAnchors()
	MTT.arrow:SetAnchor(side, MTT.defaultBar, side, anchorOffsetX, translateOffsetY)
	MTT.arrow.offsetX = w - MTT.arrow:GetWidth() - anchorOffsetX
	MTT.arrow.anchorOffsetX = anchorOffsetX
	if side == RIGHT then MTT.arrow.offsetX = -MTT.arrow.offsetX end

	MTT.arrow:SetDrawLayer(DL_OVERLAY)
	MTT.arrow:SetDrawTier(DT_HIGH)
	MTT.arrow:SetDrawLevel(100)
	MTT.arrowTexture1:SetDrawLayer(DL_OVERLAY)
	MTT.arrowTexture1:SetDrawTier(DT_HIGH)
	MTT.arrowTexture1:SetDrawLevel(100)

	MTT.arrow:SetHidden(true)

	MTT.tickAmountLabel:ClearAnchors()
	MTT.tickAmountLabel:SetParent(MTT.defaultBar)
	MTT.tickAmountLabel:SetAnchor(BOTTOM, MTT.defaultBar, TOP, 0, -25)
	MTT.tickAmountLabel:SetHidden(true)
	MTT.tickAmountLabel:SetColor(0, 1, 0, 1)

	ZO_StatusBar_SetGradientColor(MTT.defaultBar:GetNamedChild('Bar'), ZO_POWER_BAR_GRADIENT_COLORS[MTT.SV.powerType])
end

function MTT.OnTickUpdate()
	local currentTime = GetFrameTimeMilliseconds()

	if not MTT.trustedTickTime then return end

	local difference = currentTime - MTT.trustedTickTime
	local currentPower, maxPower = MTT.GetCurrentPower()
	local powerRegen = MTT.GetPowerRegen()
	local defaultBar = MTT.defaultBar:GetNamedChild('Bar')

	if powerRegen == 0 then
		if not MTT.barColorIsZero then
			defaultBar:SetColor(unpack(MTT.SV.zeroRegenColor))
			MTT.barColorIsZero = true
		end
	else
		if MTT.barColorIsZero then
			ZO_StatusBar_SetGradientColor(defaultBar, ZO_POWER_BAR_GRADIENT_COLORS[MTT.SV.powerType])
			MTT.barColorIsZero = false
		end
	end

	if difference >= 2010 then
		MTT.trustedTickTime = currentTime
		MTT.wasTickTimeTrusted = false
		MTT.arrow.animDataTick = MTT.StartAnimation(MTT.arrow, 'arrow')
	end
end

function MTT.GetCurrentPower()
	return GetUnitPower('player', MTT.SV.powerType)
end

function MTT.OnPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	if powerType ~= MTT.SV.powerType then return end

	local currentTime = GetFrameTimeMilliseconds()
	local currentPower = MTT.GetCurrentPower()

	if MTT.previousPower then
		local powerDelta = powerValue - MTT.previousPower
		if powerDelta > 0 and powerDelta == MTT.GetPowerRegen() then
			local validSecondDeltaTick
			if MTT.trustedTickTime then
				local timeDelta = currentTime - MTT.trustedTickTime
				if MTT.partialTimeDelta then
					local savedTimeDelta = currentTime - MTT.partialTimeDelta.currentTime
					local deltaSum = MTT.partialTimeDelta.timeDelta + savedTimeDelta
					validSecondDeltaTick = (deltaSum > 1900) and (deltaSum < 2100)
					MTT.partialTimeDelta = nil
				end

				if MTT.wasTickTimeTrusted and timeDelta < 1750 and not validSecondDeltaTick then
					MTT.previousPower = currentPower
					if validSecondDeltaTick == nil then
						MTT.partialTimeDelta = {timeDelta = timeDelta, currentTime = currentTime}
					end
					return
				end
			end

			MTT.trustedTickTime = currentTime
			MTT.wasTickTimeTrusted = true

			MTT.arrow.animDataTick = MTT.StartAnimation(MTT.arrow, 'arrow')
			MTT.tickAmountLabel:SetText("+" .. tostring(powerDelta))
			MTT.tickAmountLabel:SetHidden(false)
			zo_callLater(function() MTT.tickAmountLabel:SetHidden(true) end, 1500)
			if MTT.SV.playSound then
				PlaySound(SOUNDS.COUNTDOWN_TICK)
				PlaySound(SOUNDS.COUNTDOWN_TICK)
			end
			MTT.OnTickUpdate()
		end
	end
	MTT.previousPower = currentPower
end

function MTT.GetPowerRegen()
	local statTypeCombat, statTypeIdle

	if MTT.SV.powerType == POWERTYPE_STAMINA then
		statTypeCombat = STAT_STAMINA_REGEN_COMBAT
		statTypeIdle = STAT_STAMINA_REGEN_IDLE
	elseif MTT.SV.powerType == POWERTYPE_MAGICKA then
		statTypeCombat = STAT_MAGICKA_REGEN_COMBAT
		statTypeIdle = STAT_MAGICKA_REGEN_IDLE
	elseif MTT.SV.powerType == POWERTYPE_HEALTH then
		statTypeCombat = STAT_HEALTH_REGEN_COMBAT
		statTypeIdle = STAT_HEALTH_REGEN_IDLE
	end

	if IsUnitInCombat('player') then
		return GetPlayerStat(statTypeCombat, STAT_BONUS_OPTION_APPLY_BONUS)
	else
		return GetPlayerStat(statTypeIdle, STAT_BONUS_OPTION_APPLY_BONUS)
	end
end

function MTT.InsertAnimationType(animHandler, animType, control, animDuration, animDelay, animEasing, ...)
	if not animHandler then return end
	if animType == ANIMATION_TRANSLATE then
		local animationTranslate, startX, startY, offsetX, offsetY = animHandler:InsertAnimation(ANIMATION_TRANSLATE, control, animDelay), ...
		animationTranslate:SetTranslateOffsets(startX, startY, offsetX, offsetY)
		animationTranslate:SetDuration(animDuration)
		animationTranslate:SetEasingFunction(animEasing)
	end
end

function MTT.StartAnimation(control, animationType)
	if MTT.control.animDataTick and MTT.control.animDataTick:IsPlaying() then
		MTT.control.animDataTick:Stop()
	end

	control:SetHidden(false)

	if MTT.SV.powerType == POWERTYPE_HEALTH then
		MTT.arrowTexture1:SetTextureCoords(0, 1, 0, 1)
	end

	local _, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor()

	control:ClearAnchors()
	control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)

	control:SetDrawLayer(DL_OVERLAY)
	control:SetDrawTier(DT_HIGH)
	control:SetDrawLevel(100)

	local timeline = ANIMATION_MANAGER:CreateTimeline()

	if animationType == 'arrow' then
		MTT.InsertAnimationType(timeline, ANIMATION_TRANSLATE, control, 2010, 0, ZO_LinearEase,
			0, translateOffsetY, MTT.GetTranslateDistance(), translateOffsetY)
	end

	if MTT.SV.powerType == POWERTYPE_HEALTH then
		timeline:InsertCallback(function()
			MTT.arrowTexture1:SetTextureCoords(1, 0, 0, 1)
		end, 0.5 * timeline:GetDuration())
	end

	timeline:SetHandler('OnStop', function()
		control:ClearAnchors()
		control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
	end)

	timeline:PlayFromStart()
	return timeline
end

function MTT.OnPlayerActivated()
	MTT.Initialize(SchrodisTickTrackerFrame)
	MTT.trustedTickTime = nil
	MTT.wasTickTimeTrusted = false
	MTT.previousPower = GetUnitPower('player', MTT.SV.powerType)
	MTT.partialTimeDelta = nil
end

EVENT_MANAGER:RegisterForEvent('SchrodisTickTracker', EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= 'SchrodisTickTracker' then return end
	EVENT_MANAGER:UnregisterForEvent('SchrodisTickTracker', EVENT_ADD_ON_LOADED)
	TICK_TRACKER_FRAGMENT = ZO_FadeSceneFragment:New(SchrodisTickTrackerFrame, nil, 0)
	EVENT_MANAGER:RegisterForEvent('SchrodisTickTracker', EVENT_PLAYER_ACTIVATED, function()
		MTT.OnPlayerActivated()
		HUD_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
		HUD_UI_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
		LOOT_SCENE:AddFragment(TICK_TRACKER_FRAGMENT)
	end)
end)
