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

function Teleport.Helpers:endsWith(str, ending)
    return string.sub(str, -#ending) == ending
end

function Teleport.Helpers:startsWithCaseInsensitive(str, start)
    return Teleport.Helpers:startsWith(string.lower(str), string.lower(start))
end

function Teleport.Helpers:splitInTwo(input, separator)
    local position = string.find(input, separator, 1, true)
    if not position then return nil end
    return string.sub(input, 1, position - 1), string.sub(input, position + 1)
end

function Teleport.Helpers:findByCaseInsensitiveValuePrefix(map, prefix)
    local matches = {}

    for key, value in pairs(map) do
        if Teleport.Helpers:startsWithCaseInsensitive(value, prefix) then
            table.insert(matches, {key, value})
        end
    end

    -- some extra fuckery to match ie. fungal grotto I before fungal grotto II
    if #matches == 0 then return nil end
    table.sort(matches, function (a, b) return a[2] < b[2] end)
    return matches[1][1], matches[1][2]
end

function Teleport.Helpers:findByValue(map, val)
    for key, value in pairs(map) do
        if value == val then
            return key, value
        end
    end
end

function Teleport.Helpers:getSortedKeys(dictionary)
    local keys = { }
    for key in pairs(dictionary) do
        table.insert(keys, key)
    end

    table.sort(keys, function (a, b) return a < b end)
    return keys
end

