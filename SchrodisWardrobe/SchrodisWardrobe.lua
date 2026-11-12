-- SchrodisWardrobe — Wizard's Wardrobe extension
--  * every unlocked Armory build gets its own WW "zone" (A01, A02, ...)
--  * restoring / saving a build at the Armory switches WW to that build's page
--  * outside of WW instance zones WW returns to the remembered build's page
--  * entering a WW instance zone: auto-equip ON -> switch to its page (without loading the first setup),
--    auto-equip OFF -> stay on the Armory page
--  * loading a setup can buy / morph skills that are not purchased yet

local ADDON_NAME = "SchrodisWardrobe"
local ADDON_VERSION = "2.0"

local WW = WizardsWardrobe
local WWG = WW.gui

local DEFAULT_ARMORY_ICON = "/esoui/art/crafting/smithing_tabicon_armorset_up.dds"
local CRYPTCANON_ULT_ABILITY_ID = 195031     -- same special case WW has in SlotSkill
local ZONE_INIT_DELAY_MS = 250               -- same delay WW.OnZoneChange uses
local SELECT_AFTER_WW_DELAY_MS = 300         -- has to run after WW's own 250 ms callLater
local SETUP_AFTER_RESTORE_DELAY_MS = 500
local SKILL_WAIT_POLL_MS = 50
local SKILL_WAIT_TIMEOUT_MS = 3000

-- 3rd argument of WW.OnZoneChange when called by us (the game event passes nil there)
local ZONE_MODE_AUTOEQUIP_ON = 1
local ZONE_MODE_AUTOEQUIP_OFF = 2
local ZONE_MODE_FORCE_INSTANCE = 3

local DEFAULT_SETTINGS = {
	autoPurchaseSkills = true,
	autoMorphSkills = true,
	trackBuildOnSave = true,
	setupAfterRestore = 0,          -- 0 = off
	teleportButtonSwitchesPage = true,
}

local settings = nil     -- account-wide
local charData = nil     -- per character: buildIndex
local lastLookupZone = nil
local genHintShown = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- WW.Log runs the message through string.format, so dynamic parts must go in as arguments
local function Log(message, logType, ...)
	WW.Log("[SW] " .. message, logType, nil, ...)
end

local function ArmoryTag(buildIndex)
	return string.format("A%02d", buildIndex)
end

local function GetArmoryBuildIndexFromTag(tag)
	if type(tag) ~= "string" then return nil end
	local index = tag:match("^A(%d%d)$")
	return index and tonumber(index) or nil
end

local function IsArmoryZone(zone)
	return zone ~= nil and GetArmoryBuildIndexFromTag(zone.tag) ~= nil
end

local function GetBuildName(buildIndex)
	local name = GetArmoryBuildName(buildIndex)
	if not name or name == "" then
		name = "Build " .. buildIndex
	end
	return name
end

local function GetPlayerZoneId()
	local zoneId = GetUnitWorldPosition("player")
	return zoneId
end

local function IsPlayerInInstanceZone()
	return WW.lookupZones ~= nil and WW.lookupZones[GetPlayerZoneId()] ~= nil
end

---------------------------------------------------------------------------
-- Armory zones
---------------------------------------------------------------------------

local function ArmoryZoneName(buildIndex)
	return string.format("Armory %d: %s", buildIndex, GetBuildName(buildIndex))
end

local function ArmoryZoneIcon(buildIndex)
	local iconIndex = GetArmoryBuildIconIndex(buildIndex)
	if iconIndex and iconIndex > 0 and ZO_ARMORY_BUILD_ICON_TEXTURE_FORMATTER then
		return string.format(ZO_ARMORY_BUILD_ICON_TEXTURE_FORMATTER, iconIndex)
	end
	return DEFAULT_ARMORY_ICON
end

