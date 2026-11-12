AIUF = AIUF or {}
AIUF.name = "AddedInfoUnitFrames"
AIUF.version = "1.3.3"

AIUF.AUTOCOLORAMOUNT = 0.25



AIUF.defaults = {
    showResInfo = false,
    colorRoles = false,
    colorDD = POWERTYPE_HEALTH,
    colorHeal = POWERTYPE_HEALTH,
    colorTank = POWERTYPE_HEALTH,
    colorPlayer = "none",
    useCustomHighlight = false,
    customColor = {0.0, 0.0, 0.0, 1.0},
    customHighlight = {0.2, 0.2, 0.2, 1.0},
    smallGroupGrid = false,
}

AIUF.accountWideDefaults = {
    accountWide = true,
}

-- Predefined custom bar colors
ZO_POWER_BAR_GRADIENT_COLORS["yellow"]      = {ZO_ColorDef:New("a69000"), ZO_ColorDef:New("e3cf4f")}
ZO_POWER_BAR_GRADIENT_COLORS["purple"]      = {ZO_ColorDef:New("8a0050"), ZO_ColorDef:New("c21d7d")}
ZO_POWER_BAR_GRADIENT_COLORS["orange"]      = {ZO_ColorDef:New("d74700"), ZO_ColorDef:New("ff8a51")}
ZO_POWER_BAR_GRADIENT_COLORS["black"]       = {ZO_ColorDef:New("222222"), ZO_ColorDef:New("444444")}
ZO_POWER_BAR_GRADIENT_COLORS["white"]       = {ZO_ColorDef:New("dddddd"), ZO_ColorDef:New("ffffff")}
ZO_POWER_BAR_GRADIENT_COLORS["tropical"]    = {ZO_ColorDef:New("00d571"), ZO_ColorDef:New("84ff00")}
ZO_POWER_BAR_GRADIENT_COLORS["custom"]      = {ZO_ColorDef:New("000000"), ZO_ColorDef:New("222222")}
ZO_POWER_BAR_GRADIENT_COLORS["pikpik"]      = {ZO_ColorDef:New("6c002e"), ZO_ColorDef:New("bc004d")}

function AIUF.ConstructHealthNumbers(self, control)
    if GetGroupSize() <= 4 then
        for i = 1, GetGroupSize() do
            --UNIT_FRAMES.groupFrames["group"..i].healthBar.leftText = WINDOW_MANAGER:CreateControl(UNIT_FRAMES.groupFrames["group"..i]:GetPrimaryControl():GetName() .. "Race", UNIT_FRAMES.groupFrames["group"..i]:GetPrimaryControl(), CT_LABEL)
        end
    end
end

local TARGET_ATTRIBUTE_VISUALIZER_SOUNDS = {
    [STAT_MITIGATION] = {
        [STAT_STATE_IMMUNITY_GAINED]    = SOUNDS.UAV_IMMUNITY_ADDED_TARGET,
        [STAT_STATE_IMMUNITY_LOST]      = SOUNDS.UAV_IMMUNITY_LOST_TARGET,
        [STAT_STATE_SHIELD_GAINED]      = SOUNDS.UAV_DAMAGE_SHIELD_ADDED_TARGET,
        [STAT_STATE_SHIELD_LOST]        = SOUNDS.UAV_DAMAGE_SHIELD_LOST_TARGET,
        [STAT_STATE_POSSESSION_APPLIED] = SOUNDS.UAV_POSSESSION_APPLIED_TARGET,
        [STAT_STATE_POSSESSION_REMOVED] = SOUNDS.UAV_POSSESSION_REMOVED_TARGET,
        [STAT_STATE_TRAUMA_GAINED]      = SOUNDS.UAV_TRAUMA_ADDED_TARGET,
        [STAT_STATE_TRAUMA_LOST]        = SOUNDS.UAV_TRAUMA_LOST_TARGET,
    },
}


local function ColorBar(groupTag, frameType, color)
    if type(color) ~= "number" then
        for i = 1, #UNIT_FRAMES[frameType][groupTag].healthBar.barControls do
            ZO_StatusBar_SetGradientColor(UNIT_FRAMES[frameType][groupTag].healthBar.barControls[i], ZO_POWER_BAR_GRADIENT_COLORS[color])
        end
    else
        UNIT_FRAMES[frameType][groupTag].healthBar:SetColor(color)
    end
end

local KEYBOARD_CONSTANTS = {
    GROUP_FRAMES_PER_COLUMN = SMALL_GROUP_SIZE_THRESHOLD,
    NUM_COLUMNS = NUM_SUBGROUPS,
    GROUP_FRAME_SIZE_X = ZO_KEYBOARD_GROUP_FRAME_WIDTH - 30,
    GROUP_FRAME_SIZE_Y = ZO_KEYBOARD_GROUP_FRAME_HEIGHT,
    GROUP_FRAME_PAD_Y = 0,
    RAID_FRAME_SIZE_Y = ZO_KEYBOARD_RAID_FRAME_HEIGHT,
    RAID_FRAME_PAD_Y = 2,
}

