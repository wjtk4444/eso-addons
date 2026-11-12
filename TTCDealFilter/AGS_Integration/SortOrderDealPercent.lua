local AGS = AwesomeGuildStore

local SortOrderBase = nil
local SortOrderDealPercentSubclass = nil
TTCDealFilter.SortOrderDealPercent = {}

if AwesomeGuildStore then
  SortOrderBase = AGS.class.SortOrderBase
  SortOrderDealPercentSubclass = SortOrderBase:Subclass()
  TTCDealFilter.SortOrderDealPercent = SortOrderDealPercentSubclass
  local DEAL_PERCENT_ORDER = 100
  local DEAL_PERCENT_ORDER_LABEL = GetString(AGS_PERCENT_ORDER_LABEL)

  function TTCDealFilter.SortOrderDealPercent:New(...)
    return SortOrderBase.New(self, ...)
  end

  function TTCDealFilter.SortOrderDealPercent:Initialize()
    SortOrderBase.Initialize(self, DEAL_PERCENT_ORDER, DEAL_PERCENT_ORDER_LABEL, function(a, b)
      local index = a.itemUniqueId
      local itemLink_a = GetTradingHouseSearchResultItemLink(index)
      index = b.itemUniqueId
      local itemLink_b = GetTradingHouseSearchResultItemLink(index)

      local deal_a, margin_a, profit_a = TTCDealFilter.GetDealInformation(itemLink_a, a.purchasePrice, a.stackCount)
      local deal_b, margin_b, profit_b = TTCDealFilter.GetDealInformation(itemLink_b, b.purchasePrice, b.stackCount)

      margin_a = margin_a or 0.0001
      margin_b = margin_b or 0.0001
      if (margin_a == margin_b) then return 0 end

	  -- sort order
      return margin_a < margin_b and 1 or -1 
    end)

    self.useLocalDirection = true
  end
end
