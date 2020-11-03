Teleport.Players = { }

local Helpers = Teleport.Helpers
local Players = Teleport.Players

local info = Teleport.info

local GROUP  = 1
local FRIEND = 2
local GUILD  = 4

local function _sanityCheck(player)
    return (true
        and player.displayName ~= GetDisplayName()
        and player.displayName ~= "" 
    )
end

local function _teleportabilityCheck(player)
    return (true
        and player.status ~= 4
        and player.zoneName ~= nil 
        and player.zoneName ~= "" 
        and player.zoneId ~= nil 
        and player.zoneId ~= 0 
    )
end

local function _getGroupMembers()
    if not IsPlayerInGroup(GetDisplayName()) then return {} end
    
    local players = {}
    for i = 0, GetGroupSize() do
        local groupUnitTag = GetGroupUnitTagByIndex(i)        
        local player = {}
        player.type = GROUP
        if groupUnitTag ~= nil and GetUnitZoneIndex(groupUnitTag) ~= nil then
            player.displayName = GetUnitDisplayName(groupUnitTag)
            player.status = (IsUnitOnline(groupUnitTag) and 1 or 4)
            player.zoneName = GetUnitZone(groupUnitTag)
            player.zoneId = GetZoneId(GetUnitZoneIndex(groupUnitTag))
            player.gropUnitTag = groupUnitTag
            if _sanityCheck(player) then table.insert(players, player) end
        end    
    end
    
    return players
end

local function _getFriends()
    local players = {}
    for i = 0, GetNumFriends() do
        local player = {}
        player.type = FRIEND
        player.displayName, _, player.status, _ = GetFriendInfo(i)
        _, _, player.zoneName, _, _, _, _, player.zoneId = GetFriendCharacterInfo(i)
        if _sanityCheck(player) then table.insert(players, player) end
    end    
    
    return players
end

local function _getGuildies()
    local players = {}
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        for j = 0, GetNumGuildMembers(guildId) do
            local player = {}
            player.type = GUILD
            player.displayName, _, _, player.status, _ = GetGuildMemberInfo(guildId, j)
            _, _, player.zoneName, _, _, _, _, player.zoneId = GetGuildMemberCharacterInfo(guildId, j)
            if _sanityCheck(player) then table.insert(players, player) end
        end
    end
    
    return players
end

-------------------------------------------------------------------------------

function Teleport.Players:findPlayerByZone(zone)
    for _, fun in ipairs({ _getGroupMembers, _getFriends, _getGuildies }) do
        for key, player in pairs(fun()) do
            if _teleportabilityCheck(player) and player.zoneName == zone then
                return player 
            end
        end
    end
    
    return nil
end

function Teleport.Players:findPlayerByDungeon(dungeon)
    for key, player in pairs(_getGroupMembers()) do
        if _teleportabilityCheck(player) and player.zoneName == dungeon
        -- and IsGroupMemberInSameInstanceAsPlayer(player.groupUnitTag))
        then
            return player 
        end
    end

    return nil
end

function Teleport.Players:findPlayerByName(prefix, allowUnreachable)
    for _, fun in ipairs({ _getGroupMembers, _getFriends, _getGuildies }) do
        for key, player in pairs(fun()) do
            if allowUnreachable or _teleportabilityCheck(player) then
                if Teleport.Helpers:startsWithCaseInsensitive(player.displayName, prefix) then 
                    return player 
                end
            end
        end
    end
    
    return nil
end

function Teleport.Players:teleportToPlayer(player)
    if not CanJumpToPlayerInZone(player.zoneId) then
        info(player.displayName .. " is currently in a location that prevents teleporting (" .. player.zoneName .. ")")
        return false
    end

    if player.type == GROUP then
        JumpToGroupMember(player.displayName)
    elseif player.type == FRIEND then
        JumpToFriend(player.displayName)
    elseif player.type == GUILD then
        JumpToGuildMember(player.displayName)
    end

    info("Teleporting to " .. player.displayName .. " in " .. player.zoneName)
    return true
end

function Teleport.Players:teleportToLeader()
    if not IsPlayerInGroup(GetDisplayName()) then 
        info("Failed to teleport to group leader: Not in a group.")
        return
    end    

    local groupUnitTag = GetGroupLeaderUnitTag()        
    local displayName = GetUnitDisplayName(groupUnitTag)
    local zoneName = GetUnitZone(groupUnitTag)

    info("Teleporting to group leader " .. displayName .. " in " .. zoneName)
    JumpToGroupLeader() 
end
