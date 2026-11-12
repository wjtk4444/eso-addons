# LootLog Extras

An add-on for Code's **LootLog** (by @code65536). LootLog records what you loot, but it only sees items that come from looting. This addon records two more sources in LootLog's history.

## Crafting stations

Materials you get from **refining** raw materials and from **deconstructing** gear at a crafting station. This includes the deconstruction assistant and materials that go straight into the Craft Bag with ESO Plus.

Every material is written to the history, the same way LootLog records all loot. A chat note appears only when something in the batch is notable:

> From refining 100 raw materials: [Tempering Alloy] x1
> From deconstruction: [Dreugh Wax] x1

## Mail

Notable items you take from mail, both one mail at a time and with **Take All (System)** / **Take All (Player)**. This covers hireling mail, rewards and refunds.

Only notable items are written to the history. Everything else, such as gold and items from guild store mail, is left out so it does not flood the history.

> From mail (Take All (System)): [Dreugh Wax] x2

## What counts as notable

Whatever LootLog itself considers notable, based on its own settings. In addition, if LibCharacterKnowledge is installed, any recipe, motif, furnishing plan or scribing script your character doesn't know yet counts as notable, whatever its quality. LootLog judges these items by their functional quality, so an unknown green recipe would otherwise be skipped.

## Settings

*Settings → Addons → LootLog Extras* (needs LibAddonMenu-2.0). All options are on by default.

- **Crafting stations:** log refining and deconstruction
- **Mail attachments:** log notable mail attachments
- **Unknown recipes, motifs and plans are notable:** the LibCharacterKnowledge check above

Without LibAddonMenu everything stays on.

## Upgrading from LootLogCraft / LootLogMail / LootLogFishing

This addon replaces all three. Disable or delete them. If one is still enabled, you get a reminder in chat, and the matching part of this addon stays off so nothing is logged twice.

LootLogFishing is not carried over. Since LootLog 4.7.3, LootLog counts rare fish as notable on its own.

## Requirements

- LootLog
- Optional: LibCharacterKnowledge, LibAddonMenu-2.0
