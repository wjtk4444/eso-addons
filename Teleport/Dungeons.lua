Teleport.Dungeons = { }

local Dungeons = Teleport.Dungeons
local Nodes    = Teleport.Nodes
local Helpers  = Teleport.Helpers

local info = Teleport.info
local dbg  = Teleport.dbg

-- arenas
-- https://en.uesp.net/wiki/Online:Arenas
-- ' Arena' name suffix collides with other names
-- each returns different POI type
-- MA  == POI_TYPE_OBJECTIVE
-- BRP == POI_TYPE_GROUP_DUNGEON
-- DSA == POI_TYPE_STANDARD
-- there seems to be no other way than a lookup table with hardcoded names
local ARENAS = {
        ['Blackrose Prison'] = true,
        ['Dragonstar Arena'] = true,
        ['Maelstrom Arena' ] = true,
    }

local _dungeons = nil
local function _findDungeon(prefix)
    if _dungeons == nil then
        _dungeons = {}
        for nodeIndex, name in pairs(Nodes:getNodes()) do
            -- this one doesnt seem to work for trials, FFS ZOS
            --if Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_GROUP_DUNGEON then
            if Helpers:startsWith(name, 'Dungeon: ') then
                _dungeons[nodeIndex] = string.sub(name, 10)
            elseif Helpers:startsWith(name, 'Trial: ') then
                _dungeons[nodeIndex] = string.sub(name, 8)
            elseif ARENAS[name] then
                _dungeons[nodeIndex] = name
            end
        end
    end
    
    local fromAlias = Aliases:getDungeonByAlias(string.lower(prefix))
    local nodeIndex, nodeName
    if fromAlias then 
        nodeIndex, nodeName = Helpers:findByValue(_dungeons, fromAlias)
    else
        nodeIndex, nodeName = Helpers:findByCaseInsensitiveValuePrefix(_dungeons, prefix)
    end

    return nodeIndex, nodeName, fromAlias and true or false
end

-- calling SetVeteranDifficulty seems to change the return value of IsUnitUsingVeteranDifficulty
-- however, it doesn't actually do anything
-- getting and setting dungeon mode via API when not in a grup is BROKEN, period
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

local function _getDifficultyFromAlias(alias)
    local difficulty = string.lower(string.sub(alias, 1, 1))
    if difficulty == 'v' then return true end
    if difficulty == 'n' then return false end
    return nil
end

-------------------------------------------------------------------------------    

function Dungeons:portToDungeon(name, aliasOnly)
    if Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName, alias = _findDungeon(name)
    if nodeIndex == nil then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found.")
        return false
    end
    
    local vet = nil
    if alias == true then
        vet = _getDifficultyFromAlias(name)
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
    elseif aliasOnly then
        return false
    end

    local player = Players:findPlayerByDungeon(nodeName, vet)
    if player then
        dbg("Teleporting to dungeon: " .. nodeName .. " (" .. player.displayName ..  ")")
        Players:portToPlayer(player)
        return true
    end
	
	if not Nodes:isKnown(nodeIndex) then
		info("Failed to teleport to " .. nodeName .. ": Dungeon not unlocked.")
        return true
	end

    info("Teleporting to dungeon: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
    FastTravelToNode(nodeIndex)
    return true
end
