EvenBetterScoreboard = {}
local ebs = EvenBetterScoreboard
ebs.name = "EvenBetterScoreboard"
ebs.scores = {}
ebs.queues = {}
ebs.rows = {}
ebs.vars = {}

-- "Requeue automatically" checkbox state. Deliberately NOT part of ebs.vars (not saved --
-- resets to off on every /reloadui or relog, same as the request asked for).
ebs.requeueAutomatically = false

-- Self-contained: does not depend on (or touch) Better Scoreboard or the earlier
-- BetterBetterScoreboard. Disable both of those if you still have them enabled -- all three hook
-- the same base-game controls and would collide (most visibly: duplicate
-- "DamageScore"/"HealScore"/"ClassIcon" controls on every scoreboard row).

local defaultSettings = {
	queueSelections = {},
}

-- Account-wide (not per-character) -- the LAM2 settings below and the vanilla Battlegrounds
-- mode-saver further down are all "how I like my client to behave" preferences, not
-- per-character ones. Colors are stored as 0-1 float RGBA tables (LAM2 colorpicker's native
-- format); C59615/00AA00 are just this same gold/green expressed as the hex EBS used to hardcode.
local defaultAccountSettings = {
	lastSelectedBattlegroundMode = nil,
	saveVanillaBattlegroundMode = true,
	nameDisplayMode = "default",
	showQuickQueueButtons = true,
	competitiveColor = { r = 0xC5 / 255, g = 0x96 / 255, b = 0x15 / 255, a = 1 },
	standardColor = { r = 0x00 / 255, g = 0xAA / 255, b = 0x00 / 255, a = 1 },
	healColor = { r = 1, g = 0.85, b = 0, a = 1 },
	damageColor = { r = 1, g = 1, b = 1, a = 1 },
}

-------------------------------------------------------------------------------------------------
--  Battlegrounds scoreboard: class icons + damage/heal columns  --
-------------------------------------------------------------------------------------------------

local classIcons = {
	"esoui/art/icons/class/gamepad/gp_class_dragonknight.dds",
	"esoui/art/icons/class/gamepad/gp_class_sorcerer.dds",
	"esoui/art/icons/class/gamepad/gp_class_nightblade.dds",
	"esoui/art/icons/class/gamepad/gp_class_warden.dds",
	"esoui/art/icons/class/gamepad/gp_class_necromancer.dds",
	"esoui/art/icons/class/gamepad/gp_class_templar.dds"
}
classIcons[117] = "esoui/art/icons/class/gamepad/gp_class_arcanist.dds"

local function updateScore(i, roundIndex, showAggregate)
	local damage = 0
	local heal = 0
	if not showAggregate then
		damage = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_DAMAGE_DONE, roundIndex)
		heal = GetScoreboardEntryScoreByType(i, SCORE_TRACKER_TYPE_HEALING_DONE, roundIndex)
	else
		damage = GetBattlegroundCumulativeScoreForScoreboardEntryByType(i, SCORE_TRACKER_TYPE_DAMAGE_DONE, roundIndex)
		heal = GetBattlegroundCumulativeScoreForScoreboardEntryByType(i, SCORE_TRACKER_TYPE_HEALING_DONE, roundIndex)
	end

	damage = string.format("%sk", math.floor(damage / 1000))
	heal = string.format("%sk", math.floor(heal / 1000))

	if damage and ebs.scores[i] then
		ebs.scores[i].damage:SetText(damage)
	end
	if heal and ebs.scores[i] then
		ebs.scores[i].heal:SetText(heal)
	end
end

-- Shows just one name per row instead of a "Name (OtherName)" combo, and pins the class icon in
-- close to the name. Which name (and in what shape) is controlled by the "Player name display"
-- LAM2 dropdown -- see EBS_NAME_DISPLAY_FUNCS / ebs_getDisplayedName below.
local EBS_NAME_DISPLAY_FUNCS = {
	["default"] = function(charName, displayName) return ZO_ShouldPreferUserId() and displayName or charName end,
	["userid"] = function(charName, displayName) return displayName end,
	["charname"] = function(charName, displayName) return charName end,
	["userid_charname"] = function(charName, displayName) return string.format("%s (%s)", displayName, charName) end,
	["charname_userid"] = function(charName, displayName) return string.format("%s (%s)", charName, displayName) end,
}

local function ebs_getDisplayedName(charName, displayName)
	local fn = EBS_NAME_DISPLAY_FUNCS[ebs.accountVars.nameDisplayMode]
	return (fn or EBS_NAME_DISPLAY_FUNCS["default"])(charName, displayName)
end

-------------------------------------------------------------------------------------------------
--  Scoreboard layout: drop the base game's own Damage/Heals/game-type columns, fit big lobbies  --
-------------------------------------------------------------------------------------------------
-- Since 12.1.5 the base game has its own Damage, Heals and a game-type score column (flags
-- captured / flag carry time / damage taken, shown under a battlegrounds icon) at the right end of
-- every row. Damage/heal are already shown by this addon right next to Score, so all three are
-- hidden (header + row cells) and the window is narrowed back to its pre-12.1.5 width.
--
-- Height: the base game caps the team list at ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT
-- (3 x 4-player panels), which is too short for 9v9 or 6v6v6 (18 rows at 40px each) and leaves a
-- scrollbar. Instead the cap follows the screen height (never below the base cap), and if the
-- lobby still doesn't fit with the normal row spacing, the gap between rows (and the panel's top
-- padding) shrinks just enough for everyone to fit.

-- Base 12.1.5 widened the header by 150 for its 3 new columns, and each row by 3 x (column + pad).
local EBS_REMOVED_WINDOW_WIDTH = 150
local EBS_REMOVED_ROW_WIDTH = (ZO_BATTLEGROUND_SCOREBOARD_HEADER_DAMAGE_WIDTH or 50) + (ZO_BATTLEGROUND_SCOREBOARD_HEADER_HEALS_WIDTH or 50) + (ZO_BATTLEGROUND_SCOREBOARD_HEADER_GAME_TYPE_WIDTH or 50) + 3 * ZO_BATTLEGROUND_SCOREBOARD_HEADER_DOUBLE_PADDING
local EBS_REMOVED_COLUMN_NAMES = { "Damage", "Heals", "GameTypeScore" }

-- Room left for everything around the team list (header 90 + padding 60, the keyboard background's
-- decorative overhang 186, keybind strip): with this, a 1080-high GuiRoot gives exactly the base
-- game's own cap (680), and only taller UIs get a taller window.
local EBS_SCOREBOARD_SCREEN_RESERVE = 400
local EBS_ROUNDS_RESERVE = (ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT or 680) - (ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT_WITH_ROUNDS or 646)
local EBS_DEFAULT_TEAM_SIZE = 4 -- base GetPanelHeight uses a fixed 220px panel up to this size
local EBS_MIN_ROW_GAP = 2
local EBS_MIN_INITIAL_OFFSET = 8
local EBS_LIST_PADDING = 5 -- base adds this so the list isn't right against the scroll limits

-- nil = base layout (normal spacing). Otherwise { gap = px between rows, initialOffset = px above
-- the first row }. Recomputed at the start of every scoreboard UpdateAll.
ebs.rowLayout = nil

local function ebs_getRowHeight()
	if IsInGamepadPreferredMode() then
		return ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_GAMEPAD or 32
	end
	return ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_HEIGHT_KEYBOARD or 30
end

local function ebs_getMaxContainerHeight(hasRounds)
	local baseMax = hasRounds and ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT_WITH_ROUNDS or ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_MAX_HEIGHT
	local screenMax = GuiRoot:GetHeight() - EBS_SCOREBOARD_SCREEN_RESERVE - (hasRounds and EBS_ROUNDS_RESERVE or 0)
	return zo_max(baseMax, screenMax)
end

local function ebs_getTotalPanelsHeight(numTeams, panelHeight)
	return panelHeight * numTeams + ZO_BATTLEGROUND_SCOREBOARD_PANEL_OFFSET_Y * (numTeams - 1) + EBS_LIST_PADDING