-- creates the zone if missing, refreshes name / icon; returns zone, changed
local function EnsureArmoryZone(buildIndex)
	local tag = ArmoryTag(buildIndex)
	local zone = WW.zones[tag]
	local changed = false

	if not zone then
		zone = {
			tag = tag,
			id = -1,
			node = -1,
			-- right after GEN (-2) in WW's sorted lists
			priority = -2 + buildIndex * 0.01,
			category = WW.ACTIVITIES.GENERAL,
			bosses = {},
			-- WW builds this in WW.Init; set it here too in case the zone is created later
			lookupBosses = {},
		}
		function zone.Init() end
		function zone.Reset() end
		function zone.OnBossChange(bossName) WW.conditions.OnBossChange(bossName) end
		WW.zones[tag] = zone
		changed = true
	end

	local name = ArmoryZoneName(buildIndex)
	local icon = ArmoryZoneIcon(buildIndex)
	if zone.name ~= name or zone.icon ~= icon then
		zone.name = name
		zone.icon = icon
		changed = true
	end

	return zone, changed
end

local function RefreshZoneTree()
	local tree = WWG.tree and WWG.tree.tree
	if not tree or not WW.selection then return end
	WWG.tree:RefreshTree(tree, WW.selection.zone)
end

local function RefreshArmoryZones()
	local anyChanged = false
	for buildIndex = 1, GetNumUnlockedArmoryBuilds() do
		local _, changed = EnsureArmoryZone(buildIndex)
		anyChanged = anyChanged or changed
	end

	if anyChanged and WW.selection then
		RefreshZoneTree()
		if IsArmoryZone(WW.selection.zone) then
			WizardsWardrobeWindowTopMenuButtonsZoneSelect:SetText(WW.selection.zone.name)
			if WWG.zoneSelection then WWG.zoneSelection:SetLabel(WW.selection.zone.name) end
		end
	end
end

-- created as soon as the file loads so WW.Init (and the zone tree) already see them
RefreshArmoryZones()

---------------------------------------------------------------------------
-- Zone switching
---------------------------------------------------------------------------

-- WW's zone change minus "load the first setup"
local function ActivateZone(zone)
	if not zone then return end

	WW.currentZone.Reset()
	WW.conditions.ResetCache()
	WW.currentZone = zone

	zo_callLater(function()
		-- another switch happened in the meantime
		if WW.currentZone ~= zone then return end

		zone.Init()
		WWG.OnZoneSelect(zone)

		if WW.settings.fixes.surfingWeapons then
			WW.fixes.FixSurfingWeapons()
		end
	end, ZONE_INIT_DELAY_MS)
end

local function GetRememberedZone()
	local buildIndex = charData.buildIndex
	if buildIndex and buildIndex > 0 and buildIndex <= GetNumUnlockedArmoryBuilds() then
		return (EnsureArmoryZone(buildIndex)), buildIndex
	end
	return WW.zones["GEN"], nil
end

local function SwitchToRememberedBuild()
	local zone, buildIndex = GetRememberedZone()

	if not buildIndex and not genHintShown then
		genHintShown = true
		Log("No Armory build remembered yet, using the General page. Restore or save a build at the Armory once.", WW.LOGTYPES.INFO)
	end

	if WW.currentZone ~= zone then
		if buildIndex then
			Log("Switching to last equipped armory build: %s", nil, GetBuildName(buildIndex))
		end
		ActivateZone(zone)
	elseif WW.selection.zone ~= zone then
		-- already active, only the window shows another page
		if buildIndex then
			Log("Switching to last equipped armory build: %s", nil, GetBuildName(buildIndex))
		end
		WWG.OnZoneSelect(zone)
	end
end

local function SetCurrentBuild(buildIndex, reason)
	charData.buildIndex = buildIndex
	local zone = EnsureArmoryZone(buildIndex)
	Log("%s armory build: %s", nil, reason, GetBuildName(buildIndex))
	ActivateZone(zone)
	return zone
end

---------------------------------------------------------------------------
-- Top menu buttons (teleport / house)
---------------------------------------------------------------------------

local function UpdateTopButtons()
	local trialButton = WizardsWardrobeWindowTopMenuButtonsTeleportTrial
	local houseButton = WizardsWardrobeWindowTopMenuButtonsTeleportHouse

	if settings and settings.teleportButtonSwitchesPage and IsPlayerInInstanceZone() then
		-- teleport button switches WW to the page of the zone we are in
		trialButton:SetHidden(false)
		trialButton:SetEnabled(true)
		trialButton:SetDesaturation(0)
		houseButton:SetHidden(true)
		WWG.SetTooltip(trialButton, TOP, "Switch Wizard's Wardrobe to this zone's page")
		return
	end

	WWG.SetTooltip(trialButton, TOP, GetString(WW_BUTTON_TELEPORT))
	trialButton:SetEnabled(not IsInAvAZone())
	trialButton:SetDesaturation(IsInAvAZone() and 1 or 0)

	-- armory pages behave like the General page; everything else keeps WW's own logic
	if IsArmoryZone(WW.selection.zone) then
		trialButton:SetHidden(true)
		houseButton:SetHidden(false)
	end
