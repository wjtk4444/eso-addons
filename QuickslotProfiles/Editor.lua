-- A profile dropdown with Save and Discard under the wheel in the inventory's Quickslots
-- tab. Picking a profile puts it on the wheel; you edit it with the game's own drag and
-- drop and keep the changes with Save. Unsaved changes are dropped when you pick another
-- profile or leave the tab, and the current zone's profile goes back on the wheel.

local QSP = QuickslotProfiles
local Editor = {}
QSP.Editor = Editor

local editingId = nil -- profile shown on the wheel while the tab is open
local pendingId = nil -- profile to show when the tab opens (Edit slots in the settings)
local container, comboBox, zonesComboBox, saveButton, discardButton = nil, nil, nil, nil, nil
local entriesById = {}
local zoneEntries = {} -- zone key -> combo box entry

function Editor.IsEditing(id)
    return editingId ~= nil and editingId == id
end

function Editor.OnWheelChanged()
    if not container or not editingId then return end
    local dirty = QSP.HasUnsavedChanges(editingId)
    saveButton:SetEnabled(dirty)
    discardButton:SetEnabled(dirty)
end

local function SelectInDropdown(id)
    local entry = entriesById[id]
    if entry then
        comboBox:SelectItem(entry, true)
    else
        comboBox:SetSelectedItemText("")
    end
end

local function RefreshZones()
    if not zonesComboBox then return end
    zonesComboBox:ClearAllSelections()
    local profile = QSP.GetProfile(editingId)
    if profile then
        local IGNORE_CALLBACK = true
        for _, zoneType in ipairs(QSP.ZONE_TYPES) do
            if profile.zones[zoneType.key] then zonesComboBox:SelectItem(zoneEntries[zoneType.key], IGNORE_CALLBACK) end
        end
    end
    zonesComboBox:RefreshSelectedItemText()
end

local RefreshEntries

