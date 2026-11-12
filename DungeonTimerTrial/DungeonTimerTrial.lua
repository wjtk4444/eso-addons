local DT = DungeonTimer
local NAME = "DungeonTimerTrial"

DT.zoneIds[ 635] = {     0, 60 } -- Dragonstar Arena
DT.zoneIds[ 677] = {     0, 60 } -- Maelstrom Arena
DT.zoneIds[1082] = {     0, 40 } -- Blackrose Prison
DT.zoneIds[1227] = {     0, 30 } -- Vateshran Hollows

DT.zoneIds[ 636] = {     0, 33 } -- Hel Ra Citadel
DT.zoneIds[ 638] = {     0, 33 } -- Aetherian Archive
DT.zoneIds[ 639] = {     0, 33 } -- Sanctum Ophidia
DT.zoneIds[ 725] = {     0, 40 } -- Maw of Lorkhaj
DT.zoneIds[ 975] = {     0, 40 } -- Halls of Fabrication
DT.zoneIds[1000] = {     0, 15 } -- Asylum Sanctorium
DT.zoneIds[1051] = {     0, 15 } -- Cloudrest
DT.zoneIds[1121] = {     0, 30 } -- Sunspire
DT.zoneIds[1196] = {     0, 35 } -- Kyne's Aegis
DT.zoneIds[1263] = {     0, 30 } -- Rockgrove
DT.zoneIds[1344] = {     0, 30 } -- Dreadsail Reef
DT.zoneIds[1427] = {     0, 30 } -- Sanity's Edge
DT.zoneIds[1478] = {     0, 30 } -- Lucent Citadel
DT.zoneIds[1548] = {     0, 30 } -- Ossein Cage

-- /script d(GetUnitWorldPosition("player"))

--[[
Timer state (DT.vars, saved in DungeonTimerSavedVariables):
	startTime  0 - not started
	          >0 - running, local start timestamp
	          -1 - stopped, final value in finalTime
	finalTime  - seconds shown after the run ended (survives /reloadui)

Start sources, best first:
	1. Server trial timer (IsRaidInProgress / GetRaidDuration) - the same clock the
	   leaderboards use. Only exists where the game tracks score (veteran trials
	   and arenas). While it runs, the local clock is kept in sync with it, so when
	   it disappears (trial failed - vitality gone) the timer keeps going.
	2. Combat of the player OR any group member in the same instance - so the
	   timer starts when the tank pulls, not when you get hit. Never in the trial
	   staging area. This is what normal trials and all dungeons use.
	3. Subzone / special events from the base addon (unchanged).
--]]

---------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------

local function IsServerTimerRunning()
	return IsRaidInProgress() and not HasRaidEnded()
end

local function GetServerElapsed()
	return zo_floor(GetRaidDuration() / 1000)
end

local function SyncToServer()
	if IsServerTimerRunning() then
		DT.vars.startTime = GetTimeStamp() - GetServerElapsed()
		DT.vars.finalTime = nil
		return true
	end
	return false
end

local function IsAnyGroupMemberInCombat()
	if IsUnitInCombat("player") then
		return true
	end
	for i = 1, GetGroupSize() do
		local tag = GetGroupUnitTagByIndex(i)
		if tag and IsUnitOnline(tag) and IsGroupMemberInSameInstanceAsPlayer(tag) and IsUnitInCombat(tag) then
			return true
		end
	end
	return false
end

local originalStartTimer = DT.StartTimer
function DT.StartTimer()
	-- Fighting the trash in front of the portal / in the lobby is not the run.
	if IsPlayerInRaidStagingArea() then
		return
	end
	originalStartTimer()
end

local function StopTimer(finalSeconds)
	local vars = DT.vars
	if vars.startTime > 0 then
		vars.finalTime = finalSeconds or (GetTimeStamp() - vars.startTime)
		vars.startTime = -1
		GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(DT.name)
	end
	if DT.active then
		DT.Poll()
	end
end
DT.StopTimer = function() StopTimer() end

function DT.Poll()
	local vars = DT.vars
	local elapsed = 0

	if SyncToServer() then
		elapsed = GetServerElapsed()
	else
		if vars.startTime == 0 then
			vars.finalTime = nil
			if DT.mode == 0 and IsAnyGroupMemberInCombat() then
				DT.StartTimer()
			end
		end

		if vars.startTime > 0 then
			elapsed = GetTimeStamp() - vars.startTime
		elseif vars.startTime == -1 then
			elapsed = vars.finalTime or 0
		end
	end

	DT.label:SetText(string.format("%02d:%02d", zo_floor(elapsed / 60), elapsed % 60))
	DT.FitTrialBlock()

	if elapsed < DT.speedrun then
		DT.label:SetColor(1, 1, 1, 1)
	else
		DT.label:SetColor(1, 0.2, 0.2, 1)
	end
end

local function OnRaidTrialStarted()
	-- Covers the "reset instance and go again" case: the server clock restarts
	-- from zero, so follow it no matter what state the local timer was in.
	if DT.active and SyncToServer() then
		DT.Poll()
	end
end

local function OnRaidTrialComplete(_, _, _, totalTimeMs)
	if not DT.active then return end
	if DT.vars.startTime == 0 then
		-- e.g. /reloadui right before the last boss died; take the server time
		DT.vars.startTime = GetTimeStamp()
	end
	StopTimer(totalTimeMs and zo_floor(totalTimeMs / 1000) or nil)
end

local function OnActivityComplete()
	if DT.active then
		StopTimer()
	end
