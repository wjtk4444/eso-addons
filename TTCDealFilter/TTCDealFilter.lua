-- TTC Deal Filter
--
-- Master Merchant's guild store deal rating, deal filter and "Deal Percent" sort order for
-- AwesomeGuildStore, rated against Tamriel Trade Centre prices instead of Master Merchant's
-- sales history. The deal calculation, the AwesomeGuildStore filter code and the filter icons
-- are adapted from Master Merchant (BSD license, see LICENSE).

TTCDealFilter = { }

local LMP = LibMediaProvider

local DEAL_INFO_CACHE = {}
local DEAL_VALUE_COLOR_DEFS = {}

--[[TODO Update DealCalculator this so it doesn't return -1 for things and makes more
sense when you view it in the guild store
]]--
-- Deal Value Ranges
MM_DEAL_VALUE_DONT_SHOW = -1
MM_DEAL_VALUE_OVERPRICED = 0
MM_DEAL_VALUE_OKAY = 1
MM_DEAL_VALUE_REASONABLE = 2
MM_DEAL_VALUE_GOOD = 3
MM_DEAL_VALUE_GREAT = 4
MM_DEAL_VALUE_BUYIT = 5

for index = MM_DEAL_VALUE_OKAY, MM_DEAL_VALUE_BUYIT do
	DEAL_VALUE_COLOR_DEFS[index] = ZO_ColorDef.FromInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, index)
end

DEAL_VALUE_COLOR_DEFS[MM_DEAL_VALUE_OVERPRICED] = ZO_ColorDef:New(ZO_ColorDef.FloatsToHex(0.98, 0.01, 0.01, 1))

-- AGS Integration
ZO_CreateStringId("AGS_DEAL_RANGE_LABEL", "Deal Range")
ZO_CreateStringId("AGS_PROFIT_RANGE_LABEL", "Profit Range")
ZO_CreateStringId("AGS_OVERPRICED_LABEL", "Overpriced")
ZO_CreateStringId("AGS_OKAY_LABEL", "Ok")
ZO_CreateStringId("AGS_REASONABLE_LABEL", "Reasonable")
ZO_CreateStringId("AGS_GOOD_LABEL", "Good")
ZO_CreateStringId("AGS_GREAT_LABEL", "Great")
ZO_CreateStringId("AGS_BUYIT_LABEL", "Buy it!")
ZO_CreateStringId("AGS_PERCENT_ORDER_LABEL", "Deal Percent")
ZO_CreateStringId("AGS_PERCENT_ORDER_ASCENDING", "Ascending")
ZO_CreateStringId("AGS_PERCENT_ORDER_DESCENDING", "Descending")
ZO_CreateStringId("AGS_PERCENT_ORDER_NAME", "AGS Deal Percent Sort Order")
ZO_CreateStringId("AGS_PERCENT_ORDER_DESC", "Choose between ascending or descending when sorting by Deal Percent.")

function TTCDealFilter.DealCalculator(setPrice, salesCount, purchasePrice, stackCount)
  local deal = MM_DEAL_VALUE_DONT_SHOW
  local margin = 0
  local profit = -1
  if (setPrice) then
    local unitPrice = purchasePrice / stackCount
    salesCount = salesCount or 0
    profit = (setPrice - unitPrice) * stackCount
    margin = tonumber(string.format('%.2f', ((setPrice - unitPrice) / setPrice) * 100))

    margin = (margin or 0)
    profit = (profit or 0)
    unitPrice = (unitPrice or 0)

    if (salesCount > 15) then
      -- high volume margins
      if (margin >= 85) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 65 and profit >= 1000) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 50 and profit >= 3000) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 50 and profit >= 500) then
        deal = MM_DEAL_VALUE_GREAT
      elseif (margin >= 35 and profit >= 3000) then
        deal = MM_DEAL_VALUE_GREAT
      elseif (margin >= 35 and profit >= 100) then
        deal = MM_DEAL_VALUE_GOOD
      elseif (margin >= 20) then
        deal = MM_DEAL_VALUE_REASONABLE
      elseif (margin >= -2.5) then
        deal = MM_DEAL_VALUE_OKAY
      else
        deal = MM_DEAL_VALUE_OVERPRICED
      end
    elseif (salesCount > 5) then
      -- mid volume margins
      if (margin >= 85) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 80 and profit >= 1000) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 65 and profit >= 3000) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 65 and profit >= 500) then
        deal = MM_DEAL_VALUE_GREAT
      elseif (margin >= 50 and profit >= 3000) then
        deal = MM_DEAL_VALUE_GREAT
      elseif (margin >= 50 and profit >= 100) then
        deal = MM_DEAL_VALUE_GOOD
      elseif (margin >= 30) then
        deal = MM_DEAL_VALUE_REASONABLE
      elseif (margin >= -5.0) then
        deal = MM_DEAL_VALUE_OKAY
      else
        deal = MM_DEAL_VALUE_OVERPRICED
      end
    else
      -- low volume margins
      if (margin >= 90 and profit >= 1000) then
        deal = MM_DEAL_VALUE_BUYIT
      elseif (margin >= 75 and profit >= 500) then
        deal = MM_DEAL_VALUE_GREAT
      elseif (margin >= 60 and profit >= 100) then
        deal = MM_DEAL_VALUE_GOOD
      elseif (margin >= 30) then
        deal = MM_DEAL_VALUE_REASONABLE
      elseif (margin >= -7.5) then
        deal = MM_DEAL_VALUE_OKAY
      else
        deal = MM_DEAL_VALUE_OVERPRICED
      end
    end
  else
    -- No sales seen
    margin = nil
  end

  return deal, margin, profit
