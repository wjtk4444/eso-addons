ZO_ATTRIBUTE_BAR_POWER_SHIELD_LEVEL = 2000
ZO_ATTRIBUTE_BAR_POWER_SHIELD_TRAUMA_LEVEL = 3000
ZO_ATTRIBUTE_BAR_POWER_SHIELD_TRAUMA_GLOSS_LEVEL = 3001
ZO_ATTRIBUTE_BAR_POWER_SHIELD_FAKE_HEALTH_LEVEL = 4000
ZO_ATTRIBUTE_BAR_POWER_SHIELD_FAKE_HEALTH_GLOSS_LEVEL = 4001

local RELEVANT_VISUAL_TYPES = {
    ATTRIBUTE_VISUAL_POWER_SHIELDING,
    ATTRIBUTE_VISUAL_TRAUMA
} 

ZO_UnitVisualizer_PowerShieldModuleSingleBar = ZO_UnitAttributeVisualizerModuleBase:Subclass()

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:New(...)
    return ZO_UnitAttributeVisualizerModuleBase.New(self, ...)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:Initialize(layoutData)
    self.layoutData = layoutData
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:CreateInfoTable(control, oldInfo, stat, attribute, power)
    if control then
        local info = oldInfo or { visualInfo = {} }

        for _, visualType in ipairs(RELEVANT_VISUAL_TYPES) do
            if not info.visualInfo[visualType] then
                info.visualInfo[visualType] = {}
            end
            local visualInfo = info.visualInfo[visualType]

            visualInfo.value, visualInfo.maxValue = self:GetInitialValueAndMarkMostRecent(visualType, stat, attribute, power)
            if visualInfo.lastValue == nil then
                visualInfo.lastValue = 0
            end
        end

        return info
    end
    return nil
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnAdded(healthBarControl, magickaBarControl, staminaBarControl)
    self.attributeBarControls = {
        [ATTRIBUTE_HEALTH] = healthBarControl,
    }

    if IsPlayerActivated() then
        self:InitializeBarValues()
    end

    EVENT_MANAGER:RegisterForEvent("ZO_UnitVisualizer_PowerShieldModuleSingleBar" .. self:GetModuleId(), EVENT_PLAYER_ACTIVATED, function() self:InitializeBarValues() end)
    EVENT_MANAGER:RegisterForUpdate("ZO_UnitVisualizer_PowerShieldModuleSingleBar" .. self:GetModuleId(), 0, function() self:OnUpdate() end)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:InitializeBarValues()
    local healthBarControl = self.attributeBarControls[ATTRIBUTE_HEALTH]

    local oldBarInfo = self.attributeInfo
    self.attributeInfo = {
        [ATTRIBUTE_HEALTH] = self:CreateInfoTable(healthBarControl, oldBarInfo and oldBarInfo[ATTRIBUTE_HEALTH], STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH),
    }

    for attribute, bar in pairs(self.attributeBarControls) do
        local barInfo = self.attributeInfo[attribute]
        for visualType, _ in pairs(barInfo.visualInfo) do
            self:OnValueChanged(bar, barInfo, visualType)
        end
    end
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnUnitChanged()
    self:InitializeBarValues()
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnUpdate()
    if self.attributeInfo then
        for attribute, info in pairs(self.attributeInfo) do
            if info.isResizing then
                self:UpdateValue(self.attributeBarControls[attribute], info)
            end
        end
    end
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:IsUnitVisualRelevant(visualType, stat, attribute, powerType)
    if self.attributeInfo == nil or self.attributeInfo[attribute] == nil then
        return false
    end

    for _, currentVisualType in ipairs(RELEVANT_VISUAL_TYPES) do
        if visualType == currentVisualType then
            return true
        end
    end

    return false
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnUnitAttributeVisualAdded(visualType, stat, attribute, powerType, value, maxValue)
    local barInfo = self.attributeInfo[attribute]
    local info = barInfo.visualInfo[visualType]
    info.value = info.value + value
    info.maxValue = info.maxValue + maxValue
    self:OnValueChanged(self.attributeBarControls[attribute], barInfo, visualType)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnUnitAttributeVisualUpdated(visualType, stat, attribute, powerType, oldValue, newValue, oldMaxValue, newMaxValue)
    local barInfo = self.attributeInfo[attribute]
    local info = barInfo.visualInfo[visualType]
    info.value = info.value + (newValue - oldValue)
    info.maxValue = info.maxValue + (newMaxValue - oldMaxValue)
    self:OnValueChanged(self.attributeBarControls[attribute], barInfo, visualType)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnUnitAttributeVisualRemoved(visualType, stat, attribute, powerType, value, maxValue)
    local barInfo = self.attributeInfo[attribute]
    local info = barInfo.visualInfo[visualType]
    info.value = info.value - value
    info.maxValue = info.maxValue - maxValue
    self:OnValueChanged(self.attributeBarControls[attribute], barInfo, visualType)