end

---------------------------------------------------------------------------
-- Position: in score-tracked content (vet trials, arenas) the timer sits to
-- the RIGHT of the game's score / vitality display (ZO_HUDRaidLifeReservoir),
-- and the two are treated as one block: if the timer would stick out past the
-- right edge of the screen, the display itself is shifted left by just enough.
-- With the default layout (display in the bottom-right corner) that means the
-- timer takes the corner and the display moves over by the timer's width.
--
-- The display's own anchor comes from the HUD editor; the shift is applied on
-- top of whatever anchor the editor set, re-checked every poll, and undone
-- when leaving the trial. The timer can't be dragged there; elsewhere it uses
-- the normal free, draggable position.
---------------------------------------------------------------------------

local TRIAL_GAP_X = 12     -- space between the score display and the timer
local TRIAL_OFFSET_Y = 0   -- vertical nudge of the timer (negative = up)
local SCREEN_MARGIN = 15   -- distance from the screen edge (same as the game's HUD)

local function GetScoreDisplay()
	return ZO_HUDRaidLifeReservoir
end

local function ShouldAttach()
	return GetScoreDisplay() ~= nil and IsPlayerInReviveCounterRaid()
end

-- Shift state of the score display
local baseAnchor    -- the display's own anchor (from the HUD editor / default)
local appliedAnchor -- what we last set on it
local appliedShift = 0
local timerWidth = 0 -- widest the timer has been; only grows, so the block doesn't jiggle

local function ReadAnchor(control)
	local isValid, point, relTo, relPoint, x, y = control:GetAnchor(0)
	if isValid then
		return { point = point, relTo = relTo, relPoint = relPoint, x = x, y = y }
	end
end

local function SameAnchor(a, b)
	return a and b and a.point == b.point and a.relTo == b.relTo and a.relPoint == b.relPoint
		and zo_abs(a.x - b.x) < 0.5 and zo_abs(a.y - b.y) < 0.5
end

local function SetDisplayShift(shift)
	local score = GetScoreDisplay()
	local current = ReadAnchor(score)
	if not current then return end

	if not SameAnchor(current, appliedAnchor) then
		-- not ours (first time, or the HUD editor re-anchored it): new base
		baseAnchor = current
		appliedShift = 0
		appliedAnchor = current
	end

	if shift == appliedShift then return end

	local a = { point = baseAnchor.point, relTo = baseAnchor.relTo, relPoint = baseAnchor.relPoint,
		x = baseAnchor.x - shift, y = baseAnchor.y }
	score:ClearAnchors()
	score:SetAnchor(a.point, a.relTo, a.relPoint, a.x, a.y)
	appliedAnchor = a
	appliedShift = shift
end

local function RestoreDisplay()
	if appliedShift ~= 0 and SameAnchor(ReadAnchor(GetScoreDisplay()), appliedAnchor) then
		SetDisplayShift(0)
	end
	baseAnchor, appliedAnchor, appliedShift, timerWidth = nil, nil, 0, 0
end

function DT.FitTrialBlock()
	if not ShouldAttach() then return end

	local score = GetScoreDisplay()
	timerWidth = zo_max(timerWidth, DungeonTimerFrame:GetWidth())

	-- where the display's right edge would be without our shift
	local unshiftedRight = score:GetRight() + appliedShift
	local overflow = unshiftedRight + TRIAL_GAP_X + timerWidth - (GuiRoot:GetRight() - SCREEN_MARGIN)
	SetDisplayShift(zo_max(0, zo_ceil(overflow)))
end

local function ApplyPosition()
	if not DT.initialized then return end

	local frame = DungeonTimerFrame
	frame:ClearAnchors()

	if ShouldAttach() then
		frame:SetMovable(false)
		frame:SetAnchor(LEFT, GetScoreDisplay(), RIGHT, TRIAL_GAP_X, TRIAL_OFFSET_Y)
		DT.FitTrialBlock()
	else
		RestoreDisplay()
		frame:SetMovable(true)
		frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DT.vars.left, DT.vars.top)
	end
end

local originalOnMoveStop = DT.OnMoveStop
function DT.OnMoveStop()
	if ShouldAttach() then
		ApplyPosition()
	else
		originalOnMoveStop()
	end
end

local originalInitializeUI = DT.InitializeUI
function DT.InitializeUI()
	DT.vars.trialAnchor = nil -- drag-based anchor from 1.1.0, no longer used
	originalInitializeUI()
	ApplyPosition()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, ApplyPosition)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RAID_TIMER_STATE_UPDATE, ApplyPosition)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RAID_TRIAL_STARTED, OnRaidTrialStarted)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RAID_TRIAL_COMPLETE, OnRaidTrialComplete)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, OnActivityComplete)

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------

local fontSize = 24
local fontStyle = "BOLD_FONT"
local fontWeight = "soft-shadow-thin"
local font = string.format("$(%s)|$(KB_%s)|%s", fontStyle, fontSize, fontWeight)
DungeonTimerFrame:GetNamedChild("Label"):SetFont(font)
DungeonTimerFrame:GetNamedChild("Label"):ClearAnchors()
DungeonTimerFrame:GetNamedChild("Label"):SetAnchor(LEFT, DungeonTimerFrame:GetNamedChild("Icon"), RIGHT, 0, -3)
DungeonTimerFrame:GetNamedChild("Icon"):SetWidth(32)
DungeonTimerFrame:GetNamedChild("Icon"):SetHeight(32)
