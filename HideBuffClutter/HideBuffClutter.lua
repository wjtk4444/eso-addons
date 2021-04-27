local ADDON_NAME = "HideBuffClutter"

local savedVariables

local DEFAULTS = {
	-- [127596] = true, -- Bewitched Sugar Skulls
	-- [84720 ] = true, -- Ghastly Eye Bowl
	-- [86673 ] = true, -- Lava Foot Soup-and-Saltrice
	
	[21230 ] = true, -- Glyph of Weapon Damage

	-- [61694 ] = true, -- Major Resolve
	
	-- [61744 ] = true, -- Minor Berserk
	
	[40224 ] = true, -- Aggresive Horn
	-- [61747 ] = true, -- Major Force
	[147417] = true, -- Minor Courage
	[109966] = true, -- Major Courage
	[61771 ] = true, -- Powerful Assault
	[61709 ] = true, -- Major Heroism
	[93109 ] = true, -- Major Slayer
}

local function overrideFunctions()
	local function IsVisible(containerObject, effectType, timeStarted, timeEnding, permanent, castByPlayer)
		local visible = false
		local effectTypeSetting = (effectType == BUFF_EFFECT_TYPE_BUFF) and BUFFS_SETTING_BUFFS_ENABLED or BUFFS_SETTING_DEBUFFS_ENABLED
		if containerObject:GetVisibilitySetting(effectTypeSetting) then
			visible = true
			if containerObject:GetUnitTag() == "reticleover" then
				if effectType == BUFF_EFFECT_TYPE_BUFF then
					visible = visible and containerObject:GetVisibilitySetting(BUFFS_SETTING_BUFFS_ENABLED_FOR_TARGET)
				elseif effectType == BUFF_EFFECT_TYPE_DEBUFF and not castByPlayer then
					visible = visible and containerObject:GetVisibilitySetting(BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET_FROM_OTHERS)
				end
			end
			if permanent then
				visible = visible and containerObject:GetVisibilitySetting(BUFFS_SETTING_PERMANENT_EFFECTS)
			else
				local duration = timeEnding - timeStarted
				if duration >= ZO_BUFF_DEBUFF_LONG_EFFECT_DURATION_SECONDS then
					visible = visible and containerObject:GetVisibilitySetting(BUFFS_SETTING_LONG_EFFECTS)
				end
			end
		end
		return visible
	end
	
	function ZO_BuffDebuffStyleObject:UpdateContainer(containerObject)
		ZO_ClearNumericallyIndexedTable(self.sortedBuffs)
		ZO_ClearNumericallyIndexedTable(self.sortedDebuffs)

		if containerObject:ShouldContextuallyShow() then
			local unitTag = containerObject:GetUnitTag()
			local uid = 1

			if unitTag == "player" then
				--Artificial effects--
				for effectId in ZO_GetNextActiveArtificialEffectIdIter do
					local displayName, iconFile, effectType, sortOrder, timeStarted, timeEnding = GetArtificialEffectInfo(effectId)
					local duration = timeEnding - timeStarted
					local permanent = duration == 0

					if IsVisible(containerObject, effectType, timeStarted, timeEnding, permanent) then
						local data =
						{
							buffName = displayName,
							timeStarted = timeStarted,
							timeEnding = timeEnding,
							iconFilename = iconFile,
							stackCount = 0,
							effectType = effectType,
							uid = uid,
							duration = duration,
							permanent = permanent,
							sortOrder = sortOrder,
							effectId = effectId,
							isArtificial = true,
						}

						local appropriateTable = (data.effectType == BUFF_EFFECT_TYPE_BUFF) and self.sortedBuffs or self.sortedDebuffs
						table.insert(appropriateTable, data)
						uid = uid + 1
					end
				end
			end

			for i = 1, GetNumBuffs(unitTag) do
				local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, i)
				local duration = timeEnding - timeStarted
				local permanent = duration == 0

				if IsVisible(containerObject, effectType, timeStarted, timeEnding, permanent, castByPlayer) then
					local data =
					{
						buffName = buffName,
						timeStarted = timeStarted,
						timeEnding = timeEnding,
						buffSlot = buffSlot,
						stackCount = stackCount,
						iconFilename = iconFilename,
						buffType = buffType,
						effectType = effectType,
						abilityType = abilityType,
						statusEffectType = statusEffectType,
						abilityId = abilityId,
						uid = uid,
						duration = duration,
						castByPlayer = castByPlayer,
						permanent = permanent,
						isArtificial = false,
					}
					if data.effectType == BUFF_EFFECT_TYPE_DEBUFF or savedVariables.whitelistedBuffs[data.abilityId] then -- woosh
						local appropriateTable = (data.effectType == BUFF_EFFECT_TYPE_BUFF) and self.sortedBuffs or self.sortedDebuffs
						table.insert(appropriateTable, data)
						uid = uid + 1
					end
				end
			end

			if #self.sortedBuffs then
				table.sort(self.sortedBuffs, self.SortCallbackFunction)
			end
			if #self.sortedDebuffs then
				table.sort(self.sortedDebuffs, self.SortCallbackFunction)
			end
		end
	end
