Teleport.Aliases = { }

local info = Teleport.info

local PREDEFINED_ALIASES_ZONES = {
        -- Zones https://en.uesp.net/wiki/Online:Zones#Overworld_Zones
        ["Reach"                       ] = "The Reach",
        ["Rift"                        ] = "The Rift",
        ["Arkthzand Cavern"            ] = "Blackreach: Arkthzand Cavern",
        ["Greymoor Caverns"            ] = "Blackreach: Greymoor Caverns",
        ["Elsweyr"                     ] = "Northern Elsweyr",
        ["Skyrim"                      ] = "Western Skyrim",
        ["Deadlands"                   ] = "The Deadlands",
        ["Isle"                        ] = "High Isle",
    }

local PREDEFINED_ALIASES_DUNGEONS = {
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
        ["dr"  ] = "Dreadsail Reef",
        ["dsr" ] = "Dreadsail Reef",

        -- Arenas https://en.uesp.net/wiki/Online:Arenas
        ["ma"  ] = "Maelstrom Arena",
        ["msa" ] = "Maelstrom Arena",
        ["dsa" ] = "Dragonstar Arena",
        ["bp"  ] = "Blackrose Prison",
        ["brp" ] = "Blackrose Prison",
        ["va"  ] = "Vateshran Hollows",
        ["vh"  ] = "Vateshran Hollows",
        ["vha" ] = "Vateshran Hollows",
        ["vsa" ] = "Vateshran Hollows",
        ["vsh" ] = "Vateshran Hollows",
        ["vsha"] = "Vateshran Hollows",

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
        ["ws"  ] = "Wayrest Sewers I",
        ["ws1" ] = "Wayrest Sewers I",
        ["ws2" ] = "Wayrest Sewers II",

        -- DLC Dungeons https://en.uesp.net/wiki/Online:Group_Dungeons
        ["icp" ] = "Imperial City Prison",
        ["ic"  ] = "Imperial City Prison",
        ["ip"  ] = "Imperial City Prison",
        ["wgt" ] = "White-Gold Tower",
        ["cos" ] = "Cradle of Shadows",
        ["rom" ] = "Ruins of Mazzatun",
        ["maz" ] = "Ruins of Mazzatun",
        ["mazz"] = "Ruins of Mazzatun",
        ["bf"  ] = "Bloodroot Forge",
        ["brf" ] = "Bloodroot Forge",
        ["fh"  ] = "Falkreath Hold",
        ["fkh" ] = "Falkreath Hold",
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
        ["ice" ] = "Icereach",
        ["ug"  ] = "Unhallowed Grave",
        ["uhg" ] = "Unhallowed Grave",
        ["ct"  ] = "Castle Thorn",
        ["sg"  ] = "Stone Garden",
        ["bdv" ] = "Black Drake Villa",
        ["bv"  ] = "Black Drake Villa",
        ["bd"  ] = "Black Drake Villa",
        ["dv"  ] = "Black Drake Villa",
        ["tc"  ] = "The Cauldron",
        ["cd"  ] = "The Cauldron",
        ["c"   ] = "The Cauldron",
        ["tdc" ] = "The Dread Cellar",
        ["dc"  ] = "The Dread Cellar",
        ["rpb" ] = "Red Petal Bastion",
        ["ca"  ] = "Coral Aerie",
        ["sr"  ] = "Shipwright's Regret",
        ["ere" ] = "Earthen Root Enclave",
        ["gd"  ] = "Graven Deep",
    }

-------------------------------------------------------------------------------    

function Teleport.Aliases:getZoneAliases()
    return PREDEFINED_ALIASES_ZONES
end

function Teleport.Aliases:getDungeonByAlias(alias)
    alias = string.lower(alias)
    local expansion = PREDEFINED_ALIASES_DUNGEONS[alias]
    if expansion then return expansion, nil end
    local difficulty = string.sub(alias, 1, 1)
    if difficulty == 'n' or difficulty == 'v' then
        return PREDEFINED_ALIASES_DUNGEONS[string.sub(alias, 2)], difficulty == 'v'
    end
    return nil, nil
end

local USER_ALIASES = nil
function Teleport.Aliases:setSavedVars(savedVars)
    USER_ALIASES = savedVars
end

-------------------------------------------------------------------------------    

function Teleport.Aliases:expandUserDefined(alias)
    return USER_ALIASES[alias] or alias
end

function Teleport.Aliases:listAliases()
    local keys = Teleport.Helpers:getSortedKeys(USER_ALIASES)
    if #keys == 0 then
        info("No aliases registered")
        return
    end
    
    for _, key in ipairs(keys) do
        info(key .. ' => ' .. USER_ALIASES[key])
    end
end

function Teleport.Aliases:addAlias(alias)
    local alias, expansion = Teleport.Helpers:splitInTwo(alias, ' ')
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(alias)     then return end
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(expansion) then return end
    if USER_ALIASES[alias] then
        info("alias " .. alias .. " already exists")
        info(alias .. ' => ' .. USER_ALIASES[alias])
        return
    end

    USER_ALIASES[alias] = expansion
    info("New alias added:")
    info(alias .. ' => ' .. expansion)
end

function Teleport.Aliases:removeAlias(alias)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(alias) then return end
    if not USER_ALIASES[alias] then
        info("alias " .. alias .. " doesn't exist")
        return
    end

    local expansion = USER_ALIASES[alias]
    USER_ALIASES[alias] = nil
    info("Alias removed:")
    info(alias .. ' => ' .. expansion)
end
