info =           function(msg) CHAT_SYSTEM:AddMessage("[Teleport]: "        .. msg) end
dbg  = false and function(msg) CHAT_SYSTEM:AddMessage("[Teleport][DEBUG]: " .. msg) end or function() end

function checkIsEmptyAndPrintHelp(name)
    if not name or name == '' then
        info("No input specified, see `/tp help` for help")
        return true
    end
    
    return false
end

--------------------------------------------------------------------------------

local function _printHelp()
    info("All name prefixes and predefined aliases are case insensitive, first match will always be used.")
    info("All dungeons/trials/arenas are called by their common aliases such as HRC, SS, FG2, BC1, VoM.")
    info("Prepending their names with N or V will attempt to switch dungeon difficulty to veteran/normal.")
    info("Teleporting to players, zones and houses is free of cost.")
    info("Teleporting to dungeons is free of cost if any of the party members is inside,")
    info("otherwise it falls back to paid teleport.")
    info("Search order for players is: group > friends > guilds")
    info("Available commands:    (call `/tp examples` for examples)")
    info("/tp @prefix            (teleport to player, free of cost, order: group > friends > guildies)")
    info("/tp @prefix prefix     (teleport to player's house, free of cost)")
    info("/tp @@exact prefix     (teleport to player's house, free of cost)")
    info("(this one uses exact player name instead of looking trough group > friends > guildies)")
    info("(allows for visiting any player's house, but removes the ability of using primary/main instead of house name)")
    info("(all of the above will fail if you don't haver permissions to visit player's house/current location)")
    info("/tp prefix             (prefix will match in order: alias > dungeon alias > zone > wayshrine > house > dungeon")
    info("You can add your own aliases that can expand to any valid /tp command")
    info("/tp addAlias aliasname expansion")
    info("/tp delAlias aliasname (removes alias)")
    info("/tp list               (lists avaiable aliases)")
    info("/tp leader             (same as built-in /jumptoleader, just shorter and aliasable")
    info("User defined aliases are case sensitive")
    info("Call '/tp examples' to see command examples")
    info("There's a HTML manual in addon folder, check it out for more detais")
end

local function _printExamples()
    info("All name prefixes and aliases are case insensitive, first match will always be used.")
    info("/tp vv                      Vvardenfell zone")
    info("/tp Vvardenfell             Vvardenfell zone")
    info("/tp MoL                     Maw Of Lorkhaj)")
    info("/tp nMoL                    Maw Of Lorkhaj (will attempt to set dungeon difficulty to normal)")
    info("/tp fg2                     Fungal Grotto II")
    info("/tp vFG2                    Fungal Grotto II (will attempt to set dungeon difficulty to veteran)")
    info("/tp mourn                   Mournhold Wayshrine")
    info("/tp @Alice                  First party member/friend/guildie whose name starts with '@alice'")
    info("/tp @ali snug               @Alice's Snugpod house")
    info("/tp @@ali snug              @ali's Snugpod house, ali does not have to be in party/friends/guilds")
    info("/tp addAlias ali @@ali snug an alias to @ali's Sungpod house, can be called by /tp ali")
    info("/tp addAlias viv Vivec City Vivec City wayshrine alias, can be called by /tp vivec")
end

--------------------------------------------------------------------------------

local function _playerHelper(name)
    local player, house = Helpers:splitInTwo(name, ' ')
    if player and house then
        return Houses:portToPlayersHouse(player, house)
    else
        player = Players:findPlayerByName(name)
        if not player then
            info("Failed to port to " .. name .. ": Player not found.")
            return true
        end

        return Players:portToPlayer(player) 
    end
end

local function tp(name)
    name = Aliases:expand(name)
    if Helpers:startsWith(name, '@') then return _playerHelper(name) end

    if name == 'help'     then return _printHelp()           end
    if name == 'examples' then return _printExamples()       end
    if name == 'lstAlias' then return Aliases:listAliases()  end
    if name == 'leader'   then return Players:portToLeader() end

    if Helpers:startsWith(name, 'addAlias ') then return Aliases:addAlias   (string.sub(name, #'addAlias ' + 1)) end
    if Helpers:startsWith(name, 'delAlias ') then return Aliases:removeAlias(string.sub(name, #'delAlias ' + 1)) end

    if Dungeons  :portToDungeon  (name, true)  then return end -- alias only matches
    if Zones     :portToZone     (name) then return end
    if Wayshrines:portToWayshrine(name) then return end
    if Houses    :portToHouse    (name) then return end
    if Dungeons  :portToDungeon  (name, false) then return end -- all matches

    info("Failed to port to " .. name .. ": No dungeon/zone/wayshrine/house found")
end

SLASH_COMMANDS['/tp'] = tp

EVENT_MANAGER:RegisterForEvent('Teleport', EVENT_ADD_ON_LOADED, function() 
        EVENT_MANAGER:UnregisterForEvent('Teleport', EVENT_ADD_ON_LOADED)
        local SAVED_VARS = ZO_SavedVars:NewAccountWide('TeleportAliases', 1, nil, { ALIASES = { } })
        Aliases:setSavedVars(SAVED_VARS.ALIASES)
    end)

