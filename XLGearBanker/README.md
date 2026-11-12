# XL Gear Banker

Keeps gear sets as lists and moves a whole set between your bags and the bank (or house storage) with one click. Useful when you keep a lot of gear in the bank and only carry what you need.

## Changes in this fork

- **Stackable items in sets:** potions, poisons, food, drinks, siege weapons, repair kits and recall stones can be added to a set too. They are tracked by item type rather than by the individual item, and **every** stack of them is moved (siege weapons with different durability don't stack, so they used to need one click per piece).
- **More reliable transfers:** a move that fails because the server hasn't caught up yet is retried a few times instead of cancelling the whole transfer, and the error message no longer crashes when the bag is full.
- A taller set window.

## Credits

**XL Gear Banker** was written by **@XL_Olsen** ([GitHub](https://github.com/xlolsen/XLGearBanker)) and is no longer maintained. It's licensed under the **GNU GPL v3**, and so is this fork (see `LICENSE`).

## Requirements

- LibCustomMenu, LibDialog, LibShifterBox, LibAddonMenu-2.0
