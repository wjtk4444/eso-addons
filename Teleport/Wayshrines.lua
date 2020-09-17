Teleport.Wayshrines = {}

local info = Teleport.info
local dbg  = Teleport.dbg

local _wayshrines = nil
function Teleport.Wayshrines:findWayshrine(prefix)
    if _wayshrines == nil then
        _wayshrines = {}
        for nodeIndex, name in pairs(Teleport.Nodes:getNodes()) do
            if Teleport.Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_WAYSHRINE then
                _wayshrines[nodeIndex] = string.sub(name, 1, #name - #' Wayshrine')
            end
        end
    end

    return Teleport.Helpers:findByCaseInsensitiveValuePrefix(_wayshrines, prefix)
end

-------------------------------------------------------------------------------    

function Teleport.Wayshrines:teleportToWayshrine(name)
    if checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName = Teleport.Wayshrines:findWayshrine(name)
    if nodeIndex == nil then
        dbg("Failed to teleport to " .. name .. ": No such wayshrine found.")
        return false
    end
	
	if not Teleport.Nodes:isKnown(nodeIndex) then
		info("Failed to teleport to " .. nodeName .. ": Wayshrine not unlocked.")
        return true
	end

    info("Teleporting to wayshrine: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
    FastTravelToNode(nodeIndex)
    return true
end


