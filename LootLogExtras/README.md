# LootLog Extras

An add-on for Code's **LootLog** (by @code65536). LootLog records what you loot, but it only sees items that come from looting. This addon adds crafting stations, mail and trades.

## Crafting stations

Materials you get from **refining** raw materials and from **deconstructing** gear at a crafting station. This includes the deconstruction assistant and materials that go straight into the Craft Bag with ESO Plus.

Every material is written to the history, the same way LootLog records all loot. A chat note appears only when something in the batch is notable:

> From refining 100 raw materials: [Tempering Alloy] x1
> From deconstruction: [Dreugh Wax] x1

## Mail

Items and gold you take from mail, with **one chat line per mail**. This works for a single mail and for **Take All (System)** / **Take All (Player)**:

> (Mail) Raw Woodworker Materials: 1x [Rosin]
> (Mail) @friend: 3x [Dreugh Wax], 500 gold
> (Mail) Item Sold 1x [Perfect Roe] for 10,000 gold

System mail (hirelings, rewards, the guild store) is labeled with its subject, player mail with the sender.

- Only **notable** items are written to the history and shown. A mail without notable items (and without gold, see below) gets no line, so five hireling mails with two notable items give two lines.
- **Take All:** the game only reveals what's attached to a mail after the mail has been opened. So when you confirm Take All, the addon first opens the unread mails in that category one by one (the server allows one at a time), then takes everything. With many unread mails this takes a few seconds; clicking Take All again meanwhile does nothing, and you can close the mail window right away: the mailbox stays open behind the scenes until the reading and the take are done. If a mail can't be read in time, its items are still logged, together under "Take All (System)".
- **Guild store sales**: "Item Sold" mails only contain gold, but their text names the sold item ("An item you listed has sold. (…)"; with AwesomeGuildStore its own "You sold 1x … to @buyer for …"). The item is taken from there, so the mails are read before Take All as well. Sometimes the game fills in "(Data not available)" instead of the item, even for a mail that showed the item when you opened it. So the item is remembered as soon as a mail text names it (when the mail is read or shown in the mail window), and a mail that still says "(Data not available)" is read again a few times before Take All. If no text ever names it, the sale is looked up in the guild history (LibHistoire), matched by time and amount; if that fails too, the line has only the gold ("(Mail) Item Sold for 10,000 gold").
- Only what actually arrived is logged. If your bags are full and part of a Take All fails, the missing items aren't logged.
- Items and gold that arrive while a take is still running but don't come from mail (a container opened right away by AutoUnbox or Unboxer, loot picked up meanwhile) are left out. LootLog already logs those itself.

## Trades

Everything another player gives you in a completed trade, as one chat line:

> (Trade) @friend: 2x [Dreugh Wax], 1x [Kuta], 10,000 gold

Every received item is written to the history, notable or not. Cancelled trades are ignored.

## Gold

Gold from player mail, guild store sales and trades appears in the chat lines above. Gold that comes with other system mail (quest rewards and the like) is left out. LootLog's history only stores items, so gold isn't in the history.

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
- Optional: LibCharacterKnowledge (unknown recipes and motifs), LibAddonMenu-2.0 (settings), LibHistoire (sold items the mail text doesn't name)
