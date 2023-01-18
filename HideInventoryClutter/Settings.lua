function HideInventoryClutter:buildLAM2Menu()
    local LAM2 = LibAddonMenu2
	LAM2:RegisterAddonPanel(self.ADDON_NAME  .. "_LAM_PANEL", { type = "panel", name = "Hide Inventory Clutter" })
	local controls = {
		[1] = {
			type = "description",
			width = "full",
			text = 
			[[An addon that hides inventory clutter, namely locked items and common consumbles.
			See available filters below (hover over them to get a short description).
			Check addon's website or see README.md file in addon folder to learn the details.
			Full list of affected consumables:
			- lockpicks
			- grand repair kits
			- soul gems
			- buff food / drinks
			- potions
			- poisons]]
		},
		[2] = {
			type = "button",
			name = "Unlock icon position",
			func = function() 
				self.movableIcon = true
				HideInventoryClutter_ConsumablesButton:SetMovable(true)
				HideInventoryClutter_LockedButton:SetMovable(true)

				HideInventoryClutter_LockedButton:SetAlpha(1)
				HideInventoryClutter_LockedButton:SetHidden(false)
				HideInventoryClutter_ConsumablesButton:SetAlpha(1)
				HideInventoryClutter_ConsumablesButton:SetHidden(false)
				
				self.log("Icons unlocked.")
			end
		},
		[3] = {
			type = "button",
			name = "Reset position",
			func = function()
				HideInventoryClutter_LockedButton:ClearAnchors()
				HideInventoryClutter_LockedButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 282, 9)
					
				HideInventoryClutter_ConsumablesButton:ClearAnchors()
				HideInventoryClutter_ConsumablesButton:SetAnchor(TOPLEFT, ZO_PlayerInventoryInfoBar, TOPLEFT, 300, 0)

				self:saveGuiPosition()
				self.log("Icons position restored to default and saved.")
			end
		},
		[4] = {
			type = "button",
			name = "Save new position",
			func = function()
				self.movableIcon = false
				HideInventoryClutter_ConsumablesButton:SetMovable(false)
				HideInventoryClutter_LockedButton:SetMovable(false)
				HideInventoryClutter_LockedButton:SetAlpha(self.lockedVisible and 1 or 0.3)
				HideInventoryClutter_LockedButton:SetHidden(true)
				HideInventoryClutter_ConsumablesButton:SetAlpha(self.lockedVisible and 1 or 0.3)
				HideInventoryClutter_ConsumablesButton:SetHidden(true)

				self:saveGuiPosition()
				self.log("Icons locked, new position saved.")
			end
		},
		[5] = {
			type = "checkbox",
			name = "Locked items filter",
			tooltip = "hides locked items from inventory window",
			getFunc = function() return self.savedVariables.lockedEnabled end,
			setFunc = function(value) self.savedVariables.lockedEnabled = value end
		},
		[6] = {
			type = "checkbox",
			name = "Consumables filter",
			tooltip = "hides common consumables from inventory and merchant sell window",
			getFunc = function() return self.savedVariables.consumablesEnabled end,
			setFunc = function(value) self.savedVariables.consumablesEnabled = value end
		},
		[7] = {
			type = "checkbox",
			name = "Materials filter",
			tooltip = "hides materials from merchant sell window",
			getFunc = function() return self.savedVariables.materialsEnabled end,
			setFunc = function(value) self.savedVariables.materialsEnabled = value end
		},
		[8] = {
			type = "checkbox",
			name = "Deconstruction filter",
			tooltip = "hides items not worth deconstructing from deconstruction window and items worth deconstucting from merchant window",
			getFunc = function() return self.savedVariables.deconstructionEnabled end,
			setFunc = function(value) self.savedVariables.deconstructionEnabled = value end
		},
	}
	LAM2:RegisterOptionControls(self.ADDON_NAME .. "_LAM_PANEL", controls)
end


function HideInventoryClutter:saveGuiPosition()
	self.savedVariables.positionConsumable.left = math.floor(HideInventoryClutter_ConsumablesButton:GetLeft())
	self.savedVariables.positionConsumable.top  = math.floor(HideInventoryClutter_ConsumablesButton:GetTop())	
	
	self.savedVariables.positionLocked.left = math.floor(HideInventoryClutter_LockedButton:GetLeft())
	self.savedVariables.positionLocked.top  = math.floor(HideInventoryClutter_LockedButton:GetTop())		
end

function HideInventoryClutter:setupSavedVars()
	self.savedVariables = ZO_SavedVars:NewAccountWide("HideInventoryClutterPosition", 2, nil, { 
			positionLocked     = { top = nil, left = nil },
			positionConsumable = { top = nil, left = nil },
			lockedEnabled = true,
			consumablesEnabled = true,
			materialsEnabled = true,
			deconstructionEnabled = true,
		})
end