Teleport.Dungeons = { }

local info = Teleport.info
local dbg  = Teleport.dbg

-- There seems to be no other way of telling if something is a 4-man dungeon
-- (POI_TYPE_GROUP_DUNGEON includes those and Blackrose Prison)
-- a trial or a solo/group arena (POI_TYPE seems to be almost random for those)
-- so I'm using texture names instead to tell them apart from different 
-- fast travel nodes. Better that than a hardcoded list of arenas, eh?
local DUNGEON_TEXTURE_NAMES = {
        ['/esoui/art/icons/poi/poi_groupinstance_complete.dds'  ] = true, -- 4-man dungeon
        ['/esoui/art/icons/poi/poi_raiddungeon_complete.dds'    ] = true, -- trial
        ['/esoui/art/icons/poi/poi_solotrial_complete.dds'      ] = true, -- solo arena
        ['/esoui/art/icons/poi/poi_groupinstance_incomplete.dds'] = true, -- 4-man dungeon
        ['/esoui/art/icons/poi/poi_raiddungeon_incomplete.dds'  ] = true, -- trial
        ['/esoui/art/icons/poi/poi_solotrial_incomplete.dds'    ] = true, -- solo arena
    }

local _dungeons = nil
local function _findDungeon(prefix, aliasOnly)
    if _dungeons == nil then
        _dungeons = {}
        for nodeName, nodeIndex in pairs(Teleport.Nodes:getNodes()) do
            if DUNGEON_TEXTURE_NAMES[Teleport.Nodes:getPointOfInterestTextureName(nodeIndex)] then
                if Teleport.Helpers:startsWith(nodeName, 'Dungeon: ') then
                    _dungeons[string.sub(nodeName, 10)] = nodeIndex
                elseif Teleport.Helpers:startsWith(nodeName, 'Trial: ') then
                    _dungeons[string.sub(nodeName, 8)] = nodeIndex
                else
                    _dungeons[nodeName] = nodeIndex
                end
            end
        end
    end
    
    local nodeName, difficulty = Teleport.Aliases:getDungeonByAlias(prefix)
    if aliasOnly and not nodeName then
        return nil, nil, nil
    end

    if nodeName then 
        return nodeName, _dungeons[nodeName], difficulty
    end

    local nodeName, nodeIndex = Teleport.Helpers:findByCaseInsensitiveKeyPrefix(_dungeons, prefix)
    return nodeName, nodeIndex, difficulty
end

local function _teleportToDungeonAux(nodeName, nodeIndex)
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
    if IsUnitGrouped("player") then
        return IsGroupUsingVeteranDifficulty() == true and 'v' or 'n'
    else
        return IsUnitUsingVeteranDifficulty("player") == true and 'v' or 'n'
    end
end

local function _setVeteranDifficultyAndExecute(difficulty, onChanged)
    local grouped = IsUnitGrouped("player")
    if grouped and not IsUnitGroupLeader("player") then
        info("You have to be your group's leader to change dungeon difficulty.")
        return
    end
        
    if IsUnitInDungeon("player") then
        info("You cannot change dungeon difficulty while in a dungeon.")
        return
    end

    if grouped and IsAnyGroupMemberInDungeon() then
        info("One or more group members are currently in a dungeon. Changing dungeon difficulty will kick them out.")
        info("If You wish to continue anyway, change dungeon difficulty manually in the group menu.")
        return
    end
    
    local unregisterAndExecute = function()
            EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_VETERAN_DIFFICULTY_CHANGED)
            EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED)
            onChanged()
        end

    EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)
    EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)

    info('Changing dungeon difficulty to ' .. (difficulty == 'v' and 'veteran' or 'normal'))
    SetVeteranDifficulty(difficulty == 'v')
end

-------------------------------------------------------------------------------    

function Teleport.Dungeons:teleportToDungeon(name, aliasOnly)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeName, nodeIndex, difficulty = _findDungeon(name, aliasOnly)
    if nodeIndex == nil then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found." 
            .. (aliasOnly and "(aliasOnly)" or ""))
        return false
    end
    
    -- no change in difficulty
    if difficulty == nil or difficulty == _getVeteranDifficulty() then
        _teleportToDungeonAux(nodeName, nodeIndex)
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
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED)
                _teleportToDungeonAux(nodeName, nodeIndex)
            end

        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)
        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. difficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)

        info('Changing dungeon difficulty to ' .. (difficulty == 'v' and 'veteran' or 'normal'))
        SetVeteranDifficulty(difficulty == 'v')        
    else -- difficulty == 'r'
        -- reset instance / travel to reset instance
        if not leader then
            info("Teleporting to a hopefully reset instance of: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
            FastTravelToNode(nodeIndex)
            return true
        end
        
        if inDungeon then
            info("You need to leave the instance first.")
            return true
        end
        
        local currentDifficulty = _getVeteranDifficulty()
        local oppositeDifficulty = currentDifficulty == 'v' and 'n' or 'v'
        
        local unregisterAndExecute = function()
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED)
                EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED)
                
                local unregisterAndExecute2 = function()
                        EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED)
                        EVENT_MANAGER:UnregisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED)
                        zo_callLater(function() 
                                info("Teleporting to a reset instance of: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
                                FastTravelToNode(nodeIndex) 
                            end, 1000)
                    end

                EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute2)
                EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. oppositeDifficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute2)

                info('Changing dungeon difficulty to ' .. (currentDifficulty == 'v' and 'veteran' or 'normal'))
                SetVeteranDifficulty(currentDifficulty == 'v')                    
            end

        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)
        EVENT_MANAGER:RegisterForEvent("TpSetVetDiff-" .. currentDifficulty, EVENT_GEOUP_VETERAN_DIFFICULTY_CHANGED, unregisterAndExecute)

        info('Changing dungeon difficulty to ' .. (oppositeDifficulty == 'v' and 'veteran' or 'normal'))
        SetVeteranDifficulty(oppositeDifficulty == 'v')    
        
    end
    return true
end