local GAMEPAD_CONSTANTS = {
    GROUP_FRAMES_PER_COLUMN = 12,
    NUM_COLUMNS = GROUP_SIZE_MAX / 12,
    GROUP_FRAME_SIZE_X = ZO_GAMEPAD_GROUP_FRAME_WIDTH,
    GROUP_FRAME_SIZE_Y = ZO_GAMEPAD_GROUP_FRAME_HEIGHT,
    GROUP_FRAME_PAD_Y = 9,
    RAID_FRAME_SIZE_Y = ZO_GAMEPAD_RAID_FRAME_HEIGHT,
    RAID_FRAME_PAD_Y = 2,
}

local function GetPlatformConstants()
    return IsInGamepadPreferredMode() and GAMEPAD_CONSTANTS or KEYBOARD_CONSTANTS
end


local groupFrameAnchor = ZO_Anchor:New(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
local function GetGroupFrameAnchor(groupIndex)
    local constants = GetPlatformConstants()

    groupSize = GetGroupSize()
    local column = zo_floor((groupIndex - 1) / constants.GROUP_FRAMES_PER_COLUMN)
    local row = zo_mod(groupIndex - 1, constants.GROUP_FRAMES_PER_COLUMN)

    if(groupSize > SMALL_GROUP_SIZE_THRESHOLD) then
        if IsInGamepadPreferredMode() then
            column = zo_mod(groupIndex - 1, constants.NUM_COLUMNS)
            row = zo_floor((groupIndex - 1) / 2)
        end
        groupFrameAnchor:SetTarget(GetControl("ZO_LargeGroupAnchorFrame"..(column + 1)))
        groupFrameAnchor:SetOffsets(0, row * (constants.RAID_FRAME_SIZE_Y + constants.RAID_FRAME_PAD_Y))
        return groupFrameAnchor
    else
        --Our overrides
        column = zo_floor((groupIndex - 1) / 2)
        row = zo_mod(groupIndex - 1, 2)
    
        groupFrameAnchor:SetTarget(ZO_SmallGroupAnchorFrame)
        groupFrameAnchor:SetOffsets(column * constants.GROUP_FRAME_SIZE_X, row * (constants.GROUP_FRAME_SIZE_Y + constants.GROUP_FRAME_PAD_Y))
        return groupFrameAnchor
    end
end

function AIUF.UpdateGroupAnchors()
    -- Update all UnitFrame anchors.
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag then
            local unitFrame = UNIT_FRAMES:GetFrame(unitTag)
            if not unitFrame then return end
            local anchor = GetGroupFrameAnchor(i)
            unitFrame:SetAnchor(anchor)
        end
    end
end

function AIUF.UpdateUnitFrames(eventCode)  
    local frameType = "groupFrames"
    if GetGroupSize() > 4 then frameType = "raidFrames" end    

    for i = 1, GetGroupSize() do
        if not DoesUnitExist("group"..i) then break end
        if UNIT_FRAMES[frameType]["group"..i] == nil then break end
        local role = GetGroupMemberSelectedRole("group"..i)
    

        if AIUF.SV.colorRoles then
            if GetUnitDisplayName("group"..i) == "@MrPikPik" and not (GetUnitDisplayName("player") == "@MrPikPik") then
                ColorBar("group"..i, frameType, "pikpik")
            elseif AIUF.SV.colorPlayer ~= "none" and (GetUnitDisplayName("group"..i) == GetUnitDisplayName("player")) then
                ColorBar("group"..i, frameType, AIUF.SV.colorPlayer)
            elseif role == LFG_ROLE_DPS then
                ColorBar("group"..i, frameType, AIUF.SV.colorDD)
            elseif role == LFG_ROLE_HEAL then
                ColorBar("group"..i, frameType, AIUF.SV.colorHeal)
            elseif role == LFG_ROLE_TANK then
                ColorBar("group"..i, frameType, AIUF.SV.colorTank)
            end
        elseif GetUnitDisplayName("group"..i) == "@MrPikPik" then
            ColorBar("group"..i, frameType, "pikpik")
        end
        
        -- temporary bypass
        
        --d("Updating frame for unitTag group" .. i)
        local frame = UNIT_FRAMES[frameType]["group"..i]
        
        if type(frame) ~= "table" then
            d("Frame is no table! Type: " .. type(frame))
            break
        end    
        
        if AIUF.SV.smallGroupGrid and (GetGroupSize() <= SMALL_GROUP_SIZE_THRESHOLD) then
            --AIUF.UpdateGroupAnchors()
        end
        
        -- if not frame.hasModule then
        --     local visualizer = frame:CreateAttributeVisualizer(TARGET_ATTRIBUTE_VISUALIZER_SOUNDS)
        --     local layoutData = {
        --         barOverlayTemplate = "ZO_PowerShieldBarRightOverlayArrow",
        --         barColor = POWERTYPE_HEALTH,
        --         barHeight = 9,
        --         barType = "group"
        --     }
        --     
        --     if GetUnitDisplayName("group"..i) == "@MrPikPik" and not (GetUnitDisplayName("player") == "@MrPikPik") then
        --         layoutData.barColor = "pikpik"
        --     elseif AIUF.SV.colorPlayer ~= "none" and (GetUnitDisplayName("group"..i) == GetUnitDisplayName("player")) then
        --         layoutData.barColor = AIUF.SV.colorPlayer
        --     elseif role == LFG_ROLE_DPS then
        --         layoutData.barColor = AIUF.SV.colorDD
        --     elseif role == LFG_ROLE_HEAL then
        --         layoutData.barColor = AIUF.SV.colorHeal
        --     elseif role == LFG_ROLE_TANK then
        --         layoutData.barColor = AIUF.SV.colorTank
        --     end
        --     
        --     if GetGroupSize() > 4 then
        --         layoutData.barHeight = 40
        --         layoutData.barType = "raid"
        --     end
        --     
        --     visualizer:AddModule(ZO_UnitVisualizer_PowerShieldModuleSingleBar:New(layoutData))
        --     frame.hasModule = true
        -- else
        --     local visualizer = frame.attributeVisualizer
        --     local module
        --     local layoutData
        --     if visualizer then
        --         module = visualizer.visualModules[1]
        --         if module then
        --             layoutData = module.layoutData
        --         end
        --     end
        --     
        --     if layoutData == nil then break end
        -- 
        --     if GetUnitDisplayName("group"..i) == "@MrPikPik" and not (GetUnitDisplayName("player") == "@MrPikPik") then
        --         layoutData.barColor = "pikpik"
        --     elseif AIUF.SV.colorPlayer ~= "none" and (GetUnitDisplayName("group"..i) == GetUnitDisplayName("player")) then
        --         layoutData.barColor = AIUF.SV.colorPlayer
        --     elseif role == LFG_ROLE_DPS then
        --         layoutData.barColor = AIUF.SV.colorDD
        --     elseif role == LFG_ROLE_HEAL then
        --         layoutData.barColor = AIUF.SV.colorHeal
        --     elseif role == LFG_ROLE_TANK then
        --         layoutData.barColor = AIUF.SV.colorTank
        --     end
        -- end
    end
end

function AIUF.UpdateAliveStatus(unitTag, status)
    if not DoesUnitExist(unitTag) then return end
    if GetGroupSize() < 2 then return end

    if GetGroupSize() > 4 then
        if UNIT_FRAMES.raidFrames[unitTag] == nil then return end
        UNIT_FRAMES.raidFrames[unitTag].statusLabel:SetText(status)
    else
        if UNIT_FRAMES.groupFrames[unitTag] == nil then return end
        UNIT_FRAMES.groupFrames[unitTag].frame:SetWidth(400)
        UNIT_FRAMES.groupFrames[unitTag].statusLabel:SetText(status)
    end
end

function AIUF.AliveStatusUpdate()
    for i = 1, GetGroupSize() do
        if not DoesUnitExist("group"..i) then break end -- Failsafe
    
        local status = "" -- If player is actually alive, the text field gets set to an empty string anyways
        if IsUnitDead("group"..i) then
            if AIUF.SV.showResInfo then
                if IsUnitBeingResurrected("group"..i) then -- Being resurrected
                    status = (GetGroupSize() > 4) and GetString(AIUF_RESSING_SHORT) or GetString(SI_PLAYER_TO_PLAYER_RESURRECT_BEING_RESURRECTED)
                elseif DoesUnitHaveResurrectPending("group"..i) then -- Pending resurrection
                    status = (GetGroupSize() > 4) and GetString(AIUF_RES_PENDING_SHORT) or GetString(SI_PLAYER_TO_PLAYER_RESURRECT_HAS_RESURRECT_PENDING)
                else -- Just dead
                    status = GetString(SI_UNIT_FRAME_STATUS_DEAD)
                end
            else
                status = GetString(SI_UNIT_FRAME_STATUS_DEAD)
            end
        elseif not IsUnitOnline("group"..i) then -- Offline
            status = GetString(SI_UNIT_FRAME_STATUS_OFFLINE)
        end
        
        AIUF.UpdateAliveStatus("group"..i, status)
    end
end

local function RGBToHSV(red, green, blue)
    local hue, saturation, value
    local min_value = math.min(red, green, blue)
    local max_value = math.max(red, green, blue)
    value = max_value
    local value_delta = max_value - min_value
    if max_value ~= 0 then
        saturation = value_delta / max_value
    else
        saturation = 0
        hue = -1
        return hue, saturation, value;
    end
    if red == max_value then
        hue = ( green - blue ) / value_delta
    elseif green == max_value then
        hue = 2 + ( blue - red ) / value_delta
    else
        hue = 4 + ( red - green ) / value_delta
    end
    hue = hue * 60
    if hue < 0 then hue = hue + 360 end
    return hue, saturation, value
end

local function HSVToRGB(hue, saturation, value)
    if saturation == 0 then return value, value, value end
    local hue_sector = math.floor( hue / 60 )
    local hue_sector_offset = ( hue / 60 ) - hue_sector
    local p = value * ( 1 - saturation )
    local q = value * ( 1 - saturation * hue_sector_offset )
    local t = value * ( 1 - saturation * ( 1 - hue_sector_offset ) )
    if hue_sector == 0 then
        return value, t, p
    elseif hue_sector == 1 then
        return q, value, p
    elseif hue_sector == 2 then
        return p, value, t
    elseif hue_sector == 3 then
        return p, q, value
    elseif hue_sector == 4 then
        return t, p, value
    elseif hue_sector == 5 then
        return value, p, q
    end
end


local hue = 0
function AIUF.UpdateRGB()
    local r, g, b = HSVToRGB(hue, 1.0, 1.0)
    local x, y, z = HSVToRGB((hue + 60) % 360, 1.0, 1.0)
    hue = (hue + 10) % 360
    ZO_POWER_BAR_GRADIENT_COLORS["rgb"] = {ZO_ColorDef:New(r, g, b), ZO_ColorDef:New(x, y, z)}
    if AIUF.SV.colorDD == "rgb" or AIUF.SV.colorHeal == "rgb" or AIUF.SV.colorTank == "rgb" or AIUF.SV.colorPlayer == "rgb" then
        AIUF.UpdateUnitFrames()
    end
end

local function LightenColor(color, amount)
    local h, s, v = RGBToHSV(color[1] or 1, color[2] or 1, color[3] or 1)
    local r, g, b = HSVToRGB(h, s * (1-amount), v * (1+amount))
    
    local c = {
        [1] = r,
        [2] = g,
        [3] = b,
        [4] = color[4]
    }
    return c
end

function AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
    if AIUF.SV.colorPlayer == "none" then
        local role = GetGroupMemberSelectedRole("player")
        if role == LFG_ROLE_DPS then
            ZO_StatusBar_SetGradientColor(barPlayer.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorDD])
        elseif role == LFG_ROLE_HEAL then
            ZO_StatusBar_SetGradientColor(barPlayer.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorHeal])
        elseif role == LFG_ROLE_TANK then
            ZO_StatusBar_SetGradientColor(barPlayer.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorTank])
        end
    else
        ZO_StatusBar_SetGradientColor(barPlayer.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorPlayer])
    end
    
    ZO_StatusBar_SetGradientColor(barDD.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorDD])
    ZO_StatusBar_SetGradientColor(barHeal.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorHeal])
    ZO_StatusBar_SetGradientColor(barTank.bar, ZO_POWER_BAR_GRADIENT_COLORS[AIUF.SV.colorTank])
