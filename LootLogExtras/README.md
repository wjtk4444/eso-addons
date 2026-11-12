# LootLog Extras

An add-on for Code's **LootLog** (by @code65536). LootLog records what you loot, but it only sees items that come from looting. This addon adds crafting stations, mail and trades.

## Crafting stations

Materials you get from **refining** raw materials and from **deconstructing** gear at a crafting station. This includes the deconstruction assistant and materials that go straight into the Craft Bag with ESO Plus.

Every material is written to the history, the same way LootLog records all loot. A chat note appears only when something in the batch is notable:

> From refining 100 raw materials: [Tempering Alloy] x1
> From deconstruction: [Dreugh Wax] x1

## Mail

Items and gold you take from mail, with **one chat line per mail**. This works for a single mail and for **Take All (System)** / **Take All (Player)**:

> (Mail) Woodworker Hireling: 1x [Rosin]
> (Mail) @friend: 3x [Dreugh Wax], 500 gold
> (Mail) Item Sold | 1x [Perfect Roe] | 10,000 gold

- Only **notable** items are written to the history and shown. A mail without notable items (and without gold, see below) gets no line, so five hireling mails with two notable items give two lines.
- **Take All:** the game only reveals what's attached to a mail after the mail has been opened. So when you confirm Take All, the addon first opens the unread mails in that category one by one (the server allows one at a time), then takes everything. With many unread mails this takes a few seconds; above three you get a chat note. If a mail can't be read in time, its items are still logged, together under "Take All (System)".
- **Guild store sales** ("Item Sold" mails) only contain gold. The sold item is looked up in the guild history, matched by time and amount, the same way AwesomeGuildStore does it. This needs **LibHistoire**; without it, or if the sale isn't in the history yet, the line shows just the gold.
- Only what actually arrived is logged. If your bags are full and part of a Take All fails, the missing items aren't logged.

## Trades

Everything another player gives you in a completed trade, as one chat line:

> (Trade) @friend: 2x [Dreugh Wax], 1x [Kuta], 10,000 gold

Every received item is written to the history, notable or not. Cancelled trades are ignored.

## Gold

Gold from mail and trades appears in the chat lines above. LootLog's history only stores items, so gold isn't in the history.

## What counts as notable

Whatever LootLog itself considers notable, based on its own settings. In addition, if LibCharacterKnowledge is installed, any recipe, motif, furnishing plan or scribing script your character doesn't know yet counts as notable, whatever its quality. LootLog judges these items by their functional quality, so an unknown green recipe would otherwise be skipped.

## Settings

*Settings → Addons → LootLog Extras* (needs LibAddonMenu-2.0). All options are on by default.

- **Crafting stations:** log refining and deconstruction
- **Mail attachments:** log notable mail attachments
- **Trades:** log what you receive in trades
- **Gold from mail and trades:** add received gold to the mail and trade lines
- **Unknown recipes, motifs and plans are notable:** the LibCharacterKnowledge check above

Without LibAddonMenu everything stays on.

## Upgrading from LootLogCraft / LootLogMail / LootLogFishing

This addon replaces all three. Disable or delete them. If one is still enabled, you get a reminder in chat, and the matching part of this addon stays off so nothing is logged twice.

LootLogFishing is not carried over. Since LootLog 4.7.3, LootLog counts rare fish as notable on its own.

## Requirements

- LootLog
- Optional: LibCharacterKnowledge (unknown recipes and motifs), LibHistoire (items sold in the guild store), LibAddonMenu-2.0 (settings)
