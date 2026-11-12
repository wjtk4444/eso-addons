Teleport.Aliases = {}

local info  = Teleport.info
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local ZONE_ALIASES = {
        -- Zones https://en.uesp.net/wiki/Online:Zones#Overworld_Zones
        ["Arkthzand Cavern"         ] = "Blackreach: Arkthzand Cavern",
        ["Greymoor Caverns"         ] = "Blackreach: Greymoor Caverns",
        ["Elsweyr"                  ] = "Northern Elsweyr",
        ["Skyrim"                   ] = "Western Skyrim",
        ["Weald"                    ] = "West Weald",
    }

local DUNGEON_ALIASES = {
        -- Trials https://en.uesp.net/wiki/Online:Trials
        ["ss"  ] = "Sunspire",
        ["cr"  ] = "Cloudrest",
        ["rg"  ] = "Rockgrove",
        ["dsr" ] = "Dreadsail Reef",

        -- Arenas https://en.uesp.net/wiki/Online:Arenas
        ["dsa" ] = "Dragonstar Arena",
        ["brp" ] = "Blackrose Prison",

        -- Base Game Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["sc"  ] = "Spindleclutch I",
        ["sc1" ] = "Spindleclutch I",
        ["sc2" ] = "Spindleclutch II",
        ["vf"  ] = "Volenfell",

        -- DLC Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["brf" ] = "Bloodroot Forge",
        ["scp" ] = "Scalecaller Peak",
        ["mk"  ] = "Moon Hunter Keep",
        ["fv"  ] = "Frostvault",
        ["mgf" ] = "Moongrave Fane",
        ["ir"  ] = "Icereach",
        ["cd"  ] = "The Cauldron",
        ["dc"  ] = "The Dread Cellar",
    }
	
-------------------------------------------------------------------------------

local function addDungeonAliasAux(alias, name)
	if #alias > 1 then
		DUNGEON_ALIASES[alias] = name
	end
end

function Teleport.Aliases:generateDungeonAliases(dungeons)
	for _, name in ipairs(dungeons) do
		local the = false
		local one = false
		local two = false
		if Teleport.Helpers:startsWith(name, "The ") then
			the = true
		end
		if Teleport.Helpers:endsWith(name, " I") then
			one = true
		end
		if Teleport.Helpers:endsWith(name, " II") then
			two = true
		end
		
		local alias = Teleport.Helpers:initialsFromSpaceAndDash(name)
		if one or two then
			alias = Teleport.Helpers:removeLastChar(alias)
		end
		
		addDungeonAliasAux(alias, name)
		if the then
			addDungeonAliasAux(Teleport.Helpers:removeFirstChar(alias), name)
		end
		if one then
			addDungeonAliasAux(alias .. "1", name)
		end
		if two then
			addDungeonAliasAux(alias .. "2", name)
		end
	end
end


function Teleport.Aliases:generateZoneAliases(zones)
	for _, name in ipairs(zones) do
		-- remove "The " or "Blackreach: " prefix
		if Teleport.Helpers:startsWith(name, "The ") or Teleport.Helpers:startsWithLabel(name) then
			ZONE_ALIASES[Teleport.Helpers:removeFirstWord(name)] = name
		end
	end
end

-------------------------------------------------------------------------------    

local SAVED_VARS
function Teleport.Aliases:setSavedVars(savedVars)
    SAVED_VARS = savedVars
end

-------------------------------------------------------------------------------    

function Teleport.Aliases:getZoneByShortNamePrefix(shortNamePrefix)
    for shortName, zoneName in pairs(ZONE_ALIASES) do
        if Teleport.Helpers:startsWithCaseInsensitive(shortName, shortNamePrefix) then
            return zoneName
        end
    end
    
    return nil
end

function Teleport.Aliases:getDungeonByAlias(alias)
    alias = string.lower(alias)
    local expansion = DUNGEON_ALIASES[alias]
    if expansion then return expansion, nil end
    local difficulty = string.sub(alias, 1, 1)
    if difficulty == 'n' or difficulty == 'v' or difficulty == 'r' then
        expansion = DUNGEON_ALIASES[string.sub(alias, 2)]
        if expansion then return expansion, difficulty end
    end
    
    return nil, nil
end

-------------------------------------------------------------------------------    

function Teleport.Aliases:expandUserDefined(alias)
    alias = string.lower(alias)
    return SAVED_VARS[alias] or alias
end

function Teleport.Aliases:listAliases()
    info("Registered aliases:")
    for alias, expansion in pairs(SAVED_VARS) do
        info(color(alias, C.ALIAS) .. ' => ' .. color(expansion, C.ALIAS))
    end
end

function Teleport.Aliases:addAlias(alias)
    if not alias or alias == '' then
        info("USAGE: /tp --add " .. color("<alias-name> <alias-expansion>", C.ALIAS))
        return
    end
    local expansion
    alias, expansion = Teleport.Helpers:splitOnSpace(alias, ' ')
    if not alias or alias == '' or expansion == '' then
        info("USAGE: /tp --add " .. color("<alias-name> <alias-expansion>", C.ALIAS))
        return
    end
    if SAVED_VARS[alias] then
        info("alias " .. alias .. " already exists")
        info(alias .. ' => ' .. SAVED_VARS[alias])
        return
    end

    SAVED_VARS[alias] = expansion
    info("New alias added:")
    info(color(alias, C.ALIAS) .. ' => ' .. color(expansion, C.ALIAS))
end

function Teleport.Aliases:removeAlias(alias)
    if not alias or alias == '' then
        info("USAGE: /tp --remove " .. color("<alias-name>", C.ALIAS))
        return
    end
    if not SAVED_VARS[alias] then
        info("alias " .. color(alias, C.NOT_FOUND) .. " doesn't exist")
        return
    end

    local expansion = SAVED_VARS[alias]
    SAVED_VARS[alias] = nil
    info("Alias removed:")
    info(color(alias, C.ALIAS) .. ' => ' .. color(expansion, C.ALIAS))
end