-- Applied when the zone dropdown closes, like the game's multi-select filters.
local function SaveZones()
    if not QSP.GetProfile(editingId) then return end
    local keys = {}
    for _, zoneType in ipairs(QSP.ZONE_TYPES) do
        if zonesComboBox:IsItemSelected(zoneEntries[zoneType.key]) then keys[#keys + 1] = zoneType.key end
    end
    local profile = QSP.GetProfile(editingId)
    local changed = false
    for _, zoneType in ipairs(QSP.ZONE_TYPES) do
        local selected = false
        for _, key in ipairs(keys) do if key == zoneType.key then selected = true end end
        if (profile.zones[zoneType.key] == true) ~= selected then changed = true end
    end
    if not changed then return end
    for _, move in ipairs(QSP.SetProfileZones(editingId, keys)) do
        QSP.Msg(QSP.ZONE_TYPE_NAMES[move.zone] .. " moved from " .. QSP.Hi(QSP.ProfileName(move.from))
            .. " to " .. QSP.Hi(QSP.ProfileName(editingId)) .. ".")
    end
    RefreshEntries()
    QSP.RefreshSettings()
end

-- Unsaved changes when you pick another profile or leave the tab: saved with "Save changes
-- when leaving the quickslot menu" on, dropped otherwise. Returns true if they were dropped.
local function DropUnsaved()
    if not (QSP.GetProfile(editingId) and QSP.HasUnsavedChanges(editingId)) then return false end
    if QSP.IsSaveOnLeaveOn() then
        QSP.Save(editingId)
        QSP.Msg("Saved " .. QSP.Hi(QSP.ProfileName(editingId)) .. ".")
        return false
    end
    QSP.Msg("Unsaved changes to " .. QSP.Hi(QSP.ProfileName(editingId)) .. " discarded.")
    return true
end

local function ShowProfile(id)
    if id == editingId then return end
    if IsUnitInCombat("player") then
        QSP.Msg("Profiles can't be switched in combat.")
        SelectInDropdown(editingId)
        return
    end
    DropUnsaved()
    editingId = id
    QSP.Load(id, { editor = true, quiet = true })
    RefreshZones()
    Editor.OnWheelChanged()
end

local function OnSave()
    if not QSP.GetProfile(editingId) then return end
    QSP.Save(editingId)
    QSP.Msg("Saved " .. QSP.Hi(QSP.ProfileName(editingId)) .. ".")
    Editor.OnWheelChanged()
    QSP.RefreshSettings()
end

local function OnDiscard()
    if not QSP.GetProfile(editingId) then return end
    if IsUnitInCombat("player") then
        QSP.Msg("The wheel can't be changed in combat.")
        return
    end
    QSP.Load(editingId, { editor = true, quiet = true })
    Editor.OnWheelChanged()
end

RefreshEntries = function()
    comboBox:ClearItems()
    ZO_ClearTable(entriesById)
    for _, id in ipairs(QSP.GetOrder()) do
        local profile = QSP.GetProfile(id)
        local zones = {}
        for _, zoneType in ipairs(QSP.ZONE_TYPES) do
            if profile.zones[zoneType.key] then zones[#zones + 1] = zoneType.name end
        end
        local entry = comboBox:CreateItemEntry(profile.name, function() ShowProfile(id) end)
        local tooltip = #zones > 0 and ("Loads in: " .. table.concat(zones, ", ")) or "Doesn't load anywhere"
        comboBox:SetItemOnEnter(entry, function(control)
            InitializeTooltip(InformationTooltip, control, LEFT, 10, 0, RIGHT)
            SetTooltipText(InformationTooltip, tooltip)
        end)
        comboBox:SetItemOnExit(entry, function() ClearTooltip(InformationTooltip) end)
        entriesById[id] = entry
        comboBox:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    comboBox:UpdateItems()
    if editingId then SelectInDropdown(editingId) end
end

local function CreateButton(name, text, onClicked)
    local button = CreateControlFromVirtual(name, container, "ZO_DefaultButton")
    button:SetDimensions(150, 28)
    button:SetText(text)
    button:SetHandler("OnClicked", onClicked)
    return button
end

local function CreateLabel(name, text, anchorTo)
    local label = CreateControl(name, container, CT_LABEL)
    label:SetFont("ZoFontWinH4")
    label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    label:SetText(text)
    label:SetAnchor(BOTTOM, anchorTo, TOP, 0, -4)
    return label
end

local function SetEntryTooltip(box, entry, text)
    box:SetItemOnEnter(entry, function(control)
        InitializeTooltip(InformationTooltip, control, LEFT, 10, 0, RIGHT)
        SetTooltipText(InformationTooltip, text)
    end)
    box:SetItemOnExit(entry, function() ClearTooltip(InformationTooltip) end)
end

local function CreateEditorControls()
    local wheel = QUICKSLOT_KEYBOARD and QUICKSLOT_KEYBOARD.wheelControl
    if not wheel then return false end

    container = CreateControl("QuickslotProfilesEditor", wheel, CT_CONTROL)
    container:SetDimensions(500, 160)
    container:SetAnchor(TOP, wheel, BOTTOM, 0, 110)
    container:SetDrawLayer(DL_CONTROLS)
    container:SetDrawLevel(10)

    -- Profile on the left, its zone types on the right.
    local dropdown = CreateControlFromVirtual("QuickslotProfilesEditorDropdown", container, "ZO_ComboBox")
    dropdown:SetDimensions(240, 31)
    dropdown:SetAnchor(TOPRIGHT, container, TOP, -6, 28)
    CreateLabel("QuickslotProfilesEditorLabel", "Quickslot profile", dropdown)
    comboBox = ZO_ComboBox_ObjectFromContainer(dropdown)
    comboBox:SetSortsItems(false)
    comboBox:SetFont("ZoFontWinT1")
    comboBox:SetSpacing(4)

    local zones = CreateControlFromVirtual("QuickslotProfilesEditorZones", container, "ZO_ComboBox")
    zones:SetDimensions(240, 31)
    zones:SetAnchor(TOPLEFT, container, TOP, 6, 28)
    CreateLabel("QuickslotProfilesEditorZonesLabel", "Load automatically in", zones)
    zonesComboBox = ZO_ComboBox_ObjectFromContainer(zones)
    zonesComboBox:SetSortsItems(false)
    zonesComboBox:SetFont("ZoFontWinT1")
    zonesComboBox:SetSpacing(4)
    zonesComboBox:EnableMultiSelect("<<1[$d zone type/$d zone types]>>", "Nowhere")
    for _, zoneType in ipairs(QSP.ZONE_TYPES) do
        local entry = zonesComboBox:CreateItemEntry(zoneType.name)
        zoneEntries[zoneType.key] = entry
        SetEntryTooltip(zonesComboBox, entry, (zoneType.tooltip and (zoneType.tooltip .. "\n\n") or "")
            .. "A zone type belongs to one profile: picking it here takes it away from another profile.")
        zonesComboBox:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    zonesComboBox:UpdateItems()
    zonesComboBox:SetHideDropdownCallback(SaveZones)

    -- [Open settings] [Save] [Discard]
    saveButton = CreateButton("QuickslotProfilesEditorSave", "Save", OnSave)
    saveButton:SetAnchor(TOP, container, TOP, 0, 72)
    local settingsButton = CreateButton("QuickslotProfilesEditorSettings", "Open settings", function() QSP.OpenSettings() end)
    settingsButton:SetAnchor(RIGHT, saveButton, LEFT, -8, 0)
    discardButton = CreateButton("QuickslotProfilesEditorDiscard", "Discard", OnDiscard)
    discardButton:SetAnchor(LEFT, saveButton, RIGHT, 8, 0)

    local note = CreateControl("QuickslotProfilesEditorNote", container, CT_LABEL)
    note:SetFont("ZoFontGameSmall")
    note:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
    note:SetWidth(470)
    note:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    note:SetText("Every slot change is a message to the server. If the game says you're sending messages too quickly, "
        .. "wait about 10 seconds before switching profiles again.")
    note:SetAnchor(TOP, saveButton, BOTTOM, 0, 10)

    container:RegisterForEvent(EVENT_HOTBAR_SLOT_UPDATED, function(_, _, hotbarCategory)
        if hotbarCategory == QSP.CATEGORY then Editor.OnWheelChanged() end
    end)
    return true
end

local function OnShowing()
    if not container and not CreateEditorControls() then return end
    RefreshEntries()
    local id = pendingId or QSP.GetActiveId()
    pendingId = nil
    editingId = nil
    if QSP.GetProfile(id) then
        if IsUnitInCombat("player") then
            -- Only the active profile can be shown; it's on the wheel already.
            id = QSP.GetActiveId()
            editingId = QSP.GetProfile(id) and id or nil
        else
            -- Load even the active profile, so the wheel shows exactly what it holds.
            ShowProfile(id)
        end
    end
    SelectInDropdown(editingId)
    RefreshZones()
    Editor.OnWheelChanged()
end

local function OnHidden()
    if not editingId then return end
    local edited = editingId
    local discarded = DropUnsaved()
    editingId = nil
    -- The zone's profile goes back on the wheel (zone types may have changed while editing).
    local target = QSP.GetProfileForZoneType(QSP.GetZoneType())
    if not QSP.GetProfile(target) then target = QSP.GetActiveId() end
    if not QSP.GetProfile(target) then target = edited end
    QSP.SetActive(target)
    if target ~= edited or discarded then
        QSP.Load(target, { quiet = target == edited })
    end
    QSP.RefreshSettings()
end

-- Opens the inventory on the Quickslots tab with this profile on the wheel.
function Editor.Open(id)
    if IsInGamepadPreferredMode() then
        QSP.Msg("Editing in the quickslot menu needs the keyboard UI.")
        return
    end
    if IsUnitInCombat("player") then
        QSP.Msg("Profiles can't be edited in combat.")
        return
    end
    if not KEYBOARD_QUICKSLOT_FRAGMENT then return end
    if KEYBOARD_QUICKSLOT_FRAGMENT:IsShowing() then
        if id then
            ShowProfile(id)
            SelectInDropdown(editingId)
        end
        return
    end
    pendingId = id
    if SCENE_MANAGER:IsShowing("inventory") then
        INVENTORY_MENU_BAR.modeBar:SelectFragment(SI_INVENTORY_MODE_QUICKSLOTS)
    else
        INVENTORY_MENU_BAR:SetStartingFragmentQuickslots()
        MAIN_MENU_KEYBOARD:ShowScene("inventory")
    end
end

function Editor.Initialize()
    if not KEYBOARD_QUICKSLOT_FRAGMENT then return end
    KEYBOARD_QUICKSLOT_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            OnShowing()
        elseif newState == SCENE_FRAGMENT_HIDDEN then
            OnHidden()
        end
    end)
end
