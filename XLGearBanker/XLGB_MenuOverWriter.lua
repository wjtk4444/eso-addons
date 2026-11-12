--[[
  XLGB_MenuOverWriter.lua

  It adds an extra entry to the dropdown menu when you right click an item that allows you to add that item to a gearset of choice.

  The following code is heavily inspired by TTC's TamrielTradeCenterPrice.lua
]]--

-- Namespace
XLGB_MenuOverWriter = {}

-- Constants
XLGB = XLGB_Constants

-- Functions
local function MakeContextMenuEntry_AddItemToGearSet(itemLink, itemID)
  local subEntries = {}
  local totalGearSets = XLGB_GearSet:GetNumberOfGearSets()
  if totalGearSets ~= 0 then
    for i = 1, totalGearSets do
      local gearSetName = XLGB_GearSet:GetGearSet(i).name
      local subEntry = {
        label = gearSetName,
        callback =
          function()
            if (XLGB_GearSet:GetItemIndexInGearSet(itemID, i) == XLGB.ITEM_NOT_IN_SET) then
              XLGB_GearSet:AddItemToGearSet(itemLink, itemID, i)
            else
              d("[XLGB] Item " .. itemLink .. " is already in " .. gearSetName)
            end
          end
      }
      table.insert(subEntries, subEntry)
    end
    AddCustomSubMenuItem(XLGB.ADD_ITEM_TO_GEARSET, subEntries)
  end
end

local function MakeContextMenuEntry_RemoveItemFromGearSet(itemLink, itemID)
  local subEntries = {}
  local totalGearSets = XLGB_GearSet:GetNumberOfGearSets()
  if totalGearSets ~= 0 then 
    for i = 1, totalGearSets do
      if (XLGB_GearSet:GetItemIndexInGearSet(itemID, i) ~= XLGB.ITEM_NOT_IN_SET) then
        local gearSetName = XLGB_GearSet:GetGearSet(i).name
        local subEntry = {
          label = gearSetName,
          callback = 
            function()
              XLGB_GearSet:RemoveItemFromGearSet(itemLink, itemID, i)
            end
        }
        table.insert(subEntries, subEntry)
      end
    end
    if (#subEntries ~= 0) then 
      AddCustomSubMenuItem(XLGB.REMOVE_ITEM_FROM_GEARSET, subEntries)
    end
  end
end

local function AddContextMenuEntries(itemLink, itemID, inventorySlot)
  MakeContextMenuEntry_AddItemToGearSet(itemLink, itemID)
  MakeContextMenuEntry_RemoveItemFromGearSet(itemLink, itemID)
  ShowMenu(inventorySlot)
end


local function OverWriteInventoryShowContextMenuHandler()
  LibCustomMenu:RegisterContextMenu(
      function(inventorySlot, slotActions)
        -- Inventory slot should either be the player bag, equipment slots, or the bank.
        local slotTypesAllowed = {
          [SLOT_TYPE_ITEM] = true,
          [SLOT_TYPE_EQUIPMENT] = true,
          [SLOT_TYPE_BANK_ITEM] = true,
        }
        local slotType = ZO_InventorySlot_GetType(inventorySlot)
        if not slotTypesAllowed[slotType] then return end
        local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if not bag or not index then return end
        local itemLink = GetItemLink(bag, index)
        local itemID = Id64ToString(GetItemUniqueId(bag, index))
        if not itemLink or itemLink == "" or not itemID then return end
        easyDebug("Item ID of " .. itemLink .. ": " .. itemID)
        local itemType = GetItemLinkItemType(itemLink)
        local itemTypesAllowed = {
          [ITEMTYPE_ARMOR] = true,
          [ITEMTYPE_WEAPON] = true,
        }
		local itemTypesExtra = {
		  [ITEMTYPE_POISON] = true,
		  [ITEMTYPE_AVA_REPAIR] = true,
		  [ITEMTYPE_SIEGE] = true,
		  [ITEMTYPE_POTION] = true,
		  [ITEMTYPE_FOOD] = true,
		  [ITEMTYPE_DRINK] = true,
		  [ITEMTYPE_RECALL_STONE] = true,
		}
        -- Item should be armor or weapon.
        if itemTypesAllowed[itemType] then 
			-- ok
		elseif itemTypesExtra[itemType] then
			itemID = GetItemId(bag, index)
		else
			return -- not ok
		end
        AddContextMenuEntries(itemLink, itemID, inventorySlot)
		
      end,
      LibCustomMenu.CATEGORY_LATE
    )
  end

function XLGB_MenuOverWriter:Initialize()
  OverWriteInventoryShowContextMenuHandler()
end

