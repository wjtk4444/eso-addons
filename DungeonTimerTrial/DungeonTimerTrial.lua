DungeonTimer.zoneIds[ 635] = {    -2, 60 } -- Dragonstar Arena
DungeonTimer.zoneIds[1082] = {    -2, 40 } -- Blackrose Prison
		
DungeonTimer.zoneIds[ 636] = {    -2, 33 } -- Hel Ra Citadel
DungeonTimer.zoneIds[ 638] = {    -2, 33 } -- Aetherian Archive
DungeonTimer.zoneIds[ 639] = {    -2, 33 } -- Sanctum Ophidia
DungeonTimer.zoneIds[ 725] = {    -2, 40 } -- Maw of Lorkhaj
DungeonTimer.zoneIds[ 975] = {    -2, 40 } -- Halls of Fabrication
DungeonTimer.zoneIds[1000] = {    -2, 15 } -- Asylum Sanctorium
DungeonTimer.zoneIds[1051] = {    -2, 15 } -- Cloudrest
DungeonTimer.zoneIds[1121] = {    -2, 30 } -- Sunspire
DungeonTimer.zoneIds[1196] = {    -2, 35 } -- Kyne's Aegis
DungeonTimer.zoneIds[1263] = {    -2, 30 } -- Rockgrove
DungeonTimer.zoneIds[1344] = {    -2, 30 } -- Dreadsail Reef

local originalCallback = DungeonTimer.ToggleCombatEvents
DungeonTimer.ToggleCombatEvents = function( enable )
	if (enable) then
		if (not DungeonTimer.combatEvents and DungeonTimer.mode == -2 and DungeonTimer.vars.startTime == 0) then
			EVENT_MANAGER:RegisterForEvent(DungeonTimer.name, EVENT_RAID_TRIAL_STARTED, function() 
				DungeonTimer.StartTimer()
				DungeonTimer.ToggleCombatEvents(false)
			end)
		end
	else
		if (DungeonTimer.combatEvents) then
			EVENT_MANAGER:UnregisterForEvent(DungeonTimer.name, EVENT_RAID_TRIAL_STARTED)
		end
	end
	
	originalCallback(enable)
end

local fontSize = 24
local fontStyle = "BOLD_FONT"
local fontWeight = "soft-shadow-thin"
local font = string.format("$(%s)|$(KB_%s)|%s", fontStyle, fontSize, fontWeight)
DungeonTimerFrame:GetNamedChild("Label"):SetFont(font)
DungeonTimerFrame:GetNamedChild("Label"):ClearAnchors()
DungeonTimerFrame:GetNamedChild("Label"):SetAnchor(LEFT, DungeonTimerFrame:GetNamedChild("Icon"), RIGHT, 0, -3)
DungeonTimerFrame:GetNamedChild("Icon"):SetWidth(32)
DungeonTimerFrame:GetNamedChild("Icon"):SetHeight(32)