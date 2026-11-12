local furnitureConfig = {
	furnitureId = "4827049023113930771", 
	default = { x = 19706, y = 20681, z = 24077, pitch = -0, yaw = 1.7807599306107, roll = 0 },
	a =       { x = 20038, y = 20691, z = 25107, pitch = 0, yaw = 2.911687374115, roll = 0.0019174759509042 },
	b =       { x = 19975, y = 20689, z = 25305, pitch = -1.3271842362883e-05, yaw = 2.8862040042877, roll = 0.0018269348656759 },
}

local animDelay = 55
local animStep = 2

local doorConfig = {
	furnitureId = "4827049023114654549",
	name = "Telvanni Door, Round",
}

local function MoveFurniture(id, pos, rot)
	return HousingEditorRequestChangePositionAndOrientation(id, pos.x, pos.y, pos.z, rot.pitch, rot.yaw, rot.roll)
end

local function AnimFurniture(id, from, to, callback)
	local dx = to.x - from.x
	local dy = to.y - from.y
	local dz = to.z - from.z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	local numSteps = math.max(1, math.ceil(dist / animStep))
	local sx, sy, sz = dx / numSteps, dy / numSteps, dz / numSteps

	for i = 1, numSteps do
		zo_callLater(function()
			HousingEditorRequestChangePosition(id, from.x + sx * i, from.y + sy * i, from.z + sz * i)
		end, i * animDelay)
	end

	zo_callLater(function()
		HousingEditorRequestChangePosition(id, to.x, to.y, to.z)
		if callback then callback() end
	end, (numSteps + 1) * animDelay)

	return (numSteps + 2) * animDelay
end

local function RunSnugpodMagic(callback)
	local cfg = furnitureConfig
	local id = StringToId64(cfg.furnitureId)
	local result = MoveFurniture(id, cfg.a, cfg.a)
	if result == HOUSING_REQUEST_RESULT_ALREADY_BEING_MOVED then
		return result
	end
	AnimFurniture(id, cfg.a, cfg.b, function()
		MoveFurniture(id, cfg.default, cfg.default)
		if callback then callback() end
	end)
	return result
end

-- Door trigger: local player opens door -> wait 1s -> animation -> wait 1s -> close door
local doorBusy = false

EVENT_MANAGER:RegisterForEvent("EssentialSnugpodTools", EVENT_HOUSING_FURNITURE_STATE_CHANGED, function(event, furnitureId, newStateIndex, oldStateIndex)
	if doorBusy then return end
	if Id64ToString(furnitureId) ~= doorConfig.furnitureId then return end
	if newStateIndex ~= 2 then return end

	local px, py, pz = GetPlayerWorldPositionInHouse()
	local dx, dy, dz = HousingEditorGetFurnitureWorldPosition(furnitureId)
	if not dx then return end
	local dist = math.sqrt((px - dx) ^ 2 + (py - dy) ^ 2 + (pz - dz) ^ 2)
	if dist > 150 then return end

	doorBusy = true
	zo_callLater(function()
		local result = RunSnugpodMagic(function()
			zo_callLater(function()
				HousingEditorRequestChangeState(StringToId64(doorConfig.furnitureId), 0)
				zo_callLater(function() doorBusy = false end, 2000)
			end, 1000)
		end)
		if result == HOUSING_REQUEST_RESULT_ALREADY_BEING_MOVED then
			doorBusy = false
		end
	end, 1000)
end)

-- =============================================
-- Assistant Summon / Dismiss
-- =============================================

-- /script for id=1,50000 do if GetCollectibleCategoryType(id)==COLLECTIBLE_CATEGORY_TYPE_ASSISTANT then d(id.." - "..GetCollectibleName(id)) end end

