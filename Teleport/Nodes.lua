Teleport.Nodes = {}

-- There seems to be no other way of telling if something is a 4-man dungeon
-- (POI_TYPE_GROUP_DUNGEON includes those and Blackrose Prison)
-- a trial or a solo/group arena (POI_TYPE seems to be almost random for those)
-- so I'm using texture names instead to tell them apart from other 
-- fast travel nodes. Better that than a hardcoded list of arenas, eh?
local DUNGEON_TEXTURE_NAMES = {
        ['/esoui/art/icons/poi/poi_groupinstance_complete.dds'   ] = true, -- 4-man dungeon
        ['/esoui/art/icons/poi/poi_raiddungeon_complete.dds'     ] = true, -- trial
        ['/esoui/art/icons/poi/poi_solotrial_complete.dds'       ] = true, -- solo arena
        ['/esoui/art/icons/poi/poi_endlessdungeon_complete.dds'  ] = true, -- Endless Archive
        ['/esoui/art/icons/poi/poi_groupinstance_incomplete.dds' ] = true, -- 4-man dungeon
        ['/esoui/art/icons/poi/poi_raiddungeon_incomplete.dds'   ] = true, -- trial
        ['/esoui/art/icons/poi/poi_solotrial_incomplete.dds'     ] = true, -- solo arena
        ['/esoui/art/icons/poi/poi_endlessdungeon_incomplete.dds'] = true, -- Endless Archive
    }

--------------------------------------------------------------------------------

Teleport.Nodes.wayshrinesByZoneIndexPoiIndex = {}
local dungeons, sortedDungeons, houses, sortedHouses, wayshrines, sortedWayshrines, wayshrinesByZoneIndexPoiIndex
function buildCaches()
    dungeons = {}
    houses = {}
    wayshrines = {}
    wayshrinesByZoneIndexPoiIndex = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, nodeName, _, _, textureName, _, poiType = GetFastTravelNodeInfo(nodeIndex)
        if not nodeName then 
            -- continue
        else
            if poiType == POI_TYPE_WAYSHRINE then
                wayshrines[nodeName] = nodeIndex
                local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
                if not wayshrinesByZoneIndexPoiIndex[zoneIndex] then
                    wayshrinesByZoneIndexPoiIndex[zoneIndex] = {}
                end
                wayshrinesByZoneIndexPoiIndex[zoneIndex][poiIndex] = nodeIndex
            elseif poiType == POI_TYPE_HOUSE then
                houses[nodeName] = nodeIndex
            else
                if DUNGEON_TEXTURE_NAMES[textureName] then
                    if Teleport.Helpers:startsWith(nodeName, 'Dungeon: ') then
                        dungeons[string.sub(nodeName, 10)] = nodeIndex
                    elseif Teleport.Helpers:startsWith(nodeName, 'Trial: ') then
                        dungeons[string.sub(nodeName, 8)] = nodeIndex
                    else
                        dungeons[nodeName] = nodeIndex
                    end
                end
            end
        end
    end

    local keys = {}
    for key in pairs(dungeons) do
        table.insert(keys, key)
    end
    table.sort(keys)
    sortedDungeons = keys
    
    keys = {}
    for key in pairs(houses) do
        table.insert(keys, key)
    end
    table.sort(keys)
    sortedHouses = keys
    
    keys = {}
    for key in pairs(wayshrines) do
        table.insert(keys, key)
    end
    -- trim the ' Wayshrine' suffix when comparing
    table.sort(keys, function (a, b) return string.sub(a, 1, #a - 10) < string.sub(b, 1, #b - 10) end)
    sortedWayshrines = keys
end

-------------------------------------------------------------------------------

function Teleport.Nodes:isKnown(nodeIndex)
    return GetFastTravelNodeInfo(nodeIndex)
end

function Teleport.Nodes:getRecallCostString(nodeIndex)
    if Teleport.Helpers:isAtWayshrine() then
        return ""
    end

    return " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)";
end

-------------------------------------------------------------------------------

function Teleport.Nodes:getDungeonNodeIndex(exactName)
    if not dungeons then
        buildCaches()
    end

    return dungeons[exactName]
end

function Teleport.Nodes:findDungeonNode(namePrefix)
    if not dungeons then
        buildCaches()
    end

    for _, name in pairs(sortedDungeons) do
        if Teleport.Helpers:startsWithCaseInsensitive(name, namePrefix) then
            return name, dungeons[name]
        end
    end
    
    return nil
end

-------------------------------------------------------------------------------

function Teleport.Nodes:getWayshrineNodeIndex(exactName)
    if not wayshrines then
        buildCaches()
    end

    return wayshrines[exactName]
end

function Teleport.Nodes:findWayshrineNode(namePrefix)
    if not wayshrines then
        buildCaches()
    end

    for _, name in pairs(sortedWayshrines) do
        if Teleport.Helpers:startsWithCaseInsensitive(name, namePrefix) then
            return name, wayshrines[name]
        end
    end
    
    return nil
end

function Teleport.Nodes:getWayshrineByZoneByPoiIndices(zoneIndex, poiIndex)
    if not wayshrinesByZoneIndexPoiIndex then
        buildCaches()
    end

    return wayshrinesByZoneIndexPoiIndex[zoneIndex][poiIndex]
end

-------------------------------------------------------------------------------

function Teleport.Nodes:getHouseNodeIndex(exactName)
    if not houses then
        buildCaches()
    end

    return houses[exactName]
end

function Teleport.Nodes:findHouseNode(namePrefix)
    if not houses then
        buildCaches()
    end

    for _, name in pairs(sortedHouses) do
        if Teleport.Helpers:startsWithCaseInsensitive(name, namePrefix) then
            return name, houses[name]
        end
    end
    
    return nil
end
