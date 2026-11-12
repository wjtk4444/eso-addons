Teleport.SurveyMaps = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

-------------------------------------------------------------------------------

local SURVEY_PATTERN = ".- Survey: (.+)"
local MAP_PATTERN = "(.-) Treasure Map"

local MODE_FREE = 1 -- jump to players only
local MODE_PAID = 2 -- wayshrines only
local MODE_BOTH = 3 -- players first, wayshrines as a fallback

-------------------------------------------------------------------------------
-- Inventory scan

-- Every survey / treasure map in the backpack that we know the zone of:
-- { zoneId, link, data (LibTreasure entry or nil) }, in bag order.
local function collectMaps()
    local maps, skipped = {}, {}

    local trophies = SHARED_INVENTORY:GenerateFullSlotData(function(i) return i.itemType == ITEMTYPE_TROPHY end, BAG_BACKPACK)
    table.sort(trophies, function(a, b) return a.slotIndex < b.slotIndex end)

    for _, trophy in ipairs(trophies) do
        local zoneName = string.match(trophy.name, SURVEY_PATTERN) or string.match(trophy.name, MAP_PATTERN)
        local data = LibTreasure_GetItemIdData and LibTreasure_GetItemIdData(GetItemId(BAG_BACKPACK, trophy.slotIndex))

        if zoneName or data then
            local link = GetItemLink(BAG_BACKPACK, trophy.slotIndex, LINK_STYLE_BRACKETS)
            local zoneId

            if data then
                local _, _, _, zoneIndex = GetMapInfoById(data.mapId)
                if zoneIndex then
                    zoneId = Teleport.Zones:normalizeZoneId(GetZoneId(zoneIndex))
                end
            end

            if not zoneId and zoneName then
                local _, id = Teleport.Zones:findZoneByNamePrefix(string.gsub(zoneName, " I*$", ""))
                zoneId = id
            end

            if zoneId then
                table.insert(maps, { zoneId = zoneId, link = link, data = data })
            else
                table.insert(skipped, link) -- Cyrodiil & co.
            end
        end
    end

    return maps, skipped
end

-- { { zoneId, maps = {...} }, ... } - current zone first, then the zones you
-- have the most maps for (fewer zone changes overall), then bag order
local function groupByZone(maps, currentZoneId)
    local zones, ordered = {}, {}
    for i, map in ipairs(maps) do
        local zone = zones[map.zoneId]
        if not zone then
            zone = { zoneId = map.zoneId, maps = {}, firstSeen = i }
            zones[map.zoneId] = zone
            table.insert(ordered, zone)
        end
        table.insert(zone.maps, map)
    end

    table.sort(ordered, function(a, b)
        if (a.zoneId == currentZoneId) ~= (b.zoneId == currentZoneId) then
            return a.zoneId == currentZoneId
        end
        if #a.maps ~= #b.maps then
            return #a.maps > #b.maps
        end
        return a.firstSeen < b.firstSeen
    end)

    return ordered
end

local function describeZone(zone, map)
    local others = #zone.maps - 1
    local more = ""
    if others > 0 then
        more = " (+" .. others .. " more in " .. color(GetZoneNameById(zone.zoneId), C.ZONE) .. ")"
    end
    return (map or zone.maps[1]).link .. more
end

-------------------------------------------------------------------------------
-- Map positions (LibTreasure)

-- Best wayshrine / walking option for the maps of one zone. Nil if
-- LibTreasure doesn't know where any of them are.
local function planForZone(zone)
    local byMapId = {}
    for _, map in ipairs(zone.maps) do
        if map.data then
            byMapId[map.data.mapId] = byMapId[map.data.mapId] or {}
            table.insert(byMapId[map.data.mapId], { x = map.data.x, y = map.data.y, map = map })
        end
    end
    if not next(byMapId) then return nil end

    local plans = {}
    Teleport.Helpers:pushMap()
    for mapId, targets in pairs(byMapId) do
        if SetMapToMapId(mapId) ~= SET_MAP_RESULT_FAILED then
            table.insert(plans, Teleport.Nodes:planOnCurrentMap(targets))
        end
    end
    Teleport.Helpers:popMap()

    return Teleport.Nodes:mergePlans(plans)
end

local function walkMessage(plan)
    local suffix = Teleport.Helpers:isAtWayshrine() and " - this is the closest wayshrine." or " - closer than any wayshrine."
    info(plan.walkTarget.map.link .. " is " .. Teleport.Helpers:formatMeters(plan.walkDistance) .. " away" .. suffix)
end

local function travelToNode(zone, plan)
    return Teleport.Nodes:travelTo(plan.node.index, " " .. describeZone(zone, plan.nodeTarget.map))
end

local function jumpToPlayer(zone, player)
    return Teleport.Players:teleportToPlayer(player, nil,
        " " .. describeZone(zone))
end

-------------------------------------------------------------------------------

local function travel(mode)
    if Teleport.Helpers:isAtWayshrine() then
        mode = MODE_PAID -- free anyway
    end
    local canJump = mode ~= MODE_PAID
    local canPay  = mode ~= MODE_FREE

    local maps, skipped = collectMaps()
    if #maps == 0 then
        if #skipped > 0 then
            info("Only maps / surveys Teleport can't help with are left: " .. table.concat(skipped, ", "))
        else
            info("No more maps / surveys found in your inventory.")
        end
        return
    end

    if canPay and not LibTreasure then
        info(color("LibTreasure", C.NOT_FOUND) .. " is required for paid teleport to survey maps")
        if not canJump then return end
        canPay = false
    end

    local currentZoneId = Teleport.Zones:getPlayerZoneId()
    local zones = groupByZone(maps, currentZoneId) -- current zone first

    -- 0. already close to a map in the current zone - just walk there
    local plans = {}
    if zones[1].zoneId == currentZoneId then
        plans[zones[1]] = planForZone(zones[1])
        if Teleport.Nodes:shouldWalk(plans[zones[1]]) then
            return walkMessage(plans[zones[1]])
        end
    end

    -- 1. free: players in any of the zones, current zone first
    if canJump then
        local zoneSet = {}
        for _, zone in ipairs(zones) do zoneSet[zone.zoneId] = true end
        local players = Teleport.Players:findPlayersInZones(zoneSet)

        for _, zone in ipairs(zones) do
            if players[zone.zoneId] then
                return jumpToPlayer(zone, players[zone.zoneId])
            end
        end

        local names = {}
        for _, zone in ipairs(zones) do
            table.insert(names, color(GetZoneNameById(zone.zoneId), C.SURVEY))
        end
        local msg = "No players in the following zones: " .. table.concat(names, ", ")
        if not canPay then
            info(msg)
            return
        end
        info(msg .. ". Falling back to paid teleport.")
    end

    -- 2. paid (or free when at a wayshrine): wayshrines, current zone first
    for _, zone in ipairs(zones) do
        local plan = plans[zone] or planForZone(zone)
        if plan and plan.node then
            return travelToNode(zone, plan)
        end
        info("Skipping " .. describeZone(zone) .. ": " .. (plan and "No known wayshrines in that zone." or "Unknown map location."))
    end
end

function Teleport.SurveyMaps:teleportToSurveyMap(tryPaid)
    return travel(tryPaid and MODE_BOTH or MODE_FREE)
end

function Teleport.SurveyMaps:paidTeleportToSurveyMap()
    return travel(MODE_PAID)
end
