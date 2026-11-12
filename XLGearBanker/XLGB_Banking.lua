--[[
  XLGB_Banking.lua

  This module contains all functionality related to item transfer.

  Functions:

]]--

--Namespace
XLGB_Banking = {}
local libDialog = LibDialog
local sV

local XLGB = XLGB_Constants

function XLGB_Banking.OnBankOpenEvent(event, bankBag)
  if not XLGB_Banking.bankOpen then
    XLGB_Banking.bankOpen = IsBankOpen()
    XLGB_Banking.currentBankBag = bankBag
    XLGB_UI:OnBankOpen()
    KEYBIND_STRIP:AddKeybindButtonGroup(XLGB_Banking.bankButtonGroup)
    easyDebug("Bank open!")
  end
end

function XLGB_Banking.OnBankCloseEvent(event)
  if XLGB_Banking.bankOpen then
    XLGB_Banking.bankOpen = IsBankOpen()
    XLGB_Banking.currentBankBag = XLGB.NO_BAG
    XLGB_Banking.isMoveCancelled = true
    XLGB_UI:OnBankClosed()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(XLGB_Banking.bankButtonGroup)
    easyDebug("Bank closed")
  end
end

-- Armor/weapon entries are tracked by their unique instance ID (a string), and a unique
-- item instance can only ever occupy one bag slot at a time, so a single match is always
-- correct/complete for those.
--
-- Stackable/siege entries (added for potions, food, siege weapons, etc.) are tracked by
-- their shared item ID (a number) instead, since those items don't have a stable per-copy
-- unique ID. But a shared item ID is not guaranteed to correspond to exactly one bag slot:
-- a genuine stack can split across slots once it exceeds the max stack size, and siege
-- weapons in particular only stack together while at full durability - e.g. 5 ballistas at
-- 5 different repair levels sit in 5 separate, non-mergeable slots that all share the same
-- item ID. So for a numeric itemID we scan the whole bag and collect every matching slot,
-- not just the first one - otherwise only one physical copy gets queued to move at a time
-- and the rest are silently left behind (needing the move button pressed once per copy).
local function findAllItemIndicesInBag(bag, itemID)
  local isUniqueId = (type(itemID) == "string")
  local indices = {}
  for i = 0, GetBagSize(bag) do
    if GetItemName(bag, i) ~= "" then
      if isUniqueId then
        if Id64ToString(GetItemUniqueId(bag, i)) == itemID then
          table.insert(indices, i)
          return indices -- unique items only ever occupy a single slot
        end
      elseif itemID == GetItemId(bag, i) then
        table.insert(indices, i)
      end
    end
  end
  return indices
end

local function findItemsToMove(sourceBag, sourceItems)
  local itemsToMove = {}
  for _, item in pairs(sourceItems) do
    local indices = findAllItemIndicesInBag(sourceBag, item.ID)
    for _, itemIndex in ipairs(indices) do
      local itemToMoveEntry = {}
      itemToMoveEntry.item = item
      itemToMoveEntry.index = itemIndex
      table.insert(itemsToMove, itemToMoveEntry)
    end
  end
  return itemsToMove
end