local ASSISTANTS = {
	-- Bankers
	[267]  = { name = "Tythis the Banker", category = "banker" },
	[6376] = { name = "Ezabi the Banker", category = "banker" },
	[8994] = { name = "Baron Jangleplume", category = "banker" },
	[9743] = { name = "Factotum Property Steward", category = "banker" },
	[12413] = { name = "Eri, Barking Banker", category = "banker" },
	[13517] = { name = "Celia Tyde, Lost Fleet Bursar", category = "banker" },
	-- Merchants
	[301]  = { name = "Nuzhimeh the Merchant", category = "merchant" },
	[6378] = { name = "Fezez the Merchant", category = "merchant" },
	[8995] = { name = "Peddler of Prizes", category = "merchant" },
	[9744] = { name = "Factotum Commerce Delegate", category = "merchant" },
	[396]  = { name = "Allaria Erwen the Exporter", category = "merchant" },
	[397]  = { name = "Cassus Andronicus the Mercenary", category = "merchant" },
	[11059] = { name = "Hoarfrost, Takubar Trader", category = "merchant" },
	[13063] = { name = "Siluruz, Realm Craftsmaster", category = "merchant" },
	[13066] = { name = "Terilorne, Dibellan Freetrader", category = "merchant" },
	[14204] = { name = "Cambio Zammes, Rooster in Exile", category = "merchant" },
	-- Deconstruction
	[10184] = { name = "Giladil the Ragpicker", category = "deconstructor" },
	[10617] = { name = "Adarene, Fargrave Dregs Dealer", category = "deconstructor" },
	[11097] = { name = "Pyroclast, Infernace Conservator", category = "deconstructor" },
	[11877] = { name = "Tzozabrar, Dwarven Deconstructor", category = "deconstructor" },
	[12414] = { name = "Xyn, Planar Purveyor", category = "deconstructor" },
	[14018] = { name = "Pontius Remus, Lupine Scavenger", category = "deconstructor" },
	-- Smuggling
	[300]  = { name = "Pirharri the Smuggler", category = "smuggler" },
	-- Armory
	[9745] = { name = "Ghrasharog, Armory", category = "armorer" },
	[10618] = { name = "Zuqoth, Armory Advisor", category = "armorer" },
	[11876] = { name = "Drinweth, Valenwood Armorer", category = "armorer" },
	[13518] = { name = "Voko, Carnaval Weapondancer", category = "armorer" },
}

local summoned = {}
local cooldownTime = 0

local function ParseCollectibleIdFromLink(link)
	if type(link) ~= "string" then return nil end
	local id = tonumber(string.sub(link, 17, -5))
	return id
end

local function FormatHousingResult(result)
	if result == HOUSING_REQUEST_RESULT_SUCCESS then return ""
	elseif result == HOUSING_REQUEST_RESULT_PERMISSION_FAILED then return "Insufficient permissions."
	elseif result == HOUSING_REQUEST_RESULT_NO_SUCH_FURNITURE then return "Furniture not found."
	elseif result == HOUSING_REQUEST_RESULT_PLACE_FAILED then return "Over furnishing limit."
	elseif result == HOUSING_REQUEST_RESULT_MOVE_FAILED then return "Move failed."
	elseif result == HOUSING_REQUEST_RESULT_ALREADY_BEING_MOVED then return "Already being moved."
	elseif result == HOUSING_REQUEST_RESULT_REQUEST_IN_PROGRESS then return "Request in progress."
	elseif result == HOUSING_REQUEST_RESULT_NOT_IN_HOUSE then return "Not in a house."
	elseif result == HOUSING_REQUEST_RESULT_IN_COMBAT then return "In combat."
	elseif result == HOUSING_REQUEST_RESULT_HIGH_IMPACT_COLLECTIBLE_PLACE_LIMIT then return "Over furnishing limit."
	else return "Error " .. tostring(result) .. "." end
end

local function FindFurnitureIdForCollectible(collectibleId)
	local fid = GetNextPlacedHousingFurnitureId()
	while fid do
		local cid = GetCollectibleIdFromFurnitureId(fid)
		if cid and cid == collectibleId then
			return fid
		end
		fid = GetNextPlacedHousingFurnitureId(fid)
	end
	return nil
end

local function FindFurnitureIdForCategory(category)
	local fid = GetNextPlacedHousingFurnitureId()
	while fid do
		local cid = GetCollectibleIdFromFurnitureId(fid)
		if cid then
			local info = ASSISTANTS[cid]
			if info and info.category == category then
				return fid, cid
			end
		end
		local nextFid = GetNextPlacedHousingFurnitureId(fid)
		if nextFid == fid then break end
		fid = nextFid
	end
	for cid, info in pairs(ASSISTANTS) do
		if info.category == category then
			local f = GetFurnitureIdFromCollectibleId(cid)
			if f and f ~= 0 and f == f then
				return f, cid
			end
		end
	end
	return nil, nil
end

