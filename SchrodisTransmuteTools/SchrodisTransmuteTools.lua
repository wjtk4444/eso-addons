local ADDON = "SchrodisTransmuteTools"

local NIRNHONED = ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
local SEARCH_DELAY_MS = 150

local defaults = {
    includeBanked = true,
}

local sv
local retrait -- ZO_RETRAIT_KEYBOARD
local searchTerms = {}
local bankButton

local function RefreshInventory()
    retrait.inventory:HandleDirtyEvent()
end

----------------------------------------------------------------------------------------------------
-- 1) Text search + "include banked items" toggle
----------------------------------------------------------------------------------------------------

local function SetSearchText(text)
    ZO_ClearNumericallyIndexedTable(searchTerms)
    for word in zo_strlower(text or ""):gmatch("%S+") do
        searchTerms[#searchTerms + 1] = word
    end
end

local function MatchesSearch(bagId, slotIndex)
    if #searchTerms == 0 then
        return true
    end

    local link = GetItemLink(bagId, slotIndex)
    local _, setName = GetItemLinkSetInfo(link)
    local haystack = zo_strlower(table.concat({
        zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotIndex)),
        GetString("SI_ITEMTRAITTYPE", GetItemTrait(bagId, slotIndex)),
        setName and zo_strformat(SI_TOOLTIP_ITEM_NAME, setName) or "",
    }, "\n"))

    for _, term in ipairs(searchTerms) do
        if not haystack:find(term, 1, true) then
            return false
        end
    end
    return true
end

-- The retrait inventory calls this with banks included; we drop banks when the toggle is off and
-- wrap the filter with the text search. Not using inventory.additionalFilter, LibFilters owns it.
local function HookInventoryGather()
    local inventory = retrait.inventory
    local class = getmetatable(inventory)

    inventory.GetIndividualInventorySlotsAndAddToScrollData = function(self, predicate, filterFunction, filterType, data, useWornBag, excludeBankedItems)
        local filter = filterFunction
        if #searchTerms > 0 then
            filter = function(bagId, slotIndex, ...)
                if filterFunction and not filterFunction(bagId, slotIndex, ...) then
                    return false
                end
                return MatchesSearch(bagId, slotIndex)
            end
        end
        return class.GetIndividualInventorySlotsAndAddToScrollData(self, predicate, filter, filterType, data, useWornBag, excludeBankedItems or not sv.includeBanked)
    end
end

local function BankTooltipText()
    return sv.includeBanked and "Include banked items: |c00FF00ON|r" or "Include banked items: |cFF0000OFF|r (backpack + equipped only)"
end

local function UpdateBankButton()
    local icon = bankButton:GetNamedChild("Icon")
    icon:SetAlpha(sv.includeBanked and 1 or 0.35)
    icon:SetDesaturation(sv.includeBanked and 0 or 1)
end

local function CreateFilterControls()
    local inventoryControl = retrait.inventoryControl
    local tabs = inventoryControl:GetNamedChild("Tabs")
    local activeLabel = inventoryControl:GetNamedChild("TabsActive")

    local search = CreateControlFromVirtual("$(parent)SchrodisTransmuteToolsSearch", inventoryControl, "SchrodisTransmuteTools_SearchTemplate")
    search:SetAnchor(LEFT, inventoryControl, TOPLEFT, 0, 0, ANCHOR_CONSTRAINS_X)
    search:SetAnchor(LEFT, tabs, LEFT, 0, 0, ANCHOR_CONSTRAINS_Y)

    local box = search:GetNamedChild("Box")
    ZO_CraftingUtils_ConnectEditBoxToCraftingProcess(box)
    box:SetHandler("OnTextChanged", function(self)
        SetSearchText(self:GetText())
        EVENT_MANAGER:UnregisterForUpdate(ADDON .. "Search")
        EVENT_MANAGER:RegisterForUpdate(ADDON .. "Search", SEARCH_DELAY_MS, function()
            EVENT_MANAGER:UnregisterForUpdate(ADDON .. "Search")
            RefreshInventory()
        end)
    end)

    bankButton = CreateControlFromVirtual("$(parent)SchrodisTransmuteToolsBank", inventoryControl, "SchrodisTransmuteTools_BankToggleTemplate")
    bankButton:SetAnchor(LEFT, search, RIGHT, 6, 0)
    bankButton:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
        SetTooltipText(InformationTooltip, BankTooltipText())
    end)
    bankButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
    bankButton:SetHandler("OnClicked", function(self)
        if ZO_CraftingUtils_IsPerformingCraftProcess() then
            return
        end
        sv.includeBanked = not sv.includeBanked
        PlaySound(SOUNDS.DEFAULT_CLICK)
        UpdateBankButton()
        ClearTooltip(InformationTooltip)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -5)
        SetTooltipText(InformationTooltip, BankTooltipText())
        RefreshInventory()
    end)
    UpdateBankButton()

    -- The "WEAPONS"/"ARMOR" header label normally stretches to the panel's left edge.
    activeLabel:ClearAnchors()
    activeLabel:SetAnchor(LEFT, bankButton, RIGHT, 10, 0, ANCHOR_CONSTRAINS_X)
    activeLabel:SetAnchor(RIGHT, tabs, LEFT, -20, 0)

    -- Start every station visit with an empty search.
    SCENE_MANAGER:GetScene("retrait_keyboard_root"):RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDDEN and box:GetText() ~= "" then
            box:SetText("")
        end
    end)
end

----------------------------------------------------------------------------------------------------
-- 2) Trait list tall enough for every trait (vanilla fits 7 of 8 and scrolls)
----------------------------------------------------------------------------------------------------

