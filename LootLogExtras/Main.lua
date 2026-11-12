local LLE = LootLogExtras

-- The addons this one replaces. If one is still enabled it would log the same items twice.
local LEGACY_ADDONS =
{
    LootLogCraft = "logCrafting",
    LootLogMail = "logMail",
    LootLogFishing = false, -- nothing to skip: LootLog itself handles rare fish since 4.7.3
}

local function CheckLegacyAddons()
    local found = {}
    local manager = GetAddOnManager()
    for i = 1, manager:GetNumAddOns() do
        local name, _, _, _, isEnabled = manager:GetAddOnInfo(i)
        if isEnabled and LEGACY_ADDONS[name] ~= nil then
            found[#found + 1] = name
        end
    end
    if #found == 0 then
        return {}
    end

    table.sort(found)
    local skipped = {}
    for _, name in ipairs(found) do
        if LEGACY_ADDONS[name] then
            skipped[LEGACY_ADDONS[name]] = true
        end
    end

    EVENT_MANAGER:RegisterForEvent(LLE.ADDON_NAME .. "Warn", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(LLE.ADDON_NAME .. "Warn", EVENT_PLAYER_ACTIVATED)
        LLE.Msg("%s replaced by LootLogExtras and still enabled. Please disable %s in the AddOns menu; until then the matching logging here is off.",
            table.concat(found, ", ") .. (#found == 1 and " is" or " are"), #found == 1 and "it" or "them")
    end)
    return skipped
end

local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = LLE.ADDON_NAME .. "Settings"
    LAM:RegisterAddonPanel(panelName,
    {
        type = "panel",
        name = "LootLog Extras",
        author = "Schrodi",
        registerForDefaults = true,
    })

    local controls =
    {
        {
            type = "checkbox",
            name = "Crafting stations",
            tooltip = "Log materials received from refining and deconstruction, including the deconstruction assistant. Every material goes into the history; a chat note only appears for notable ones.",
            getFunc = function() return LLE.sv.logCrafting end,
            setFunc = function(value) LLE.sv.logCrafting = value end,
            default = LLE.defaults.logCrafting,
        },
        {
            type = "checkbox",
            name = "Mail attachments",
            tooltip = "Log notable items taken from mail, including system mail (hirelings, rewards) and \"Take All\". Items that are not notable are not logged, so guild store mail does not flood the history.",
            getFunc = function() return LLE.sv.logMail end,
            setFunc = function(value) LLE.sv.logMail = value end,
            default = LLE.defaults.logMail,
        },
        {
            type = "checkbox",
            name = "Unknown recipes, motifs and plans are notable",
            tooltip = "Treat anything your character does not know yet as notable, whatever its quality. Needs LibCharacterKnowledge.",
            getFunc = function() return LLE.sv.unknownKnowledgeIsNotable end,
            setFunc = function(value) LLE.sv.unknownKnowledgeIsNotable = value end,
            disabled = function() return LibCharacterKnowledge == nil end,
            default = LLE.defaults.unknownKnowledgeIsNotable,
        },
    }
    LAM:RegisterOptionControls(panelName, controls)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= LLE.ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(LLE.ADDON_NAME, EVENT_ADD_ON_LOADED)

    LLE.sv = ZO_SavedVars:NewAccountWide("LootLogExtras_SV", 1, nil, LLE.defaults)

    -- Legacy addons only switch the matching part off for this session; the saved setting stays.
    local skipped = CheckLegacyAddons()
    if next(skipped) then
        local IsEnabled = LLE.IsEnabled
        LLE.IsEnabled = function(settingKey)
            return not skipped[settingKey] and IsEnabled(settingKey)
        end
    end

    LLE.InitializeCrafting()
    LLE.InitializeMail()
    CreateSettingsMenu()
end

EVENT_MANAGER:RegisterForEvent(LLE.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
