Houses = { }

local _houses = nil
local function _findHouse(prefix)
    if _houses == nil then
        _houses = {}
        for nodeIndex, name in pairs(Nodes:getNodes()) do
            if Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_HOUSE then
                _houses[nodeIndex] = name
            end
        end
    end

    return Helpers:findByCaseInsensitiveValuePrefix(_houses, prefix)
end

-------------------------------------------------------------------------------    

function Houses:portToHouse(name)
    if checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName = _findHouse(name)
    if not nodeIndex then
        dbg("Failed to port to " .. name .. ": No such house.")
        return false
    end

    local collectibleId = GetCollectibleIdForHouse(GetFastTravelNodeHouseId(nodeIndex))
    local _, _, _, _, unlocked, _, _, _, _, _ = GetCollectibleInfo(collectibleId)

    if not unlocked then
        info("Failed to port to " .. nodeName .. ": House not owned.")
        return true
    end
    
    info("Porting to house: " .. nodeName)
    FastTravelToNode(nodeIndex)
    return true
end

function Houses:portToPlayersHouse(name, house)
    local player = nil
    local exact = false
    if Helpers:startsWith(name, '@@') then
        -- assume a correct exact name if @@ was used
        player = { }
        player.displayName = string.sub(name, 2)
        exact = true
    else
        player = Players:findPlayerByName(name, true)
        if not player then
            info("Failed to port to " .. name .. "'s " .. house .. ": Player not found.")
            return true
        end
    end

    if house == 'primary' or house == 'main' then
        info("Porting to " .. player.displayName .. "'s primary residence")
        JumpToHouse(player.displayName)
        return true
    end

    local nodeIndex, nodeName = _findHouse(house)
    if not nodeIndex then
        info("Failed to port to " .. player.displayName .. "'s " .. house .. ": No such house.")
        return false
    end

    info("Porting to " .. player.displayName .. "'s " .. nodeName)
    JumpToSpecificHouse(player.displayName, GetFastTravelNodeHouseId(nodeIndex))
    return true
end