local function HookTraitList()
    local container = retrait.traitContainer
    -- XML: CENTER of GuiRoot, offsetY -40, height 480. Keep the bottom edge where it was and grow upwards.
    local bottomOffset = -40 + container:GetHeight() / 2
    local fittedRows = 0 -- grow at most once per row count, never trust a measurement taken right after a resize

    SecurePostHook(retrait, "RefreshTraitList", function(self)
        local list = self.traitList
        local rows = #self.traitListData
        local needed = rows * ZO_RETRAIT_TRAIT_LIST_ROW_HEIGHT
        local available = list:GetHeight()
        if rows > fittedRows and needed > available then
            fittedRows = rows
            container:SetHeight(container:GetHeight() + (needed - available) + 2)
            container:ClearAnchors()
            container:SetAnchor(BOTTOM, GuiRoot, CENTER, 0, bottomOffset)
            ZO_ScrollList_Commit(list)
        end
    end)
end

----------------------------------------------------------------------------------------------------
-- 3) "Nirnhoned" in the context menu of purple-or-lower weapons
----------------------------------------------------------------------------------------------------

local function IsNirnhonedCandidate(bagId, slotIndex)
    return GetItemTraitCategory(bagId, slotIndex) == ITEM_TRAIT_TYPE_CATEGORY_WEAPON
        and GetItemTrait(bagId, slotIndex) ~= NIRNHONED
        and GetItemDisplayQuality(bagId, slotIndex) <= ITEM_DISPLAY_QUALITY_ARTIFACT
        and CanItemBeRetraited(bagId, slotIndex)
end

local function GetBlockReason(bagId, slotIndex)
    if ZO_CraftingUtils_IsPerformingCraftProcess() or IsAwaitingCraftingProcessResponse() then
        return "Busy."
    end
    if not IsItemTraitKnownForRetraitResult(bagId, slotIndex, NIRNHONED) then
        return zo_strformat(SI_RETRAIT_STATION_MUST_RESEARCH_TRAIT, GetCraftingSkillName(GetRearchLineInfoFromRetraitItem(bagId, slotIndex)))
    end
    local cost, currency, location = GetItemRetraitCost()
    if cost > GetCurrencyAmount(currency, location) then
        return GetString("SI_RETRAITRESPONSE", RETRAIT_RESPONSE_INSUFFICIENT_FUNDS)
    end
end

local function TransmuteToNirnhoned(bagId, slotIndex)
    if GetBlockReason(bagId, slotIndex) or not IsNirnhonedCandidate(bagId, slotIndex) then
        return
    end

    -- Go through the station UI so the slot, result tooltip and craft animation look like a normal transmute.
    retrait:SetRetraitSlotItem(bagId, slotIndex)
    if not retrait:IsItemSlotted(bagId, slotIndex) then
        return
    end
    for _, entry in ipairs(retrait.traitListData) do
        if entry.data.trait == NIRNHONED then
            ZO_ScrollList_SelectDataAndScrollIntoView(retrait.traitList, entry.data)
            break
        end
    end
    if retrait.selectedTrait ~= NIRNHONED then
        return
    end

    if IsItemPlayerLocked(bagId, slotIndex) or IsItemBoPAndTradeable(bagId, slotIndex) or not IsItemBound(bagId, slotIndex) then
        -- Locked, still tradeable within the group, or unbound (transmuting binds it): keep the vanilla confirmation.
        retrait:PerformRetrait()
    else
        PlaySound(SOUNDS.RETRAITING_START_RETRAIT)
        RequestItemTraitChange(bagId, slotIndex, NIRNHONED)
    end
end

local function OnContextMenu(inventorySlot)
    if not retrait:IsShowing() then
        return
    end
    local parent = inventorySlot:GetParent()
    local owner = inventorySlot.owner or (parent and parent.owner)
    if owner ~= retrait.inventory then
        return
    end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not IsNirnhonedCandidate(bagId, slotIndex) then
        return
    end

    local blockReason = GetBlockReason(bagId, slotIndex)
    AddCustomMenuItem(GetString("SI_ITEMTRAITTYPE", NIRNHONED), function()
        TransmuteToNirnhoned(bagId, slotIndex)
    end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil, nil, nil, nil, blockReason == nil)
    if blockReason then
        AddCustomMenuTooltip(blockReason)
    end
end

----------------------------------------------------------------------------------------------------
-- 4) Transmute crystal count on the Reconstruction tab (vanilla only shows it on the Transmute tab)
----------------------------------------------------------------------------------------------------

local function CreateReconstructCurrency()
    local reconstruct = ZO_RECONSTRUCT_KEYBOARD
    local label = CreateControlFromVirtual("$(parent)SchrodisTransmuteToolsCurrency", reconstruct.control, "ZO_CurrencyTemplate")
    label:SetFont("ZoFontWinH3")

    -- Left of the "RECONSTRUCTION" title next to the mode tabs: free in both the set book and the options view.
    label:SetAnchor(RIGHT, ZO_RetraitStation_KeyboardTopLevelModeMenuBarLabel, LEFT, -40, 0)

    local SHOW_CURRENCY_CAP = true
    ZO_SharedInventory_ConnectPlayerCurrencyLabel(label, CURT_TRANSMUTE_CRYSTALS, CURRENCY_LOCATION_ACCOUNT, ZO_KEYBOARD_CURRENCY_OPTIONS, SHOW_CURRENCY_CAP)
end

----------------------------------------------------------------------------------------------------

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("SchrodisTransmuteTools_SV", 1, nil, defaults)

    retrait = ZO_RETRAIT_KEYBOARD

    HookInventoryGather()
    CreateFilterControls()
    HookTraitList()
    LibCustomMenu:RegisterContextMenu(OnContextMenu, LibCustomMenu.CATEGORY_LATE)
    CreateReconstructCurrency()
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
