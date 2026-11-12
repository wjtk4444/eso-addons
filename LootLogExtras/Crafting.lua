-- Crafting stations: materials received from refining and from deconstruction
-- (blacksmithing, clothing, woodworking, jewelry crafting, including the deconstruction
-- assistant, which goes through the same calls).
--
-- LootLog only listens to EVENT_LOOT_RECEIVED, which never fires for crafting results,
-- and there is no per-item result event. Refining and deconstructing are the same engine
-- call: PrepareDeconstructMessage / AddItemToDeconstructMessage / SendDeconstructMessage,
-- and completion is EVENT_CRAFT_COMPLETED without any item data. So the bags are
-- snapshotted right before the message is sent and diffed once things settle.
--
-- It is not known whether a big batch completes with one EVENT_CRAFT_COMPLETED or several,
-- so every completion pushes the final diff back by DEBOUNCE_MS.
--
-- Unlike mail, every gained material is written to the history (as LootLog does for loot);
-- the chat note only appears when something in the batch is notable.

local LLE = LootLogExtras
local DEBOUNCE_NAME = LLE.ADDON_NAME .. "CraftDebounce"

-- Current batch, filled while items are queued.
local batchIsRefine = nil      -- decided from the first queued item
local batchQueuedQuantity = 0  -- raw materials going in (refining is not 1:1)

-- { isRefine, queuedQuantity, before = snapshot } between Send and the final diff.
local pending = nil

local function FinalizeCraft()
    EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)
    if not pending then return end

    local batch = pending
    pending = nil

    local gains = LLE.DiffSnapshots(batch.before, LLE.SnapshotOwnedItems())
    local notableText = LLE.DescribeNotable(gains)

    if notableText then
        local header
        if batch.isRefine then
            header = string.format("From refining %d raw material%s:", batch.queuedQuantity, batch.queuedQuantity == 1 and "" or "s")
        else
            header = "From deconstruction:"
        end
        LootLog.Msg(header .. " " .. notableText)
    end

    for _, gain in ipairs(gains) do
        if gain.notable then
            LLE.LogItemQuietly(gain.itemLink, gain.quantity, true) -- already named in the note
        else
            LootLog.LogItem(gain.itemLink, gain.quantity, false, nil) -- LootLog's chat mode decides
        end
    end
end

local function OnCraftCompleted()
    if pending then
        EVENT_MANAGER:RegisterForUpdate(DEBOUNCE_NAME, LLE.DEBOUNCE_MS, FinalizeCraft)
    end
end

-- Plain global API functions, wrapped right away so the wrap is in place whatever the load order.

local originalPrepare = PrepareDeconstructMessage
PrepareDeconstructMessage = function(...)
    batchIsRefine = nil
    batchQueuedQuantity = 0
    return originalPrepare(...)
end

local originalAddItem = AddItemToDeconstructMessage
AddItemToDeconstructMessage = function(bagId, slotIndex, quantity)
    local added = originalAddItem(bagId, slotIndex, quantity)
    if added then
        batchQueuedQuantity = batchQueuedQuantity + (quantity or 0)
        if batchIsRefine == nil then
            -- The same check the refinement panel uses to put an item on the Refine tab.
            batchIsRefine = CanItemBeRefined(bagId, slotIndex, GetCraftingInteractionType())
        end
    end
    return added
end

local originalSend = SendDeconstructMessage
SendDeconstructMessage = function(...)
    if LLE.IsEnabled("logCrafting") then
        pending = { isRefine = batchIsRefine == true, queuedQuantity = batchQueuedQuantity, before = LLE.SnapshotOwnedItems() }
    end
    return originalSend(...)
end

function LLE.InitializeCrafting()
    EVENT_MANAGER:RegisterForEvent(LLE.ADDON_NAME .. "Craft", EVENT_CRAFT_COMPLETED, OnCraftCompleted)
end
