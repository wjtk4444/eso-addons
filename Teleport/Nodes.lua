Teleport.Nodes = {}

local _nodes = nil
function Teleport.Nodes:getNodes()
    if _nodes == nil then
        _nodes = {}
        for nodeIndex = 1, GetNumFastTravelNodes() do
            _, nodeName, _, _, _, _, _ = GetFastTravelNodeInfo(nodeIndex)
            if nodeName then _nodes[nodeName] = nodeIndex end
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

function Teleport.Nodes:getPointOfInterestTextureName(nodeIndex)
    local _, _, _, _, textureName = GetFastTravelNodeInfo(nodeIndex)
    return textureName
end
