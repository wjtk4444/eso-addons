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
        return IsGroupUsingVeteranDifficulty()
    else
        return IsUnitUsingVeteranDifficulty("player")
    end
end

local function _setVeteranDifficultyAndExecute(veteranDifficulty, onChanged)
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

    local nodeName, nodeIndex, veteranDifficulty = _findDungeon(name, aliasOnly)
    if nodeIndex == nil then
        dbg("Failed to teleport to " .. name .. ": No such dungeon/trial/arena found." 
            .. (aliasOnly and "(aliasOnly)" or ""))
        return false
    end
    
    if veteranDifficulty == nil or veteranDifficulty == _getVeteranDifficulty() then
        _teleportToDungeonAux(nodeName, nodeIndex)
        return true
    end

    _setVeteranDifficultyAndExecute(veteranDifficulty, function() _teleportToDungeonAux(nodeName, nodeIndex) end)
    return true
end

