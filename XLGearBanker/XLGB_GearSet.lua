XLGB_GearSet = {}

local XLGB = XLGB_Constants
local sV

function XLGB_GearSet:Initialize()
  sV = XLGearBanker.savedVariables
  -- sV.gearSetList = sV.gearSetList or {}

end

function XLGB_GearSet:ValidGearSetNumber(gearSetNumber, totalGearSets)
  if gearSetNumber == nil
  or gearSetNumber == ""
  or gearSetNumber > totalGearSets
  or gearSetNumber < 1 then
    d("[XLGB_ERROR] GearSetNumber is invalid. Got:", gearSetNumber)
    return false
  else
    return true
  end
end

-- credit: https://gist.github.com/tylerneylon/81333721109155b2d244
local function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end


function XLGB_GearSet:ValidGearSetName(gearSetName)
  if gearSetName == nil
  or gearSetName == "" then 
    d("[XLGB_ERROR] Enter a name for the set.")
    return false
  else
    return true
  end
end

function XLGB_GearSet:GetGearSet(gearSetNumber)
  return sV.gearSetList[gearSetNumber]
end

function XLGB_GearSet:GetNumberOfGearSets()
  return #sV.gearSetList
end

local function isNameUnique(name)
  local totalSets = XLGB_GearSet:GetNumberOfGearSets()
  local isUnique = true
  for i = 1, totalSets do
    local gearSet = XLGB_GearSet:GetGearSet(i)
    if (gearSet.name == name) then
      isUnique = false
    end
  end
  return isUnique
end

local function sortGearSets()
  local function compareSets(setA, setB)
    return setA.name < setB.name
  end
  local preSortList = {}
  for i, set in pairs(sV.gearSetList) do
      preSortList[i] = set.name
  end
  table.sort(sV.gearSetList, compareSets)
  XLGB_Events:OnGearSetSort(preSortList)
end

function XLGB_GearSet:CreateNewGearSet(gearSetName)
  if (not isNameUnique(gearSetName)) then
    return false
  end
  local gearSet = {}
  gearSet.name = "" .. gearSetName
  gearSet.items = {}
  table.insert(sV.gearSetList, gearSet)
  sortGearSets()
  d("[XLGB] Created new set: " .. gearSetName)
  return true
end

function XLGB_GearSet:GenerateNewSet()
  local xcounter = "X"
  local name = "My " .. xcounter .. "LGB Set"
  while not(XLGB_GearSet:CreateNewGearSet(name)) do
      xcounter = "X" .. xcounter
      name = "My " .. xcounter .. "LGB Set"
  end
  return name
end

function XLGB_GearSet:FindGearSet(gearSetName)
  local gearSets = sV.gearSetList
  for _, gearSet in pairs(gearSets) do
      if gearSet.name == gearSetName then
        return gearSet
      end
  end
  return nil
end

function XLGB_GearSet:GetGearSetIndex(gearSetName)
  local gearSets = sV.gearSetList
  for i, gearSet in pairs(gearSets) do
      if gearSet.name == gearSetName then
        return i
      end
  end
  return -1
end

function XLGB_GearSet:CopyGearSet(gearSetNumber)
  return copy(XLGB_GearSet:GetGearSet(gearSetNumber))
end

local function findAndUpdateItem(itemIndex, item, gearSet)
  local bag  = BAG_BACKPACK
  local slot = ZO_GetNextBagSlotIndex(bag)
  while slot do
    local itemID = type(item.ID) == "string" and Id64ToString(GetItemUniqueId(bag, slot)) or GetItemId(bag, slot)
    if itemID == item.ID then
      local itemLink = GetItemLink(bag, slot)
      local itemData = XLGB_GearSet:CreateItemData(itemLink, itemID)
      gearSet.items[itemIndex] = itemData
      return
    end
    slot = ZO_GetNextBagSlotIndex(bag, slot)
  end
end

function XLGB_GearSet:UpdateGearSetItems(gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)
  for i, item in pairs(gearSet.items) do
    findAndUpdateItem(i, item, gearSet)
  end
end

function XLGB_GearSet:EditGearSetName(newName, gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)
  local isUnique = isNameUnique(newName)
  if isUnique then
    XLGB_Events:OnGearSetNameChange(gearSet.name, newName)
    gearSet.name = newName
    sortGearSets()
    return true
  end
  return gearSet.name == newName
end

function XLGB_GearSet:RemoveGearSet(gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)
  XLGB_Events:OnGearSetRemove(gearSet.name)
  table.remove(sV.gearSetList, gearSetNumber)
  d("[XLGB] Removed set: " .. gearSet.name)
end

function XLGB_GearSet:CreateItemData(itemLink, itemID)
  local itemData = {}
  itemData.link = itemLink
  itemData.ID = itemID
  return itemData
end

local function compareItems(itemA, itemB)
  return itemA.link < itemB.link
end

function XLGB_GearSet:AddItemToGearSet(itemLink, itemID, gearSetNumber)
  local itemData = XLGB_GearSet:CreateItemData(itemLink, itemID)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)

  table.insert(sV.gearSetList[gearSetNumber].items, itemData)
  table.sort(sV.gearSetList[gearSetNumber].items, compareItems)

  XLGB_Events:OnGearSetItemAdd(gearSet, sV.gearSetList[gearSetNumber])
  --d("[XLGB] Added item " .. itemLink .. " to " .. gearSet.name .. " id: " .. itemID)
end

function XLGB_GearSet:AddEquippedItemsToGearSet(gearSetNumber)
  local itemsToBeAdded = XLGB_Inventory:GetEquippedItems()
  XLGB_GearSet:AddItemsToGearSet(itemsToBeAdded, gearSetNumber)
