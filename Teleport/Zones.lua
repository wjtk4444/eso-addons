Teleport.Zones = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local zones
local zoneNames
function Teleport.Zones:findZoneByNamePrefix(prefix)
    if not zones then
        zones = {}
        zoneNames = {}
        for i = 1, GetNumMaps() do
            if GetCyrodiilMapIndex() ~= i and GetImperialCityMapIndex() ~= i then
                local _, mapType, mapContentType, zoneIndex = GetMapInfoByIndex(i)
                if mapType == MAPTYPE_ZONE and mapContentType == MAP_CONTENT_NONE then
                    local zoneName = GetZoneNameByIndex(zoneIndex)
                    zones[zoneName] = GetZoneId(zoneIndex)
                    table.insert(zoneNames, zoneName)
                end
            end
        end
    end

    local expansion = Teleport.Aliases:getZoneByShortNamePrefix(prefix)
    if expansion then return expansion end
    
    for _, zoneName in pairs(zoneNames) do
        if Teleport.Helpers:startsWithCaseInsensitive(zoneName, prefix) then
            return zoneName, zones[zoneName]
        end
    end

    return nil
end

function Teleport.Zones:teleportToZone(prefix)
    local zoneName, zoneId = Teleport.Zones:findZoneByNamePrefix(prefix)
    if not zoneName then
        dbg("Failed to teleport to " .. color(prefix, C.NOT_FOUND) .. ": No such zone found.")
        return false
    end
        
    local player = Teleport.Players:findPlayerByZoneId(zoneId)
    if not player then
        info("Failed to teleport to " .. color(zoneName, C.ZONE) .. ": No party members/friends/guildies in that zone.")
        return true
    end
    
    return Teleport.Players:teleportToPlayer(player)
end