end

local function ebs_computeRowLayout(fragment)
	ebs.rowLayout = nil

	local battlegroundId = fragment.currentBattlegroundId
	if not battlegroundId or battlegroundId == 0 then return end

	local teamSize = GetBattlegroundTeamSize(battlegroundId)
	local numTeams = GetBattlegroundNumTeams(battlegroundId)
	if teamSize <= EBS_DEFAULT_TEAM_SIZE or numTeams < 1 then return end

	local maxHeight = ebs_getMaxContainerHeight(DoesBattlegroundHaveRounds(battlegroundId))
	local rowHeight = ebs_getRowHeight()
	local gap = ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_OFFSET_Y
	local initialOffset = ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_INITIAL_OFFSET_Y

	local function fits(rowGap, offset)
		return ebs_getTotalPanelsHeight(numTeams, teamSize * (rowHeight + rowGap) + offset) <= maxHeight
	end
	if fits(gap, initialOffset) then return end -- base spacing already fits, nothing to change

	local function largestGap(offset)
		local available = maxHeight - EBS_LIST_PADDING - ZO_BATTLEGROUND_SCOREBOARD_PANEL_OFFSET_Y * (numTeams - 1) - numTeams * offset
		return zo_floor(available / (numTeams * teamSize)) - rowHeight
	end

	local newGap = largestGap(initialOffset)
	if newGap < EBS_MIN_ROW_GAP then
		initialOffset = EBS_MIN_INITIAL_OFFSET
		newGap = largestGap(initialOffset)
	end
	-- Still too tall even with no gap at all: keep it at 0 and let the base scrollbar handle the rest.
	ebs.rowLayout = { gap = zo_clamp(newGap, 0, gap), initialOffset = initialOffset }
end

local function ebs_isCompactRowLayout()
	return ebs.rowLayout ~= nil and ebs.rowLayout.gap < ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_OFFSET_Y
end

-- Team panel height / row anchoring with ebs.rowLayout applied. GetPanelHeight is a plain function
-- (called as ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight(teamSize) and as
-- self.GetPanelHeight(teamSize)), so it's replaced on the class rather than hooked.
local baseGetPanelHeight = ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight
ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight = function(teamSize)
	local layout = ebs.rowLayout
	if not layout or teamSize <= EBS_DEFAULT_TEAM_SIZE then
		return baseGetPanelHeight(teamSize)
	end
	return teamSize * (ebs_getRowHeight() + layout.gap) + layout.initialOffset
end

local baseTeamPanelUpdateAnchors = ZO_Battleground_Scoreboard_Team_Panel_Object.UpdateAnchors
function ZO_Battleground_Scoreboard_Team_Panel_Object:UpdateAnchors()
	local layout = ebs.rowLayout
	if not layout or self.teamSize <= EBS_DEFAULT_TEAM_SIZE then
		return baseTeamPanelUpdateAnchors(self)
	end

	local previousControl
	for _, playerRow in ipairs(self.sortedPlayerRows) do
		local control = playerRow.control
		control:ClearAnchors()
		if previousControl then
			control:SetAnchor(TOPLEFT, previousControl, BOTTOMLEFT, 0, layout.gap)
		else
			control:SetAnchor(TOPLEFT, self.control, TOPLEFT, self.initialPlayerRowOffsetX, layout.initialOffset)
		end
		previousControl = control
	end
end

-- Narrower window (no Damage/Heals/game-type columns). Re-applied after every UpdateAll, which the
-- base game also runs at the end of every platform-style (keyboard/gamepad) switch, so templates
-- re-applied there can't undo it.
local function ebs_applyScoreboardWidth(fragment)
	local headers = fragment.headers
	headers:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_HEADER_WIDTH - EBS_REMOVED_WINDOW_WIDTH)
	local divider = headers:GetNamedChild("Divider")
	if divider and ZO_BATTLEGROUND_SCOREBOARD_HEADER_DIVIDER_WIDTH then
		divider:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_HEADER_DIVIDER_WIDTH - EBS_REMOVED_WINDOW_WIDTH)
	end
	for _, columnName in ipairs(EBS_REMOVED_COLUMN_NAMES) do
		local header = headers:GetNamedChild(columnName)
		if header then header:SetHidden(true) end
	end

	fragment.backgroundsContainer:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_BACKGROUND_WIDTH - EBS_REMOVED_WINDOW_WIDTH)
	if ZO_BATTLEGROUND_SCOREBOARD_BACKGROUND_WIDTH_KEYBOARD then
		fragment.keyboardBackground:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_BACKGROUND_WIDTH_KEYBOARD - EBS_REMOVED_WINDOW_WIDTH)
	end
	fragment.panelContainer:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_PANEL_CONTAINER_WIDTH - EBS_REMOVED_WINDOW_WIDTH)

	local teamBgWidth = IsInGamepadPreferredMode() and ZO_BATTLEGROUND_SCOREBOARD_TEAM_WIDTH_GAMEPAD or ZO_BATTLEGROUND_SCOREBOARD_TEAM_WIDTH_KEYBOARD
	for _, teamPanel in pairs(fragment.teamPanels) do
		teamPanel.control:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_PANEL_WIDTH - EBS_REMOVED_WINDOW_WIDTH)
		if teamBgWidth then
			teamPanel.bgControl:SetWidth(teamBgWidth - EBS_REMOVED_WINDOW_WIDTH)
		end
	end
end

-- Mirrors the container/background sizing at the top of the base UpdateAll, but with
-- ebs_getMaxContainerHeight instead of the base fixed cap (the panel heights themselves already
-- come from the replaced GetPanelHeight above).
local BACKGROUND_DEFAULT_OFFSET_X = 0
local BACKGROUND_DEFAULT_OFFSET_X_GAMEPAD = -10
local BACKGROUND_DEFAULT_OFFSET_Y = -20
local BACKGROUND_ROUNDS_OFFSET_Y_KEYBOARD = -60
local BACKGROUND_ROUNDS_OFFSET_Y_GAMEPAD = -117

local function ebs_applyScoreboardHeight(fragment)
	local battlegroundId = fragment.currentBattlegroundId
	if not battlegroundId or battlegroundId == 0 then return end

	local hasRounds = DoesBattlegroundHaveRounds(battlegroundId)
	local numTeams = GetBattlegroundNumTeams(battlegroundId)
	local teamSize = GetBattlegroundTeamSize(battlegroundId)
	local totalHeight = ebs_getTotalPanelsHeight(numTeams, ZO_Battleground_Scoreboard_Team_Panel_Object.GetPanelHeight(teamSize))
	local maxHeight = ebs_getMaxContainerHeight(hasRounds)
	-- Within the base's own 5px padding of the cap: show it all rather than scroll 5px (4v4v4).
	local containerHeight = (totalHeight <= maxHeight + EBS_LIST_PADDING) and totalHeight or maxHeight
	fragment.panelContainer:SetHeight(containerHeight)

	fragment.backgroundsContainer:SetHeight(containerHeight + ZO_BATTLEGROUND_SCOREBOARD_HEADER_HEIGHT + ZO_BATTLEGROUND_SCOREBOARD_PADDING_HEIGHT * 2)
	fragment.backgroundsContainer:ClearAnchors()
	local isGamepad = IsInGamepadPreferredMode()
	local offsetY = BACKGROUND_DEFAULT_OFFSET_Y
	if hasRounds and containerHeight >= maxHeight then
		offsetY = isGamepad and BACKGROUND_ROUNDS_OFFSET_Y_GAMEPAD or BACKGROUND_ROUNDS_OFFSET_Y_KEYBOARD
	end
	local offsetX = isGamepad and BACKGROUND_DEFAULT_OFFSET_X_GAMEPAD or BACKGROUND_DEFAULT_OFFSET_X
	fragment.backgroundsContainer:SetAnchor(CENTER, nil, CENTER, offsetX, offsetY)