end

local function ApplyPlatformStyleToShield(bar, overlay)
    ApplyTemplateToControl(bar, ZO_GetPlatformTemplate(overlay))
end

local LEFT_BAR, RIGHT_BAR = 1, 2
local SHIELD_COLOR_GRADIENT = { ZO_ColorDef:New(.5, .5, 1, .3), ZO_ColorDef:New(.25, .25, .5, .5) }
local TRAUMA_COLOR_GRADIENT = { ZO_ColorDef:New("ab1c6473"), ZO_ColorDef:New("ab76bcc3") }
function ZO_UnitVisualizer_PowerShieldModuleSingleBar:ShowOverlay(attributeBar, info)
    if not info.overlayControl then
        local statusBar = unpack(attributeBar.barControls)
        
        info.overlayControl = CreateControlFromVirtual("$(parent)PowerShieldOverlay", attributeBar, self.layoutData.barOverlayTemplate)
        --info.overlayControl:SetHeight(9)
        
        ZO_StatusBar_SetGradientColor(info.overlayControl, SHIELD_COLOR_GRADIENT)
        ZO_StatusBar_SetGradientColor(info.overlayControl.traumaBar, TRAUMA_COLOR_GRADIENT)
        ZO_StatusBar_SetGradientColor(info.overlayControl.fakeHealthBar, ZO_POWER_BAR_GRADIENT_COLORS[self.layoutData.barColor])
        info.overlayControl:SetValue(1)

        ZO_PreHookHandler(statusBar, "OnMinMaxValueChanged", function(_, min, max)
            info.attributeMax = max
            self:OnStatusBarValueChanged(attributeBar, info)
        end)

        ZO_PreHookHandler(statusBar, "OnValueChanged", function(_, value)
            info.attributeValue = value
            self:OnStatusBarValueChanged(attributeBar, info)
        end)

        info.attributeMax = select(2, statusBar:GetMinMax())
        info.attributeValue = statusBar:GetValue()
    end

    ApplyPlatformStyleToShield(info.overlayControl, self.layoutData.barOverlayTemplate)

    self:GetOwner():NotifyTakingControlOf(attributeBar)
    self:GetOwner():NotifyEndingControlOf(attributeBar)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:ShouldHideBar(barInfo)
    for _, visualInfo in pairs(barInfo.visualInfo) do
        if visualInfo.value > 0 then
            return false
        end
    end
    return true
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:ApplyValueToBar(attributeBar, barInfo, control, value)
    local percentOfBarRequested = zo_clamp(value / barInfo.attributeMax, 0, 1.0)
    -- arbitrary hardcoded threshold to avoid "too-small" values
    if percentOfBarRequested <= .01 then
        control:SetHidden(true)
        return
    else
        control:SetHidden(false)
    end

    local bar = attributeBar.barControls[1]
    local halfWidth = bar:GetWidth()
    local leftOffsetX = halfWidth * (1 - percentOfBarRequested)
    local rightOffsetX = leftOffsetX + halfWidth * percentOfBarRequested


    control:ClearAnchors()
    control:SetAnchor(RIGHT, bar, RIGHT, -leftOffsetX, 0)
    control:SetAnchor(LEFT, bar, RIGHT, -rightOffsetX, 0)
    control:SetHeight(self.layoutData.barHeight)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnStatusBarValueChanged(attributeBar, barInfo)
    local shieldInfo, traumaInfo = barInfo.visualInfo[ATTRIBUTE_VISUAL_POWER_SHIELDING], barInfo.visualInfo[ATTRIBUTE_VISUAL_TRAUMA]
    local leftOverlay = barInfo.overlayControl
    if not self:ShouldHideBar(barInfo) then
        -- This math just establishes the relationships between each bar: the clamping and scaling to turn these into actual control positions happens in ApplyValueToBar().
        -- Each bar is drawn on top of the last one in the sequence, so the actual amount of each bar the player will see will always be distance between the last bar and the next.

        local health = barInfo.attributeValue
        local shield = shieldInfo.value
        local trauma = traumaInfo.value

        -- Shields add to your original health bar, so they grow out of that value.
        -- When that amount extends beyond your max health we need shrink your fakehealth to compensate, which we carry over as shieldOverflow
        local shieldBarSize = health + shield
        self:ApplyValueToBar(attributeBar, barInfo, leftOverlay, shieldBarSize)
        local shieldOverflow = zo_max(0, shieldBarSize - barInfo.attributeMax)

        -- Trauma starts at your current health value, minus any shield overflow.
        -- This means that you should perceive the size of this bar as being your "health", it just needs to be overhealed before you can benefit from extra heal.
        local traumaBarSize = health - shieldOverflow
        self:ApplyValueToBar(attributeBar, barInfo, leftOverlay.traumaBar, traumaBarSize)

        -- Then the fakehealth starts at the step 2 interpretation of health minus any trauma experienced.
        -- Sometimes trauma and shield overflow will be 0, in which case this value is the same as your actual health, otherwise it shrinks to fit each effect.
        local fakeHealthSize = traumaBarSize - trauma
        self:ApplyValueToBar(attributeBar, barInfo, leftOverlay.fakeHealthBar, fakeHealthSize)
    else
        leftOverlay:SetHidden(true)
    end
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:UpdateValue(attributeBar, info)
    if info.overlayControl then
        self:OnStatusBarValueChanged(attributeBar, info)
    end
