-- Essential Snugpod Tools: the Snugpod magic.
-- Opening the round Telvanni door in the author's Snugpod animates a piece of furniture;
-- /snugpod runs the same animation by hand. Tied to that one house: the furniture ids below
-- don't exist anywhere else, so the addon does nothing in other houses.
--
-- The general helpers that used to live here (assistants from quickslots, /storage) are now
-- in Schrodi's Housing Tools.

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

SLASH_COMMANDS["/snugpod"] = function(args)
	if GetCurrentZoneHouseId() == 0 then
		d("You need to be in a house.")
		return
	end

	if args == "selected" then
		-- Prints the selected furniture's id and position, for filling in furnitureConfig.
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

	if args ~= nil and args ~= "" then
		d("Usage: /snugpod (run the magic), /snugpod selected (print the selected furniture's position)")
		return
	end

	RunSnugpodMagic(function() d("Snugpod magic complete!") end)
end