end

TTCDealFilter.GetDealInformation = function(itemLink, purchasePrice, stackCount)
  local key = string.format("%s_%d_%d", itemLink, purchasePrice, stackCount)
  if (not DEAL_INFO_CACHE[key]) then
	local priceStats = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
	local averagePrice, salesCount
    if priceStats and priceStats.SaleAvg and priceStats.SaleAvg > 0 then averagePrice = priceStats.SaleAvg end
    if priceStats and priceStats.SaleEntryCount then salesCount = priceStats.SaleEntryCount end
  
    DEAL_INFO_CACHE[key] = { TTCDealFilter.DealCalculator(averagePrice, salesCount, purchasePrice, stackCount) }
  end
  return unpack(DEAL_INFO_CACHE[key])
end

--[[ TODO update this for the colors and the value so that when there
isn't any buying advice then it is blank or 0
]]--
function TTCDealFilter.AddBuyingAdvice(rowControl, result)
  local buyingAdvice = rowControl:GetNamedChild('BuyingAdvice')
  if (not buyingAdvice) then
    local controlName = rowControl:GetName() .. 'BuyingAdvice'
    buyingAdvice = rowControl:CreateControl(controlName, CT_LABEL)

    if (not AwesomeGuildStore) then
      local anchorControl = rowControl:GetNamedChild('SellPricePerUnit')
      local _, point, relTo, relPoint, offsX, offsY = anchorControl:GetAnchor(0)
      anchorControl:ClearAnchors()
      anchorControl:SetAnchor(point, relTo, relPoint, offsX, offsY + 10)
    end

    local anchorControl = rowControl:GetNamedChild('TimeRemaining')
    local _, point, relTo, relPoint, offsX, offsY = anchorControl:GetAnchor(0)
    anchorControl:ClearAnchors()
    anchorControl:SetAnchor(point, relTo, relPoint, offsX, offsY - 10)
    buyingAdvice:SetAnchor(TOPLEFT, anchorControl, BOTTOMLEFT, 0, 0)
    local fontString = LMP:Fetch('font', "Univers 67")
    buyingAdvice:SetFont(fontString .. '|14|soft-shadow-thin')
  end

  local index = result.slotIndex
  if (AwesomeGuildStore) then index = result.itemUniqueId end
  local itemLink = GetTradingHouseSearchResultItemLink(index)
  local dealValue, margin, profit = TTCDealFilter.GetDealInformation(itemLink, result.purchasePrice, result.stackCount)
  if dealValue then
    if dealValue > MM_DEAL_VALUE_DONT_SHOW then
      --if MasterMerchant.systemSavedVariables.displayProfit then
      --  buyingAdvice:SetText(MasterMerchant.LocalizedNumber(profit) .. ' |t16:16:EsoUI/Art/currency/currency_gold.dds|t')
      --else
        buyingAdvice:SetText(string.format('%.2f', margin) .. '%')
      --end
      buyingAdvice:SetColor(DEAL_VALUE_COLOR_DEFS[dealValue]:UnpackRGBA())
      buyingAdvice:SetHidden(false)
    else
      buyingAdvice:SetHidden(true)
    end
  else
    buyingAdvice:SetHidden(true)
  end
  buyingAdvice = nil
end

function TTCDealFilter:initBuyingAdvice()
  --[[Keyboard Mode has a TRADING_HOUSE.searchResultsList
  that is set to
  ZO_TradingHouseBrowseItemsRightPaneSearchResults and
  then from there, there is a
  dataTypes[1].dataType.setupCallback.

  This does not exist in GamepadMode
  ]]--
  if TTCDealFilter.originalSetupCallback then return end
  if TRADING_HOUSE and TRADING_HOUSE.searchResultsList then

    local dataType = TRADING_HOUSE.searchResultsList.dataTypes[1]

    TTCDealFilter.originalSetupCallback = dataType.setupCallback
    if TTCDealFilter.originalSetupCallback then
      dataType.setupCallback = function(...)
        local row, data = ...
        TTCDealFilter.originalSetupCallback(...)
        zo_callLater(function() TTCDealFilter.AddBuyingAdvice(row, data) end, 1)
      end
    else
      d("TTC Deal Filter: could not hook the guild store results list.")
    end
  end

  if TRADING_HOUSE_GAMEPAD then
  end
end

local function OnAddOnLoaded(eventCode, addOnName)
  if addOnName:find('^ZO_') then return end
  if addOnName == "AwesomeGuildStore" then
    -- Set up AGS integration, if it's installed
    TTCDealFilter:initAGSIntegration()
  end
end
EVENT_MANAGER:RegisterForEvent("TTCDealFilter", EVENT_ADD_ON_LOADED, OnAddOnLoaded)

EVENT_MANAGER:RegisterForEvent("TTCDealFilter", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
	if responseType == TRADING_HOUSE_RESULT_POST_PENDING and result == TRADING_HOUSE_RESULT_SUCCESS then return end
    -- Set up guild store buying advice
    TTCDealFilter:initBuyingAdvice()
end)

