local BAIT = {
    --lureID
    LAKE = {
        REG = 2, --guts
        ALT = 8  --minnow
    },
    FOUL = {
        REG = 3, --crawlers
        ALT = 9  --roe
    },
    RIVR = {
        REG = 4, --insects
        ALT = 6  --shad
    },
    SALT = {
        REG = 5, --worms
        ALT = 7  --chub
    },
    SIMPLE = 1 --simple bait
}

FishThief = {
    name = "FishThief",
    settingsName = "FishThief",
    delay = false,
	reelIn = false,
    defaults = {
        filtered = true,
        msg      = false
    }
}

--local logger = LibDebugLogger(FishThief.name)
local LAM = LibAddonMenu2


local function FISHTHIEF_GetItemQuantity(lureID)
    local _, _, stack = GetFishingLureInfo(lureID)
    return stack
end


local function FISHTHIEF_EquipBait(baittype)
    if FISHTHIEF_GetItemQuantity(baittype.ALT) > 0 and FishThief.SavedVariables.filtered == true then
        SetFishingLure(baittype.ALT)
    elseif FISHTHIEF_GetItemQuantity(baittype.REG) > 0 then
        SetFishingLure(baittype.REG)
    elseif FISHTHIEF_GetItemQuantity(BAIT.SIMPLE) > 0 then
        SetFishingLure(BAIT.SIMPLE)
    else
        if FishThief.SavedVariables.msg then
            ZO_CreateStringId("SI_HOLD_TO_SELECT_BAIT", GetString(FISHTHIEF_NO_BAIT))
        else
            ZO_CreateStringId("SI_HOLD_TO_SELECT_BAIT", GetString(FISHTHIEF_NO_BAIT_RST))
        end
    end
end


local function FISHTHIEF_OnAction()
    if FishThief.delay then return end
    EVENT_MANAGER:RegisterForUpdate(FishThief.name .. "Delay", 300, function()
        FishThief.delay = false
        EVENT_MANAGER:UnregisterForUpdate(FishThief.name .. "Delay")
    end)
    FishThief.delay = true

    local _, interactableName, _, _, additionalInteractInfo, _, _, _ = GetGameCameraInteractableActionInfo()
    if additionalInteractInfo ~= ADDITIONAL_INTERACT_INFO_FISHING_NODE then return end

    --Lake Bait
    if interactableName == GetString(FISHTHIEF_LAKE_FISHING_HOLE) then
        FISHTHIEF_EquipBait(BAIT.LAKE)
    --Salt or Mystic Bait
    elseif interactableName == GetString(FISHTHIEF_SALT_FISHING_HOLE) 
		or interactableName == GetString(FISHTHIEF_MYST_FISHING_HOLE) 
		or interactableName == GetString(FISHTHIEF_ABEC_FISHING_HOLE) then
        FISHTHIEF_EquipBait(BAIT.SALT)
    --Foul or Oily Bait
    --elseif interactableName == GetString(FISHTHIEF_FOUL_FISHING_HOLE) or interactableName == GetString(FISHTHIEF_OILY_FISHING_HOLE) or interactableName == GetString(FISHTHIEF_FOAB_FISHING_HOLE) then
    --    FISHTHIEF_EquipBait(BAIT.FOUL)
    --River Bait
    elseif interactableName == GetString(FISHTHIEF_RIVR_FISHING_HOLE) then
        FISHTHIEF_EquipBait(BAIT.RIVR)
    --Foul, Oily, Abyssal and Spawning (Event)
	else
		FISHTHIEF_EquipBait(BAIT.FOUL)
	end
end