end

function AIUF.InitializeAddonMenu()
    local frame
    local barDD, barHeal, barTank, barPlayer
    
	local panelData = {
		type = "panel",
		name = "Added Info - Unit Frames",
		displayName = "Added Info - Unit Frame (AIUF)",
		author = "MrPikPik",
		version = AIUF.version,
		registerForRefresh = true,
		registerForDefaults = true
	}

	local optionsData = {}

    -- Description
	table.insert(optionsData, {
		type = "description",
		text = GetString(AIUF_OPTIONS_DESCRIPTION),
	})
    
    -- Options header
	table.insert(optionsData, {
		type = "header",
		name = GetString(AIUF_OPTIONS_HEADER),
	})
    
    -- Account wide setting
	table.insert(optionsData, {
		type = "checkbox",
		name = GetString(AIUF_OPTIONS_ACCOUNTWIDE_SETTINGS),
		tooltip = GetString(AIUF_OPTIONS_ON) .. GetString(AIUF_OPTIONS_ACCOUNTWIDE_SETTINGS_TT_ON) .. "\n" .. GetString(AIUF_OPTIONS_OFF) .. GetString(AIUF_OPTIONS_ACCOUNTWIDE_SETTINGS_TT_OFF),
		requiresReload = true,
		default = AIUF.accountWideDefaults.accountWide,
		getFunc = function() return AIUF.DS.accountWide end,
		setFunc = function(newValue) AIUF.DS.accountWide = newValue end,
	})
    
    -- Divider
    table.insert(optionsData, {
		type = "divider",
	})
    
    -- Resurrection info
	table.insert(optionsData, {
		type = "checkbox",
		name = GetString(AIUF_OPTIONS_RESURRECTION_STATUS),
		tooltip = GetString(AIUF_OPTIONS_RESURRECTION_STATUS_TT),
        default = AIUF.defaults.showResInfo,
		getFunc = function() return AIUF.SV.showResInfo end,
		setFunc = function(newValue) AIUF.SV.showResInfo = newValue end,
	})
    
    -- Role coloring
    table.insert(optionsData, {
		type = "checkbox",
		name = GetString(AIUF_OPTIONS_COLOR),
		tooltip = GetString(AIUF_OPTIONS_COLOR_TT),
        default = AIUF.defaults.colorRoles,
		getFunc = function() return AIUF.SV.colorRoles end,
		setFunc = function(newValue)
            AIUF.SV.colorRoles = newValue
            AIUF.UpdateUnitFrames()
        end,
	})
    
    -- Role coloring
    table.insert(optionsData, {
		type = "checkbox",
		name = GetString(AIUF_OPTIONS_SMALL_GROUP),
		tooltip = GetString(AIUF_OPTIONS_SMALL_GROUP_TT),
        requiresReload = true,
        default = AIUF.defaults.colorRoles,
		getFunc = function() return AIUF.SV.smallGroupGrid end,
		setFunc = function(newValue)
            AIUF.SV.smallGroupGrid = newValue
        end,
	})
    
    -- Color DD
	table.insert(optionsData, {
		type = "dropdown",
		name = GetString(AIUF_OPTIONS_COLOR_DD),
        disabled = function() return not AIUF.SV.colorRoles end,
		choices = {
            GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
            GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA),
            GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA),
            GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB),
            GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
        },
		getFunc = function() 
			if AIUF.SV.colorDD == POWERTYPE_HEALTH then
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
            elseif AIUF.SV.colorDD == POWERTYPE_MAGICKA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA)
            elseif AIUF.SV.colorDD == POWERTYPE_STAMINA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA)
            elseif AIUF.SV.colorDD == POWERTYPE_WEREWOLF then
                return GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF)
            elseif AIUF.SV.colorDD == "yellow" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW)
            elseif AIUF.SV.colorDD == "purple" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE)
            elseif AIUF.SV.colorDD == "orange" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE)
            elseif AIUF.SV.colorDD == "black" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK)
            elseif AIUF.SV.colorDD == "white" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE)
            elseif AIUF.SV.colorDD == "custom" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
            elseif AIUF.SV.colorDD == "tropical" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL)
            elseif AIUF.SV.colorDD == "rgb" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB)
            else
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
			end
		end,
		setFunc = function(newValue)
			if newValue == GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH) then 
                AIUF.SV.colorDD = POWERTYPE_HEALTH
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA) then 
                AIUF.SV.colorDD = POWERTYPE_MAGICKA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA) then 
                AIUF.SV.colorDD = POWERTYPE_STAMINA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF) then 
                AIUF.SV.colorDD = POWERTYPE_WEREWOLF
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW) then 
                AIUF.SV.colorDD = "yellow"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE) then 
                AIUF.SV.colorDD = "purple"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE) then 
                AIUF.SV.colorDD = "orange"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK) then 
                AIUF.SV.colorDD = "black"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE) then 
                AIUF.SV.colorDD = "white"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL) then 
                AIUF.SV.colorDD = "tropical"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB) then 
                AIUF.SV.colorDD = "rgb"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM) then 
                AIUF.SV.colorDD = "custom"
            else
                AIUF.SV.colorDD = POWERTYPE_HEALTH
			end
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
		end,
		default = GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
        reference = "AIUF_DD",
	})
    
    -- Color Heal
    table.insert(optionsData, {
		type = "dropdown",
		name = GetString(AIUF_OPTIONS_COLOR_HEAL),
        disabled = function() return not AIUF.SV.colorRoles end,
		choices = {
            GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
            GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA),
            GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA),
            GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB),
            GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
        },
		getFunc = function() 
			if AIUF.SV.colorHeal == POWERTYPE_HEALTH then
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
            elseif AIUF.SV.colorHeal == POWERTYPE_MAGICKA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA)
            elseif AIUF.SV.colorHeal == POWERTYPE_STAMINA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA)
            elseif AIUF.SV.colorHeal == POWERTYPE_WEREWOLF then
                return GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF)
            elseif AIUF.SV.colorHeal == "yellow" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW)
            elseif AIUF.SV.colorHeal == "purple" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE)
            elseif AIUF.SV.colorHeal == "orange" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE)
            elseif AIUF.SV.colorHeal == "black" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK)
            elseif AIUF.SV.colorHeal == "white" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE)
            elseif AIUF.SV.colorHeal == "tropical" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL)
            elseif AIUF.SV.colorHeal == "rgb" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB)
            elseif AIUF.SV.colorHeal == "custom" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
            else
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
			end
		end,
		setFunc = function(newValue)
			if newValue == GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH) then 
                AIUF.SV.colorHeal = POWERTYPE_HEALTH
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA) then 
                AIUF.SV.colorHeal = POWERTYPE_MAGICKA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA) then 
                AIUF.SV.colorHeal = POWERTYPE_STAMINA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF) then 
                AIUF.SV.colorHeal = POWERTYPE_WEREWOLF
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW) then 
                AIUF.SV.colorHeal = "yellow"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE) then 
                AIUF.SV.colorHeal = "purple"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE) then 
                AIUF.SV.colorHeal = "orange"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK) then 
                AIUF.SV.colorHeal = "black"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE) then 
                AIUF.SV.colorHeal = "white"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL) then 
                AIUF.SV.colorHeal = "tropical"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB) then 
                AIUF.SV.colorHeal = "rgb"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM) then 
                AIUF.SV.colorHeal = "custom"
            else
                AIUF.SV.colorHeal = POWERTYPE_HEALTH
			end
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
		end,
		default = GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
        reference = "AIUF_Heal",
	})
	
    --Color Tank
    table.insert(optionsData, {
		type = "dropdown",
		name = GetString(AIUF_OPTIONS_COLOR_TANK),
        disabled = function() return not AIUF.SV.colorRoles end,
		choices = {
            GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
            GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA),
            GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA),
            GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB),
            GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
        },
		getFunc = function() 
			if AIUF.SV.colorTank == POWERTYPE_HEALTH then
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
            elseif AIUF.SV.colorTank == POWERTYPE_MAGICKA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA)
            elseif AIUF.SV.colorTank == POWERTYPE_STAMINA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA)
            elseif AIUF.SV.colorTank == POWERTYPE_WEREWOLF then
                return GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF)
            elseif AIUF.SV.colorTank == "yellow" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW)
            elseif AIUF.SV.colorTank == "purple" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE)
            elseif AIUF.SV.colorTank == "orange" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE)
            elseif AIUF.SV.colorTank == "black" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK)
            elseif AIUF.SV.colorTank == "white" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE)
            elseif AIUF.SV.colorTank == "tropical" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL)
            elseif AIUF.SV.colorTank == "rgb" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB)
            elseif AIUF.SV.colorTank == "custom" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
            else
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
			end
		end,
		setFunc = function(newValue)
			if newValue == GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH) then 
                AIUF.SV.colorTank = POWERTYPE_HEALTH
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA) then 
                AIUF.SV.colorTank = POWERTYPE_MAGICKA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA) then 
                AIUF.SV.colorTank = POWERTYPE_STAMINA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF) then 
                AIUF.SV.colorTank = POWERTYPE_WEREWOLF
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW) then 
                AIUF.SV.colorTank = "yellow"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE) then 
                AIUF.SV.colorTank = "purple"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE) then 
                AIUF.SV.colorTank = "orange"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK) then 
                AIUF.SV.colorTank = "black"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE) then 
                AIUF.SV.colorTank = "white"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL) then 
                AIUF.SV.colorTank = "tropical"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB) then 
                AIUF.SV.colorTank = "rgb"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM) then 
                AIUF.SV.colorTank = "custom"
            else
                AIUF.SV.colorTank = POWERTYPE_HEALTH
			end
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
		end,
		default = GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
        reference = "AIUF_Tank",
	})
    
    -- Color Player
    table.insert(optionsData, {
		type = "dropdown",
		name = GetString(AIUF_OPTIONS_COLOR_PLAYER),
        disabled = function() return not AIUF.SV.colorRoles end,
		choices = {
            GetString(AIUF_OPTIONS_COLOR_NAME_NONE),
            GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH),
            GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA),
            GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA),
            GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL),
            GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB),
            GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
        },
		getFunc = function()
            if AIUF.SV.colorPlayer == "none" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_NONE)
			elseif AIUF.SV.colorPlayer == POWERTYPE_HEALTH then
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
            elseif AIUF.SV.colorPlayer == POWERTYPE_MAGICKA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA)
            elseif AIUF.SV.colorPlayer == POWERTYPE_STAMINA then
                return GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA)
            elseif AIUF.SV.colorPlayer == POWERTYPE_WEREWOLF then
                return GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF)
            elseif AIUF.SV.colorPlayer == "yellow" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW)
            elseif AIUF.SV.colorPlayer == "purple" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE)
            elseif AIUF.SV.colorPlayer == "orange" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE)
            elseif AIUF.SV.colorPlayer == "black" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK)
            elseif AIUF.SV.colorPlayer == "white" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE)
            elseif AIUF.SV.colorPlayer == "tropical" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL)
            elseif AIUF.SV.colorPlayer == "rgb" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB)
            elseif AIUF.SV.colorPlayer == "custom" then
                return GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM)
            else
                return GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH)
			end
		end,
		setFunc = function(newValue)
            if newValue == GetString(AIUF_OPTIONS_COLOR_NAME_NONE) then
                AIUF.SV.colorPlayer = "none"
			elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_HEALTH) then 
                AIUF.SV.colorPlayer = POWERTYPE_HEALTH
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_MAGICKA) then 
                AIUF.SV.colorPlayer = POWERTYPE_MAGICKA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_STAMINA) then 
                AIUF.SV.colorPlayer = POWERTYPE_STAMINA
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_WEREWOLF) then 
                AIUF.SV.colorPlayer = POWERTYPE_WEREWOLF
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_YELLOW) then 
                AIUF.SV.colorPlayer = "yellow"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_PURPLE) then 
                AIUF.SV.colorPlayer = "purple"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_ORANGE) then 
                AIUF.SV.colorPlayer = "orange"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_BLACK) then 
                AIUF.SV.colorPlayer = "black"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_WHITE) then 
                AIUF.SV.colorPlayer = "white"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_TROPICAL) then 
                AIUF.SV.colorPlayer = "tropical"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_PRESET_RGB) then 
                AIUF.SV.colorPlayer = "rgb"
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_NAME_CUSTOM) then 
                AIUF.SV.colorPlayer = "custom"
            else
                AIUF.SV.colorPlayer = AIUF_OPTIONS_COLOR_NAME_NONE
			end
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
		end,
		default = GetString(AIUF_OPTIONS_COLOR_NAME_NONE),
        reference = "AIUF_Player",
	})
    
    -- Options header
	table.insert(optionsData, {
		type = "header",
		name = GetString(AIUF_OPTIONS_COLOR_CUSTOM_HEADER),
	})
    
    -- Custom Color Mode
    table.insert(optionsData, {
		type = "dropdown",
		name = GetString(AIUF_OPTIONS_COLOR_CUSTOM_MODE),
        tooltip = GetString(AIUF_OPTIONS_COLOR_CUSTOM_MODE_TT),
        choices = {
            GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_AUTO),
            GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_CUSTOM)
        },
		getFunc = function() 
            if AIUF.SV.useCustomHighlight then
                return GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_CUSTOM)
            else
                return GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_AUTO)
            end
        end,
		setFunc = function(newValue) 
            if newValue == GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_AUTO) then
                AIUF.SV.useCustomHighlight = false
                
                AIUF.SV.customHighlight = LightenColor(AIUF.SV.customColor, AIUF.AUTOCOLORAMOUNT)
            
                -- Update Bar
                ZO_POWER_BAR_GRADIENT_COLORS["custom"] = {ZO_ColorDef:New(unpack(AIUF.SV.customColor)), ZO_ColorDef:New(unpack(AIUF.SV.customHighlight))}
                ZO_StatusBar_SetGradientColor(frame.bar, ZO_POWER_BAR_GRADIENT_COLORS["custom"])
            elseif newValue == GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_CUSTOM) then
                AIUF.SV.useCustomHighlight = true
            else
                AIUF.SV.useCustomHighlight = false
            end
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
        end,
        default = GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_AUTO),
	})
    
    -- Custom Color Picker (Base Color)
	table.insert(optionsData, {
		type = "colorpicker",
		name = GetString(AIUF_OPTIONS_COLOR_CUSTOM_BASE),
		tooltip = GetString(AIUF_OPTIONS_COLOR_CUSTOM_BASE_TT),
		default = AIUF.defaults.customColor,
		getFunc = function() return unpack(AIUF.SV.customColor) end,
		setFunc = function(r, g, b) 
            AIUF.SV.customColor = {r, g, b, 1.00}
            
            if not AIUF.SV.useCustomHighlight then
                AIUF.SV.customHighlight = LightenColor(AIUF.SV.customColor, AIUF.AUTOCOLORAMOUNT)
            end
            
            -- Update Bar
            ZO_POWER_BAR_GRADIENT_COLORS["custom"] = {ZO_ColorDef:New(unpack(AIUF.SV.customColor)), ZO_ColorDef:New(unpack(AIUF.SV.customHighlight))}
            ZO_StatusBar_SetGradientColor(frame.bar, ZO_POWER_BAR_GRADIENT_COLORS["custom"])
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
        end,
	})
    
    -- Custom Color Picker (Highlight)
	table.insert(optionsData, {
		type = "colorpicker",
		name = GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT),
        disabled = function() return not AIUF.SV.useCustomHighlight end,
		tooltip = GetString(AIUF_OPTIONS_COLOR_CUSTOM_HIGHLIGHT_TT),
		default = AIUF.defaults.customHighlight,
		getFunc = function() return unpack(AIUF.SV.customHighlight) end,
		setFunc = function(r, g, b) 
            AIUF.SV.customHighlight = {r, g, b, 1.00}
            
            -- Update Bar
            ZO_POWER_BAR_GRADIENT_COLORS["custom"] = {ZO_ColorDef:New(unpack(AIUF.SV.customColor)), ZO_ColorDef:New(unpack(AIUF.SV.customHighlight))}
            ZO_StatusBar_SetGradientColor(frame.bar, ZO_POWER_BAR_GRADIENT_COLORS["custom"])
            
            AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
            AIUF.UpdateUnitFrames()
        end,
        reference = "AIUF_Bar",
	})  
    
    local optionsPanel = LibAddonMenu2:RegisterAddonPanel(AIUF.name, panelData)
	LibAddonMenu2:RegisterOptionControls(AIUF.name, optionsData)
    
    -- Register icon for highlight player icon selector
    local SetupAIUFBar = function(control)
    if control ~= optionsPanel then return end
        if not frame then
            frame = CreateControlFromVirtual("AIUF_Dummy", AIUF_Bar, "ZO_RaidUnitFrame")
            frame:SetWidth(180)
            frame:SetHeight(50)
            frame:SetAnchor(LEFT, nil, LEFT, 200, 45)
        
            local bar = CreateControlFromVirtual("AIUF_Dummybar", frame, "ZO_UnitFrameStatus")
            bar:SetDimensions(176, 46)
            bar:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
            frame.bar = bar
            
            local exampletext = CreateControl("AIUF_DummybarText", frame.bar, CT_LABEL)
            exampletext:SetFont("ZoFontGameOutline")
            exampletext:SetAnchor(LEFT, frame.bar, LEFT, 5, -10)
            exampletext:SetVerticalAlignment(TOP)
            exampletext:SetText(GetUnitName("player"))
            
        end
        
        if not barDD then
            barDD = CreateControlFromVirtual("AIUF_DummyDD", AIUF_DD, "ZO_RaidUnitFrame")
            barDD:SetDimensions(100, 28)
            barDD:SetAnchor(RIGHT, AIUF_DD.dropdown:GetControl(), LEFT, -10, 0)
        
            local bar2 = CreateControlFromVirtual("AIUF_DummyDDbar", barDD, "ZO_UnitFrameStatus")
            bar2:SetDimensions(96, 24)
            bar2:SetAnchor(TOPLEFT, barDD, TOPLEFT, 2, 2)
            barDD.bar = bar2
        end
        
        if not barHeal then
            barHeal = CreateControlFromVirtual("AIUF_DummyHeal", AIUF_Heal, "ZO_RaidUnitFrame")
            barHeal:SetDimensions(100, 28)
            barHeal:SetAnchor(RIGHT, AIUF_Heal.dropdown:GetControl(), LEFT, -10, 0)
        
            local bar3 = CreateControlFromVirtual("AIUF_DummyHealbar", barHeal, "ZO_UnitFrameStatus")
            bar3:SetDimensions(96, 24)
            bar3:SetAnchor(TOPLEFT, barHeal, TOPLEFT, 2, 2)
            barHeal.bar = bar3
        end
        
        if not barTank then
            barTank = CreateControlFromVirtual("AIUF_DummyTank", AIUF_Tank, "ZO_RaidUnitFrame")
            barTank:SetDimensions(100, 28)
            barTank:SetAnchor(RIGHT, AIUF_Tank.dropdown:GetControl(), LEFT, -10, 0)
        
            local bar4 = CreateControlFromVirtual("AIUF_DummyTankbar", barTank, "ZO_UnitFrameStatus")
            bar4:SetDimensions(96, 24)
            bar4:SetAnchor(TOPLEFT, barTank, TOPLEFT, 2, 2)
            barTank.bar = bar4
        end
        
        if not barPlayer then
            barPlayer = CreateControlFromVirtual("AIUF_DummyPlayer", AIUF_Player, "ZO_RaidUnitFrame")
            barPlayer:SetDimensions(100, 28)
            barPlayer:SetAnchor(RIGHT, AIUF_Player.dropdown:GetControl(), LEFT, -10, 0)
        
            local bar5 = CreateControlFromVirtual("AIUF_DummyPlayerbar", barPlayer, "ZO_UnitFrameStatus")
            bar5:SetDimensions(96, 24)
            bar5:SetAnchor(TOPLEFT, barPlayer, TOPLEFT, 2, 2)
            barPlayer.bar = bar5
        end
        
        ZO_POWER_BAR_GRADIENT_COLORS["custom"] = {ZO_ColorDef:New(unpack(AIUF.SV.customColor)), ZO_ColorDef:New(unpack(AIUF.SV.customHighlight))}
        
        AIUF.UpdateBars(barDD, barHeal, barTank, barPlayer)
        ZO_StatusBar_SetGradientColor(frame.bar, ZO_POWER_BAR_GRADIENT_COLORS["custom"])
        
        CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", SetupAIUFBar)
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", SetupAIUFBar)
end



