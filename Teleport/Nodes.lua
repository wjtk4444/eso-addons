Teleport.Nodes = {}

local _nodes = nil
function Teleport.Nodes:getNodes()
    if _nodes == nil then
        _nodes = {}
        for nodeIndex = 1, GetNumFastTravelNodes() do
            _, nodeName, _, _, _, _, _ = GetFastTravelNodeInfo(nodeIndex)
            if nodeName then _nodes[nodeIndex] = nodeName end
        end
    end
    
    return _nodes
end
    
function Teleport.Nodes:isKnown(nodeIndex)
    return GetFastTravelNodeInfo(nodeIndex)
end

function Teleport.Nodes:getPointOfInterestType(nodeIndex)
    local _, _, _, _, _, _, poiType = GetFastTravelNodeInfo(nodeIndex)
    return poiType
end