function FishThief.CreateSettings()
    local panelName = "FishThiefSettingsPanel"

    local panelData = {
        type = "panel",
        name = FishThief.settingsName,
        displayName = FishThief.settingsName,
        author = "Schrodi",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local panel = LAM:RegisterAddonPanel(panelName, panelData)
    local optionsData = {}
        optionsData[#optionsData + 1] = {
            type = "description",
            text = GetString(FISHTHIEF_CNF_DESCRIPTION)
        }
        optionsData[#optionsData + 1] = {
            type = "checkbox",
            name = GetString(FISHTHIEF_CNF_SET),
            default = FishThief.defaults.filtered,
            disabled = false,
            getFunc = function() return FishThief.SavedVariables.filtered end,
            setFunc = function(value) FishThief.SavedVariables.filtered = value end
        }
        optionsData[#optionsData + 1] = {
            type = "checkbox",
            name = GetString(FISHTHIEF_CNF_MSG),
            default = FishThief.defaults.msg,
            disabled = false,
            getFunc = function() return FishThief.SavedVariables.msg end,
            setFunc = function(value) FishThief.SavedVariables.msg = value end
        }

    LAM:RegisterOptionControls(panelName, optionsData)
end


local function FISHTHIEF_SlotUpdate_ReelOut(_, _, _, _, itemSoundCategory, _, stackCountChange)
	if FishThief.reelIn == true then -- and stackCountChange == 1 then 
		FishThief.reelIn = false
		ZO_ReticleContainerInteractKeybindButtonNameLabel:SetColor(197/255, 194/255, 158/255, 1)
		EVENT_MANAGER:UnregisterForEvent(FishThief.name .. 'reelOut1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		EVENT_MANAGER:UnregisterForEvent(FishThief.name .. 'reelOut2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
		--d('ri-e: ' .. itemSoundCategory .. ' ' .. stackCountChange) -- (itemSoundCategory == ITEM_SOUND_CATEGORY_DEFAULT or itemSoundCategory == ITEM_SOUND_CATEGORY_FISH)
	end
end

local function FISHTHIEF_SlotUpdate_ReelIn(_, _, _, _, itemSoundCategory, _, stackCountChange)
	--d('ri?')
	if itemSoundCategory == ITEM_SOUND_CATEGORY_LURE and stackCountChange == -1 then
		FishThief.reelIn = true 
		PlaySound(SOUNDS.JUSTICE_PICKPOCKET_BONUS)
		ZO_ReticleContainerInteractKeybindButtonNameLabel:SetColor(42/255, 220/255, 34/255, 1)
		--d('ri-s')
		zo_callLater(function() 
			if not FishThief.reelIn then return end 
			FishThief.reelIn = false 
			ZO_ReticleContainerInteractKeybindButtonNameLabel:SetColor(197/255, 194/255, 158/255, 1)
			EVENT_MANAGER:UnregisterForEvent(FishThief.name .. 'reelOut1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
			EVENT_MANAGER:UnregisterForEvent(FishThief.name .. 'reelOut2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
			--d('ri-e: t/o') 
		end, 3000)
		
		EVENT_MANAGER:RegisterForEvent(FishThief.name .. 'reelOut1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, FISHTHIEF_SlotUpdate_ReelOut)
		EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelOut1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelOut1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
		EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelOut1', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
		
		EVENT_MANAGER:RegisterForEvent(FishThief.name .. 'reelOut2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, FISHTHIEF_SlotUpdate_ReelOut)
		EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelOut2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_VIRTUAL)
		EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelOut2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
		EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelOut2', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
	end
end

function FishThief.OnAddOnLoaded(event, addonName)
    if addonName ~= FishThief.name then return end

    EVENT_MANAGER:UnregisterForEvent(FishThief.name, EVENT_ADD_ON_LOADED)
    FishThief.SavedVariables = ZO_SavedVars:New("FishThiefSavedVariables", 1, nil, FishThief.defaults)
    FishThief.CreateSettings()
    ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", FISHTHIEF_OnAction)
	
	EVENT_MANAGER:RegisterForEvent(FishThief.name .. 'reelIn', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, FISHTHIEF_SlotUpdate_ReelIn)
	EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelIn', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_VIRTUAL)
	EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelIn', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
	EVENT_MANAGER:AddFilterForEvent(FishThief.name .. 'reelIn', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, false)
end

EVENT_MANAGER:RegisterForEvent(FishThief.name, EVENT_ADD_ON_LOADED, FishThief.OnAddOnLoaded)