end

---------------------------------------------------------------------------
-- WW.OnZoneChange override
---------------------------------------------------------------------------

local WW_OnZoneChange = WW.OnZoneChange

local function OnZoneChange(_, _, mode)
	local zoneId = GetPlayerZoneId()
	local instanceZone = WW.lookupZones[zoneId]
	local instanceZoneChanged = lastLookupZone ~= instanceZone
	lastLookupZone = instanceZone

	if instanceZone and mode ~= ZONE_MODE_AUTOEQUIP_OFF then
		local wantsSwitch = instanceZoneChanged or mode == ZONE_MODE_AUTOEQUIP_ON or mode == ZONE_MODE_FORCE_INSTANCE
		if wantsSwitch and (WW.settings.autoEquipSetups or mode == ZONE_MODE_FORCE_INSTANCE) then
			Log("Switching to %s (first setup is NOT loaded, pick it manually)", nil, instanceZone.name)
			-- WW treats currentZoneId == 0 as "first zone after reload" and skips loading the first setup
			WW.currentZoneId = 0
			WW_OnZoneChange()
			-- with autoSelectInstance off WW would show the remembered page instead
			zo_callLater(function()
				if WW.currentZone == instanceZone and WW.selection.zone ~= instanceZone then
					WWG.OnZoneSelect(instanceZone)
				end
				UpdateTopButtons()
			end, SELECT_AFTER_WW_DELAY_MS)
			return
		end

		if wantsSwitch then
			Log("Not switching to %s because auto-equip is disabled", nil, instanceZone.name)
		end
		WW.currentZoneId = zoneId
		UpdateTopButtons()
		return
	end

	WW.currentZoneId = zoneId
	SwitchToRememberedBuild()
	UpdateTopButtons()
end

-- WW registers EVENT_PLAYER_ACTIVATED with whatever WW.OnZoneChange is at that moment;
-- the override is set here and the event is re-registered in OnAddOnLoaded, so both load orders work
WW.OnZoneChange = OnZoneChange

---------------------------------------------------------------------------
-- WW.SlotSkill override: buy / morph missing skills
---------------------------------------------------------------------------

local skillWaitCounter = 0

local function WaitForSkillThenSlot(skillData, morphSlot, slotFunction)
	skillWaitCounter = skillWaitCounter + 1
	local updateName = ADDON_NAME .. "SkillWait" .. skillWaitCounter
	local deadline = GetFrameTimeMilliseconds() + SKILL_WAIT_TIMEOUT_MS

	EVENT_MANAGER:RegisterForUpdate(updateName, SKILL_WAIT_POLL_MS, function()
		local done = skillData:IsPurchased()
			and (morphSlot == nil or skillData:GetCurrentSkillProgressionKey() == morphSlot)
		local timedOut = GetFrameTimeMilliseconds() > deadline
		if done or timedOut then
			EVENT_MANAGER:UnregisterForUpdate(updateName)
			if not done then
				Log("Server did not confirm the skill change in time, trying to slot anyway", WW.LOGTYPES.ERROR)
			end
			slotFunction()
		end
	end)
end

