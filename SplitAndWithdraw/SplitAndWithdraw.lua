SplitAndWithdraw = {}

function SplitAndWithdraw:onInventoryContextMenu(control, ...)
	if control:GetOwningWindow() ~= ZO_TradingHouse 
	and ZO_InventorySlot_IsSplittableType(control) 
	and ZO_InventorySlot_CanSplitItemStack(control) then
		local bag, slot = ZO_Inventory_GetBagAndIndex(control)
		local count = GetSlotStackSize(bag, slot)
		if count > 1 then 
			zo_callLater(function()
				local count = GetSlotStackSize(bag, slot)
				local operation = bag == BAG_BACKPACK and "Split" or "Withdraw"
				if count > 1 then
					AddCustomMenuItem(operation .. " 1",   function() self:splitAndMove(1,   bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 25 then
					AddCustomMenuItem(operation .. " 25",  function() self:splitAndMove(25,  bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 50 then
					AddCustomMenuItem(operation .. " 50",  function() self:splitAndMove(50,  bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 100 then
					AddCustomMenuItem(operation .. " 100", function() self:splitAndMove(100, bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				ShowMenu(self) 
			end, 1)
		end
	end
end

function SplitAndWithdraw:splitAndMove(amount, bag, slot)
	local targetBag = BAG_BACKPACK
	local targetSlot = FindFirstEmptySlotInBag(targetBag)
	CallSecureProtected("RequestMoveItem", bag, slot, targetBag, targetSlot, amount)
	if bag ~= targetBag then StackBag(bag) end
end

ZO_PreHook("ZO_InventorySlot_ShowContextMenu", function(...) SplitAndWithdraw:onInventoryContextMenu(...) end)
