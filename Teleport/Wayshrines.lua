Wayshrines = {}

local _wayshrines = nil

function Wayshrines:findWayshrine(prefix)
    if _wayshrines == nil then
        _wayshrines = {}
        for nodeIndex, name in pairs(Nodes:getNodes()) do
            if Nodes:getPointOfInterestType(nodeIndex) == POI_TYPE_WAYSHRINE then
                _wayshrines[nodeIndex] = string.sub(name, 1, #name - #' Wayshrine')
            end
        end
    end

    return Helpers:findByCaseInsensitiveValuePrefix(_wayshrines, prefix)
end

-------------------------------------------------------------------------------    

function Wayshrines:portToWayshrine(name)
    if checkIsEmptyAndPrintHelp(name) then return true end

    local nodeIndex, nodeName = Wayshrines:findWayshrine(name)
    if nodeIndex == nil then
        dbg("Failed to port to " .. name .. ": No such wayshrine found.")
        return false
    end
	
	if not Nodes:isKnown(nodeIndex) then
		info("Failed to port to " .. nodeName .. ": Wayshrine not unlocked.")
        return true
	end

    info("Teleporting to wayshrine: " .. nodeName .. " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)")
    FastTravelToNode(nodeIndex)
    return true
end