local function getAvailableBagSpaces(bag)
  easyDebug("Finding available bagspaces in bag: " .. bag)
  local availableBagSpaces = {}
  local slot = FindFirstEmptySlotInBag(bag)
  while slot do
    if GetItemName(bag, slot) == "" then
      table.insert(availableBagSpaces, slot)
    end
    slot = ZO_GetNextBagSlotIndex(bag, slot)
  end
  -- for i = firstEmptySlot, GetBagSize(bag) do
  --   if GetItemName(bag, i) == "" then
  --     table.insert(availableBagSpaces, i)
  --   end
  -- end

  easyDebug("Found " .. #availableBagSpaces .. " available spaces in bag.")
  return availableBagSpaces
end

local function stopMovingItems()
  EVENT_MANAGER:UnregisterForEvent(XLGearBanker.name .. "MoveGearFromTwoBags", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
  EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "MoveGearFromTwoBags")
  
  EVENT_MANAGER:UnregisterForEvent(XLGearBanker.name .. "MoveGear", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
  EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "MoveGear")

  XLGB_Banking.isWaitingForBag = false
  XLGB_Banking.movesInSuccession = XLGB_Banking.movesInSuccession - 1
  if XLGB_Banking.movesInSuccession < 1 then
    XLGB_Banking.isMovingItems = false
    sV.safeMode = XLGB_Banking.safeModeBefore
  end

end

local function onMoveFailed(sourceBag, failedAtItemIndex, targetBag, spaceFailedToMoveInto)
  d("---------------------------------")
  d("Failed to move item!")
  d("-")
  d("sourceBag " .. tostring(sourceBag))
  d("failedAtItemIndex " .. tostring(failedAtItemIndex))
  d("targetBag " .. tostring(targetBag))
  d("spaceFailedToMoveInto " .. tostring(spaceFailedToMoveInto))
  d("-")
  d("Item at index = '" .. tostring(failedAtItemIndex and GetItemName(sourceBag, failedAtItemIndex)) ..  "'")
  if spaceFailedToMoveInto then
    d("Space = '" .. GetItemName(targetBag, spaceFailedToMoveInto) .. "'")
  else
    d("Space = <no free slot was available - ran out of precomputed bag space>")
  end
  d("-")
  d("--------------------------------")
  XLGB_Banking.isMoveCancelled = true
  stopMovingItems()
end

-- Retries a move a limited number of times before giving up. This exists because under
-- server lag/desync, the target slot we pre-computed as "empty" can briefly still appear
-- occupied (the server hasn't caught up yet) even though it's about to become free, or the
-- previous RequestMoveItem in this batch hasn't been fully acknowledged yet. Immediately
-- treating that as a hard failure (and cancelling the whole set/page transfer) is overly
-- aggressive - a short retry usually lets the desync resolve itself.
local function moveItem(sourceBag, itemIndex, targetBag, availableSpace, retryCount, sessionId)
  retryCount = retryCount or 0
  -- Tag every (non-retry) call with the current move "session". A retry is delayed via
  -- zo_callLater, and by the time it fires the whole batch may have already finished (or
  -- the next set/page in a batch may have already started a new session) - if that
  -- happened, acting on this stale retry would corrupt an unrelated operation's
  -- bookkeeping (double-decrementing movesInSuccession, or cancelling a later transfer).
  sessionId = sessionId or XLGB_Banking.moveSessionId

  -- No free slot was even available for this item (ran off the end of the precomputed
  -- list of empty slots) - retrying won't help since there's nothing to retry into.
  if availableSpace == nil then
    return onMoveFailed(sourceBag, itemIndex, targetBag, availableSpace)
  end

  local _, stack = GetItemInfo(sourceBag, itemIndex)
  --d("Moving Item at index = '" .. GetItemName(sourceBag, itemIndex) .. " " .. (stack or 1) .. "' to space = '" .. GetItemName(targetBag, availableSpace) .. "'")
  local moveFailed = not CallSecureProtected("RequestMoveItem", sourceBag, itemIndex, targetBag, availableSpace, stack or 1)
  if moveFailed or GetItemName(targetBag, availableSpace) ~= "" then
    if (not moveFailed) and retryCount < XLGB_Banking.maxMoveRetries then
      -- Likely a transient desync - the slot we thought was empty still shows an item.
      -- Wait a beat and try this exact move again before giving up on the whole batch.
      zo_callLater(function()
        if sessionId ~= XLGB_Banking.moveSessionId then return end
        if XLGB_Banking.isMoveCancelled then return end
        moveItem(sourceBag, itemIndex, targetBag, availableSpace, retryCount + 1, sessionId)
      end, XLGB_Banking.moveRetryDelay)
    else
      onMoveFailed(sourceBag, itemIndex, targetBag, availableSpace)
    end
  end
end

local function moveItemDelayed(sourceBag, itemIndex, targetBag, availableSpace)
  zo_callLater(function () moveItem(sourceBag, itemIndex, targetBag, availableSpace) end, XLGB_Banking.itemMoveDelay)
end

local function updateMoveEvent(eventName, targetBag, lambda)
  EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. eventName)
  EVENT_MANAGER:UnregisterForEvent(XLGearBanker.name .. eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

  if sV.safeMode then
    EVENT_MANAGER:RegisterForEvent(XLGearBanker.name .. eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, lambda)
    EVENT_MANAGER:AddFilterForEvent(XLGearBanker.name .. eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, false)
    EVENT_MANAGER:AddFilterForEvent(XLGearBanker.name .. eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, targetBag)
    EVENT_MANAGER:AddFilterForEvent(XLGearBanker.name .. eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
  else
    EVENT_MANAGER:RegisterForUpdate(XLGearBanker.name .. eventName, XLGB_Banking.itemMoveDelay, lambda)
  end
end

-- local function refreshRecentlyMovedItems(safeModeBefore)
--   XLGB_Banking.recentlyMovedItems = 0
--   sV.safeMode = safeModeBefore
--   EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "RefreshRecentlyMoved")
-- end

-- local function checkMoveEventAndUpdate(eventName, targetBag, lambda, safeModeBefore)
--   if not sV.safeMode and (XLGB_Banking.recentlyMovedItems > sV.threshold) then
--     sV.safeMode = true
--     updateMoveEvent(eventName, targetBag, lambda)
--     EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "RefreshRecentlyMoved")
--     EVENT_MANAGER:RegisterForUpdate(XLGearBanker.name .. "RefreshRecentlyMoved", sV.safeModeDowntime, function () refreshRecentlyMovedItems(safeModeBefore) end)
--   elseif (sV.safeMode ~= safeModeBefore) and (XLGB_Banking.recentlyMovedItems < sV.threshold) then
--     updateMoveEvent(eventName, targetBag, lambda)
--   end
--   -- if XLGB_Banking.swapEvent then
--   --   XLGB_Banking.swapEvent = false
--   --   updateMoveEvent(eventName, targetBag, lambda)
--   -- end
-- end

local function moveGear(sourceBag, itemsToMove, targetBag, availableBagSpaces)
  local nextIndex = 1
  local safeModeBefore = sV.safeMode

  local function _onTargetBagItemReceived(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    -- d("Received item!")
    if XLGB_Banking.isMoveCancelled then
      -- d("Move cancelled!")
      return stopMovingItems()
    end
    if nextIndex > #availableBagSpaces then
      -- d("Not enough spaces!")
      return stopMovingItems()
    end
    if (nextIndex > #itemsToMove) then
      -- d("Bag done!")
      return stopMovingItems()
    end
    -- d("(".. tostring(sourceBag) .. ") Moving item [" .. tostring(nextIndex) .. "/" .. tostring(#itemsToMove) .. "]")
    moveItem(sourceBag, itemsToMove[nextIndex].index, targetBag, availableBagSpaces[nextIndex])
    local itemsLeft = #itemsToMove - nextIndex
    XLGB_Events:OnMoveItem(targetBag, itemsLeft)
    nextIndex = nextIndex + 1
  end

  updateMoveEvent("MoveGear", targetBag, _onTargetBagItemReceived)
  -- d("Source Bag: " .. tostring(sourceBag))
  -- d("ItemsToMove: " .. tostring(#itemsToMove))

  _onTargetBagItemReceived()
end

local function moveGearFromTwoBags(sourceBagOne, itemsToMoveOne, sourceBagTwo, itemsToMoveTwo, targetBag, availableBagSpaces)
  local nextIndex = 1
  local sourceBag = sourceBagOne
  local itemsToMove = itemsToMoveOne
  local availableSpaceOffset = 0
  local safeModeBefore = sV.safeMode

  local function _onTargetBagItemReceived(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    -- d("Received item number " .. tostring(nextIndex-1))
    if XLGB_Banking.isMoveCancelled then
      -- d("Move cancelled!")
      return stopMovingItems()
    end
    if (nextIndex + availableSpaceOffset) > #availableBagSpaces then
      -- d("Not enough space!")
      return stopMovingItems()
    end
    if (nextIndex > #itemsToMove) then

      if sourceBag == sourceBagTwo then
        -- d("Bag 2 done!")
        return stopMovingItems()
      else
        -- d("Bag 1 done! Swapping to bag 2!")
        availableSpaceOffset = #itemsToMove
        sourceBag = sourceBagTwo
        itemsToMove = itemsToMoveTwo
        nextIndex = 1
        return _onTargetBagItemReceived()
      end
    end
    -- d("(".. tostring(sourceBag) .. ") Moving item [" .. tostring(nextIndex) .. "/" .. tostring(#itemsToMove) .. "]")
    moveItem(sourceBag, itemsToMove[nextIndex].index, targetBag, availableBagSpaces[nextIndex + availableSpaceOffset])
    local itemsLeft = #itemsToMove - nextIndex
    XLGB_Events:OnMoveItem(targetBag, itemsLeft)
    nextIndex = nextIndex + 1
  end

  updateMoveEvent("MoveGearFromTwoBags", targetBag, _onTargetBagItemReceived)
  
  -- d("Source Bag 1: " .. tostring(sourceBagOne))
  -- d("ItemsToMove 1: " .. tostring(#itemsToMoveOne))
  -- d("-")
  -- d("Source Bag 2: " .. tostring(sourceBagTwo))
  -- d("ItemsToMove 2: " .. tostring(#itemsToMoveTwo))
  -- d("-")
  -- d("Equipment bag: " .. tostring(BAG_WORN))
  -- d("Backpack bag: " .. tostring(BAG_BACKPACK))
  -- d("-")

  _onTargetBagItemReceived()
end

local function _onNotEnoughSpace(itemsToMove, availableSpaces)
  d("[XLGB_ERROR] Trying to move " .. itemsToMove .. "items into a bag with " .. availableSpaces .." empty slots.")
  XLGB_Banking.spacesNeeded = itemsToMove - availableSpaces
  libDialog:ShowDialog("XLGearBanker", "NotEnoughSpace", nil)
  -- Hack that only shows confirm button
  ZO_Dialog1Button2:SetHidden(true)
  ZO_Dialog1Button1:ClearAnchors()
  ZO_Dialog1Button1:SetAnchor(TOPRIGHT, ZO_Dialog1Button2, TOPLEFT, 120, 0)

  XLGB_Banking.isMoveCancelled = true
end

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--
--
--
--                                        WITHDRAW FUNCTIONS
--
--
--
--------------------------------------------------------------------------------------------

local function withdrawGearESOPlus(gearSet)
  -- d("withdrawGearESOPlus")
  local regularBankItemsToMove = findItemsToMove(BAG_BANK, gearSet.items)
  local ESOPlusItemsToMove = findItemsToMove(BAG_SUBSCRIBER_BANK, gearSet.items)
  local availableBagSpaces = getAvailableBagSpaces(BAG_BACKPACK)
  local numberOfItemsToMove = #regularBankItemsToMove + #ESOPlusItemsToMove
  if (#availableBagSpaces < numberOfItemsToMove) then
    -- d("[XLGB_ERROR] Trying to move " .. numberOfItemsToMove.. "items into a bag with " .. #availableBagSpaces .." empty slots.")
    _onNotEnoughSpace(numberOfItemsToMove, #availableBagSpaces)
    return false
  end
  -- if CheckInventorySpaceAndWarn(numberOfItemsToMove) then
  --   d("[XLGB_ERROR] Trying to move " .. numberOfItemsToMove.. "items into a bag with " .. #availableBagSpaces .." empty slots.")
  --   return false
  -- end
  if numberOfItemsToMove > sV.threshold then
    sV.safeMode = true
  end
  moveGearFromTwoBags(
      BAG_BANK, regularBankItemsToMove,
      BAG_SUBSCRIBER_BANK, ESOPlusItemsToMove,
      BAG_BACKPACK, availableBagSpaces)
  return true
end

local function withdrawItemsNonESOPlus(itemsToWithdraw)
  -- d("withdrawItemsNonESOPlus")
  local itemsToMove = findItemsToMove(XLGB_Banking.currentBankBag, itemsToWithdraw)
  local availableBagSpaces = getAvailableBagSpaces(BAG_BACKPACK)
  if (#availableBagSpaces < #itemsToMove) then
    _onNotEnoughSpace(#itemsToMove, #availableBagSpaces)
    return false
  end
  -- if CheckInventorySpaceAndWarn(#itemsToMove) then
  --   d("[XLGB_ERROR] Trying to move " .. #itemsToMove.. "items into a bag with " .. #availableBagSpaces .." empty slots.")
  --   return false
  -- end
  if #itemsToMove > sV.threshold then
    sV.safeMode = true
  end
  moveGear(XLGB_Banking.currentBankBag, itemsToMove, BAG_BACKPACK, availableBagSpaces)
  return true
end

local function waitForMoveItemEnd(startTime, setName, isWithdrawing)
  -- d("waitForMoveItemEnd")
  local function _waitForEnd()
    if XLGB_Banking.isMovingItems then return end
    local endTime = GetGameTimeMilliseconds()

    local text = ""
    if isWithdrawing then
      text = "withdrawn"
      if not XLGB_Page.isMovingPage then
        XLGB_Events:OnSingleSetWithdrawStop(setName)
      end
    else
      text = "deposited"
      if not XLGB_Page.isMovingPage then
        XLGB_Events:OnSingleSetDepositStop(setName)
      end
    end
    if XLGB_Banking.isMoveCancelled then
      d("[XLGB_ERROR] Movement of '" .. setName .."' got cancelled.")
    else
      d("[XLGB] Set '" .. setName .."' ".. text .." in " .. tostring(string.format("%.2f", (endTime - startTime)/1000)) .. " seconds.")
    end
    EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "waitForMoveItemEnd")
  end
  EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "waitForMoveItemEnd")
  EVENT_MANAGER:RegisterForUpdate(XLGearBanker.name .. "waitForMoveItemEnd", 400, _waitForEnd)
end

function XLGB_Banking:WithdrawSet(gearSetName)
  if not XLGB_Banking.bankOpen then
    d("[XLGB_ERROR] Bank is not open, abort!")
    PlaySound(SOUNDS.ABILITY_FAILED)
    return false
  end

  if XLGB_Banking.isMovingItems then
    d("Already moving")
    return false
  end
  XLGB_Banking.isMovingItems = true
  XLGB_Banking.isMoveCancelled = false
  XLGB_Banking.movesInSuccession = 1
  XLGB_Banking.safeModeBefore = sV.safeMode
  XLGB_Banking.moveSessionId = (XLGB_Banking.moveSessionId or 0) + 1

  local startTime = GetGameTimeMilliseconds()
  if not XLGB_Page.isMovingPage then
    XLGB_Events:OnSingleSetWithdrawStart(gearSetName)
  end

  local gearSet = XLGB_GearSet:FindGearSet(gearSetName)
  if (IsESOPlusSubscriber() and (XLGB_Banking.currentBankBag == BAG_BANK)) then
    if withdrawGearESOPlus(gearSet) then
      PlaySound(SOUNDS.RETRAITING_ITEM_TO_RETRAIT_REMOVED)
      return waitForMoveItemEnd(startTime, gearSetName, true)
    end
  else
    if withdrawItemsNonESOPlus(gearSet.items) then
      PlaySound(SOUNDS.RETRAITING_ITEM_TO_RETRAIT_REMOVED)
      return waitForMoveItemEnd(startTime, gearSetName, true)
    end
  end
  PlaySound(SOUNDS.ABILITY_FAILED)
  XLGB_Banking.isMovingItems = false
  return waitForMoveItemEnd(startTime, gearSetName, true)
end

--------------------------------------------------------------------------------------------
-- WITHDRAW FUNCTIONS END
--------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--
--
--
--                                        DEPOSIT FUNCTIONS
--
--
--
--------------------------------------------------------------------------------------------

local function depositItemsToBankNonESOPlus(itemsToDeposit)
  -- d("depositItemsToBankNonESOPlus")
  local equippedItemsToMove = findItemsToMove(BAG_WORN, itemsToDeposit)
  local inventoryItemsToMove = findItemsToMove(BAG_BACKPACK, itemsToDeposit)

  local availableBagSpaces = getAvailableBagSpaces(XLGB_Banking.currentBankBag)
  local numberOfItemsToMove = #equippedItemsToMove + #inventoryItemsToMove

  if (#availableBagSpaces < numberOfItemsToMove) then
      
      _onNotEnoughSpace(numberOfItemsToMove, #availableBagSpaces)
    return false
  end
  -- if CheckInventorySpaceAndWarn(numberOfItemsToMove) then
  --   return false
  -- end

  if numberOfItemsToMove > sV.threshold then
    sV.safeMode = true
  end

  moveGearFromTwoBags(
      BAG_BACKPACK, inventoryItemsToMove,
      BAG_WORN, equippedItemsToMove,
      XLGB_Banking.currentBankBag, availableBagSpaces)
  return true
end

local function depositGearToBankESOPlus(gearSet)
  -- d("depositGearToBankESOPlus")
  local equippedItemsToMove = findItemsToMove(BAG_WORN, gearSet.items)
  local inventoryItemsToMove = findItemsToMove(BAG_BACKPACK, gearSet.items)

  local availableBagSpacesRegularBank = getAvailableBagSpaces(BAG_BANK)
  local availableBagSpacesESOPlusBank = getAvailableBagSpaces(BAG_SUBSCRIBER_BANK)
  -- 
  local numberOfAvailableSpaces = #availableBagSpacesRegularBank + #availableBagSpacesESOPlusBank
  local numberOfItemsToMove = #equippedItemsToMove + #inventoryItemsToMove

  if (numberOfAvailableSpaces < numberOfItemsToMove) then
    _onNotEnoughSpace(numberOfItemsToMove, numberOfAvailableSpaces)
    return false
  end

  if numberOfItemsToMove > sV.threshold then
    sV.safeMode = true
  end

  if (#availableBagSpacesRegularBank >= numberOfItemsToMove) then
    moveGearFromTwoBags(
        BAG_BACKPACK, inventoryItemsToMove,
        BAG_WORN, equippedItemsToMove,
        BAG_BANK, availableBagSpacesRegularBank)
    return true

  else
    -- Add items to regular bank
    XLGB_Banking.isWaitingForBag = true
    XLGB_Banking.movesInSuccession = 2

    moveGearFromTwoBags(
        BAG_BACKPACK, inventoryItemsToMove,
        BAG_WORN, equippedItemsToMove,
        BAG_BANK, availableBagSpacesRegularBank)

    local function _waitForBag()
      -- d("Waiting for bag to finish...")
      if XLGB_Banking.isWaitingForBag then return end
      -- d("-")
      -- d("-")
      -- d("Starting 2nd bank bag ------------")
      -- d("-")
      -- d("-")
      inventoryItemsToMove = findItemsToMove(BAG_BACKPACK, gearSet.items)
      equippedItemsToMove = findItemsToMove(BAG_WORN, gearSet.items)

      moveGearFromTwoBags(
          BAG_BACKPACK, inventoryItemsToMove,
          BAG_WORN, equippedItemsToMove,
          BAG_SUBSCRIBER_BANK, availableBagSpacesESOPlusBank)

      EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "isWaitingForBag")
    end

    EVENT_MANAGER:UnregisterForUpdate(XLGearBanker.name .. "isWaitingForBag")
    EVENT_MANAGER:RegisterForUpdate(XLGearBanker.name .. "isWaitingForBag", 500, _waitForBag)

    return true
  end
end

function XLGB_Banking:DepositSet(gearSetName)
  if not XLGB_Banking.bankOpen then
    d("[XLGB_ERROR] Bank is not open, abort!")
    PlaySound(SOUNDS.ABILITY_FAILED)
    return false
  end

  if XLGB_Banking.isMovingItems then
    d("Already moving")
    return false
  end
  XLGB_Banking.isMovingItems = true
  XLGB_Banking.isMoveCancelled = false
  XLGB_Banking.movesInSuccession = 1
  XLGB_Banking.safeModeBefore = sV.safeMode
  XLGB_Banking.moveSessionId = (XLGB_Banking.moveSessionId or 0) + 1

  local startTime = GetGameTimeMilliseconds()
  if not XLGB_Page.isMovingPage then
    XLGB_Events:OnSingleSetDepositStart(gearSetName)
  end

  local gearSet = XLGB_GearSet:FindGearSet(gearSetName)
  if IsESOPlusSubscriber() and (XLGB_Banking.currentBankBag == BAG_BANK) then
    if depositGearToBankESOPlus(gearSet) then
      PlaySound(SOUNDS.INVENTORY_ITEM_UNLOCKED)
      return waitForMoveItemEnd(startTime, gearSetName, false)
    end
  else
    if depositItemsToBankNonESOPlus(gearSet.items) then
      PlaySound(SOUNDS.INVENTORY_ITEM_UNLOCKED)
      return waitForMoveItemEnd(startTime, gearSetName, false)
    end
  end
  PlaySound(SOUNDS.ABILITY_FAILED)
  XLGB_Banking.isMovingItems = false
  return waitForMoveItemEnd(startTime, gearSetName, false)
end

--------------------------------------------------------------------------------------------
-- DEPOSIT FUNCTIONS END
--------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--
--
--
--                                        INITIALIZATION
--
--
--
--------------------------------------------------------------------------------------------

local function printSpacesNeeded()
  return XLGB_Banking.spacesNeeded 
end

function XLGB_Banking:Initialize()
  sV = XLGearBanker.savedVariables
  self.bankOpen = IsBankOpen()
  self.isMoveCancelled = false
  self.isMovingItems = false
  self.isWaitingForBag = false
  self.itemMoveDelay = 0
  self.movesInSuccession = 0
  self.spacesNeeded = 0
  -- How long to wait before retrying a move whose target slot briefly still looks occupied
  -- (server desync), and how many times to retry before actually giving up on that item.
  self.moveRetryDelay = 300
  self.maxMoveRetries = 3
  -- Bumped every time a new withdraw/deposit operation starts, so a delayed retry from an
  -- older, already-finished operation can recognize it's stale and no-op instead of
  -- corrupting a newer operation's bookkeeping.
  self.moveSessionId = 0
  self.dialogMoveText = "deposit"

  -- self.swapEvent = false
  -- self.recentlyMovedItems = 0
  -- self.safeModeBefore = sV.safeMode

  self.bankButtonGroup = {
    {
      name = "Toggle XLGB UI",
      keybind = "TOGGLE_XLGB_UI",
      callback = function() XLGB_UI:TogglePageUI() end,
    },
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
  }

  libDialog:RegisterDialog(
    "XLGearBanker", 
    "NotEnoughSpace", 
    "XL Gear Banker", 
    "Not enough bagspace.",
    function() -- reverse the hack that only shows confirm button
      ZO_Dialog1Button2:SetHidden(false)
      ZO_Dialog1Button1:ClearAnchors()
      ZO_Dialog1Button1:SetAnchor(TOPRIGHT, ZO_Dialog1Button2, TOPLEFT, -30, 0) 
    end,
    nil,
    nil)

    --libDialog:RegisterDialog("YourAddonName", 
      -- "DialogNameConfirmation1", 
      -- "Title of the dialog", 
      -- "Body text of the dialog.\n\nAre you sure?", 
      -- callbackYes, 
      -- callbackNo, 
      -- callbackSetup, 
      -- forceUpdate, 
      -- additionalOptions,
      -- textParams)

  EVENT_MANAGER:RegisterForEvent(self.name, EVENT_OPEN_BANK, self.OnBankOpenEvent)
  EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CLOSE_BANK, self.OnBankCloseEvent)
end