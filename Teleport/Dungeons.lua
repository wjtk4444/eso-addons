Teleport.Dungeons = { }

local info = Teleport.info
local dbg  = Teleport.dbg

-- arenas
-- https://en.uesp.net/wiki/Teleport:Arenas
-- ' Arena' name suffix collides with other names
-- each returns different POI type
-- MA  == POI_TYPE_OBJECTIVE
-- BRP == POI_TYPE_GROUP_DUNGEON
-- DSA == POI_TYPE_STANDARD
-- there seems to be no other way than a lookup table with hardcoded names
local ARENAS = {
        ['Blackrose Prison' ] = true,
        ['Dragonstar Arena' ] = true,
        ['Maelstrom Arena'  ] = true,
        ['Vateshran Hollows'] = true,
    }

local _dungeons = nil
local function _findDungeon(prefix, aliasOnly)
    if _dungeons == nil then
        _dungeons = {}
        for nodeIndex, name in pairs(Teleport.Nodes:getNodes()) do
            -- this one doesnt seem to work for trials
            --if Teleport.Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_GROUP_DUNGEON then
            if Teleport.Helpers:startsWith(name, 'Dungeon: ') then
                _dungeons[nodeIndex] = string.sub(name, 10)
            elseif Teleport.Helpers:startsWith(name, 'Trial: ') then
                _dungeons[nodeIndex] = string.sub(name, 8)
            elseif ARENAS[name] then
                _dungeons[nodeIndex] = name
            end
        end
    end
    
    local fullName, difficulty = Teleport.Aliases:getDungeonByAlias(prefix)
    if aliasOnly and not fullName then
        return nil, nil, nil
    end

    local nodeIndex, nodeName
    if fullName then 
        nodeIndex, nodeName = Teleport.Helpers:findByValue(_dungeons, fullName)
    else
        nodeIndex, nodeName = Teleport.Helpers:findByCaseInsensitiveValuePrefix(_dungeons, prefix)
    end

    return nodeIndex, nodeName, difficulty
end

local function _teleportToDungeonAux(nodeIndex, nodeName)
    local player = Teleport.Players:findPlayerByDungeon(nodeName)
    if player then
        dbg("Teleporting to dungeon: " .. nodeName .. " (" .. player.displayName ..  ")")
        Teleport.Players:teleportToPlayer(player)
        return
    end
    
    if not Teleport.Nodes:isKnown(nodeIndex) then
        info("Failed to teleport to " .. nodeName .. ": Dungeon not unlocked.")
        return
    end

    info("Teleporting to dungeon: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
    FastTravelToNode(nodeIndex)
end

local function _getVeteranDifficulty()
    return IsUnitGrouped("player") and IsGroupUsingVeteranDifficulty() or IsUnitUsingVeteranDifficulty("player")
end

local function _setVeteranDifficultyAndExecute(veteranDifficulty, onChanged)
	local grouped = IsUnitGrouped("player")
	if grouped and not IsUnitGroupLeader("player") then
		info("You have to be your group's leader to change dungeond difficulty.")
        return
	end
		
	if IsUnitInDungeon("player") then
		info("You cannot change dungeon difficulty in a dungeon.")
        return
	end

    if grouped and IsAnyGroupMemberInDungeon() then
		info("One or more group members are currently in a dungeon. Changing dungeon difficulty will kick them out.")
		info("If You wish to continue anyway, change dungeon difficulty manually in the group menu.")
        return
    end
	
    local unregisterAndExecute = function()
            EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff", EVENT_VETERAN_DIFFICULTY_CHANGED)
            EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff", EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED)
            onChanged()
        end

	EVENT_MANAGER:RegisterForEvent("TpSetVetDiff", EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)
	EVENT_MANAGER:RegisterForEvent("TpSetVetDiff", EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)

    info('Changing dungeon difficulty to ' .. (veteranDifficulty and 'veteran' or 'normal'))
	SetVeteranDifficulty(veteranDifficulty)
end

-------------------------------------------------------------------------------    

function Teleport.Dungeons:teleportToDungeon(name, aliasOnly)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName, veteranDifficulty = _findDungeon(name, aliasOnly)
    if nodeIndex == nil then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found." 
            .. (aliasOnly and "(aliasOnly)" or ""))
        return false
    end
    
    if veteranDifficulty == nil or veteranDifficulty == _getVeteranDifficulty() then
        _teleportToDungeonAux(nodeIndex, nodeName)
        return true
    end

    _setVeteranDifficultyAndExecute(veteranDifficulty, function() _teleportToDungeonAux(nodeIndex, nodeName) end)
    return true
end

