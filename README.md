# eso-addons

Addons for The Elder Scrolls Online that I wrote or reworked. Each folder is one addon with its own README.

## Combat

| Addon | |
|---|---|
| [AmIStunned](AmIStunned) | A reliable STUNNED / ROOTED / BLOCKING indicator in the middle of the screen. |
| [ImprovedDeathRecapVanillaUI](ImprovedDeathRecapVanillaUI) | [Improved Death Recap](https://www.esoui.com/downloads/info1319-ImprovedDeathRecap.html)'s data (by Solinur) in the game's own death recap window. Needs Improved Death Recap. |
| [SchrodisTickTracker](SchrodisTickTracker) | [Miat's Tick Tracker](https://www.esoui.com/downloads/info1989-MiatsTickTracker.html) reworked: shows when your next stamina regen tick lands, right on the game's stamina bar. |
| [SkillIssue](SkillIssue) | Blocks chosen skills from being cast: always, in combat or out of combat. |
| [UltimateRegenTimer](UltimateRegenTimer) | Counts down the 8 seconds of passive ultimate generation after a light attack, block or dodge. |

## Groups, dungeons and PvP

| Addon | |
|---|---|
| [AddedInfoUnitFrames](AddedInfoUnitFrames) | Role colors, large frames for groups of up to 12 in a role-sorted grid, class icon and CP. Fork of @MrPikPik's [Added Info - Unit Frames](https://www.esoui.com/downloads/info2771-AddedInfo-UnitFrames.html). |
| [DungeonSorter](DungeonSorter) | Sorts the dungeon list in the Activity Finder alphabetically. |
| [DungeonTimerTrial](DungeonTimerTrial) | Adds trials and arenas to @code65536's [Dungeon Timer](https://www.esoui.com/downloads/info2262-DungeonTimer.html). |
| [EvenBetterScoreboard](EvenBetterScoreboard) | Battleground scoreboard with damage, healing and class icons, plus multi-queue. Based on @M0R_Gaming's [Better Scoreboard](https://www.esoui.com/downloads/info3182-BetterScoreboard.html). |
| [RideAlong](RideAlong) | One keybind to ride a group member's multi-rider mount. |
| [SchrodisWardrobe](SchrodisWardrobe) | [Wizard's Wardrobe](https://www.esoui.com/downloads/info3170-WizardsWardrobe.html) pages for every Armory build. |
| [Teleport](Teleport) | `/tp` for every kind of travel: zones, dungeons, houses, players, survey maps, quests. |

## Inventory, crafting and housing

| Addon | |
|---|---|
| [AutoAcceptNextWrit](AutoAcceptNextWrit) | Accepts the next crafted master writ right after a turn-in. |
| [BagWatcher](BagWatcher) | Free bag space next to the FPS / latency meters. |
| [EssentialSnugpodTools](EssentialSnugpodTools) | The Snugpod magic: a door that animates furniture in one particular house. Needs decorating permission there. |
| [ExtraTTCTooltips](ExtraTTCTooltips) | TTC prices where Tamriel Trade Centre doesn't add them: housing Retrieve list, Character Knowledge. |
| [HideInventoryClutter](HideInventoryClutter) | Hides locked gear and consumables; shows only items worth deconstructing or selling. |
| [LibDeconValue](LibDeconValue) | Shows the average value of what you'd get from deconstructing an item in its tooltip, next to the vendor price; with a learning mode. Also a library for other addons. Started from otac0n's [ESO-LibLootStats](https://github.com/otac0n/ESO-LibLootStats). |
| [LootLogExtras](LootLogExtras) | Logs crafting-station results, mail and trades into @code65536's [LootLog](https://www.esoui.com/downloads/info1455-LootLog.html). |
| [SchrodisHousingTools](SchrodisHousingTools) | Assistants from your quickslots, /storage, housing editor and Furniture Vault quality of life. |
| [SplitAndWithdraw](SplitAndWithdraw) | Split or withdraw 1/2/3/5/10/25/50/100 items from the right-click menu. Based on [Stack Master](https://www.esoui.com/downloads/info2508-StackMaster.html). |
| [TTCDealFilter](TTCDealFilter) | Master Merchant's guild store deal rating, filter and sort for AwesomeGuildStore, using Tamriel Trade Centre prices. |
| [XLGearBanker](XLGearBanker) | Move whole gear sets (and consumables) between bags and bank. Fork of @XL_Olsen's [XL Gear Banker](https://www.esoui.com/downloads/info2482-XLGearBanker.html), GPLv3. |

## Exploration and gathering

| Addon | |
|---|---|
| [DeclutteredScryingLeads](DeclutteredScryingLeads) | A filter dropdown for the Antiquities All Leads list: hide antiquities you've already dug up unless the reward or codex is worth it. |
| [FishThief](FishThief) | Picks the right bait for every fishing hole and tells you when a fish bites. Inspired by [Fisherman's Friend](https://www.esoui.com/downloads/info2731-FishermansFriend.html). |

## Social

| Addon | |
|---|---|
| [BetterSocialSearch](BetterSocialSearch) | Friends list and guild roster search also finds notes and zones. |

## Installation

1. **[Download all addons as a ZIP](https://github.com/wjtk4444/eso-addons/archive/refs/heads/master.zip)** (or *Code → Download ZIP* on GitHub).
2. Open the ZIP. Inside the `eso-addons-master` folder there is one folder per addon. Copy the ones you want (the addon folders themselves, not `eso-addons-master`) into `Documents/Elder Scrolls Online/live/AddOns/`. Create the `AddOns` folder if it doesn't exist.
3. Enable them in the game's AddOns menu.

Check each addon's README for the libraries it needs; those are on [ESOUI](https://www.esoui.com/) and in Minion.

The `master` branch holds the versions I use myself, but there are no release builds, so a commit can occasionally be broken.