end

local STATE_GAINED_SOUND_FOR_VISUAL_TYPE = {
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = STAT_STATE_SHIELD_GAINED,
    [ATTRIBUTE_VISUAL_TRAUMA] = STAT_STATE_TRAUMA_GAINED
}

local STATE_LOST_SOUND_FOR_VISUAL_TYPE = {
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = STAT_STATE_SHIELD_LOST,
    [ATTRIBUTE_VISUAL_TRAUMA] = STAT_STATE_TRAUMA_LOST
}

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:OnValueChanged(attributeBar, barInfo, visualType)
    local visualInfo = barInfo.visualInfo[visualType]
    local value = visualInfo.value
    local lastValue = visualInfo.lastValue
    visualInfo.lastValue = value

    if value > 0 and lastValue <= 0 then
        self:ShowOverlay(attributeBar, barInfo)
        self.owner:PlaySoundFromStat(STAT_MITIGATION, STATE_GAINED_SOUND_FOR_VISUAL_TYPE[visualType])
        TriggerTutorial(TUTORIAL_TRIGGER_COMBAT_STATUS_EFFECT)
    elseif value <= 0 and lastValue > 0 then
        self.owner:PlaySoundFromStat(STAT_MITIGATION, STATE_LOST_SOUND_FOR_VISUAL_TYPE[visualType])
    end

    self:UpdateValue(attributeBar, barInfo)
end

function ZO_UnitVisualizer_PowerShieldModuleSingleBar:ApplyPlatformStyle()
    if self.attributeInfo then
        for _, info in pairs(self.attributeInfo) do
            if info.overlayControl then
                ApplyPlatformStyleToShield(info.overlayControl, self.layoutData.barOverlayTemplate)
            end
        end
    end
end