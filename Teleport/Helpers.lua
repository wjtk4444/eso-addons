Teleport.Helpers = {}

function Teleport.Helpers:startsWith(str, start)
    if not str or not start then return false end
    return string.sub(str, 1, #start) == start
end

function Teleport.Helpers:startsWithCaseInsensitive(str, start)
    if type(start) == 'table' then d(start[1], start[2]) end
    if not str or not start then return false end
    return Teleport.Helpers:startsWith(string.lower(str), string.lower(start))
end

function Teleport.Helpers:splitOnSpace(input)
    local position = string.find(input, ' ', 1, true)
    if not position then return nil end
    return string.sub(input, 1, position - 1), string.sub(input, position + 1)
end

function Teleport.Helpers:isAtWayshrine()
    return GetInteractionType() == INTERACTION_FAST_TRAVEL
end
