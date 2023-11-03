Teleport.Players = {}

local info  = Teleport.info
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local GROUP  = 1
local FRIEND = 2
local GUILD  = 3

function Teleport.Players:findPlayerByNamePrefix(nameFilter, onlineOnly)
    -- check group members first (max 12 players)
    if IsPlayerInGroup(GetDisplayName()) then
        for i = 0, GetGroupSize() do
            local groupUnitTag = GetGroupUnitTagByIndex(i)
            if onlineOnly and not IsUnitOnline(groupUnitTag) then
                -- continue
            else
                local playerName = GetUnitDisplayName(groupUnitTag)
                if playerName ~= GetDisplayName() then
                    if Teleport.Helpers:startsWithCaseInsensitive(playerName, nameFilter) then
                        return {
                            type = GROUP,
                            displayName = playerName,
                            zoneName = GetUnitZone(groupUnitTag)
                        }
                    end
                end
            end
        end
    end

    -- check friends next (max 100 players)
    for i = 0, GetNumFriends() do
        local playerName, _, status = GetFriendInfo(i)
        if onlineOnly and status == PLAYER_STATUS_OFFLINE then
            -- continue
        else
            if Teleport.Helpers:startsWithCaseInsensitive(playerName, nameFilter) then
                local _, _, zoneName = GetFriendCharacterInfo(i)
                return {
                    type = FRIEND,
                    displayName = playerName,
                    zoneName = zoneName
                }
            end
        end
    end    
    
    -- check guildies last (max 2500 players)
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        for j = 0, GetNumGuildMembers(guildId) do
            local playerName, _, _, status = GetGuildMemberInfo(guildId, j)
            if playerName == GetDisplayName() then
                -- continue
            elseif onlineOnly and status == PLAYER_STATUS_OFFLINE then
                -- continue
            else
                if Teleport.Helpers:startsWithCaseInsensitive(playerName, nameFilter) then
                    local _, _, zoneName = GetGuildMemberCharacterInfo(guildId, j)
                    return {
                        type = GUILD,
                        displayName = playerName,
                        zoneName = zoneName
                    }
                end
            end
        end
    end

    return nil
end

function Teleport.Players:findPlayerByZoneId(targetZoneId, zoneIdMap)
    -- check group members first (max 12 players)
    if IsPlayerInGroup(GetDisplayName()) then
        for i = 0, GetGroupSize() do
            local groupUnitTag = GetGroupUnitTagByIndex(i)
            if not IsUnitOnline(groupUnitTag) then
                -- continue
            else
                local zoneId = GetZoneId(GetUnitZoneIndex(groupUnitTag))
                if (zoneIdMap and zoneIdMap[zoneId]) or zoneId == targetZoneId then
                    local playerName = GetUnitDisplayName(groupUnitTag)
                    if playerName ~= GetDisplayName() then
                        return {
                            type = GROUP,
                            displayName = playerName,
                            zoneId = zoneId,
                            zoneName = GetZoneNameById(zoneId)
                        }
                    end
                end
            end
        end
    end

    -- check friends next (max 100 players)
    for i = 0, GetNumFriends() do
        local playerName, _, status = GetFriendInfo(i)
        if status == PLAYER_STATUS_OFFLINE then
            -- continue
        else
            local _, _, zoneName, _, _, _, _, zoneId = GetFriendCharacterInfo(i)
            if (zoneIdMap and zoneIdMap[zoneId]) or zoneId == targetZoneId then
                return {
                        type = FRIEND,
                        displayName = playerName,
                        zoneId = zoneId,
                        zoneName = zoneName
                    }
            end
        end
    end    
    
    -- check guilds last (max 2500 players)
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        for j = 0, GetNumGuildMembers(guildId) do
            local playerName, _, _, status = GetGuildMemberInfo(guildId, j)
            if playerName == GetDisplayName() then
                -- continue
            elseif status == PLAYER_STATUS_OFFLINE then
                -- continue
            else
                local _, _, zoneName, _, _, _, _, zoneId = GetGuildMemberCharacterInfo(guildId, j)
                if (zoneIdMap and zoneIdMap[zoneId]) or zoneId == targetZoneId then
                    return {
                        type = GUILD,
                        displayName = playerName,
                        zoneId = zoneId,
                        zoneName = zoneName
                    }
                end
            end
        end
    end

    return nil
end

function Teleport.Players:findPlayerByDungeonName(dungeonName)
    -- check group members only
    if IsPlayerInGroup(GetDisplayName()) then
        for i = 0, GetGroupSize() do
            local groupUnitTag = GetGroupUnitTagByIndex(i)
            if not IsUnitOnline(groupUnitTag) then
                -- continue
            else
                local zoneName = GetUnitZone(groupUnitTag)
                if zoneName == dungeonName then
                    local playerName = GetUnitDisplayName(groupUnitTag)
                    if playerName ~= GetDisplayName() then
                        return {
                            type = GROUP,
                            displayName = playerName,
                            zoneName = zoneName
                        }
                    end
                end
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------------

function Teleport.Players:teleportToPlayer(player, surveys)
    if player.type == GROUP then
        JumpToGroupMember(player.displayName)
    elseif player.type == FRIEND then
        JumpToFriend(player.displayName)
    elseif player.type == GUILD then
        JumpToGuildMember(player.displayName)
    end

    if surveys then
        info("Teleporting to " .. color(ZO_LinkHandler_CreateDisplayNameLink(player.displayName), C.PLAYER) .. surveys[player.zoneId])
    else
        info("Teleporting to " .. color(ZO_LinkHandler_CreateDisplayNameLink(player.displayName), C.PLAYER) .. " in " .. color(player.zoneName, C.ZONE))
    end

    return true
end

function Teleport.Players:teleportToLeader()
    if not IsPlayerInGroup(GetDisplayName()) then 
        info("Failed to teleport to " .. color("group leader", C.NOT_FOUND) .. ": Not in a group.")
        return
    end    

    local groupUnitTag = GetGroupLeaderUnitTag()        
    local displayName = GetUnitDisplayName(groupUnitTag)
    local zoneName = GetUnitZone(groupUnitTag)

    info("Teleporting to group leader " .. color(ZO_LinkHandler_CreateDisplayNameLink(displayName), C.LEADER) .. " in " .. color(zoneName, C.ZONE))

    JumpToGroupLeader() 
end