end

ZO_PreHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(self)
	ebs_computeRowLayout(self)
end)

-- Compact rows (big lobbies) leave less room for the stacked damage/heal pair next to Score:
-- smaller font, centered on the row, so the heal number doesn't run into the next row's damage.
local function ebs_styleScoreLabels(row)
	if ebs_isCompactRowLayout() then
		row.damage:SetFont("ZoFontGameSmall")
		row.heal:SetFont("ZoFontGameSmall")
		row.damage:SetTransformOffsetY(-8)
		row.heal:SetTransformOffsetY(8)
	else
		row.damage:SetFont("ZoFontGame")
		row.heal:SetFont("ZoFontGame")
		row.damage:SetTransformOffsetY(-5)
		row.heal:SetTransformOffsetY(15)
	end
end

local function updateRow(row)
	-- The base UpdateRow un-hides these on every update -- hide them again right after it.
	if row.damageLabel then row.damageLabel:SetHidden(true) end
	if row.healsLabel then row.healsLabel:SetHidden(true) end
	if row.gameTypeScoreLabel then row.gameTypeScoreLabel:SetHidden(true) end

	ebs_styleScoreLabels(row)

	if row.data.isPlaceholderEntry then -- new bgs have placeholders
		row.nameLabel:SetText("")
		row.classIcon:SetTexture("/esoui/art/icons/heraldrycrests_misc_blank_01.dds")
		row.heal:SetText("")
		row.damage:SetText("")
		return
	end

	local charName = zo_strformat(SI_PLAYER_NAME, row.data.characterName)
	local displayName = zo_strformat(SI_PLAYER_NAME, row.data.displayName)
	row.nameLabel:SetText(ebs_getDisplayedName(charName, displayName))

	local classId = GetScoreboardEntryClassId(row.data.entryIndex)
	row.classIcon:SetTexture(classIcons[classId])

	-- Re-applied on every update (not just once in Initialize) so a live color change from the
	-- LAM2 panel takes effect immediately, without needing fresh pooled row controls.
	local healColor = ebs.accountVars.healColor
	local damageColor = ebs.accountVars.damageColor
	row.heal:SetColor(healColor.r, healColor.g, healColor.b, healColor.a)
	row.damage:SetColor(damageColor.r, damageColor.g, damageColor.b, damageColor.a)
end

SecurePostHook(Battleground_Scoreboard_Player_Row, "UpdateRow", updateRow)

SecurePostHook(Battleground_Scoreboard_Player_Row, "Initialize", function(self, row)
	local rowName = row:GetName()
	local metalScore = row:GetNamedChild("MedalScore")
	local nameLabel = row:GetNamedChild("NameLabel")

	-- The row height as the base game set it up, before we add anything to it. The controls
	-- added below (class icon, heal/damage labels) are taller than a single row, so the row
	-- (and therefore the whole list) would otherwise silently grow to fit them -- with a full
	-- lobby that pushes the panel past the screen and forces a scrollbar. Pin the height back
	-- afterwards so our additions can never change how tall a row is.
	local originalHeight = row:GetHeight()

	local damage = CreateControl(rowName .. "DamageScore", row, CT_LABEL)
	local heal = CreateControl(rowName .. "HealScore", row, CT_LABEL)
	heal:SetAnchor(LEFT, metalScore, RIGHT, 15, 0, 0)
	damage:SetAnchor(LEFT, metalScore, RIGHT, 15, 0, 0)
	heal:SetTransformOffsetY(15)
	damage:SetTransformOffsetY(-5)
	damage:SetFont("ZoFontGame")
	heal:SetFont("ZoFontGame")
	-- Colors are applied (and kept current) in updateRow, from the LAM2 "Healing Done"/"Damage
	-- Done" colorpickers -- no need to set a color here, updateRow runs before either label is
	-- ever shown.

	local classIcon = CreateControl(rowName .. "ClassIcon", row, CT_TEXTURE)
	classIcon:SetAnchor(RIGHT, nameLabel, LEFT, -2, 0, 0)
	classIcon:SetDimensions(24, 24)
	classIcon:SetDrawLevel(6)

	if originalHeight and originalHeight > 0 then
		row:SetHeight(originalHeight)
	end

	-- Base Damage/Heals/game-type cells stay hidden (see updateRow), so the row loses their width.
	row:SetWidth(ZO_BATTLEGROUND_SCOREBOARD_PLAYER_ROW_WIDTH - EBS_REMOVED_ROW_WIDTH)

	self.damage = damage
	self.heal = heal
	self.classIcon = classIcon
end)

SecurePostHook(BATTLEGROUND_SCOREBOARD_FRAGMENT, "UpdateAll", function(self)
	ebs_applyScoreboardWidth(self)
	-- The base UpdateAll bails out early (just marks itself dirty) while hidden -- nothing laid
	-- out yet, so nothing to resize either.
	if not self:IsShowing() then return end
	ebs_applyScoreboardHeight(self)

	local showAggregate = BATTLEGROUND_SCOREBOARD_FRAGMENT:ShouldShowAggregateScores()
	local roundIndex = showAggregate and GetCurrentBattlegroundRoundIndex() or BATTLEGROUND_SCOREBOARD_FRAGMENT.viewedRound

	-- when the stuff updates, reload the row list as things prob changed
	ebs.scores = {}
	for i, v in pairs(self.playerEntryData) do
		ebs.scores[v.entryIndex] = v.rowObject
		updateRow(v.rowObject)
		updateScore(v.entryIndex, roundIndex, showAggregate)
	end
end)

SecurePostHook(Battleground_Scoreboard_Player_Row, "SetupOnAcquire", function(self, panel, poolKey, data)
	local showAggregate = BATTLEGROUND_SCOREBOARD_FRAGMENT:ShouldShowAggregateScores()
	local roundIndex = showAggregate and GetCurrentBattlegroundRoundIndex() or BATTLEGROUND_SCOREBOARD_FRAGMENT.viewedRound

	for i = 1, GetNumScoreboardEntries() do
		local _, name = GetScoreboardEntryInfo(i)
		if name == data.displayName then
			ebs.scores[i] = self
			updateScore(i, roundIndex, showAggregate)
		end
	end
end)

function ebs.somethingChanged(code)
	-- logic used in base game BATTLEGROUND_SCOREBOARD_FRAGMENT to identify round index.
	local showAggregate = BATTLEGROUND_SCOREBOARD_FRAGMENT:ShouldShowAggregateScores()
	local roundIndex = showAggregate and GetCurrentBattlegroundRoundIndex() or BATTLEGROUND_SCOREBOARD_FRAGMENT.viewedRound

	for i = 1, GetNumScoreboardEntries() do
		updateScore(i, roundIndex, showAggregate)
	end
end

-------------------------------------------------------------------------------------------------
--  Vanilla Battlegrounds queue screen: remember/restore the selected mode filter  --
-------------------------------------------------------------------------------------------------
-- Ported straight from the standalone BattlegroundModeSaver addon (BadCompany309/imPDA), for
-- people who'd rather keep using the built-in Battlegrounds screen (BATTLEGROUND_FINDER_KEYBOARD)
-- than our own "EBS BG Queue" panel below, but still want this addon's scoreboard columns/icons.
-- Independent of everything else here -- doesn't touch our own panel or its saved selections.
--
-- The vanilla screen's own RefreshFilters (zo_activityfindertemplate_keyboard.lua) already tries
-- to keep the dropdown's current selection across a refresh, but that's just in-memory combobox
-- state -- gone the moment the screen is rebuilt from scratch (a UI reload, a relog, or the very
-- first time you open it this session). Account-wide, not per-character, matching the original
-- addon's own scope (ZO_SavedVars:NewAccountWide) -- see defaultAccountSettings near the top.

local function ebs_getBattlegroundModeItem(modeName)
	for _, item in ipairs(BATTLEGROUND_FINDER_KEYBOARD.filterComboBox.m_sortedItems) do
		if item.name == modeName then return item end
	end