-- returns skillData and the morph to wait for when a server confirmation is needed before slotting
local function PrepareSkill(abilityId)
	local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
	if not progressionData then return end

	local skillData = progressionData:GetSkillData()
	if not skillData or skillData:IsPassive() then return end
	if skillData.IsCraftedAbility and skillData:IsCraftedAbility() then return end

	-- during a respec at a shrine the changes are batched by the respec UI, don't touch them
	if SKILLS_AND_ACTION_BAR_MANAGER:GetSkillPointAllocationMode() ~= SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY then return end

	local allocator = skillData:GetPointAllocator()
	local baseName = zo_strformat("<<C:1>>", skillData:GetMorphData(MORPH_SLOT_BASE):GetName())
	local wantedMorph = progressionData:GetMorphSlot()

	-- allocator state already contains changes requested earlier (e.g. the same skill on the other bar)
	if not allocator:IsPurchased() then
		if not settings.autoPurchaseSkills then
			Log("%s is not purchased (auto-purchase is off)", WW.LOGTYPES.INFO, baseName)
			return
		end
		if allocator:Purchase() then
			Log("Purchasing skill: %s", nil, baseName)
		else
			Log("Cannot purchase %s (not enough skill points or skill line rank too low)", WW.LOGTYPES.ERROR, baseName)
			return
		end
	end

	local waitForMorph = nil
	if wantedMorph ~= MORPH_SLOT_BASE then
		local allocatedMorph = allocator:GetSkillProgressionKey()
		local morphName = zo_strformat("<<C:1>>", skillData:GetMorphData(wantedMorph):GetName())

		if allocatedMorph == MORPH_SLOT_BASE then
			if not settings.autoMorphSkills then
				Log("%s is not morphed (auto-morph is off)", WW.LOGTYPES.INFO, baseName)
			elseif allocator:Morph(wantedMorph) then
				Log("Morphing skill: %s -> %s", nil, baseName, morphName)
				waitForMorph = wantedMorph
			else
				Log("Cannot morph %s -> %s (rank IV not reached or not enough skill points)", WW.LOGTYPES.ERROR, baseName, morphName)
			end
		elseif allocatedMorph ~= wantedMorph then
			local otherName = zo_strformat("<<C:1>>", skillData:GetMorphData(allocatedMorph):GetName())
			Log("%s is morphed into %s, setup wants %s (needs a respec)", WW.LOGTYPES.ERROR, baseName, otherName, morphName)
		elseif skillData:GetCurrentSkillProgressionKey() ~= wantedMorph then
			-- morph requested earlier during this load and not confirmed yet
			waitForMorph = wantedMorph
		end
	end

	if not skillData:IsPurchased() or waitForMorph then
		return skillData, waitForMorph
	end
end

local WW_SlotSkill = WW.SlotSkill

WW.SlotSkill = function(hotbarCategory, slotIndex, abilityId)
	local skipPrepare = not abilityId
		or abilityId <= 0
		or abilityId == CRYPTCANON_ULT_ABILITY_ID
		or (slotIndex == 8 and WW.HasCryptCanon())   -- WW won't slot the ultimate anyway

	if not skipPrepare then
		local skillData, waitForMorph = PrepareSkill(abilityId)
		if skillData then
			WaitForSkillThenSlot(skillData, waitForMorph, function()
				WW_SlotSkill(hotbarCategory, slotIndex, abilityId)
			end)
			return true
		end
	end

	return WW_SlotSkill(hotbarCategory, slotIndex, abilityId)
end

---------------------------------------------------------------------------
-- Armory events
---------------------------------------------------------------------------

local function OnArmoryBuildRestored(_, result, buildIndex)
	if result ~= ARMORY_BUILD_RESTORE_RESULT_SUCCESS then return end

	local zone = SetCurrentBuild(buildIndex, "Switched to")

	local setupIndex = settings.setupAfterRestore
	if setupIndex and setupIndex > 0 then
		zo_callLater(function()
			if WW.selection.zone ~= zone then return end
			WW.LoadSetupCurrent(setupIndex, false)
		end, SETUP_AFTER_RESTORE_DELAY_MS)
	end
end

local function OnArmoryBuildSaved(_, result, buildIndex)
	if result ~= ARMORY_BUILD_SAVE_RESULT_SUCCESS then return end
	RefreshArmoryZones()
	if settings.trackBuildOnSave then
		SetCurrentBuild(buildIndex, "Saved current loadout as")
	end
end

---------------------------------------------------------------------------
-- Settings panel
---------------------------------------------------------------------------

local settingsPanel = nil

