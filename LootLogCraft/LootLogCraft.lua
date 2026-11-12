-- LootLogCraft
--
-- Logs the materials you get back from refining raw materials and from
-- deconstructing gear at a crafting station (blacksmithing, clothier,
-- woodworking, jewelrycrafting - including the universal "deconstruct all"
-- assistant, which is just another source of the same calls below).
--
-- LootLog only listens for EVENT_LOOT_RECEIVED, which never fires for
-- crafting-station results, so none of this is logged today.
--
-- There is no per-item result event for this (same fundamental problem as
-- mail): refine and deconstruct are actually the SAME engine call -
-- PrepareDeconstructMessage() / AddItemToDeconstructMessage(bagId,
-- slotIndex, quantity) / SendDeconstructMessage() - differing only in
-- which inventory filter tab was active when the items were queued, and
-- completion is signaled generically by EVENT_CRAFT_COMPLETED(event,
-- station) with no item data at all. So: wrap those three (real, global)
-- functions to snapshot what we own right before the message is sent,
-- then diff against what we own once things settle.
--
-- Refine-vs-deconstruct is decided via CanItemBeRefined(bagId, slotIndex,
-- GetCraftingInteractionType()) on the first queued item - the same
-- predicate the real panel uses - rather than guessing from item type.
--
-- "From refining" also reports how many raw materials went in (summed
-- from the `quantity` argument of every AddItemToDeconstructMessage call
-- in the batch) - this is the input count, not the output count, since
-- refining isn't 1:1.
--
-- "What we own" has to include the Craft Bag (BAG_VIRTUAL), not just the
-- backpack (BAG_BACKPACK) - with ESO Plus active, refined/raw materials
-- route straight into the Craft Bag instead of the backpack. The Craft
-- Bag isn't a normal slot-indexed bag, but ZO_IterateBagSlots(bagId) is
-- the engine's own generic per-bag iterator (confirmed from the base
-- game's own SharedInventory code, which uses exactly this to populate
-- its bag caches for every bag type, BAG_VIRTUAL included) so the same
-- scan works for both bags unchanged. Without ESO Plus, BAG_VIRTUAL is
-- just always empty and costs nothing.
--
-- Debounce note: it isn't confirmed whether a single big batch (e.g.
-- refining a large stack in one action, or "deconstruct all" on many
-- items) settles behind one EVENT_CRAFT_COMPLETED firing or several in
-- sequence. Rather than assume either way, every firing while a batch is
-- pending just pushes the "read the final result" check back by
-- DEBOUNCE_MS; we only diff once things have gone quiet, so a multi-tick
-- batch is handled correctly either way at the cost of a short delay
-- before it shows up in LootLog.

local ADDON_NAME = "LootLogCraft"
local DEBOUNCE_NAME = ADDON_NAME .. "Debounce"
local DEBOUNCE_MS = 500

-- Whether the current batch is a refine, decided from the first item
-- queued into it. nil until the first AddItemToDeconstructMessage call of
-- the batch sets it, reset to nil each time a new message is prepared.
local pendingIsRefine = nil

-- Sum of the `quantity` argument across every successful
-- AddItemToDeconstructMessage call in the current batch - i.e. how many
-- raw materials are being fed in. Reset alongside pendingIsRefine.
local pendingQueuedQuantity = 0

-- { isRefine = bool, queuedQuantity = n, before = { [itemLink] = totalCount, ... } } or nil
local pendingSnapshot = nil

-- Wrapped in pcall per-bag: if BAG_VIRTUAL (the Craft Bag) turns out not to
-- support this kind of scan the way BAG_BACKPACK does, we want a visible
-- diagnostic in chat rather than a silently wrong/empty result.
local function ScanBagSafely( snapshot, bagId )
	local ok, err = pcall(function()
		for slotIndex in ZO_IterateBagSlots(bagId) do
			local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
			if (itemLink and itemLink ~= "") then
				local _, stackCount = GetItemInfo(bagId, slotIndex)
				if (stackCount and stackCount > 0) then
					snapshot[itemLink] = (snapshot[itemLink] or 0) + stackCount
				end
			end
		end
	end)

	if (not ok) then
		LootLog.Msg(string.format("LootLogCraft: couldn't scan bag %s (%s)", tostring(bagId), tostring(err)))
	end
end

local function SnapshotOwnedMaterials()
	local snapshot = {}

	ScanBagSafely(snapshot, BAG_BACKPACK)
	ScanBagSafely(snapshot, BAG_VIRTUAL)

	return snapshot
end

-- LootLog.LogItem's own chat line for an item is gated by LootLog.vars.chatMode,
-- independent of our own note below. For items we've already named in our
-- note, that would mean the same item printed twice whenever chatMode
-- happens to also cover it. Rather than predict chatMode (the same kind of
-- guesswork that got refine-vs-decon detection wrong once already), force
-- it off for just this one call - history/Mats/etc. are untouched, only
-- LogItem's own "if (...) LootLog.Msg(...)" branch is skipped - then
-- restore it immediately, even if LogItem errors.
local function LogItemWithoutDuplicateChat( itemLink, quantity, notable )
	local savedChatMode = LootLog.vars.chatMode
	LootLog.vars.chatMode = 0

	local ok, err = pcall(LootLog.LogItem, itemLink, quantity, notable, nil)

	LootLog.vars.chatMode = savedChatMode

	if (not ok) then
		LootLog.Msg(string.format("LootLogCraft: LogItem error: %s", tostring(err)))
	end
end

