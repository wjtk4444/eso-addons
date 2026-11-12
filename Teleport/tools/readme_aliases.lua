-- Prints the alias tables for README.md (everything after the <!--splitter--> line).
-- Runs the addon's own Aliases.lua, so the tables match what the game does.
-- Usage (from the addon folder): lua tools/readme_aliases.lua   (Lua 5.1 / LuaJIT)

Teleport = { info = function() end, color = function(msg) return msg end, COLORS = {} }
dofile("Helpers.lua")
dofile("Aliases.lua")

local sections, all = {}, {}
for line in io.lines("tools/instances.txt") do
    local header = line:match("^## (.+)$")
    if header then
        table.insert(sections, { header = header, names = {} })
    elseif line ~= "" and not line:match("^#") then
        table.insert(sections[#sections].names, line)
        table.insert(all, line)
    end
end

-- the addon passes the names in alphabetical order
table.sort(all)
Teleport.Aliases:generateDungeonAliases(all)

local byName = {}
for _, entry in ipairs(Teleport.Aliases:getDungeonAliases()) do
    byName[entry.name] = byName[entry.name] or {}
    table.insert(byName[entry.name], entry.alias)
end

local out = {}
local function add(text) table.insert(out, text) end

for _, section in ipairs(sections) do
    local header, link = section.header:match("^(.-) %((http.-)%)$")
    add("")
    add("### " .. (header or section.header))
    if link then add("") add("[" .. link .. "](" .. link .. ")") end
    add("")
    add("| Name | Aliases |")
    add("|-|-|")
    for _, name in ipairs(section.names) do
        local aliases = byName[name] or {}
        for i, alias in ipairs(aliases) do aliases[i] = "`" .. alias .. "`" end
        add("| " .. name .. " | " .. (#aliases > 0 and table.concat(aliases, ", ") or "-") .. " |")
    end
end

add("")
add("### Zone short names")
add("")
add("Zones starting with \"The \" or a \"Something: \" label also work without it (The Reach → Reach, Blackreach: Greymoor Caverns → Greymoor Caverns). Additionally:")
add("")
add("| Short name | Zone |")
add("|-|-|")
local zones = {}
for short, name in pairs(Teleport.Aliases:getZoneAliases()) do
    table.insert(zones, { short = short, name = name })
end
table.sort(zones, function(a, b) return a.short < b.short end)
for _, zone in ipairs(zones) do
    add("| " .. zone.short .. " | " .. zone.name .. " |")
end

io.write(table.concat(out, "\n"), "\n")
