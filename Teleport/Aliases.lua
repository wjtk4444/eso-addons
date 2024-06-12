Teleport.Aliases = {}

local info  = Teleport.info
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local PREDEFINED_ZONE_SHORT_NAMES = {
        -- Zones https://en.uesp.net/wiki/Online:Zones#Overworld_Zones
        ["Reach"                    ] = "The Reach",
        ["Rift"                     ] = "The Rift",
        ["Arkthzand Cavern"         ] = "Blackreach: Arkthzand Cavern",
        ["Greymoor Caverns"         ] = "Blackreach: Greymoor Caverns",
        ["Elsweyr"                  ] = "Northern Elsweyr",
        ["Skyrim"                   ] = "Western Skyrim",
        ["Deadlands"                ] = "The Deadlands",
        ["Weald"                    ] = "West Weald",
    }

local PREDEFINED_DUNGEON_ALIASES = {
        -- Trials https://en.uesp.net/wiki/Online:Trials
        ["as"  ] = "Asylum Sanctorium",
        ["aa"  ] = "Aetherian Archive",
        ["hrc" ] = "Hel Ra Citadel",
        ["so"  ] = "Sanctum Ophidia",
        ["ss"  ] = "Sunspire",
        ["mol" ] = "Maw of Lorkhaj",
        ["cr"  ] = "Cloudrest",
        ["hof" ] = "Halls of Fabrication",
        ["ka"  ] = "Kyne's Aegis",
        ["rg"  ] = "Rockgrove",
        ["dsr" ] = "Dreadsail Reef",
        ["se"  ] = "Sanity's Edge",
        ["lc"  ] = "Lucent Citadel",

        -- Arenas https://en.uesp.net/wiki/Online:Arenas
        ["ma"  ] = "Maelstrom Arena",
        ["dsa" ] = "Dragonstar Arena",
        ["brp" ] = "Blackrose Prison",
        ["vh"  ] = "Vateshran Hollows",

        -- Base Game Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["ac"  ] = "Arx Corinium",
        ["arx" ] = "Arx Corinium",
        ["bc"  ] = "The Banished Cells I",
        ["bc1" ] = "The Banished Cells I",
        ["tbc1"] = "The Banished Cells I",
        ["bc2" ] = "The Banished Cells II",
        ["tbc2"] = "The Banished Cells II",
        ["bh"  ] = "Blackheart Haven",
        ["bc"  ] = "Blessed Crucible",
        ["coa" ] = "City of Ash I",
        ["coa1"] = "City of Ash I",
        ["coa2"] = "City of Ash II",
        ["coh" ] = "Crypt of Hearts I",
        ["coh1"] = "Crypt of Hearts I",
        ["coh2"] = "Crypt of Hearts II",
        ["dc1" ] = "Darkshade Caverns I",
        ["dc2" ] = "Darkshade Caverns II",
        ["dk"  ] = "Direfrost Keep",
        ["dfk" ] = "Direfrost Keep",
        ["eh"  ] = "Elden Hollow I",
        ["eh1" ] = "Elden Hollow I",
        ["eh2" ] = "Elden Hollow II",
        ["fg"  ] = "Fungal Grotto I",
        ["fg1" ] = "Fungal Grotto I",
        ["fg2" ] = "Fungal Grotto II",
        ["sw"  ] = "Selene's Web",
        ["sc"  ] = "Spindleclutch I",
        ["sc1" ] = "Spindleclutch I",
        ["sc2" ] = "Spindleclutch II",
        ["ti"  ] = "Tempest Island",
        ["vom" ] = "Vaults of Madness",
        ["vf"  ] = "Volenfell",
        ["vol" ] = "Volenfell",
        ["ws"  ] = "Wayrest Sewers I",
        ["ws1" ] = "Wayrest Sewers I",
        ["ws2" ] = "Wayrest Sewers II",

        -- DLC Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["icp" ] = "Imperial City Prison",
        ["ic"  ] = "Imperial City Prison",
        ["wgt" ] = "White-Gold Tower",
        ["cos" ] = "Cradle of Shadows",
        ["cs"  ] = "Cradle of Shadows",
        ["rom" ] = "Ruins of Mazzatun",
        ["bf"  ] = "Bloodroot Forge",
        ["brf" ] = "Bloodroot Forge",
        ["fh"  ] = "Falkreath Hold",
        ["fl"  ] = "Fang Lair",
        ["sp"  ] = "Scalecaller Peak",
        ["scp" ] = "Scalecaller Peak",
        ["mos" ] = "March of Sacrifices",
        ["mk"  ] = "Moon Hunter Keep",
        ["mhk" ] = "Moon Hunter Keep",
        ["dom" ] = "Depths of Malatar",
        ["fv"  ] = "Frostvault",
        ["lom" ] = "Lair of Maarselok",
        ["mf"  ] = "Moongrave Fane",
        ["mgf" ] = "Moongrave Fane",
        ["ir"  ] = "Icereach",
        ["ug"  ] = "Unhallowed Grave",
        ["ct"  ] = "Castle Thorn",
        ["sg"  ] = "Stone Garden",
        ["bdv" ] = "Black Drake Villa",
        ["tc"  ] = "The Cauldron",
        ["cd"  ] = "The Cauldron",
        ["tdc" ] = "The Dread Cellar",
        ["dc"  ] = "The Dread Cellar",
        ["rpb" ] = "Red Petal Bastion",
        ["ca"  ] = "Coral Aerie",
        ["sr"  ] = "Shipwright's Regret",
        ["ere" ] = "Earthen Root Enclave",
        ["gd"  ] = "Graven Deep",
        ["sh"  ] = "Scrivener's Hall",
        ["bs"  ] = "Bal Sunnar",
        ["op"  ] = "Oathsworn Pit",
        ["bv"  ] = "Bedlam Veil",

        ["ia"  ] = "Infinite Archive",
    }

-------------------------------------------------------------------------------    

local SAVED_VARS
function Teleport.Aliases:setSavedVars(savedVars)
    SAVED_VARS = savedVars
end

-------------------------------------------------------------------------------    

function Teleport.Aliases:getZoneByShortNamePrefix(shortNamePrefix)
    for shortName, zoneName in pairs(PREDEFINED_ZONE_SHORT_NAMES) do
        if Teleport.Helpers:startsWithCaseInsensitive(shortName, shortNamePrefix) then
            return zoneName
        end
    end
    
    return nil
end

function Teleport.Aliases:getDungeonByAlias(alias)
    alias = string.lower(alias)
    local expansion = PREDEFINED_DUNGEON_ALIASES[alias]
    if expansion then return expansion, nil end
    local difficulty = string.sub(alias, 1, 1)
    if difficulty == 'n' or difficulty == 'v' or difficulty == 'r' then
        expansion = PREDEFINED_DUNGEON_ALIASES[string.sub(alias, 2)]
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
