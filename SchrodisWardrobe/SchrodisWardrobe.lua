local WW = WizardsWardrobe
local WWG = WW.gui

local savedVariables = nil

local autoEquipTextures = {
	[true] = "/esoui/art/crafting/smithing_tabicon_armorset_down.dds",
	[false] = "/esoui/art/crafting/smithing_tabicon_armorset_up.dds"
}

local function buildTag(index) 
	return "A" .. (index < 10 and '0' or '') ..  index
end

local function WW_LoadArmoryZone(zoneTag)
	WW.currentZone.Reset()
	WW.conditions.ResetCache()
	WW.currentZone = WW.zones[zoneTag]
	
	zo_callLater(function()
		-- init new zone
		WW.currentZone.Init()
		-- change ui if loaded
		WW.gui.OnZoneSelect(WW.currentZone)
		
		if WW.settings.fixes.surfingWeapons then
			WW.fixes.FixSurfingWeapons()
		end
	end, 250)
end

EVENT_MANAGER:RegisterForEvent(name, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function(_, result, buildIndex)
	if result ~= ARMORY_BUILD_RESTORE_RESULT_SUCCESS then return end
	
	savedVariables.buildIndex = buildIndex
	WW_LoadArmoryZone(buildTag(buildIndex))
	WW.Log("[SW] Switched to armory build: " .. GetArmoryBuildName(buildIndex))
end)

local numBuilds = GetNumUnlockedArmoryBuilds()
for i = 1, numBuilds do
	local tag = buildTag(i)
	WW.zones[tag] = { }
	local zone = WW.zones[tag]
	zone.priority = -110 + i
	zone.name = GetArmoryBuildName(i)
	zone.tag = tag
	zone.icon = "EsoUI/Art/Armory/BuildIcons/buildIcon_" .. GetArmoryBuildIconIndex(i) .. ".dds"
	zone.id = -1	
	zone.bosses = {	}
	function zone.Init() end
	function zone.Reset() end
	function zone.OnBossChange(bossName) WW.conditions.OnBossChange(bossName) end
end

local WW_OnZoneChange = WW.OnZoneChange

WW.OnZoneChange = function(_, _)
	local isFirstZoneAfterReload = (WW.currentZoneId == 0)
	
	local zone, x, y, z = GetUnitWorldPosition("player")
	if WW.lookupZones[zone] then
		if WW.settings.autoEquipSetups then
			WW.settings.autoEquipSetups = false
			WizardsWardrobeWindowTopMenuAutoEquip:SetNormalTexture(autoEquipTextures[WW.settings.autoEquipSetups])
			WW.Log("[SW] Switching to " .. WW.lookupZones[zone].name .. ". Choose the desired page manually and re-enable auto-equip.")
			WW_OnZoneChange(_, _)
		else
			WW.currentZoneId = zone
			WW.Log("[SW] Auto-equip is disabled. If you want to use this feature, you need to enable it re-enter the trial for changes to take effect.")
		end
	else
		WW.currentZoneId = zone
		local buildIndex = savedVariables.buildIndex
		if buildIndex == -1 then
			WW.Log("Switching to WW GEN page (use armory station at least once so SchrodisWardrobe can remember the last selected build)")
			WW_LoadArmoryZone("GEN")
		else
			local armoryTag = buildTag(buildIndex)
			if WW.selection.zone.tag ~= armoryTag then		
				WW.Log("[SW] Switching to last equipped armory build: " .. GetArmoryBuildName(buildIndex))
				WW_LoadArmoryZone(armoryTag)
				
				if not isFirstZoneAfterReload and WW.settings.autoEquipSetups then
					zo_callLater(function() WW.LoadSetupCurrent(1, auto) end, 500)
				end
			end
		end	
	end
	
	
end

EVENT_MANAGER:RegisterForEvent("SchrodisWardrobe", EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= "SchrodisWardrobe" then return end

	savedVariables = ZO_SavedVars:NewCharacterIdSettings("SchrodisWardrobe", 1, nil, { buildIndex = -1 })

	local initTag = savedVariables.buildIndex == -1 and "GEN" or buildTag(savedVariables.buildIndex)
	WW_LoadArmoryZone(initTag)
end)