local function CreateSettingsPanel()
	local LAM = LibAddonMenu2
	if not LAM then return end

	local panelName = ADDON_NAME .. "Settings"
	settingsPanel = LAM:RegisterAddonPanel(panelName, {
		type = "panel",
		name = "Schrodi's Wardrobe",
		author = "Schrodi",
		version = ADDON_VERSION,
		slashCommand = "/swsettings",
		registerForRefresh = true,
	})

	LAM:RegisterOptionControls(panelName, {
		{
			type = "header",
			name = "Armory",
		},
		{
			type = "checkbox",
			name = "Saving a build also switches to it",
			tooltip = "After saving the current loadout into an Armory slot, remember that build and switch Wizard's Wardrobe to its page.",
			getFunc = function() return settings.trackBuildOnSave end,
			setFunc = function(value) settings.trackBuildOnSave = value end,
			default = DEFAULT_SETTINGS.trackBuildOnSave,
		},
		{
			type = "slider",
			name = "Setup to load after restoring a build",
			tooltip = "Number of the setup (on the build's current page) loaded right after a successful Armory restore. 0 = off.\n\nThe Armory already restores gear, skills and CP, so a setup is only useful if it adds something on top (food, poisons, prebuffs...). Loading CP again triggers the CP cooldown.",
			min = 0,
			max = 20,
			step = 1,
			getFunc = function() return settings.setupAfterRestore end,
			setFunc = function(value) settings.setupAfterRestore = value end,
			default = DEFAULT_SETTINGS.setupAfterRestore,
		},
		{
			type = "header",
			name = "Skills",
		},
		{
			type = "checkbox",
			name = "Auto-purchase skills",
			tooltip = "When a setup contains a skill that is not purchased yet, buy it (spends skill points). Off: only a chat message.",
			getFunc = function() return settings.autoPurchaseSkills end,
			setFunc = function(value) settings.autoPurchaseSkills = value end,
			default = DEFAULT_SETTINGS.autoPurchaseSkills,
		},
		{
			type = "checkbox",
			name = "Auto-morph skills",
			tooltip = "When a setup contains a morph of a skill that is still unmorphed, choose that morph (spends a skill point, needs rank IV). Off: only a chat message.",
			getFunc = function() return settings.autoMorphSkills end,
			setFunc = function(value) settings.autoMorphSkills = value end,
			default = DEFAULT_SETTINGS.autoMorphSkills,
		},
		{
			type = "header",
			name = "Interface",
		},
		{
			type = "checkbox",
			name = "Teleport button switches page inside instances",
			tooltip = "Inside a trial / dungeon / arena known to Wizard's Wardrobe, the teleport button switches WW to that zone's page instead of teleporting.",
			getFunc = function() return settings.teleportButtonSwitchesPage end,
			setFunc = function(value)
				settings.teleportButtonSwitchesPage = value
				UpdateTopButtons()
			end,
			default = DEFAULT_SETTINGS.teleportButtonSwitchesPage,
		},
	})
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function PrintStatus()
	local _, buildIndex = GetRememberedZone()
	d("|c18bed8[Schrodi's Wardrobe " .. ADDON_VERSION .. "]|r")
	d("Remembered build: " .. (buildIndex and string.format("%d (%s)", buildIndex, GetBuildName(buildIndex)) or "none"))
	d("WW active zone: " .. tostring(WW.currentZone.name) .. " [" .. tostring(WW.currentZone.tag) .. "]")
	d("WW displayed page: " .. tostring(WW.selection.zone.name) .. " [" .. tostring(WW.selection.zone.tag) .. "]")
	d("WW auto-equip: " .. (WW.settings.autoEquipSetups and "on" or "off"))
	d(string.format("Auto-purchase: %s, auto-morph: %s, setup after restore: %s",
		settings.autoPurchaseSkills and "on" or "off",
		settings.autoMorphSkills and "on" or "off",
		settings.setupAfterRestore > 0 and tostring(settings.setupAfterRestore) or "off"))
end

local function OnSlashCommand(args)
	local command, argument = zo_strsplit(" ", zo_strtrim(args or ""))
	command = command and command:lower() or ""

	if command == "" or command == "status" then
		PrintStatus()
	elseif command == "build" then
		local buildIndex = tonumber(argument)
		local numBuilds = GetNumUnlockedArmoryBuilds()
		if not buildIndex or buildIndex < 1 or buildIndex > numBuilds then
			d(string.format("[SW] Usage: /sw build <1-%d>", numBuilds))
			return
		end
		SetCurrentBuild(buildIndex, "Manually switched to")
	elseif command == "settings" then
		if LibAddonMenu2 and settingsPanel then LibAddonMenu2:OpenToPanel(settingsPanel) end
	else
		d("[SW] /sw (status) | /sw build <n> - treat build n as equipped and show its page | /sw settings")
	end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

