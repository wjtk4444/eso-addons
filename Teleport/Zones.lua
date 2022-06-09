Teleport.Zones = { }

local info = Teleport.info
local dbg  = Teleport.dbg

-- similarly to arenas, there seems to be no separate POI type for those
-- so a Zone Name => Zone ID lookup table is the only option
-- https://en.uesp.net/wiki/Online:Zones#Overworld_Zones
-- https://wiki.esoui.com/Zones
local ZONES = {
        -- Aldmeri Dominion
        ["Auridon"                     ] = 381,
        ["Grahtwood"                   ] = 383,
        ["Greenshade"                  ] = 108,
        ["Khenarthi's Roost"           ] = 537,
        ["Malabal Tor"                 ] = 58,
        ["Reaper's March"              ] = 382,

        -- Daggerfall Covenant
        ["Alik'r Desert"               ] = 104,
        ["Bangkorai"                   ] = 92,
        ["Betnikh"                     ] = 535,
        ["Glenumbra"                   ] = 3,
        ["Rivenspire"                  ] = 20,
        ["Stormhaven"                  ] = 19,
        ["Stros M'Kai"                 ] = 534,

        -- Ebonheart Pact
        ["Bal Foyen"                   ] = 281,
        ["Bleakrock Isle"              ] = 280,
        ["Deshaan"                     ] = 57,
        ["Eastmarch"                   ] = 101,
        ["The Rift"                    ] = 103,
        ["Shadowfen"                   ] = 117,
        ["Stonefalls"                  ] = 41,

        -- Neutral and Disputed
        ["Coldharbour"                 ] = 347,
        ["Craglorn"                    ] = 888,
        ["Cyrodiil"                    ] = 181,

        -- Chapter Zones
        ["Artaeum"                     ] = 1027,
        ["Blackreach: Greymoor Caverns"] = 1161,
        ["Blackwood"                   ] = 1261,
        ["Northern Elsweyr"            ] = 1086,
        ["Summerset"                   ] = 1011,
        ["Vvardenfell"                 ] = 849,
        ["Western Skyrim"              ] = 1160,
        ["High Isle"                   ] = 1318,

        -- Story DLC Zones
        ["Blackreach: Arkthzand Cavern"] = 1208,
        ["Clockwork City"              ] = 980,
        ["Gold Coast"                  ] = 823,
        ["Hew's Bane"                  ] = 816,
        ["Murkmire"                    ] = 726,
        ["The Reach"                   ] = 1207,
        ["Southern Elsweyr"            ] = 1133,
        ["Wrothgar"                    ] = 684,
        ["The Deadlands"               ] = 1272,
    }

-------------------------------------------------------------------------------    

function Teleport.Zones:findZone(prefix)
    for alias, zoneName in pairs(Teleport.Aliases:getZoneAliases()) do
        if Teleport.Helpers:startsWithCaseInsensitive(alias, prefix) then
            return zoneName, ZONES[zoneName]
        end
    end

    for zoneName, zoneId in pairs(ZONES) do
        if Teleport.Helpers:startsWithCaseInsensitive(zoneName, prefix) then
            return zoneName, zoneId
        end
    end
    
    return nil, nil
end

function Teleport.Zones:teleportToZone(prefix)
    if Teleport.Helpers:checkIsEmptyAndPrintHelp(prefix) then return true end
        
    local zoneName, zoneId = Teleport.Zones:findZone(prefix)
    if not zoneName then
        dbg("Failed to teleport to " .. prefix .. ": No such zone found.")
        return false
    end
        
    local player = Teleport.Players:findPlayerByZoneId(zoneId)
    if not player then
        info("Failed to teleport to " .. zoneName .. ": No party members/friends/guildies in that zone.")
        return true
    end
    
    return Teleport.Players:teleportToPlayer(player)
end

