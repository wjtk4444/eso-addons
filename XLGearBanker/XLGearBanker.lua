-- Namespace
XLGearBanker = {}

XLGearBanker.name = "XLGearBanker"

-- Default settings.
XLGearBanker.savedVariables = {
  pages = {},
  gearSetList = {},
  pageWindow_x = 995,
  pageWindow_y = 250,
  setWindow_x = 640,
  setWindow_y = 250,
  setWindow_width = 350,
  setWindow_height = 600,
  safeMode = true,
  debug = false,
  threshold = 70,
  reportMissing = true,
  showSetWindowOnOpen = true,
  showPageWindowOnOpen = true,
  displayingSet = 1,
  displayingPage = 1
}

function XLGearBanker.OnAddOnLoaded(event, addonName)
  if addonName == XLGearBanker.name then
    XLGB_Constants:Initialize()
    XLGearBanker:Initialize()
    XLGB_GearSet:Initialize()
    XLGB_Page:Initialize()
    XLGB_Banking:Initialize()
    XLGB_MenuOverWriter:Initialize()
    XLGB_Settings:Initialize()
    XLGB_UI:Initialize()
  end
end

function easyDebug(...)
  if sV.debug == true then
    d("[XLGB_DEBUG] " .. ...)
  end
end

function XLGearBanker:Initialize()
  self.savedVariables = ZO_SavedVars:NewAccountWide("XLGearBankerSavedVariables", 1, nil, XLGearBanker.savedVariables)
  sV = XLGearBanker.savedVariables
end

EVENT_MANAGER:RegisterForEvent(XLGearBanker.name, EVENT_ADD_ON_LOADED, XLGearBanker.OnAddOnLoaded)

-------------------------------------------------------------------------------
--Slash Commands! --
-- Note: Slash commands should not contain capital letters!
SLASH_COMMANDS["/xlgb_debug"] = function(argsv)
  if sV.debug then
    d("[XLGB] Debugging = off.")
    sV.debug = false
  else
    d("[XLGB] Debugging = on.")
    sV.debug = true
  end
end

SLASH_COMMANDS["/xlgb_overlay"] = function(argsv)
  XLGB_GreyOverlay:SetHidden(not XLGB_GreyOverlay:IsHidden())
end

SLASH_COMMANDS["/xlgb_help"] = function(argsv)
  d("[XLGB] Commands")
  d("'/xlgb_debug': Toggles debug mode. (Note: quite verbose)")
end

SLASH_COMMANDS["/xlgb"] = function()
  XLGB_UI.TogglePageUI()
end
-------------------------------------------------------------------------------
