XLGB_Inventory = {}

local XLGB = XLGB_Constants

function XLGB_Inventory:GetEquippedItems()
  local equippedItems = {}
  -- for _, slot in pairs(XLGB_Inventory.validEquippedSlots) do
  local bag = BAG_WORN
  local slot = ZO_GetNextBagSlotIndex(bag)
  while slot do
      local itemLink = GetItemLink(bag, slot)
      local itemType = GetItemLinkItemType(itemLink)
      if itemType == ITEMTYPE_ARMOR 
      or itemType == ITEMTYPE_WEAPON then
        local itemID = Id64ToString(GetItemUniqueId(bag, slot))
        local itemData = XLGB_GearSet:CreateItemData(itemLink, itemID)
        table.insert(equippedItems, itemData)
      end
      slot = ZO_GetNextBagSlotIndex(bag, slot)
  end
  return equippedItems
end

function XLGB_Inventory:Initialize()
  -- self.validEquippedSlots = {
  --   EQUIP_SLOT_HEAD,
  --   EQUIP_SLOT_SHOULDERS,
  --   EQUIP_SLOT_CHEST,
  --   EQUIP_SLOT_WAIST,
  --   EQUIP_SLOT_LEGS,
  --   EQUIP_SLOT_FEET,
  --   EQUIP_SLOT_HAND,
  --   EQUIP_SLOT_NECK,
  --   EQUIP_SLOT_RING1,
  --   EQUIP_SLOT_RING2,
  --   EQUIP_SLOT_MAIN_HAND,
  --   EQUIP_SLOT_OFF_HAND,
  --   EQUIP_SLOT_BACKUP_MAIN,
  --   EQUIP_SLOT_BACKUP_OFF
  -- }
end