end

-- Only a real click in the dropdown should be remembered -- IsDropdownVisible() is what tells
-- that apart from a SelectItem call that came from RefreshFilters' own reselect-by-name logic or
-- from ebs_restoreBattlegroundMode below (both of which run with the dropdown closed).
--
-- Both hooks below are installed once (at EVENT_PLAYER_ACTIVATED) and stay installed for the rest
-- of the session -- SecurePostHook/ZO_PostHook can't be un-hooked. The "Remember last
-- battleground mode in vanilla finder" LAM2 checkbox is instead gated right here, inside each
-- callback, so it takes effect immediately either way without needing a fresh hook or a reload.
-- Turning it off just stops saving/restoring -- the last remembered mode (if any) is left alone
-- in SavedVariables in case it's turned back on later.
local function ebs_hookBattlegroundModeSelection()
	ZO_PostHook(BATTLEGROUND_FINDER_KEYBOARD.filterComboBox, "SelectItem", function(_, item)
		if not ebs.accountVars.saveVanillaBattlegroundMode then return end
		if not item then return end
		if not BATTLEGROUND_FINDER_KEYBOARD.filterComboBox:IsDropdownVisible() then return end
		ebs.accountVars.lastSelectedBattlegroundMode = item.name
	end)
end

local function ebs_restoreBattlegroundMode()
	ZO_PostHook(BATTLEGROUND_FINDER_KEYBOARD, "RefreshFilters", function()
		if not ebs.accountVars.saveVanillaBattlegroundMode then return end

		local rememberedName = ebs.accountVars.lastSelectedBattlegroundMode
		local rememberedItem = rememberedName and ebs_getBattlegroundModeItem(rememberedName)

		if rememberedItem
			and rememberedItem.name ~= BATTLEGROUND_FINDER_KEYBOARD.filterComboBox:GetSelectedItemData().name
			and BATTLEGROUND_FINDER_KEYBOARD.fragment:IsShowing() then
			BATTLEGROUND_FINDER_KEYBOARD.filterComboBox:SelectItem(rememberedItem)
		end
	end)
end

-------------------------------------------------------------------------------------------------
--  Group & Activity Finder: "EBS BG Queue" multi-queue panel  --
-------------------------------------------------------------------------------------------------
-- Lets you queue for several battleground types at once, like the gamepad UI does. Styled to
-- match the game's own activity-finder lists: real checkboxes with a hover highlight, and a
-- Join Queue / View Veterancy button pair at the bottom, both sharing the same content-area
-- anchors as the built-in category panels so everything lines up with them.

function ebs.buildQueues()
	ebs.queues = {}

	-- Adapted from the base game's own activity finder (zo_activityfinderroot_manager.lua /
	-- zo_battlegroundfinder_manager.lua).
	local filterModeData = ZO_ActivityFinderFilterModeData:New(LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL, LFG_ACTIVITY_BATTLE_GROUND_CHAMPION, LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION)
	filterModeData:SetSubmenuFilterNames(GetString(SI_BATTLEGROUND_FINDER_SPECIFIC_FILTER_TEXT), GetString(SI_BATTLEGROUND_FINDER_RANDOM_FILTER_TEXT))
	filterModeData:SetVisibleEntryTypes(ZO_ACTIVITY_FINDER_LOCATION_ENTRY_TYPE.SET)

	for _, activityType in ipairs(filterModeData:GetActivityTypes()) do
		if ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetNumLocationsByActivity(activityType, filterModeData:GetVisibleEntryTypes()) > 0 then
			local isLocked = ZO_ActivityFinderTemplate_Shared:GetLevelLockInfoByActivity(activityType)
			if not isLocked then
				local locationsData = ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType)
				for _, location in ipairs(locationsData) do
					if filterModeData:IsEntryTypeVisible(location:GetEntryType()) and location:IsActive() then
						ebs.queues[#ebs.queues + 1] = location
					end
				end
			end
		end
	end
end

local EBS_ROW_HEIGHT = 30

-- Colors the qualifier part of a queue's display name, matching how these read in-game (gold for
-- Competitive, green for Standard/Weekly/Weekend, both configurable via the LAM2 panel) --
-- everything else (the team-size prefix, the "- Solo"/"- Group" suffix) is left at the row
-- label's own default color. Weekly/Weekend are matched case-insensitively (their exact in-game
-- capitalization isn't confirmed yet) while keeping whatever casing the game actually uses in the
-- displayed text (the "%0" replacement is the whole match, not a fixed-case literal).
local function ebs_floatToHex(r, g, b)
	return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ebs_colorizeLocationName(rawName)
	local c = ebs.accountVars.competitiveColor
	local s = ebs.accountVars.standardColor
	local competitiveHex = ebs_floatToHex(c.r, c.g, c.b)
	local standardHex = ebs_floatToHex(s.r, s.g, s.b)

	local colored = rawName:gsub("Competitive", "|c" .. competitiveHex .. "Competitive|r")
	colored = colored:gsub("Standard", "|c" .. standardHex .. "Standard|r")
	colored = colored:gsub("[Ww][Ee][Ee][Kk][Ll][Yy]", "|c" .. standardHex .. "%0|r")
	colored = colored:gsub("[Ww][Ee][Ee][Kk][Ee][Nn][Dd]", "|c" .. standardHex .. "%0|r")
	return colored
end

-- Quick-queue grouping key: the queue's own name with the words "Solo"/"Group" (and whatever
-- separator/brackets they leave behind) taken out, e.g. "4v4 Competitive - Solo" and "4v4
-- Competitive - Group" -> "4v4 Competitive", "Big Team Battles (Solo)" -> "Big Team Battles".
-- Every queue sharing a key goes under one "Queue <key>" button. Purely name-based on purpose: the
-- line-up changes with events (weeklies, holiday queues, new formats like 9v9 without any team
-- size in the name), and the name is the one thing every variant reliably shares. A queue
-- without a Solo/Group word just gets its own button.
local EBS_QUEUE_VARIANT_WORDS = { solo = true, group = true }

local function ebs_getQuickQueueKey(rawName)
	local key = rawName:gsub("%a+", function(word)
		if EBS_QUEUE_VARIANT_WORDS[word:lower()] then return "" end
	end)
	key = key:gsub("%(%s*%)", ""):gsub("%[%s*%]", "")
	key = key:gsub("%s+", " ")
	key = key:gsub("^[%s%-:/|,]+", ""):gsub("[%s%-:/|,]+$", "")
	if key == "" then return rawName end
	return key
end

-- Created on demand, reused across rebuilds (named controls can't be destroyed), so this only
-- grows to the most buttons ever needed in one session.
ebs.quickQueueButtons = {}
local EBS_QUICK_QUEUE_MAX_BUTTONS = 6
local EBS_QUICK_QUEUE_PER_ROW = 2
local EBS_QUICK_QUEUE_MIN_WIDTH = 200 -- same as Join Queue / View Veterancy
local EBS_QUICK_QUEUE_TEXT_PADDING = 40
local EBS_QUICK_QUEUE_GAP_X = 30 -- same gap as Join Queue / View Veterancy
local EBS_QUICK_QUEUE_GAP_Y = 10

-- Just the enabled/disabled visual state of the checklist checkboxes -- never touches selections,
-- so unlike ebs.refreshVisibleState's full resync, this is safe to call from broad status-change
-- listeners even when our own panel isn't the one currently open (e.g. the player queued from the
-- built-in Battlegrounds tab instead of ours -- same underlying locations/selections, so that
-- fires our callbacks too, and we still want our own checkboxes to reflect it without touching
-- whatever they selected over there).
function ebs.refreshRowEnabledState()
	local groupSize = GetGroupSize()
	-- Matches vanilla's own filter checkboxes (zo_activityfindertemplate_keyboard.lua
	-- InitializeNavigationList/TreeEntrySetup: "control.enabled = not isLocked and not
	-- IsCurrentlySearchingForGroup()") -- locked while actively searching/queued/mid ready check.
	-- Deliberately NOT gated on ebs.queueCooldownEndMs: the decline/timeout cooldown by itself
	-- must leave these clickable, only being actually in queue does not.
	local isSearching = IsCurrentlySearchingForGroup()
	for _, data in ipairs(ebs.rows) do
		local row, location = data[1], data[2]
		local checkbox = row:GetNamedChild("Check")
		if isSearching or groupSize > location.maxGroupSize then
			ZO_CheckButton_Disable(checkbox)
		else
			ZO_CheckButton_Enable(checkbox)
		end
	end
