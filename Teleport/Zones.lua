Teleport.Zones = { }

local info = Teleport.info
local dbg  = Teleport.dbg

-- similarly to arenas, there seems to be no separate POI type for those
-- so lookup table is the only option
-- https://en.uesp.net/wiki/Online:Zones#Overworld_Zones
local ZONES = {
        -- Aldmeri Dominion
        ["Auridon"          ] = true,
        ["Grahtwood"        ] = true,
        ["Greenshade"       ] = true,
        ["Khenarthi's Roost"] = true,
        ["Malabal Tor"      ] = true,
        ["Reaper's March"   ] = true,

        -- Daggerfall Covenant
        ["Alik'r Desert"    ] = true,
        ["Bangkorai"        ] = true,
        ["Betnikh"          ] = true,
        ["Glenumbra"        ] = true,
        ["Rivenspire"       ] = true,
        ["Stormhaven"       ] = true,
        ["Stros M'Kai"      ] = true,

        -- Ebonheart Pact
        ["Bal Foyen"        ] = true,
        ["Bleakrock Isle"   ] = true,
        ["Deshaan"          ] = true,
        ["Eastmarch"        ] = true,
        ["The Rift"         ] = true,
        ["Shadowfen"        ] = true,
        ["Stonefalls"       ] = true,

        -- Neutral and Disputed
        ["Coldharbour"      ] = true,
        ["Craglorn"         ] = true,
        ["Cyrodiil"         ] = true,

        -- Chapter Zones
        ["Artaeum"          ] = true,
        ["Blackreach"       ] = true,
        ["Northern Elsweyr" ] = true,
        ["Summerset"        ] = true,
        ["Vvardenfell"      ] = true,
        ["Western Skyrim"   ] = true,

        -- Story DLC Zones
        ["Clockwork City"   ] = true,
        ["Gold Coast"       ] = true,
        ["Hew's Bane"       ] = true,
        ["Murkmire"         ] = true,
        ["Southern Elsweyr" ] = true,
        ["Wrothgar"         ] = true,
    }
    
-------------------------------------------------------------------------------    

function Teleport.Zones:findZone(prefix)
    for zone, _ in pairs(ZONES) do
        if Teleport.Helpers:startsWithCaseInsensitive(zone, prefix) then
            return zone
        end
    end
    
    return nil
end

function Teleport.Zones:teleportToZone(name)
    if checkIsEmptyAndPrintHelp(name) then return true end
        
    local zone = Teleport.Zones:findZone(name)
    if not zone then
        dbg("Failed to teleport to " .. name .. ": No such zone found.")
        return false
    end
        
    local player = Teleport.Players:findPlayerByZone(zone)
    if not player then
        info("Failed to teleport to " .. zone .. ": No party members/friends/guildies in that zone.")
        return true
    end
    
    return Teleport.Players:teleportToPlayer(player)
end

