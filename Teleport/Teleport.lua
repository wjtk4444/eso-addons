Teleport = { }

Teleport.info =           function(msg) CHAT_SYSTEM:AddMessage("[Teleport]: "        .. msg) end
Teleport.dbg  = false and function(msg) CHAT_SYSTEM:AddMessage("[Teleport][DEBUG]: " .. msg) end or function() end

local info = Teleport.info
local dbg  = Teleport.dbg

--------------------------------------------------------------------------------

local function _printHelp()
    info("All name prefixes and predefined aliases are case insensitive, first match will always be used.")
    info("All dungeons/trials/arenas are called by their common aliases such as HRC, SS, FG2, BC1, VoM.")
    info("Prepending their names with N or V will attempt to switch dungeon difficulty to veteran/normal.")
    info("Teleporting to players, zones and houses is free of cost.")
    info("Teleporting to dungeons is free of cost if any of the party members is inside,")
    info("otherwise it falls back to paid teleport.")
    info("Search order for players: group, friends, guilds")
    info("Search order for places: zone, wayshrine, house, dungeon")
    info("Available commands:         (call `/tp examples` for examples)")
    info("/tp customaliasname")
    info("/tp builtinaliasname")
    info("/tp placenameprefix")
    info("/tp @playernameprefix                 (teleport to online player)")
    info("/tp @playernameprefix housenameprefix (teleport to player's house)")
    info("/tp @@exactplayername housenameprefix (teleport to player's house)")
    info("You can use 'primary' or 'main' instead of house name.")
    info("When using @@ and exact player names, they don't have to be in your group/friends/guilds.")
    info("You can add custom aliases that can expand to any valid /tp command")
    info("/tp addAlias aliasname expansion")
    info("/tp delAlias aliasname (removes alias)")
    info("/tp lstAlias           (lists avaiable aliases)")
    info("/tp leader             (same as built-in /jumptoleader, just shorter and aliasable")
    info("User defined aliases are case sensitive")
    info("Call '/tp examples' to see command examples")
    info("There's a README.md file in addon folder, check it out for more detais")
    info("A pretty-formatted online version of the manual is available here:")
    info("https://github.com/wjtk4444/eso-addons/tree/master/Teleport")
end

local function _printExamples()
    info("All name prefixes and built-in aliases are case insensitive, first match will always be used.")
    info("User defined aliases are case sensitive")
    info("/tp vv                        (Vvardenfell zone")
    info("/tp Vvardenfell               (Vvardenfell zone")
    info("/tp MoL                       (Maw Of Lorkhaj)")
    info("/tp nMoL                      (Maw Of Lorkhaj (will attempt to set dungeon difficulty to normal)")
    info("/tp fg2                       (Fungal Grotto II")
    info("/tp vFG2                      (Fungal Grotto II (will attempt to set dungeon difficulty to veteran)")
    info("/tp mourn                     (Mournhold Wayshrine")
    info("/tp @Alice                    (First party member/friend/guildie whose name starts with '@alice'")
    info("/tp @ali snug                 (@Alice's Snugpod house")
    info("/tp @@ali snug                (@ali's Snugpod house, ali does not have to be in party/friends/guilds")
    info("/tp addAlias ali @@ali snug   (an alias to @ali's Sungpod house)")
    info("/tp ali")
    info("/tp addAlias vivec Vivec City (Vivec City wayshrine alias)")
    info("/tp vivec")
end

--------------------------------------------------------------------------------

local function _playerHelper(name)
    local player, house = Teleport.Helpers:splitInTwo(name, ' ')
    if player and house then
        return Teleport.Houses:teleportToPlayersHouse(player, house)
    else
        player = Teleport.Players:findPlayerByName(name)
        if not player then
            info("Failed to teleport to " .. name .. ": Player not found.")
            return true
        end

        return Teleport.Players:teleportToPlayer(player) 
    end
end

local function tp(name)
    name = Teleport.Aliases:expandUserDefined(name)
    if Teleport.Helpers:startsWith(name, '@') then return _playerHelper(name) end

    if name == 'help'     then return _printHelp()           end
    if name == 'examples' then return _printExamples()       end
    if name == 'lstAlias' then return Teleport.Aliases:listAliases()  end
    if name == 'leader'   then return Teleport.Players:teleportToLeader() end

    if Teleport.Helpers:startsWith(name, 'addAlias ') then 
        return Teleport.Aliases:addAlias   (string.sub(name, #'addAlias ' + 1)) 
    end
    if Teleport.Helpers:startsWith(name, 'delAlias ') then 
        return Teleport.Aliases:removeAlias(string.sub(name, #'delAlias ' + 1)) 
    end

    if Teleport.Dungeons  :teleportToDungeon  (name, true)  then return end -- alias only matches
    if Teleport.Zones     :teleportToZone     (name) then return end
    if Teleport.Wayshrines:teleportToWayshrine(name) then return end
    if Teleport.Houses    :teleportToHouse    (name) then return end
    if Teleport.Dungeons  :teleportToDungeon  (name, false) then return end -- all matches

    info("Failed to teleport to " .. name .. ": No dungeon/zone/wayshrine/house found")
end

SLASH_COMMANDS['/tp'] = tp

EVENT_MANAGER:RegisterForEvent('Teleport', EVENT_ADD_ON_LOADED, function() 
        EVENT_MANAGER:UnregisterForEvent('Teleport', EVENT_ADD_ON_LOADED)
        local SAVED_VARS = ZO_SavedVars:NewAccountWide('TeleportAliases', 1, nil, { ALIASES = { } })
        Teleport.Aliases:setSavedVars(SAVED_VARS.ALIASES)
    end)

