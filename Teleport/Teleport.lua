Teleport = {}

Teleport.COLORS = {
    NONE = nil,
    NOT_FOUND = "FF8811",
    NOT_UNLOCKED = "FF8811",
    
    ALIAS = "CCCCCC",
    
    ZONE = "FFAA11",
    WAYSHRINE = "FFAA11",
    DUNGEON = "FFAA11",
    HOUSE = "AAFFAA",
    
    PLAYER = "CCCCCC",
    LEADER = "AAFFAA",

    SURVEY = "3A93FF",
}

Teleport.info  =           function(msg) CHAT_SYSTEM:AddMessage("[Teleport]: "        .. msg) end
Teleport.dbg   = false and function(msg) CHAT_SYSTEM:AddMessage("[Teleport][DEBUG]: " .. msg) end or function() end

Teleport.color = function(msg, color) if color then return "|c" .. color .. msg .. "|r" end return msg end

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local function printHelp()
    info([[ Teleport tl;dr manual:
The full manual is available in the addon folder (README.md) or at:
https://github.com/wjtk4444/eso-addons/tree/master/Teleport

1. There is only one command - /tp
2. All arguments to it are case-insensitive
3. You pretty much type:
/tp <prefix of the english name of the place where you want to end up>
4. That's it.
5. Not really, so here's some examples to loook at:

Zones:
    /tp Deshaan
    /tp crag

Dungeons, Trials and Arenas
(you can find the full list of short names in the full manual):
    /tp vmol (will set difficulty to veteran)
    /tp nfg1 (will set difficulty to normal)
    /tp rbrp (will reset the instance before tping)
    /tp ka
    /tp crypt of hea

Homes:
    /tp Snugpod
    /tp outside snugpod
    /tp antiq
    /tp @frindorguildienameprefix housenameprefix
    /tp @fren snug
    /tp @@fullaccountname housenameprefix
    /tp @@schrodingerscatgirl Snugpod <- try this one

Players:
    /tp leader
    /tp @fren

Crafting Surveys and Treasure Maps:
    /tp bothsurveymaps

Adding and removing Aliases:
    /tp --add s bothsurveymaps
    /tp --add l leader
    /tp --add snuggy @@schrodingerscatgirl snugpod
    /tp --list
    /tp snuggy
    /tp --remove snuggy (i cri everytiem)
    ]])
end

--------------------------------------------------------------------------------

local function removeExtraWhitespace(args)
    if not args then return nil end
    args = string.gsub(args, "%s+", " ")
    args = string.gsub(args, "^%s*(.-)%s*$", "%1")
    return args
end

local function tp(args)
    args = removeExtraWhitespace(args)
    if not args then
        info("No input specified, see " .. color("`/tp help`", C.NOT_FOUND) .. " for help")
        return
    end

    args = Teleport.Aliases:expandUserDefined(args)
   
    if args == '--help'          then return printHelp() end

    if Teleport.Helpers:startsWith(args, '--list') then
        return Teleport.Aliases:listAliases()
    end
    if Teleport.Helpers:startsWith(args, '--add') then
        return Teleport.Aliases:addAlias(string.sub(args, 7))
    end
    if Teleport.Helpers:startsWith(args, '--remove') then
        return Teleport.Aliases:removeAlias(string.sub(args, 10))
    end

    if args == 'leader'          then return Teleport.Players:teleportToLeader()             end
    if args == 'freesurveymaps'  then return Teleport.SurveyMaps:teleportToSurveyMap()     end
    if args == 'paidsurveymaps'  then return Teleport.SurveyMaps:paidTeleportToSurveyMap() end
    if args == 'bothsurveymaps'  then return Teleport.SurveyMaps:teleportToSurveyMap(true) end

    if Teleport.Helpers:startsWith(args, '@') then 
        local playerNamePrefix, houseNamePrefix = Teleport.Helpers:splitOnSpace(args)
        if playerNamePrefix and houseNamePrefix then
            return Teleport.Houses:teleportToPlayersHouse(playerNamePrefix, houseNamePrefix)
        else
            local player = Teleport.Players:findPlayerByNamePrefix(args, true)
            if not player then
                info("Failed to teleport to " .. color(args, C.NOT_FOUND) .. ": Player not found.")
                return
            end
            return Teleport.Players:teleportToPlayer(player)
        end
    end

    -- check dungeon alias-only matches first - they can start with n, v or r for [n]ormal, [v]eteran or [r]eset instances
    if Teleport.Dungeons:teleportToDungeon(args, true) then return end

    -- prioritize direct node travel when wayshrine menu is open
    if Teleport.Helpers:isAtWayshrine() then
        if Teleport.Wayshrines:teleportToWayshrine(args) then return end
        if Teleport.Dungeons  :teleportToDungeon  (args) then return end
        if Teleport.Houses    :teleportToHouse    (args) then return end
        if Teleport.Zones     :teleportToZone     (args) then return end
    else
        if Teleport.Zones     :teleportToZone     (args) then return end
        if Teleport.Dungeons  :teleportToDungeon  (args) then return end
        if Teleport.Houses    :teleportToHouse    (args) then return end
        if Teleport.Wayshrines:teleportToWayshrine(args) then return end
    end

    info("Failed to teleport to " .. color(args, C.NOT_FOUND) .. ": No dungeon/zone/house/wayshrine found")
end

EVENT_MANAGER:RegisterForEvent('Teleport', EVENT_ADD_ON_LOADED, function(_, addonName) 
        if addonName ~= 'Teleport' then return end
        
        EVENT_MANAGER:UnregisterForEvent('Teleport', EVENT_ADD_ON_LOADED)
        SLASH_COMMANDS['/tp'] = tp
        local SAVED_VARS = ZO_SavedVars:NewAccountWide('TeleportAliases', 1, nil, { ALIASES = { } })
        Teleport.Aliases:setSavedVars(SAVED_VARS.ALIASES)
    end)
