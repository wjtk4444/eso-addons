Teleport.Helpers = { }

local info = Teleport.info

function Teleport.Helpers:checkIsEmptyAndPrintHelp(name)
    if not name or name == '' then
        info("No input specified, see `/tp help` for help")
        return true
    end
    
    return false
end

function Teleport.Helpers:startsWith(str, start)
    return string.sub(str, 1, #start) == start
end

function Teleport.Helpers:startsWithCaseInsensitive(str, start)
    return self:startsWith(string.lower(str), string.lower(start))
end

function Teleport.Helpers:splitInTwo(input, separator)
    local position = string.find(input, separator, 1, true)
    if not position then return nil end
    return string.sub(input, 1, position - 1), string.sub(input, position + 1)
end

function Teleport.Helpers:findByCaseInsensitiveKeyPrefix(map, prefix, customComparator)
    for _, key in ipairs(self:getSortedKeys(map, customComparator)) do
        if self:startsWithCaseInsensitive(key, prefix) then
            return key, map[key]
        end
    end
    
    return nil
end

function Teleport.Helpers:getSortedKeys(map, comparator)
    local keys = { }
    for key in pairs(map) do
        table.insert(keys, key)
    end

    table.sort(keys, comparator or (function (a, b) return a < b end))
    return keys
end