end

-- Join Queue is enabled only when at least one queue is ticked, we're not already
-- searching/queued, and the Group Finder isn't in use -- the same conditions the built-in Join
-- Queue button uses (zo_activityfindertemplate_keyboard.lua RefreshButtons:
-- isJoinButtonEnabled), plus our own post-ready-check cooldown on top of that. The quick-queue
-- buttons don't need a queue already ticked (they tick their own), but they're just as unable to
-- do anything during those other conditions, so they grey out right along with Join Queue.
function ebs.refreshQueueButtonState()
	ebs.refreshRowEnabledState()

	local isCooldownActive = ebs.queueCooldownEndMs ~= nil
	local isCurrentlyInQueue = ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetIsCurrentlyInQueue()
	local isGroupFinderInUse = ZO_GroupFinder_IsGroupFinderInUse()

	local isQuickQueueEnabled = not (isCooldownActive or isCurrentlyInQueue or isGroupFinderInUse)
	for _, button in ipairs(ebs.quickQueueButtons) do
		button:SetEnabled(isQuickQueueEnabled)
	end

	if not EBS_QueueButton then return end

	if isCooldownActive then
		EBS_QueueButton:SetEnabled(false)
		return
	end

	local isAnyLocationSelected = ZO_ACTIVITY_FINDER_ROOT_MANAGER:IsAnyLocationSelected()
	local isJoinButtonEnabled = isAnyLocationSelected and not isCurrentlyInQueue and not isGroupFinderInUse
	EBS_QueueButton:SetEnabled(isJoinButtonEnabled)
end

-- Re-checks/re-enables every row's checkbox against the current group size, searching state, and
-- saved selection, exactly like the StateChange/SCENE_SHOWING handler below -- pulled out on its
-- own so ebs.rebuildRows() can also call it when the queue list changes while the panel is open.
function ebs.refreshVisibleState()
	local groupSize = GetGroupSize()
	local isSearching = IsCurrentlySearchingForGroup()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:ClearSelections()
	for i, data in ipairs(ebs.rows) do
		local checkbox = data[1]:GetNamedChild("Check")
		local location = data[2]
		local locationName = location.rawName

		local checked = ebs.vars.queueSelections[locationName] and true or false
		ZO_CheckButton_SetCheckState(checkbox, checked)

		if groupSize > location.maxGroupSize then
			-- Genuinely can't be selected with this party size -- disable AND clear it.
			ZO_CheckButton_Disable(checkbox)
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, false)
		elseif isSearching then
			-- Already queued/searching -- lock the checkbox like vanilla's own filter list does,
			-- but leave the selection itself alone: it should keep showing what you're queued
			-- for, not clear it.
			ZO_CheckButton_Disable(checkbox)
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, checked)
		else
			ZO_CheckButton_Enable(checkbox)
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, checked)
		end
	end

	ebs.refreshQueueButtonState()
end

