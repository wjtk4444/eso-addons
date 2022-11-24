Teleport.Houses = { }
local info = Teleport.info
local dbg  = Teleport.dbg
local help

local _houses = nil
local function _findHouse(prefix)
    if _houses == nil then
        _houses = {}
        for nodeName, nodeIndex in pairs(Teleport.Nodes:getNodes()) do
            if Teleport.Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_HOUSE then
                _houses[nodeName] = nodeIndex
				_houses["outside " .. nodeName] = nodeIndex
            end
        end
    end

    return Teleport.Helpers:findByCaseInsensitiveKeyPrefix(_houses, prefix)
end

-------------------------------------------------------------------------------    

function Teleport.Houses:teleportToHouse(name)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeName, nodeIndex = _findHouse(name)
    if not nodeName then
        dbg("Failed to teleport to " .. name .. ": No such house.")
        return false
    end

	local outside = Teleport.Helpers:startsWithCaseInsensitive(nodeName, "outside ")
	local houseId = GetFastTravelNodeHouseId(nodeIndex)
    local collectibleId = GetCollectibleIdForHouse(houseId)
    local _, _, _, _, unlocked, _, _, _, _, _ = GetCollectibleInfo(collectibleId)

	

    if not unlocked then
		if outside then
			info("Cannot teleport outside of a house you don't own")
			return true
		end
        
        info("Previewing house: " .. nodeName)
        RequestJumpToHouse(houseId, false)
        return true
    end
	
    if not outside then
		info("Teleporting to house: " .. nodeName)
		RequestJumpToHouse(houseId, false)
	else
		info("Teleporting outside of house: " .. string.sub(nodeName, 9)) -- 'remove "outside " prefix from house's name'
		RequestJumpToHouse(houseId, true)
	end
    return true
end

function Teleport.Houses:teleportToPlayersHouse(name, house)
    local player = nil
    local exact = false
    if Teleport.Helpers:startsWith(name, '@@') then
        -- assume a correct exact name if @@ was used
        player = { }
        player.displayName = string.sub(name, 2)
        exact = true
    else
        player = Teleport.Players:findPlayerByName(name, true)
        if not player then
            info("Failed to teleport to " .. name .. "'s " .. house .. ": Player not found.")
            return true
        end
    end

    if house == 'primary' or house == 'main' then
        info("Teleporting to " .. player.displayName .. "'s primary residence")
        JumpToHouse(player.displayName)
        return true
    end

    local nodeName, nodeIndex = _findHouse(house)
    if not nodeName then
        info("Failed to teleport to " .. player.displayName .. "'s " .. house .. ": No such house.")
        return false
    end
	
	if Teleport.Helpers:startsWithCaseInsensitive(nodeName, "outside ") then
		info("You cannot teleport outside of other people's houses")
        return true
	end

    info("Teleporting to " .. player.displayName .. "'s " .. nodeName)
    JumpToSpecificHouse(player.displayName, GetFastTravelNodeHouseId(nodeIndex))
    return true
end