local function DoSummonDismiss(link)
	if GetCurrentZoneHouseId() == 0 then return false end

	local collectibleId = ParseCollectibleIdFromLink(link)
	if not collectibleId then return false end

	if collectibleId == 8006 then
		local wellId
		local fid = GetNextPlacedHousingFurnitureId()
		while fid do
			local name, _, _ = GetPlacedHousingFurnitureInfo(fid)
			if name == "Aetherial Well" then
				wellId = fid
				break
			end
			local nextFid = GetNextPlacedHousingFurnitureId(fid)
			if nextFid == fid then break end
			fid = nextFid
		end
		if not wellId then d("Aetherial Well not found in this house.") return true end
		local saved = summoned["well"]
		if not saved then
			local ox, oy, oz = HousingEditorGetFurnitureWorldPosition(wellId)
			local opitch, oyaw, oroll = HousingEditorGetFurnitureOrientation(wellId)
			summoned["well"] = { x = ox, y = oy, z = oz, pitch = opitch, yaw = oyaw, roll = oroll }
			local px, py, pz, pyaw = GetPlayerWorldPositionInHouse()
			local sx = px - math.sin(pyaw) * 200
			local sz = pz - math.cos(pyaw) * 200
			local syaw = (pyaw + math.pi) % (2 * math.pi)
			local result = HousingEditorRequestChangePositionAndOrientation(wellId, sx, py, sz, 0, syaw, 0)
			if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
				summoned["well"] = nil
				d("Failed to summon Aetherial Well. " .. FormatHousingResult(result))
			else
				d("Summoning Aetherial Well.")
			end
		else
			local result = HousingEditorRequestChangePositionAndOrientation(wellId, saved.x, saved.y, saved.z, saved.pitch, saved.yaw, saved.roll)
			if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
				d("Failed to desummon Aetherial Well. " .. FormatHousingResult(result))
			else
				d("Desummoning Aetherial Well.")
				summoned["well"] = nil
			end
		end
		return true
	end

	local info = ASSISTANTS[collectibleId]
	if not info then return false end

	local category = info.category
	local name = info.name
	local saved = summoned[category]

	if not saved then
		local px, py, pz, pyaw = GetPlayerWorldPositionInHouse()
		local sx = px - math.sin(pyaw) * 200
		local sz = pz - math.cos(pyaw) * 200
		local syaw = (pyaw + math.pi) % (2 * math.pi)

		local fid, foundCid = FindFurnitureIdForCategory(category)

		if fid then
			local ox, oy, oz = HousingEditorGetFurnitureWorldPosition(fid)
			local opitch, oyaw, oroll = HousingEditorGetFurnitureOrientation(fid)
			summoned[category] = { collectibleId = foundCid, x = ox, y = oy, z = oz, pitch = opitch, yaw = oyaw, roll = oroll }
			local result = HousingEditorRequestChangePositionAndOrientation(fid, sx, py, sz, 0, syaw, 0)
			if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
				summoned[category] = nil
				d("Failed to summon " .. category .. ". " .. FormatHousingResult(result))
			else
				d("Summoning " .. category .. ".")
			end
			return true
		end

		if not IsOwnerOfCurrentHouse() then
			d("No " .. category .. " assistant found. Cannot place assistants outside of your own house.")
			return false
		end

		d("Placing " .. category .. ".")
		local result = HousingEditorRequestCollectiblePlacement(collectibleId, sx, py, sz, 0, syaw, 0)
		if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
			d("Failed to place " .. category .. ". " .. FormatHousingResult(result))
			return false
		end

		zo_callLater(function()
			local fid2, cid2 = FindFurnitureIdForCategory(category)
			if not fid2 then
				d("Failed to place " .. category .. ". Not found after placement.")
				return
			end
			local ox, oy, oz = HousingEditorGetFurnitureWorldPosition(fid2)
			local opitch, oyaw, oroll = HousingEditorGetFurnitureOrientation(fid2)
			summoned[category] = { collectibleId = cid2, x = ox, y = oy, z = oz, pitch = opitch, yaw = oyaw, roll = oroll, autoPlaced = true }
		end, 500)
	else
		local fid = FindFurnitureIdForCollectible(saved.collectibleId)
		if not fid then
			summoned[category] = nil
			return true
		end

		if saved.autoPlaced then
			d("Removing " .. category .. ".")
			local result = HousingEditorRequestRemoveFurniture(fid)
			if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
				d("Failed to remove " .. category .. ". " .. FormatHousingResult(result))
			else
				summoned[category] = nil
			end
		else
			d("Desummoning " .. category .. ".")
			local result = HousingEditorRequestChangePositionAndOrientation(fid, saved.x, saved.y, saved.z, saved.pitch, saved.yaw, saved.roll)
			if result ~= HOUSING_REQUEST_RESULT_SUCCESS then
				d("Failed to desummon " .. category .. ". " .. FormatHousingResult(result))
			else
				summoned[category] = nil
			end
		end
	end

	return true
end

local function OnQuickslotRelease(button)
	if GetCurrentZoneHouseId() == 0 then return false end

	local slotIndex = button:GetSlot()
	local hotbarCategory = button:GetHotbarCategory()
	local link = GetSlotItemLink(slotIndex, hotbarCategory)

	if link == "" then return false end

	local frameTime = GetFrameTimeSeconds()
	if cooldownTime >= frameTime then return true end

	local handled = DoSummonDismiss(link)
	if handled then
		cooldownTime = frameTime + 2
	end
	return handled
