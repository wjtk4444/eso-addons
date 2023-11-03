Teleport.SurveyMaps = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

-------------------------------------------------------------------------------

local SURVEY_PATTERN = ".- Survey: (.+)"
local MAP_PATTERN = "(.-) Treasure Map"

function Teleport.SurveyMaps:teleportToSurveyMap(tryPaid)
    local surveyMapZones = {}
    local empty = true

    for _, trophy in pairs(SHARED_INVENTORY:GenerateFullSlotData(function(i) return i.itemType == ITEMTYPE_TROPHY end, BAG_BACKPACK)) do
        local zone = string.match(trophy.name, SURVEY_PATTERN)
        if not zone then
            zone = string.match(trophy.name, MAP_PATTERN)
        end
        if zone then
            zone = string.gsub(zone, " I*$", "")
            local zoneName, zoneId = Teleport.Zones:findZoneByNamePrefix(zone)
            if zoneName then
                local itemLink = GetItemLink(BAG_BACKPACK, trophy.slotIndex, LINK_STYLE_BRACKETS)
                surveyMapZones[zoneId] = itemLink
                empty = false
            end
        end
    end

    if empty then
        info("No more maps / surveys found in your inventory.")
        return
    end

    local player = Teleport.Players:findPlayerByZoneId(nil, surveyMapZones)
    if player then
        return Teleport.Players:teleportToPlayer(player, surveyMapZones)
    end

    local msg = "No players in the following zones: "
    local first = true
    for key in pairs(surveyMapZones) do
        msg = msg .. (first and '' or ", ") .. color(GetZoneNameById(key), C.SURVEY)
        first = false
    end
    if tryPaid then
        msg = msg .. ". Falling back to paid teleport."
        info(msg)
        return Teleport.SurveyMaps:paidTeleportToSurveyMap()
    end
    info(msg)
end

function findNearest(wayshrines, x, y)
    local smallestDistance, bestIndex
    for _, w in ipairs(wayshrines) do
        local distance = LibGPS3:GetLocalDistanceInMeters(x, y, w.x, w.y)
        dbg(w.name .. x .. "," .. y .. " - x:" .. w.x .. " y:" .. w.y .. " - d: " .. distance)
        if not smallestDistance or distance < smallestDistance then
            smallestDistance = distance
            bestIndex = w.index
        end
    end
    return bestIndex
end

function Teleport.SurveyMaps:paidTeleportToSurveyMap()
    if not LibTreasure then
        info(color("LibTreasure", C.NOT_FOUND) .. " is required for paid teleport to survey maps")
        return
    end

    if not LibGPS3 then
        info(color("LibGPS", C.NOT_FOUND) .. " is required for paid teleport to survey maps")
        return
    end

    local empty = true
    for _, trophy in pairs(SHARED_INVENTORY:GenerateFullSlotData(function(i) return i.itemType == ITEMTYPE_TROPHY end, BAG_BACKPACK)) do
        local mapData = LibTreasure_GetItemIdData(trophy.itemId)
        if mapData then
            local itemLink = GetItemLink(BAG_BACKPACK, trophy.slotIndex, LINK_STYLE_BRACKETS)
            local zoneName, _, _, zoneIndex = GetMapInfoById(mapData.mapId)
            if zoneName == 'Cyrodiil' then
                info("Skipping " .. itemLink)
            else
                emtpy = false
                local candidateWayshrines = {}
                for i=1, GetNumPOIs(zoneIndex) do
                    if GetPOIType(zoneIndex, i) == POI_TYPE_WAYSHRINE then
                        SetMapToMapId(mapData.mapId)
                        local x, z, _, _, _, _, discovered = GetPOIMapInfo(zoneIndex, i)
                        if discovered then
                            local wayshrineName = GetPOIInfo(zoneIndex, i)
                            table.insert(candidateWayshrines, {
                                name = wayshrineName,
                                x = x,
                                y = z, -- call z y for the consistency with LibTreasure
                                index = i
                            })
                        end
                    end
                end

                if #candidateWayshrines == 0 then
                    info("Failed to teleport to " .. itemLink .. ". No known wayshrines in that zone.")
                    return
                end

                local nearestWayshrineIndex = findNearest(candidateWayshrines, mapData.x, mapData.y)
                local nodeIndex = Teleport.Nodes:getWayshrineByZoneByPoiIndices(zoneIndex, nearestWayshrineIndex)
                local _, nodeName = GetFastTravelNodeInfo(nodeIndex)
                info("Teleporting to " .. color(nodeName, C.WAYSHRINE) .. " " .. itemLink .. Teleport.Nodes:getRecallCostString(nodeIndex))
                FastTravelToNode(nodeIndex)
                return
            end
        end
    end

    if empty then
        info("No maps / surveys found in your inventory.")
        return
    end
end