-- Rebuilds the checkbox rows from the current ebs.queues (see ebs.buildQueues -- a live query,
-- not a fixed list). Called once at startup and again whenever the game's own activity finder
-- data changes, so a queue that unlocks, gets added (e.g. a weekly), or disappears mid-session
-- shows up here without needing a /reloadui, the same as the built-in Battlegrounds tab.
-- ZO_ControlPool (not a plain CreateControlFromVirtual loop) is what makes rebuilding safe to
-- call more than once: ReleaseAllObjects() hides and reclaims the previous rows instead of
-- leaking a fresh set of named controls on every refresh.
function ebs.rebuildRows()
	ebs.rowPool:ReleaseAllObjects()
	ebs.rows = {}

	local last = EBS_PanelList

	for i, location in ipairs(ebs.queues) do
		local row = ebs.rowPool:AcquireObject()
		local checkbox = row:GetNamedChild("Check")
		row:GetNamedChild("Name"):SetText(ebs_colorizeLocationName(location.rawName))

		ebs.rows[i] = { row, location }

		row:SetAnchor(TOPLEFT, last, i == 1 and TOPLEFT or BOTTOMLEFT, 0, 0)
		last = row

		ZO_CheckButton_SetCheckState(checkbox, false)

		local locationName = location.rawName
		ZO_CheckButton_SetToggleFunction(checkbox, function(control, checked)
			-- Goes through the root manager (not location:SetSelected directly) so its own
			-- numSelected count -- what IsAnyLocationSelected() and therefore
			-- ebs.refreshQueueButtonState() rely on -- stays accurate, and so OnSelectionsChanged
			-- fires to refresh the Join Queue button's enabled state.
			ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, checked)
			if checked then
				ebs.vars.queueSelections[locationName] = true
			else
				ebs.vars.queueSelections[locationName] = nil
			end
		end)
	end

	EBS_PanelList:SetDimensions(360, math.max(#ebs.queues, 1) * EBS_ROW_HEIGHT)

	ebs.rebuildQuickQueueButtons()

	-- The panel might already be open when the queue list changes (e.g. a weekly queue turning
	-- on while you're sitting on this tab) -- re-sync the fresh rows immediately instead of
	-- waiting for the tab to be reopened.
	if EBS_Panel and not EBS_Panel:IsHidden() then
		ebs.refreshVisibleState()
	end
end

-- Rebuilds the "Queue <name>" shortcut buttons above Join Queue / View Veterancy from the current
-- ebs.queues, same live data ebs.rebuildRows uses -- one button per quick-queue key (see
-- ebs_getQuickQueueKey), in the order the queues are listed, so whatever the game offers right now
-- (e.g. "4v4 Competitive" + "Big Team Battles", plus any event queue) gets a button without a
-- /reloadui. Laid out EBS_QUICK_QUEUE_PER_ROW per row, each row centered, extra rows stacking
-- upward from Join Queue (the container is anchored by its BOTTOM). Each button is at least as
-- wide as Join Queue, wider if its label needs it.
local function ebs_getQuickQueueButton(index)
	local button = ebs.quickQueueButtons[index]
	if not button then
		button = CreateControlFromVirtual("EBS_QuickQueueButton" .. index, EBS_PanelQuickQueueContainer, "EBS_QuickQueueButtonTemplate")
		ebs.quickQueueButtons[index] = button
	end
	return button
end

function ebs.rebuildQuickQueueButtons()
	for _, button in ipairs(ebs.quickQueueButtons) do
		button:SetHidden(true)
		button.quickQueueKey = nil
	end
	if not ebs.accountVars.showQuickQueueButtons then return end

	local keys = {}
	local seen = {}
	for _, location in ipairs(ebs.queues) do
		local key = ebs_getQuickQueueKey(location.rawName)
		if not seen[key] then
			seen[key] = true
			keys[#keys + 1] = key
			if #keys == EBS_QUICK_QUEUE_MAX_BUTTONS then break end
		end
	end
	if #keys == 0 then return end

	-- Label + width first, so every row can be centered on the widest one.
	local buttons = {}
	for i, key in ipairs(keys) do
		local button = ebs_getQuickQueueButton(i)
		button:SetText("Queue " .. key)
		button.quickQueueKey = key
		local label = button:GetLabelControl()
		local textWidth = label and label:GetTextWidth() or 0
		button:SetWidth(zo_max(EBS_QUICK_QUEUE_MIN_WIDTH, textWidth + EBS_QUICK_QUEUE_TEXT_PADDING))
		button:SetHidden(false)
		buttons[i] = button
	end

	local rows = {}
	local maxRowWidth = 0
	for i, button in ipairs(buttons) do
		local rowIndex = zo_floor((i - 1) / EBS_QUICK_QUEUE_PER_ROW) + 1
		local row = rows[rowIndex]
		if not row then
			row = { buttons = {}, width = -EBS_QUICK_QUEUE_GAP_X }
			rows[rowIndex] = row
		end
		row.buttons[#row.buttons + 1] = button
		row.width = row.width + EBS_QUICK_QUEUE_GAP_X + button:GetWidth()
		maxRowWidth = zo_max(maxRowWidth, row.width)
	end

	local y = 0
	for _, row in ipairs(rows) do
		local x = zo_floor((maxRowWidth - row.width) / 2)
		local rowHeight = 0
		for _, button in ipairs(row.buttons) do
			button:ClearAnchors()
			button:SetAnchor(TOPLEFT, EBS_PanelQuickQueueContainer, TOPLEFT, x, y)
			x = x + button:GetWidth() + EBS_QUICK_QUEUE_GAP_X
			rowHeight = zo_max(rowHeight, button:GetHeight())
		end
		y = y + rowHeight + EBS_QUICK_QUEUE_GAP_Y
	end
end

-- Selects every queue location that shares this quick-queue key (Solo and Group variants alike,
-- per the same grouping ebs.rebuildQuickQueueButtons uses), deselecting everything else, then
-- queues immediately -- one click instead of ticking the boxes by hand. ebs.refreshVisibleState
-- still applies the usual real-party-size gating on top of this, so e.g. the Solo variant isn't
-- selected while you're grouped.
function ebs.quickQueue(quickQueueKey)
	if not quickQueueKey then return end
	for _, data in ipairs(ebs.rows) do
		local location = data[2]
		local locationName = location.rawName
		if ebs_getQuickQueueKey(locationName) == quickQueueKey then
			ebs.vars.queueSelections[locationName] = true
		else
			ebs.vars.queueSelections[locationName] = nil
		end
	end

	ebs.refreshVisibleState()
	ebs.startSearch()
end

function ebs.buildPanel()
	local fragment = ZO_FadeSceneFragment:New(EBS_Panel)

	-- Veterancy rank display (icon + rank + name + XP bar), same object the built-in
	-- Battlegrounds screen uses for its own VeterancyRank control.
	ebs.veterancyRankObject = ZO_VeterancyRank:New(EBS_PanelVeterancyRank)
	ZO_VETERANCY_MANAGER:RegisterCallback("OnVeterancyRankProgressed", function()
		ebs.veterancyRankObject:Refresh()
	end)

	ebs.rowPool = ZO_ControlPool:New("EBS_Row", EBS_PanelList, "EBS_Row")
	ebs.rebuildRows()

	-- "Requeue automatically" toggle, same checkbox-row look as the queue checklist above it (it's
	-- just another EBS_Row instance, standalone rather than pool-managed since there's always
	-- exactly one of it). Always starts unchecked: ebs.requeueAutomatically isn't part of
	-- ebs.vars, so this never restores a checked state from a previous session.
	local requeueToggle = CreateControlFromVirtual("EBS_RequeueToggle", EBS_Panel, "EBS_Row")
	requeueToggle:SetAnchor(TOPLEFT, EBS_PanelList, BOTTOMLEFT, 0, 15)
	requeueToggle:GetNamedChild("Name"):SetText("Requeue automatically")
	local requeueCheckbox = requeueToggle:GetNamedChild("Check")
	ZO_CheckButton_SetCheckState(requeueCheckbox, false)
	ZO_CheckButton_SetToggleFunction(requeueCheckbox, function(control, checked)
		ebs.requeueAutomatically = checked
		ebs.refreshAutoRequeueLabel()
	end)

	fragment:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING then
			EBS_PanelVeterancyRank:SetHidden(not IsVeterancySeasonActive())
			ebs.veterancyRankObject:Refresh()
			ebs.refreshVisibleState()
		end
	end)

	local queueButton = CreateControlFromVirtual("EBS_QueueButton", EBS_PanelButtonContainer, "EBS_QueueButtonTemplate")
	queueButton:SetAnchor(TOPLEFT)

	local viewVeterancyButton = CreateControlFromVirtual("EBS_ViewVeterancyButton", EBS_PanelButtonContainer, "EBS_ViewVeterancyButtonTemplate")
	-- Same anchor point and 30px gap the built-in Battlegrounds action bar uses between its own
	-- buttons (zo_activityfindertemplate_keyboard.lua RefreshButtons: SetAnchor(TOPLEFT, ..., TOPRIGHT, 30, 0)).
	viewVeterancyButton:SetAnchor(TOPLEFT, queueButton, TOPRIGHT, 30, 0)

	-- Keeps the Join Queue button's enabled state current: selections changing (including from
	-- outside our own panel, e.g. GetIsCurrentlyInQueue/GroupFinder) and entering/leaving the
	-- queue or a ready check both go through these same callbacks in the built-in game.
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnSelectionsChanged", ebs.refreshQueueButtonState)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnActivityFinderStatusUpdate", ebs.refreshQueueButtonState)

	GROUP_MENU_KEYBOARD:AddCategory({
		name = "EBS BG Queue",
		categoryFragment = fragment,
		normalIcon = "esoui/art/journal/journal_tabicon_achievements_up.dds",
		pressedIcon = "esoui/art/journal/journal_tabicon_achievements_down.dds",
		mouseoverIcon = "esoui/art/journal/journal_tabicon_achievements_over.dds",
		-- Right after Battlegrounds, ahead of Tales of Tribute -- see
		-- esoui/ingame/lfg/zo_activityfinderroot_manager.lua for the full priority table.
		priority = ZO_ACTIVITY_FINDER_SORT_PRIORITY.BATTLEGROUNDS + 10,
	})
end

function ebs.startSearch()
	if ebs.queueCooldownEndMs then return end -- can't requeue during the post-ready-check-decline/timeout cooldown

	if not IsCurrentlySearchingForGroup() then
		ZO_ACTIVITY_FINDER_ROOT_MANAGER:StartSearch()
	end
end

-- Mirrors the built-in "View Veterancy" button (zo_activityfindertemplate_keyboard.lua).
function ebs.viewVeterancy()
	VETERANCY_KEYBOARD:SetIsFromActivityFinder(true)
	SCENE_MANAGER:Push("VeterancySceneKeyboard")
end

-------------------------------------------------------------------------------------------------
--  Ready Check decline/timeout cooldown timer  --
-------------------------------------------------------------------------------------------------
-- When a battleground match is found, the base game pops up a ready check (a PLAYER_TO_PLAYER
-- accept/decline prompt) wherever you happen to be -- almost never with the Group & Activity
-- Finder window open, since that's not where the prompt appears. Declining it, or just not
-- responding until it expires, kicks you from the queue and the server briefly blocks you from
-- requeueing, with zero feedback about when you're allowed to queue again. Accepting the ready
-- check must NOT trigger any of this.
--
-- The "Status: Queued" / "Actual:" labels (ZO_SearchingForGroupStatus / ZO_SearchingForGroupAct-
-- ualTime) it replaces only exist inside that Group Menu window -- if that window is closed when
-- this fires, there's nothing to show it in (by design; a floating always-on-screen label was
-- tried and works, but ends up in a spot that doesn't match where you're used to looking).
-- It also disables this addon's own "Join Queue" button for the same duration.
--
-- Two ways this can start:
--  1. Explicit decline: the "Yes" button of the LFG_DECLINE_READY_CHECK_CONFIRMATION dialog
--     calls DeclineLFGReadyCheckNotification() directly (esoui/ingame/globals/ingamedialogs.lua)
--     -- hooked directly below for an immediate, reliable trigger.
--  2. Timing out with no response: there's no dedicated "expired" API call for that, so this
--     tracks the ready check state via EVENT_ACTIVITY_FINDER_STATUS_UPDATE, the same event the
--     base game's own SearchingForGroupManager uses (esoui/ingame/lfg/searchingforgroup.lua /
--     zo_activityfinderroot_manager.lua): status == ACTIVITY_FINDER_STATUS_READY_CHECK marks one
--     active. If it ends without either the decline hook or an explicit accept
--     (AcceptLFGReadyCheckNotification) having fired first, that means it expired.