end

local function generateDescription()
	local desc = "Whitelisted buffs:"
	for key, value in pairs(savedVariables.whitelistedBuffs) do
		desc = desc .. "\n[" .. tostring(key) .. "] " .. GetAbilityName(key)
	end
	
	desc = desc .. "\n\nActive player buffs:"
	for i = 1, GetNumBuffs("player") do
		local buffName, _, _, _, _, _, _, effectType, _, _, abilityId = GetUnitBuffInfo("player", i)
		if effectType == BUFF_EFFECT_TYPE_BUFF then
			desc = desc .. '\n[' .. tostring(abilityId) .. '] ' .. buffName
		end
	end
	
	return desc
end

local function updateDescription()
	HBC_LAM_Description.data.text = generateDescription()
	HBC_LAM_Description:UpdateValue()
end

local addBuffEditboxValue, removeBuffEditboxValue
local function OnAddOnLoaded(_, addOnName)
	if addOnName == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)		
		savedVariables = ZO_SavedVars:NewAccountWide('HideBuffClutterWhitelistedBuffs', 1, nil, { whitelistedBuffs = DEFAULTS })
		local LAM2 = LibAddonMenu2
		LAM2:RegisterAddonPanel(ADDON_NAME, { type = "panel", name = ADDON_NAME })
		local controls = {
			[1] = {
				type = "description",
				text = generateDescription(),
				width = "full",
				reference = "HBC_LAM_Description",
			},
			[2] = {
				type = "button",
				name = "Refresh active buffs list",
				func = updateDescription,
			},
			[3] = {
				type = "button",
				name = "Restore defaults",
				func = function() 
						savedVariables.whitelistedBuffs = DEFAULTS
						updateDescription()
					end,
			},
			[4] = {
				type = "editbox",
				textType = TEXT_TYPE_NUMERIC,
				name = "Add buff id to the whitelist",
				reference = "HBC_LAM_EditboxAddBuffId",
				getFunc = function() return "" end,
				setFunc = function(text) addBuffEditboxValue = tonumber(text) end,
			},
			[5] = {
				type = "button",
				name = "Add buff id",
				tooltip = "On success editbox value will reset. If the value persists, make sure that entered buff id is correct",
				func = function() 
						if addBuffEditboxValue and DoesAbilityExist(addBuffEditboxValue) then 
							savedVariables.whitelistedBuffs[addBuffEditboxValue] = true
							updateDescription() 
							HBC_LAM_EditboxAddBuffId:UpdateValue()
						end
					end
			},		
			[6] = {
				type = "editbox",
				textType = TEXT_TYPE_NUMERIC,
				name = "Remove buff id from the whitelist",
				reference = "HBC_LAM_EditboxRemoveBuffId",
				getFunc = function() return "" end,
				setFunc = function(text) removeBuffEditboxValue = tonumber(text) end,
			},
			[7] = {
				type = "button",
				name = "Remove buff id",
				tooltip = "On success editbox value will reset. If the value persists, make sure that entered buff id is correct",
				func = function() 
						if removeBuffEditboxValue and savedVariables.whitelistedBuffs[removeBuffEditboxValue] then 
							savedVariables.whitelistedBuffs[removeBuffEditboxValue] = nil
							updateDescription() 
							HBC_LAM_EditboxRemoveBuffId:UpdateValue()
						end 
					end
			},				
		}	
		LAM2:RegisterOptionControls(ADDON_NAME, controls)
		overrideFunctions()
	end
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
