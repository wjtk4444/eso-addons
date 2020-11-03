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
            -- this one doesnt seem to work for trials, FFS ZOS
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

-- calling SetVeteranDifficulty **WHEN NOT IN A GROUP** of 2 or more seems to change the return 
-- value of IsUnitUsingVeteranDifficulty API call, but it doesn't actually do anything in-game,
-- difficulty still has to be updated manually
local function _changeDungeonDifficulty(veteran)
    local vet = nil
    if IsPlayerInGroup(GetDisplayName()) then
        vet = IsGroupUsingVeteranDifficulty()
    else
        return false, false, 1
        --vet = IsUnitUsingVeteranDifficulty('player') 
    end

    if vet == veteran then
        return true, false
    end

    if not IsUnitGroupLeader('player') then
        return true, false, 3
    end

    if CanPlayerChangeGroupDifficulty() then
        if IsAnyGroupMemberInDungeon() then
            return true, false, 2
        end
        SetVeteranDifficulty(veteran)
        return true, true
    end
    return false, false
end

-------------------------------------------------------------------------------    

function Teleport.Dungeons:teleportToDungeon(name, aliasOnly)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName, vet = _findDungeon(name, aliasOnly)
    if nodeIndex == nil then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found." 
            .. (aliasOnly and "(aliasOnly)" or ""))
        return false
    end
    
    if vet ~= nil then
        local success, change, errCode = _changeDungeonDifficulty(vet)
        if errCode == 1 then
            info("Changing dungeon difficulty when not in a group is currently broken.")
            info("Change the difficulty manually and try again without the n/v prefix.")
            info("Sorry for the inconvienience, but it's up to ZOS to fix their API.")
            return true
        elseif errCode == 2 then
            info("One or more group members are currently in a dungeon/trial/arena. Difficulty change aborted.")
            info("You can still change it manually, but know that they will be kicked from the instance.")
            return true
        elseif errCode == 3 then
            info("You need to be a group leader to change dungeon difficulty")
            return true
        else
            if change then
                info('Changing dungeon difficulty to ' .. (vet and 'veteran' or 'normal'))
            elseif not success then
                info('Failed to change dungeon difficulty to ' .. (vet and 'veteran' or 'normal'))
                return true
            end
        end
    end

    local player = Teleport.Players:findPlayerByDungeon(nodeName)
    if player then
        dbg("Teleporting to dungeon: " .. nodeName .. " (" .. player.displayName ..  ")")
        Teleport.Players:teleportToPlayer(player)
        return true
    end
	
	if not Teleport.Nodes:isKnown(nodeIndex) then
		info("Failed to teleport to " .. nodeName .. ": Dungeon not unlocked.")
        return true
	end

    info("Teleporting to dungeon: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
    FastTravelToNode(nodeIndex)
    return true
end