local EBS_QUEUE_COOLDOWN_SECONDS = 30 -- change this if the real server-side lockout ever changes
local EBS_COOLDOWN_TEXT = "Requeue available in: %ds" -- edit to taste / translate

local EBS_COOLDOWN_UPDATE_NAME = "EBS_QueueCooldown"
local cooldownLabel

local function ebs_getCooldownLabel()
	if not cooldownLabel and SEARCHING_FOR_GROUP and SEARCHING_FOR_GROUP.leaveQueueButton then
		-- Same spot the base game's own "Actual:" label (ZO_SearchingForGroupActualTime) uses.
		-- Trade-off, by design: this only shows up while the Group & Activity Finder window
		-- happens to be open.
		cooldownLabel = CreateControl("EBS_QueueCooldownLabel", SEARCHING_FOR_GROUP.control, CT_LABEL)
		cooldownLabel:SetFont("ZoFontHeader")
		cooldownLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
		cooldownLabel:SetAnchor(BOTTOM, SEARCHING_FOR_GROUP.leaveQueueButton, TOP, 0, -5)
		cooldownLabel:SetHidden(true)
	end
	return cooldownLabel
end

local function ebs_setVanillaLabelsHidden(hidden)
	if not SEARCHING_FOR_GROUP then return end
	if SEARCHING_FOR_GROUP.statusLabel then SEARCHING_FOR_GROUP.statusLabel:SetHidden(hidden) end
	if SEARCHING_FOR_GROUP.actualTimeLabel then SEARCHING_FOR_GROUP.actualTimeLabel:SetHidden(hidden) end
	if SEARCHING_FOR_GROUP.estimatedTimeLabel then SEARCHING_FOR_GROUP.estimatedTimeLabel:SetHidden(hidden) end
end

local autoRequeueLabel

local function ebs_getAutoRequeueLabel()
	if not autoRequeueLabel and SEARCHING_FOR_GROUP and SEARCHING_FOR_GROUP.statusLabel then
		-- One more row stacked above the base game's own "Status: Queued" label (same
		-- ZO_SearchingForGroup_StatusLabel look), so it reads as part of that same block instead
		-- of a bolted-on extra. Unlike the cooldown label above, this one is never hidden by us --
		-- it's meant to stay visible (and current) the whole time you're queued, cooldown or not.
		autoRequeueLabel = CreateControl("EBS_AutoRequeueLabel", SEARCHING_FOR_GROUP.control, CT_LABEL)
		autoRequeueLabel:SetFont("ZoFontHeader")
		autoRequeueLabel:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
		autoRequeueLabel:SetAnchor(BOTTOM, SEARCHING_FOR_GROUP.statusLabel, TOP, 0, 0)
	end
	return autoRequeueLabel
end

-- Called whenever ebs.requeueAutomatically changes, and again on every activity finder status
-- update (queueing, a ready check starting/ending, ...) so a toggle that happened before
-- SEARCHING_FOR_GROUP even existed yet still ends up showing the right text once it does.
function ebs.refreshAutoRequeueLabel()
	local label = ebs_getAutoRequeueLabel()
	if label then
		label:SetText("Auto requeue: " .. (ebs.requeueAutomatically and "On" or "Off"))
	end
end

-- Snapshot of ebs.vars.queueSelections taken at the moment of an explicit decline (see
-- ebs_onDeclinedReadyCheck below) -- what "requeue automatically" requeues for once the cooldown
-- ends, regardless of whatever the checklist happens to show by then. Left nil by a timeout (see
-- ebs_onActivityFinderStatusUpdate), which is what keeps a timeout from ever auto-requeueing even
-- though it starts the same cooldown a decline does.
local pendingRequeueSelections = nil

local function ebs_endQueueCooldown()
	EVENT_MANAGER:UnregisterForUpdate(EBS_COOLDOWN_UPDATE_NAME)
	ebs.queueCooldownEndMs = nil

	local label = ebs_getCooldownLabel()
	if label then label:SetHidden(true) end

	ebs_setVanillaLabelsHidden(false)

	ebs.refreshQueueButtonState()

	-- Only ever set by an explicit decline, never by a timeout or a manual leave-queue (neither
	-- of those touches pendingRequeueSelections at all) -- so this only fires in the one case the
	-- checkbox's tooltip promises.
	if ebs.requeueAutomatically and pendingRequeueSelections then
		ebs.vars.queueSelections = pendingRequeueSelections
		ebs.refreshVisibleState()
		ebs.startSearch()
	end
	pendingRequeueSelections = nil
end

local function ebs_updateQueueCooldown()
	if not ebs.queueCooldownEndMs then return end

	local remainingMs = ebs.queueCooldownEndMs - GetFrameTimeMilliseconds()
	if remainingMs <= 0 then
		ebs_endQueueCooldown()
		return
	end

	local label = ebs_getCooldownLabel()
	if label then
		label:SetText(string.format(EBS_COOLDOWN_TEXT, math.ceil(remainingMs / 1000)))
	end
end

function ebs.startQueueCooldown()
	ebs.queueCooldownEndMs = GetFrameTimeMilliseconds() + (EBS_QUEUE_COOLDOWN_SECONDS * 1000)

	ebs_setVanillaLabelsHidden(true)

	local label = ebs_getCooldownLabel()
	if label then
		label:SetHidden(false)
	end

	ebs.refreshQueueButtonState()

	ebs_updateQueueCooldown()
	EVENT_MANAGER:RegisterForUpdate(EBS_COOLDOWN_UPDATE_NAME, 200, ebs_updateQueueCooldown)
end

local EBS_READY_CHECK_EVENT_NAME = "EBS_ReadyCheckWatcher"

local wasInReadyCheck = false
local respondedToReadyCheck = false -- set once we've explicitly accepted or declined the current one

local function ebs_onAcceptedReadyCheck()
	respondedToReadyCheck = true
end

local function ebs_onDeclinedReadyCheck()
	respondedToReadyCheck = true
	-- Captured now, not read back from ebs.vars.queueSelections when the cooldown ends: the
	-- checklist (or the queue list itself) could change during the 30s wait, and "requeue
	-- automatically" is supposed to requeue for the same modes that were queued before the
	-- decline, not whatever's ticked by the time it fires.
	pendingRequeueSelections = ZO_ShallowTableCopy(ebs.vars.queueSelections)
	ebs.startQueueCooldown()
end

-- EVENT_ACTIVITY_FINDER_STATUS_UPDATE(status) is what the base game's own SearchingForGroupManager
-- (esoui/ingame/lfg/searchingforgroup.lua, see ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback
-- ("OnActivityFinderStatusUpdate", ...) / esoui/ingame/lfg/zo_activityfinderroot_manager.lua)
-- listens to for this exact purpose, and it hands the new status directly as an argument -- no
-- need to separately poll GetActivityFinderStatus() and risk reading it before it's updated.
local function ebs_onActivityFinderStatusUpdate(status)
	local isInReadyCheck = (status == ACTIVITY_FINDER_STATUS_READY_CHECK)

	if isInReadyCheck and not wasInReadyCheck then
		-- A new ready check just started; reset tracking for it.
		respondedToReadyCheck = false
	elseif wasInReadyCheck and not isInReadyCheck then
		-- The ready check we were tracking just ended. The decline hook already starts the
		-- cooldown on its own and marks respondedToReadyCheck, so getting here with that still
		-- false means neither Accept nor Decline fired -- it expired on its own.
		if not respondedToReadyCheck then
			-- Expired with no response -- never auto-requeue for this one, only an explicit
			-- decline does (see ebs_onDeclinedReadyCheck).
			pendingRequeueSelections = nil
			ebs.startQueueCooldown()
		end
	end

	wasInReadyCheck = isInReadyCheck

	-- Catches SEARCHING_FOR_GROUP just now coming into existence (e.g. the checkbox got toggled
	-- before the player had ever queued this session, so ebs_getAutoRequeueLabel had nothing to
	-- attach to yet) as well as keeping the label itself in place across status changes.
	ebs.refreshAutoRequeueLabel()
