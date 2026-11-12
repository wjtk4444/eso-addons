SchrodisHousingTools = {}
local SHT = SchrodisHousingTools

SHT.ADDON_NAME = "SchrodisHousingTools"
SHT.SORT_KEY_NAME = "name"
SHT.SORT_KEY_DISTANCE = "distance"

local defaults =
{
    sortKey = SHT.SORT_KEY_DISTANCE,
    sortOrder = ZO_SORT_ORDER_UP, -- UP = ascending (A->Z, nearest first)
    rightClickStore = false,
    boundToVault = false,
}

-- The two addons this one replaces. If either is still enabled, its part is skipped here,
-- otherwise every hook would be installed twice (double sort headers, double dropdowns).
local LEGACY_ADDONS =
{
    HousingRetrieveSort = "housing editor",
    FurnitureVaultFilters = "Furniture Vault",
}

local function GetEnabledLegacyAddons()
    local enabled = {}
    local manager = GetAddOnManager()
    for i = 1, manager:GetNumAddOns() do
        local name, _, _, _, isEnabled = manager:GetAddOnInfo(i)
        if isEnabled and LEGACY_ADDONS[name] then
            enabled[name] = true
        end
    end
    return enabled
end

local function WarnAboutLegacyAddons(legacy)
    local names = {}
    for name in pairs(legacy) do
        names[#names + 1] = name
    end
    if #names == 0 then
        return
    end
    table.sort(names)
    local message = string.format(
        "|cFFAA33Schrodi's Housing Tools:|r %s replaced by this addon and still enabled. Its features are skipped here until you disable it in the AddOns menu.",
        table.concat(names, " and ") .. (#names == 1 and " is" or " are"))
    -- Chat is not ready at EVENT_ADD_ON_LOADED.
    EVENT_MANAGER:RegisterForEvent(SHT.ADDON_NAME .. "Warn", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(SHT.ADDON_NAME .. "Warn", EVENT_PLAYER_ACTIVATED)
        CHAT_ROUTER:AddSystemMessage(message)
    end)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= SHT.ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(SHT.ADDON_NAME, EVENT_ADD_ON_LOADED)

    SHT.sv = ZO_SavedVars:NewAccountWide("SchrodisHousingTools_SV", 1, nil, defaults)

    local legacy = GetEnabledLegacyAddons()
    WarnAboutLegacyAddons(legacy)

    if not legacy.HousingRetrieveSort then
        SHT.InitializeHousingEditor(SHT.sv)
    end
    if not legacy.FurnitureVaultFilters then
        SHT.InitializeFurnitureVault()
    end
end

EVENT_MANAGER:RegisterForEvent(SHT.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
