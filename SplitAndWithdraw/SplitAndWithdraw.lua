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
				local itemType = GetItemType(bag, slot)
				if operation == "Withdraw" and itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK or itemType == ITEMTYPE_CROWN_ITEM or itemType == ITEMTYPE_GROUP_REPAIR then
					AddCustomMenuItem("Withdraw and use 1",   function() self:takeOneAndNomIt(bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 1 then
					AddCustomMenuItem(operation .. " 1",   function() self:splitAndMove(1,   bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 2 and count < 20 then
					AddCustomMenuItem(operation .. " 2",   function() self:splitAndMove(2,   bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 3 and count < 30 then
					AddCustomMenuItem(operation .. " 3",   function() self:splitAndMove(3,   bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 5 and count < 50 then
					AddCustomMenuItem(operation .. " 5",   function() self:splitAndMove(5,   bag, slot) end, MENU_ADD_OPTION_LABEL)
				end
				if count > 10 then
					AddCustomMenuItem(operation .. " 10",  function() self:splitAndMove(10,  bag, slot) end, MENU_ADD_OPTION_LABEL)
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

function SplitAndWithdraw:takeOneAndNomIt(bag, slot)
	local targetBag = BAG_BACKPACK
	local targetSlot = FindFirstEmptySlotInBag(targetBag)
	CallSecureProtected("RequestMoveItem", bag, slot, targetBag, targetSlot, 1)
	
	EVENT_MANAGER:RegisterForEvent("SplitAndWithdrawNomNom", EVENT_CLOSE_BANK, function ()
		zo_callLater(function() 
				d("Using one: " .. GetItemLink(targetBag, targetSlot, LINK_STYLE_BRACKETS))
				CallSecureProtected("UseItem", targetBag, targetSlot) 
			end, 500)
		EVENT_MANAGER:UnregisterForEvent("SplitAndWithdrawNomNom", EVENT_CLOSE_BANK)
	end)
end

function SplitAndWithdraw:splitAndMove(amount, bag, slot)
	local targetBag = BAG_BACKPACK
	local targetSlot = FindFirstEmptySlotInBag(targetBag)
	CallSecureProtected("RequestMoveItem", bag, slot, targetBag, targetSlot, amount)
	if bag ~= targetBag then 
		StackBag(bag) 
		StackBag(targetBag) 
	end
end

ZO_PreHook("ZO_InventorySlot_ShowContextMenu", function(...) SplitAndWithdraw:onInventoryContextMenu(...) end)
