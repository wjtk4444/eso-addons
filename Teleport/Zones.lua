Teleport.Zones = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local zones
local zoneNames
local zoneNamesById

function Teleport.Zones:initialize() 
	zones = {}
	zoneNames = {}
	zoneNamesById = {}
	for i = 1, GetNumMaps() do
		if GetCyrodiilMapIndex() ~= i and GetImperialCityMapIndex() ~= i then
			local _, mapType, mapContentType, zoneIndex = GetMapInfoByIndex(i)
			if mapContentType == MAP_CONTENT_NONE and (mapType == MAPTYPE_ZONE or mapType == MAPTYPE_SUBZONE) then
				local zoneName = GetZoneNameByIndex(zoneIndex)
				zones[zoneName] = GetZoneId(zoneIndex)
				zoneNamesById[zones[zoneName]] = zoneName
				table.insert(zoneNames, zoneName)
			end
		end
	end
	
	Teleport.Aliases:generateZoneAliases(zoneNames)
end

function Teleport.Zones:findZoneByNamePrefix(prefix)
    local expansion = Teleport.Aliases:getZoneByShortNamePrefix(prefix)
    if expansion then
        prefix = expansion
    end
    
    for _, zoneName in pairs(zoneNames) do
        if Teleport.Helpers:startsWithCaseInsensitive(zoneName, prefix) then
            return zoneName, zones[zoneName]
        end
    end

    return nil
end

function Teleport.Zones:findZoneById(zoneId)
    local zoneName = zoneId and zoneNamesById[zoneId]
    if zoneName then
        return zoneName, zoneId
    end

    return nil
end

-- zoneId followed by its parents (delve -> zone, etc.)
function Teleport.Zones:getZoneChain(zoneId)
    local chain, seen = {}, {}
    while zoneId and zoneId ~= 0 and not seen[zoneId] do
        seen[zoneId] = true
        table.insert(chain, zoneId)
        zoneId = GetParentZoneId(zoneId)
    end
    return chain
end

-- first zone in the chain that you can /tp to, nil for Cyrodiil, IC, etc.
function Teleport.Zones:normalizeZoneId(zoneId)
    for _, id in ipairs(self:getZoneChain(zoneId)) do
        if zoneNamesById[id] then
            return id
        end
    end
    return nil
end

function Teleport.Zones:getPlayerZoneChain()
    local zoneIndex = GetUnitZoneIndex("player")
    if not zoneIndex then return {} end
    return self:getZoneChain(GetZoneId(zoneIndex))
end

function Teleport.Zones:getPlayerZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    return zoneIndex and self:normalizeZoneId(GetZoneId(zoneIndex))
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

