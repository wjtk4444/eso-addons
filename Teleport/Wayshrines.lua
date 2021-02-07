Teleport.Wayshrines = {}

local info = Teleport.info
local dbg  = Teleport.dbg

local function _compareNames(w1, w2)
    return string.sub(w1, 1, #w1 - #' Wayshrine') < string.sub(w2, 1, #w2 - #' Wayshrine')
end

local _wayshrines = nil
local function _findWayshrine(prefix)
    if _wayshrines == nil then
        _wayshrines = {}
        for nodeName, nodeIndex in pairs(Teleport.Nodes:getNodes()) do
            if Teleport.Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_WAYSHRINE then
                _wayshrines[nodeName] = nodeIndex
            end
        end
    end

    return Teleport.Helpers:findByCaseInsensitiveKeyPrefix(_wayshrines, prefix, _compareNames)
end

-------------------------------------------------------------------------------    

function Teleport.Wayshrines:teleportToWayshrine(name)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeName, nodeIndex = _findWayshrine(name)
    if nodeName == nil then
        dbg("Failed to teleport to " .. name .. ": No such wayshrine found.")
        return false
    end
	
	if not Teleport.Nodes:isKnown(nodeIndex) then
		info("Failed to teleport to " .. nodeName .. ": Not unlocked.")
        return true
	end

    info("Teleporting to " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
    FastTravelToNode(nodeIndex)
    return true
end