end

EVENT_MANAGER:RegisterForEvent(EBS_READY_CHECK_EVENT_NAME, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(eventCode, status)
	ebs_onActivityFinderStatusUpdate(status)
end)

-- SecurePostHook is a native (non-Lua) API, so unlike ZO_PreHook/ZO_PostHook it needs the
-- table argument spelled out explicitly (_G) rather than defaulting it for a bare function name.
SecurePostHook(_G, "AcceptLFGReadyCheckNotification", ebs_onAcceptedReadyCheck)
SecurePostHook(_G, "DeclineLFGReadyCheckNotification", ebs_onDeclinedReadyCheck)

-------------------------------------------------------------------------------------------------
--  LibAddonMenu-2.0 settings panel  --
-------------------------------------------------------------------------------------------------
-- Optional -- LibStub(..., true) returns nil instead of erroring if LAM2 isn't installed, in
-- which case this is skipped entirely and every setting just keeps whatever's in SavedVariables
-- (or the defaults above).

function ebs.registerSettingsPanel()
	local LAM = LibStub("LibAddonMenu-2.0", true)
	if not LAM then return end

	local panelData = {
		type = "panel",
		name = "EvenBetterScoreboard",
		displayName = "Even Better Scoreboard",
		version = "1.1",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local optionsTable = {
		{
			type = "dropdown",
			name = "Player name display",
			tooltip = "How player names are shown on the battlegrounds scoreboard.",
			choices = {
				"Default (respect game settings)",
				"@UserID",
				"Character Name",
				"@UserID (Character Name)",
				"Character Name (@UserID)",
			},
			choicesValues = { "default", "userid", "charname", "userid_charname", "charname_userid" },
			getFunc = function() return ebs.accountVars.nameDisplayMode end,
			setFunc = function(value) ebs.accountVars.nameDisplayMode = value end,
			default = "default",
			width = "full",
		},
		{
			type = "checkbox",
			name = "Remember last battleground mode in vanilla finder",
			tooltip = "On the built-in Battlegrounds queue screen (not the \"EBS BG Queue\" panel), remember the mode dropdown's last selection and restore it automatically across UI reloads and relogs.",
			getFunc = function() return ebs.accountVars.saveVanillaBattlegroundMode end,
			setFunc = function(value) ebs.accountVars.saveVanillaBattlegroundMode = value end,
			default = true,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Show quick queue buttons",
			tooltip = "Show the \"Queue ...\" shortcut buttons on the EBS BG Queue panel -- one per battleground queue on offer, each queueing its Solo and Group variants together.",
			getFunc = function() return ebs.accountVars.showQuickQueueButtons end,
			setFunc = function(value)
				ebs.accountVars.showQuickQueueButtons = value
				ebs.rebuildQuickQueueButtons()
			end,
			default = true,
			width = "full",
		},
		{
			type = "colorpicker",
			name = "Competitive queue color",
			tooltip = "Color used for \"Competitive\" in queue names.",
			getFunc = function()
				local c = ebs.accountVars.competitiveColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				ebs.accountVars.competitiveColor = { r = r, g = g, b = b, a = a or 1 }
				-- rowPool only exists once ebs.buildPanel() has run (first OnUpdateLocationData
				-- callback) -- nothing to recolor yet if the setting's changed before that.
				if ebs.rowPool then ebs.rebuildRows() end
			end,
			default = { r = 0xC5 / 255, g = 0x96 / 255, b = 0x15 / 255, a = 1 },
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Standard queue color",
			tooltip = "Color used for \"Standard\", \"Weekly\", and \"Weekend\" in queue names.",
			getFunc = function()
				local c = ebs.accountVars.standardColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				ebs.accountVars.standardColor = { r = r, g = g, b = b, a = a or 1 }
				if ebs.rowPool then ebs.rebuildRows() end
			end,
			default = { r = 0x00 / 255, g = 0xAA / 255, b = 0x00 / 255, a = 1 },
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Healing Done color",
			tooltip = "Color of the Healing Done number on the battlegrounds scoreboard.",
			getFunc = function()
				local c = ebs.accountVars.healColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				ebs.accountVars.healColor = { r = r, g = g, b = b, a = a or 1 }
			end,
			default = { r = 1, g = 0.85, b = 0, a = 1 },
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Damage Done color",
			tooltip = "Color of the Damage Done number on the battlegrounds scoreboard.",
			getFunc = function()
				local c = ebs.accountVars.damageColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				ebs.accountVars.damageColor = { r = r, g = g, b = b, a = a or 1 }
			end,
			default = { r = 1, g = 1, b = 1, a = 1 },
			width = "half",
		},
	}

	LAM:RegisterAddonPanel(ebs.name .. "Options", panelData)
	LAM:RegisterOptionControls(ebs.name .. "Options", optionsTable)
end

-------------------------------------------------------------------------------------------------
--  OnAddOnLoaded / Initialize  --
-------------------------------------------------------------------------------------------------

-- One-time setup: builds the fragment, buttons and Group Menu category, which can only ever be
-- created once. After that, the queue list itself keeps refreshing -- see ebs.refreshQueues.
function ebs.updateLocations()
	ebs.buildQueues()
	ebs.buildPanel()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:UnregisterCallback("OnUpdateLocationData", ebs.updateLocations)

	-- From here on the queue list stays live instead of freezing at whatever was active on
	-- login/reload: refreshed on the same triggers the built-in Battlegrounds tab uses for its
	-- own filter list (zo_activityfindertemplate_shared.lua RegisterEvents) -- location data
	-- changing, leveling up, switching campaigns, or a holiday/weekly event starting or ending.
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", ebs.refreshQueues)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnLevelUpdate", ebs.refreshQueues)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnCurrentCampaignChanged", ebs.refreshQueues)
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnHolidaysChanged", ebs.refreshQueues)
end

function ebs.refreshQueues()
	ebs.buildQueues()
	ebs.rebuildRows()
end

function ebs.OnAddOnLoaded(event, addonName)
	if addonName ~= ebs.name then return end
	ebs:Initialize()
end

function ebs:Initialize()
	EVENT_MANAGER:UnregisterForEvent(ebs.name, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent(ebs.name, EVENT_BATTLEGROUND_SCOREBOARD_UPDATED, ebs.somethingChanged)

	ebs.vars = ZO_SavedVars:NewCharacterIdSettings("EBSVars", 1, nil, defaultSettings)
	ebs.accountVars = ZO_SavedVars:NewAccountWide("EBSAccountVars", 1, nil, defaultAccountSettings)
	ebs.registerSettingsPanel()
	ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnUpdateLocationData", ebs.updateLocations)

	-- BATTLEGROUND_FINDER_KEYBOARD doesn't exist yet at load time (same reason
	-- BattlegroundModeSaver itself waited for this same event) -- it's only created once the
	-- in-game UI is fully up.
	EVENT_MANAGER:RegisterForEvent(ebs.name, EVENT_PLAYER_ACTIVATED, function()
		ebs_restoreBattlegroundMode()
		ebs_hookBattlegroundModeSelection()
		EVENT_MANAGER:UnregisterForEvent(ebs.name, EVENT_PLAYER_ACTIVATED)
	end)
end

EVENT_MANAGER:RegisterForEvent(ebs.name, EVENT_ADD_ON_LOADED, ebs.OnAddOnLoaded)