-- Not expected to matter here - refining and deconstructing gear doesn't
-- hand back recipes/motifs/furnishing plans/scribing scripts - but kept
-- in lockstep with LootLogMail's fix for the same symptom (an unknown
-- recipe/motif failing LootLog.IsItemNotable's generic quality-threshold
-- check because functional quality, not display color, is what that
-- check looks at) in case that assumption is ever wrong, or any of this
-- gets reused for a future source that does produce them. Additive to
-- LootLog's own check; a no-op if LibCharacterKnowledge isn't installed.
local function IsItemNotableExtended( itemLink )
	local ok, notable = pcall(LootLog.IsItemNotable, itemLink)
	if (not ok) then
		LootLog.Msg(string.format("LootLogCraft: IsItemNotable error: %s", tostring(notable)))
		notable = false
	end

	if (not notable and LibCharacterKnowledge) then
		local ok2, unknown = pcall(function()
			local category = LibCharacterKnowledge.GetItemCategory(itemLink)
			if (category == LibCharacterKnowledge.ITEM_CATEGORY_NONE) then return false end
			return LibCharacterKnowledge.GetItemKnowledgeForCharacter(itemLink) ~= LibCharacterKnowledge.KNOWLEDGE_KNOWN
		end)
		if (ok2 and unknown) then notable = true end
	end

	return notable
end

local function FinalizePendingCraft()
	EVENT_MANAGER:UnregisterForUpdate(DEBOUNCE_NAME)

	if (not pendingSnapshot) then return end

	local snapshot = pendingSnapshot
	pendingSnapshot = nil

	local after = SnapshotOwnedMaterials()

	-- Same rule as LootLogMail: every material gained still gets logged
	-- into history regardless (same as any other personal loot), but the
	-- "From refining/deconstruction:" chat note only shows up when
	-- something in the batch is actually notable, so routine refining
	-- doesn't spam a header for nothing.
	local gains = {}
	local anyNotable = false

	for itemLink, afterCount in pairs(after) do
		local delta = afterCount - (snapshot.before[itemLink] or 0)
		if (delta > 0) then
			local notable = IsItemNotableExtended(itemLink)
			table.insert(gains, { itemLink = itemLink, delta = delta, notable = notable })
			if (notable) then anyNotable = true end
		end
	end

	if (anyNotable) then
		-- Whether LootLog.LogItem below also prints its own chat line
		-- depends on the user's chatMode setting, which this note doesn't
		-- control and shouldn't try to predict (that's the same kind of
		-- guesswork that got refine-vs-decon detection wrong once
		-- already). So this note names the notable items itself, directly,
		-- rather than being a teaser that can end up with nothing visibly
		-- following it.
		local parts = {}
		for _, gain in ipairs(gains) do
			if (gain.notable) then
				table.insert(parts, string.format("%s x%d", gain.itemLink, gain.delta))
			end
		end
		local header
		if (snapshot.isRefine) then
			-- queuedQuantity is how many raw materials went INTO the
			-- refine, not how many of the gains above came out - those are
			-- two different numbers (refining doesn't convert 1:1).
			header = string.format("From refining %d raw material%s:", snapshot.queuedQuantity, (snapshot.queuedQuantity == 1) and "" or "s")
		else
			header = "From deconstruction:"
		end

		LootLog.Msg(string.format("%s %s", header, table.concat(parts, ", ")))
	end

	for _, gain in ipairs(gains) do
		if (gain.notable) then
			-- Already named above - suppress LogItem's own duplicate line.
			LogItemWithoutDuplicateChat(gain.itemLink, gain.delta, gain.notable)
		else
			-- Not mentioned in our note, so leave the user's own chatMode
			-- setting (e.g. "show everything") in control of this one.
			LootLog.LogItem(gain.itemLink, gain.delta, gain.notable, nil)
		end
	end
end

local function OnCraftCompleted( eventCode, station )
	if (not pendingSnapshot) then return end

	-- Push the "it's settled" check back rather than reading immediately,
	-- in case this is one of several firings for the same batch.
	EVENT_MANAGER:RegisterForUpdate(DEBOUNCE_NAME, DEBOUNCE_MS, FinalizePendingCraft)
end

-- These three are ordinary global API functions (same trick LootLogFishing
-- uses on LootLog.IsItemNotable), always available regardless of addon
-- load order, so they're wrapped immediately rather than waiting for
-- EVENT_ADD_ON_LOADED.

local originalPrepareDeconstructMessage = PrepareDeconstructMessage
PrepareDeconstructMessage = function( ... )
	pendingIsRefine = nil
	pendingQueuedQuantity = 0
	return originalPrepareDeconstructMessage(...)
end

local originalAddItemToDeconstructMessage = AddItemToDeconstructMessage
AddItemToDeconstructMessage = function( bagId, slotIndex, quantity )
	local added = originalAddItemToDeconstructMessage(bagId, slotIndex, quantity)
	if (added) then
		pendingQueuedQuantity = pendingQueuedQuantity + (quantity or 0)
		if (pendingIsRefine == nil) then
			-- This is the exact predicate the real refinement/deconstruction
			-- panel uses (ZO_SharedSmithingExtraction_IsRefinableItem) to
			-- decide which filter tab an item belongs to - much more reliable
			-- than guessing from the item's type.
			pendingIsRefine = CanItemBeRefined(bagId, slotIndex, GetCraftingInteractionType())
		end
	end
	return added
end

local originalSendDeconstructMessage = SendDeconstructMessage
SendDeconstructMessage = function( ... )
	pendingSnapshot = { isRefine = (pendingIsRefine == true), queuedQuantity = pendingQueuedQuantity, before = SnapshotOwnedMaterials() }

	return originalSendDeconstructMessage(...)
end

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= ADDON_NAME) then return end

	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
