local function distanceToUnit(unitID)
	local _, selfX, selfY, selfH = GetUnitWorldPosition("player")
	local _, targetX, targetY, targetH = GetUnitWorldPosition(unitID)
	local nDistance = zo_distance3D(targetX, targetY, targetH, selfX, selfY, selfH) / 100
	return nDistance
end

local function mountPlayer()
	local isMountable = false
	if IsUnitDeadOrReincarnating("player") or IsUnitInCombat("player") or HasPendingCompanion() then
		d("MountyPython: Unable to mount player right now")
		return
	end
	for iD = 1, GetGroupSize() do
		local playerID = GetGroupUnitTagByIndex(iD)
		local playerDisplayName = GetUnitDisplayName(playerID)
		if playerDisplayName ~= GetUnitDisplayName("player") and IsUnitOnline(playerID) and IsUnitInGroupSupportRange(playerID) then
			local playerCharName = GetUnitName(playerID)
			local mountedState, hasEnabledGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(playerDisplayName)
			local isMountable = mountedState == MOUNTED_STATE_MOUNT_RIDER and hasEnabledGroupMount and hasFreePassengerSlot
			local displayNamePref = zo_strformat("<<1>>", ZO_ShouldPreferUserId() and playerDisplayName or playerCharName)
			if isMountable and distanceToUnit(playerID) < 5.0 then
				d("MountyPython: Mounting " .. displayNamePref)
				UseMountAsPassenger(playerDisplayName)
				return
			end
		end
	end
	d("MountyPython: No player in group mountable")
end

EVENT_MANAGER:RegisterForEvent("MountyPythonOnAddonLoaded", EVENT_ADD_ON_LOADED, function(ec, addonName)
		if addonName ~= "MountyPython" then return end
		EVENT_MANAGER:UnregisterForEvent("MountyPythonOnAddonLoaded", EVENT_ADD_ON_LOADED)
		
		ZO_CreateStringId('SI_BINDING_NAME_MP_HOTKEY_MOUNT', 'Mount Player')
		SLASH_COMMANDS["/mountypython"] = function () mountPlayer() end
	end)