end

ZO_PreHook(QuickslotActionButton, "OnRelease", OnQuickslotRelease)

-- =============================================
-- Storage Chests
-- =============================================

local CHEST_LARGE = {
	[4674] = "Storage Chest, Fortified",
	[4678] = "Storage Chest, Oaken",
	[4679] = "Storage Chest, Secure",
	[4680] = "Storage Chest, Sturdy",
}

local CHEST_SMALL = {
	[4673] = "Storage Coffer, Fortified",
	[4675] = "Storage Coffer, Oaken",
	[4676] = "Storage Coffer, Secure",
	[4677] = "Storage Coffer, Sturdy",
}

local STORAGE_IDS = {}
for k, v in pairs(CHEST_LARGE) do STORAGE_IDS[k] = v end
for k, v in pairs(CHEST_SMALL) do STORAGE_IDS[k] = v end

local storageState = {}

local function FindAllStorageChests()
	local chests = {}
	local fid = GetNextPlacedHousingFurnitureId()
	while fid do
		local cid = GetCollectibleIdFromFurnitureId(fid)
		if cid and STORAGE_IDS[cid] then
			table.insert(chests, { fid = fid, cid = cid })
		end
		local nextFid = GetNextPlacedHousingFurnitureId(fid)
		if nextFid == fid then break end
		fid = nextFid
	end
	return chests
end

SLASH_COMMANDS['/storage'] = function(args)
	if GetCurrentZoneHouseId() == 0 then d("You must be in a house to use this command.") return end

	if args == "magic" then
		RunSnugpodMagic(function() d("Snugpod magic complete!") end)
		return
	end

	if args == "selected" then
		local id = HousingEditorGetSelectedFurnitureId()
		if not id then d("No furniture selected.") return end
		local x, y, z = HousingEditorGetFurnitureWorldPosition(id)
		local pitch, yaw, roll = HousingEditorGetFurnitureOrientation(id)
		d("-- furnitureId:")
		d('"' .. Id64ToString(id) .. '",')
		d("-- default / a / b:")
		d("{ x = " .. x .. ", y = " .. y .. ", z = " .. z .. ", pitch = " .. pitch .. ", yaw = " .. yaw .. ", roll = " .. roll .. " },")
		return
	end

	if args ~= "" and args ~= nil then
		d("Usage: /storage, /storage magic, /storage selected")
		return
	end

	if next(storageState) then
		local count = 0
		for cid, saved in pairs(storageState) do
			HousingEditorRequestChangePositionAndOrientation(saved.fid, saved.x, saved.y, saved.z, saved.pitch, saved.yaw, saved.roll)
			count = count + 1
		end
		if count > 0 then
			d("Sending " .. count .. " storage back.")
			storageState = {}
		end
		return
	end

	local px, py, pz, pyaw = GetPlayerWorldPositionInHouse()

	local chests = FindAllStorageChests()
	if #chests == 0 then
		d("No storage chests found. " .. FormatHousingResult(HOUSING_REQUEST_RESULT_PLACE_FAILED))
		return
	end

	table.sort(chests, function(a, b)
		if CHEST_LARGE[a.cid] and not CHEST_LARGE[b.cid] then return false end
		if not CHEST_LARGE[a.cid] and CHEST_LARGE[b.cid] then return true end
		return false
	end)

	local placed = 0
	local dist = 200
	local hSpacing = 165
	local rowSpacing = 120

	for i, chest in ipairs(chests) do
		local ox, oy, oz = HousingEditorGetFurnitureWorldPosition(chest.fid)
		local opitch, oyaw, oroll = HousingEditorGetFurnitureOrientation(chest.fid)
		storageState[chest.cid] = { fid = chest.fid, x = ox, y = oy, z = oz, pitch = opitch, yaw = oyaw, roll = oroll }

		local row = math.floor((i - 1) / 4)
		local col = (i - 1) % 4
		local hx = (col - 1.5) * hSpacing
		local hz = row * rowSpacing

		local sx = px - math.sin(pyaw) * dist + math.cos(pyaw) * hx - math.sin(pyaw) * hz
		local sz = pz - math.cos(pyaw) * dist - math.sin(pyaw) * hx - math.cos(pyaw) * hz

		local result = HousingEditorRequestChangePositionAndOrientation(chest.fid, sx, py, sz, 0, pyaw, 0)
		if result == HOUSING_REQUEST_RESULT_SUCCESS then placed = placed + 1 end
	end

	if placed > 0 then
		d("Summoning " .. placed .. " storage chests.")
	else
		d("Failed to summon storage. " .. FormatHousingResult(HOUSING_REQUEST_RESULT_PERMISSION_FAILED))
		storageState = {}
	end
end