function AIUF.OnAddonLoaded(event, addonName)
    if addonName ~= AIUF.name then return end

    -- Creating saved vars
    AIUF.DS = ZO_SavedVars:NewAccountWide("AIUFSavedVariables", 1.0, nil, AIUF.accountWideDefaults)
    
    if AIUF.DS.accountWide then
		AIUF.SV = ZO_SavedVars:NewAccountWide("AIUFSavedVariables", 1.0, nil, AIUF.defaults)
	else
		AIUF.SV = ZO_SavedVars:New("AIUFSavedVariables", 1.0, nil, AIUF.defaults)
	end
    
    ZO_POWER_BAR_GRADIENT_COLORS["custom"] = {ZO_ColorDef:New(unpack(AIUF.SV.customColor)), ZO_ColorDef:New(unpack(AIUF.SV.customHighlight))}
    
    AIUF:InitializeAddonMenu()
    
    
    EVENT_MANAGER:RegisterForEvent(AIUF.name, EVENT_GROUP_MEMBER_ROLE_CHANGED, AIUF.UpdateUnitFrames)
    EVENT_MANAGER:RegisterForEvent(AIUF.name, EVENT_GROUP_UPDATE, AIUF.UpdateUnitFrames)
    EVENT_MANAGER:RegisterForEvent(AIUF.name, EVENT_PLAYER_ACTIVATED, AIUF.UpdateUnitFrames)    
    
    EVENT_MANAGER:RegisterForUpdate(AIUF.name, 100, AIUF.AliveStatusUpdate)
    EVENT_MANAGER:RegisterForUpdate(AIUF.name.."RBG", 100, AIUF.UpdateRGB)
end
EVENT_MANAGER:RegisterForEvent(AIUF.name, EVENT_ADD_ON_LOADED, AIUF.OnAddonLoaded)

-- Make health bars bigger?
--UNIT_FRAMES.groupFrames[groupTag].resourceBars[POWERTYPE_HEALTH]:GetBarControls()[1]:SetHeight(20)
--
-- And then add numbers to it?