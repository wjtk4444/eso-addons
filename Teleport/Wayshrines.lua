Teleport.Wayshrines = {}

local info = Teleport.info
local dbg  = Teleport.dbg

local _wayshrines = nil
local function _findWayshrine(prefix)
    if _wayshrines == nil then
        _wayshrines = {}
        for nodeIndex, name in pairs(Teleport.Nodes:getNodes()) do
            if Teleport.Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_WAYSHRINE then
                _wayshrines[nodeIndex] = name
            end
        end
    end

    return Teleport.Helpers:findByCaseInsensitiveValuePrefix(_wayshrines, prefix)
end

-------------------------------------------------------------------------------    

function Teleport.Wayshrines:teleportToWayshrine(name)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName = _findWayshrine(name)
    if nodeIndex == nil then
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


