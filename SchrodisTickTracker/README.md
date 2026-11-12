# Schrodi's Tick Tracker

Stamina in ESO doesn't regenerate continuously; it comes back in a tick every 2 seconds. This addon shows when the next tick will land, right on the game's own stamina bar, so you can time sprinting, dodging and blocking around it.

<!-- screenshot: stamina bar with the arrow and a "+1234" tick -->

- **An arrow sweeps across the stamina bar** over 2 seconds. When it reaches the end, the next tick lands.
- **The tick amount** (e.g. `+1234`) pops up above the bar for a moment.
- **The bar turns grey while your regen is zero**, for example while sprinting, blocking or crouching, so you notice that you're not getting anything back.

The timing comes from the ticks themselves: the addon watches for a stamina gain equal to your regen stat and syncs to it, ignoring gains from potions, skills and procs.

## Credits

This addon is a reworked **Miat's Tick Tracker** (MiatsTickTracker). The idea and the tick detection come from it; this version has a different UI, drawn directly on the default stamina bar, and a few improvements.

## Settings

None. It tracks stamina on the default (vanilla) attribute bars and doesn't play a sound on each tick. The code can also track magicka or health, and play a sound, but only by changing `addonDefaults` at the top of `SchrodisTickTracker.lua`.

## Requirements

None. It needs the game's default attribute bars, so it won't show up with addons that replace them.