local function InstallHooks()
	-- auto-equip toggle: re-evaluate which page should be active
	ZO_PostHookHandler(WizardsWardrobeWindowTopMenuButtonsAutoEquip, "OnClicked", function()
		WW.OnZoneChange(nil, nil, WW.settings.autoEquipSetups and ZONE_MODE_AUTOEQUIP_ON or ZONE_MODE_AUTOEQUIP_OFF)
	end)

	-- teleport button inside an instance zone: switch to its page instead
	ZO_PreHookHandler(WizardsWardrobeWindowTopMenuButtonsTeleportTrial, "OnClicked", function()
		if settings.teleportButtonSwitchesPage and IsPlayerInInstanceZone() then
			WW.OnZoneChange(nil, nil, ZONE_MODE_FORCE_INSTANCE)
			return true
		end
	end)

	ZO_PostHook(WWG, "OnZoneSelect", function(zone)
		-- WW stores the last page to reopen it after a reload; an armory tag there
		-- would crash WW if SchrodisWardrobe gets disabled, and we pick the page ourselves anyway
		if IsArmoryZone(zone) and WW.storage.selectedZoneTag[WW.storage.selectedCharacterId] == zone.tag then
			WW.storage.selectedZoneTag[WW.storage.selectedCharacterId] = "GEN"
		end
		UpdateTopButtons()
	end)

	-- WW only gates substitute setups for the General zone; apply the same rules on armory pages
	ZO_PreHook(WW.conditions, "LoadSubstitute", function()
		if not IsArmoryZone(WW.currentZone) then return false end
		local isDungeon = GetCurrentZoneDungeonDifficulty() > 0
		local allowed = (WW.settings.substitute.dungeons and isDungeon)
			or (WW.settings.substitute.overland and not isDungeon)
		return not allowed
	end)

	-- WW's handler was registered by reference; make sure it goes through the current WW.OnZoneChange
	EVENT_MANAGER:UnregisterForEvent(WW.name, EVENT_PLAYER_ACTIVATED)
	EVENT_MANAGER:RegisterForEvent(WW.name, EVENT_PLAYER_ACTIVATED, function(...) WW.OnZoneChange(...) end)
end

local function CleanupStoredZoneTags()
	for characterId, tag in pairs(WW.storage.selectedZoneTag) do
		if GetArmoryBuildIndexFromTag(tag) then
			WW.storage.selectedZoneTag[characterId] = "GEN"
		end
	end
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	charData = ZO_SavedVars:NewCharacterIdSettings(ADDON_NAME, 1, nil, { buildIndex = -1 })
	settings = ZO_SavedVars:NewAccountWide(ADDON_NAME, 1, "settings", DEFAULT_SETTINGS)

	-- in case WW was initialized before the zones existed
	for _, zone in pairs(WW.zones) do
		if IsArmoryZone(zone) and not zone.lookupBosses then
			zone.lookupBosses = {}
		end
	end
	local firstArmoryZone = WW.zones[ArmoryTag(1)]
	if firstArmoryZone and WWG.tree and WWG.tree.tree and not WWG.tree.tree:GetTreeNodeByData(firstArmoryZone) then
		RefreshZoneTree()
	end

	CleanupStoredZoneTags()
	InstallHooks()
	CreateSettingsPanel()

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnArmoryBuildRestored)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ARMORY_BUILD_SAVE_RESPONSE, OnArmoryBuildSaved)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ARMORY_BUILD_UPDATED, RefreshArmoryZones)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ARMORY_BUILDS_FULL_UPDATE, RefreshArmoryZones)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ARMORY_BUILD_COUNT_UPDATED, RefreshArmoryZones)

	SLASH_COMMANDS["/schrodi"] = OnSlashCommand
	if not SLASH_COMMANDS["/sw"] then
		SLASH_COMMANDS["/sw"] = OnSlashCommand
	end

	-- show the remembered build right away (the zone change handler refines it on EVENT_PLAYER_ACTIVATED)
	ActivateZone((GetRememberedZone()))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