end

function XLGB_GearSet:AddItemsToGearSet(itemsToBeAdded, gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)  
  for _, itemData in pairs(itemsToBeAdded) do
    if (XLGB_GearSet:GetItemIndexInGearSet(itemData.ID, gearSetNumber) == XLGB.ITEM_NOT_IN_SET) then
      table.insert(sV.gearSetList[gearSetNumber].items, itemData)
    end
  end
  table.sort(sV.gearSetList[gearSetNumber].items, compareItems)

  d("[XLGB] Added items to " .. gearSet.name)
end

function XLGB_GearSet:RemoveItemFromGearSet(itemLink, itemID, gearSetNumber)
  local gearSet = copy(XLGB_GearSet:GetGearSet(gearSetNumber))
  local gearSetName = gearSet.name

  for i, item in pairs(gearSet.items) do
    if item.ID == itemID then
      table.remove(sV.gearSetList[gearSetNumber].items, i)
      XLGB_Events:OnGearSetItemRemove(gearSet, sV.gearSetList[gearSetNumber])
      break
    end
  end
  
  d("[XLGB] Removed item " .. itemLink .. " from " .. gearSetName)
end

function XLGB_GearSet:RemoveItemsFromGearSet(itemsToBeRemoved, gearSetNumber)
  local gearSet = copy(XLGB_GearSet:GetGearSet(gearSetNumber))
  local gearSetName = gearSet.name

  for _, itemToBeRemoved in pairs(itemsToBeRemoved) do
    for i, item in pairs(gearSet.items) do
      if item.ID == itemToBeRemoved then
        table.remove(sV.gearSetList[gearSetNumber].items, i)
        break
      end
    end

  end
  XLGB_Events:OnGearSetItemRemove(gearSet, sV.gearSetList[gearSetNumber])
  d("[XLGB] Removed items from " .. gearSetName)
end

local function updateItemLink(bag, slot, itemID, itemIndex, gearSet)
  local itemLink = GetItemLink(bag, slot)
  local itemData = XLGB_GearSet:CreateItemData(itemLink, itemID)
  gearSet.items[itemIndex] = itemData
end

local function updateMissingItem(fromBag, item, accList, itemIndex, gearSet)
  local bag = fromBag
  local slot = ZO_GetNextBagSlotIndex(bag)
  while slot do
    local itemID = type(item.ID) == "string" and Id64ToString(GetItemUniqueId(bag, slot)) or GetItemId(bag, slot)
    if itemID == item.ID then
      return updateItemLink(bag, slot, itemID, itemIndex, gearSet)
    end
    slot = ZO_GetNextBagSlotIndex(bag, slot)
  end

  if (bag == BAG_BANK) then -- if bag is bank then look through both bags
    bag = BAG_SUBSCRIBER_BANK
    slot = ZO_GetNextBagSlotIndex(bag)
  elseif(bag == BAG_SUBSCRIBER_BANK) then
    bag = BAG_BANK
    slot = ZO_GetNextBagSlotIndex(bag)
  elseif (bag == BAG_BACKPACK) then
    bag = BAG_WORN
    slot = ZO_GetNextBagSlotIndex(bag)
  elseif (bag == BAG_WORN) then
      bag = BAG_BACKPACK
      slot = ZO_GetNextBagSlotIndex(bag)
  end

  while slot do
    local itemID = type(item.ID) == "string" and Id64ToString(GetItemUniqueId(bag, slot)) or GetItemId(bag, slot)
    if itemID == item.ID then
      return updateItemLink(bag, slot, itemID, itemIndex, gearSet)
    end
    slot = ZO_GetNextBagSlotIndex(bag, slot)
  end

  table.insert(accList, item.link)
end

function XLGB_GearSet:GetMissingItems(fromBag, gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)
  local set = {}
  local missingItems = {}
  for i, item in pairs(gearSet.items) do
    updateMissingItem(fromBag, item, missingItems, i, gearSet)
  end
  set.items = missingItems
  set.name = gearSet.name
  return set
end


--[[
  function XLGB_GearSet:GetItemIndexInGearSet(itemLink, gearSetNumber)
  Input: 
    itemLink = The itemLink of the item you wish to find index for in the gearSet.
    gearSetNumber = The number index of the gearSet you wish to check
  Output:
    (item_index, gearSetNumber) = Returns item_index that indicates where the item is located
      or item_index = ITEM_NOT_IN_SET if the item doesn't exist in the gearSet.
]]--
function XLGB_GearSet:GetItemIndexInGearSet(itemID, gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)
  local itemIndex = XLGB.ITEM_NOT_IN_SET
  for i, item in pairs(gearSet.items) do
    if (item.ID == itemID) then
      itemIndex = i
    end
  end
  return itemIndex
end

function XLGB_GearSet:PrintGearSets()
  local totalGearSets = XLGB_GearSet:GetNumberOfGearSets()
  for i = 1, totalGearSets do
    local gearSet = XLGB_GearSet:GetGearSet(i)
    d("Set " .. i .. " = " .. gearSet.name)
  end
  d("[XLGB] Total sets = " .. totalGearSets)
end

function XLGB_GearSet:PrintGearSetItems(gearSetNumber)
  local gearSet = XLGB_GearSet:GetGearSet(gearSetNumber)

  d("Set \'" .. gearSet.name .. "\' contains the following items:")
  for _, item in pairs(gearSet.items) do 
    d(item.link)
  end
  d("[XLGB] Total items = " .. #gearSet.items)
end