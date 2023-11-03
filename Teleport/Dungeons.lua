Teleport.Dungeons = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

-- returns: nodeName, nodeIndex, difficulty (n, v or r)
local function findDungeon(namePrefix, aliasOnly)
    local dungeonName, difficulty = Teleport.Aliases:getDungeonByAlias(namePrefix)
    if aliasOnly and not dungeonName then
        return nil, nil, nil
    end
    
    if dungeonName then
        return dungeonName, Teleport.Nodes:getDungeonNodeIndex(dungeonName), difficulty
    end
    
    local nodeName, nodeIndex = Teleport.Nodes:findDungeonNode(namePrefix)
    return nodeName, nodeIndex, difficulty
end

local function teleportToDungeonAux(nodeName, nodeIndex)
    if Teleport.Helpers:isAtWayshrine() and Teleport.Nodes:isKnown(nodeIndex) then
        info("Teleporting to " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
        FastTravelToNode(nodeIndex)
        return
    end

    local player = Teleport.Players:findPlayerByDungeonName(nodeName)
    if player then
        dbg("Teleporting to " .. player.displayName .. " in " .. nodeName)
        Teleport.Players:teleportToPlayer(player)
        return
    end
    
    if not Teleport.Nodes:isKnown(nodeIndex) then
        info("Failed to teleport to " .. color(nodeName, C.NOT_UNLOCKED) .. ": Dungeon not unlocked.")
        return
    end

    info("Teleporting to " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
    FastTravelToNode(nodeIndex)
end

local function getVeteranDifficulty()
    if IsUnitGrouped("player") then
        return IsGroupUsingVeteranDifficulty() == true and 'v' or 'n'
    else
        return IsUnitUsingVeteranDifficulty("player") == true and 'v' or 'n'
    end
end

-------------------------------------------------------------------------------    

function Teleport.Dungeons:teleportToDungeon(name, aliasOnly)
    local nodeName, nodeIndex, difficulty = findDungeon(name, aliasOnly)
    if not nodeIndex then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found." 
            .. (aliasOnly and "(aliasOnly)" or ""))
        return false
    end
    
    -- no change in difficulty
    if not difficulty or difficulty == getVeteranDifficulty() then
        teleportToDungeonAux(nodeName, nodeIndex)
        return true
    end

    local leader = IsUnitGroupLeader("player") or not IsUnitGrouped("player") 
    local inDungeon = IsUnitInDungeon("player")

    if difficulty == 'n' or difficulty == 'v' then
        -- change difficulty to desired one
        if not leader then
            info("You have to be your group's leader to change difficulty.")
            return true
        end
            
        if IsUnitInDungeon("player") then
            info("You cannot change dungeon difficulty while in an instance.")
            return true
        end

        if grouped and IsAnyGroupMemberInDungeon() then
            info("One or more group members are currently in a dungeon. Changing dungeon difficulty will kick them out.")
            info("If You wish to continue anyway, change dungeon difficulty manually in the group menu.")
            return true
        end
        
        local unregisterAndExecute = function()
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_VETERAN_DIFFICULTY_CHANGED)
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED)
                teleportToDungeonAux(nodeName, nodeIndex)
            end

        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)
        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)

        info('Changing dungeon difficulty to ' .. (difficulty == 'v' and 'veteran' or 'normal'))
        SetVeteranDifficulty(difficulty == 'v')
    else -- difficulty == 'r'
        -- reset instance / travel to reset instance
        if not leader then
            info("Teleporting to a hopefully reset instance of " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
            FastTravelToNode(nodeIndex)
            return true
        end
        
        if inDungeon then
            info("You need to leave the instance first.")
            return true
        end
        
        local currentDifficulty = getVeteranDifficulty()
        local oppositeDifficulty = currentDifficulty == 'v' and 'n' or 'v'
        
        local unregisterAndExecute = function()
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED)
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED)
                
                local unregisterAndExecute2 = function()
                        EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED)
                        EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED)
                        zo_callLater(function()
                            info("Teleporting to a reset instance of: " .. color(nodeName, C.DUNGEON) .. Teleport.Nodes:getRecallCostString(nodeIndex))
                            FastTravelToNode(nodeIndex)
                            end, 1000)
                    end

                EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute2)
                EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute2)

                info('Changing dungeon difficulty to ' .. (currentDifficulty == 'v' and 'veteran' or 'normal'))
                SetVeteranDifficulty(currentDifficulty == 'v')
            end

        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)
        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)

        info('Changing dungeon difficulty to ' .. (oppositeDifficulty == 'v' and 'veteran' or 'normal'))
        SetVeteranDifficulty(oppositeDifficulty == 'v')
        
    end
    return true
end

