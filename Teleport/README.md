# Teleport

**Teleport** is a general purpose teleportation addon. Its main aim is to make teleportation a quick and pleasant experience, very different to what the game offers - minutes, if not _seconds (!!!)_ of looking trough menus, icons and lists. Ugh. The only extra feature it offers over in-game menus is teleporting to a specific house of any player. I took some ideas from [BeamMeUp](https://www.esoui.com/downloads/info2143-BeamMeUp-TeleporterFastTravel.html) as well from [Travelleer](https://www.esoui.com/downloads/info1744-Traveller-FastTravelRedesigned.html), you may want to check them out before deciding on what to use. **Teleport** is not supposed to replace any of the addons mentioned above, it just takes a different approach to mostly the same problem (ok now that I look at **Traveler**'s readme it seems painfully similar, sorry not sorry).

## Changelog

See [changelog.md on github](https://github.com/wjtk4444/eso-addons/blob/master/Teleport/changelog.md) (or in the addon folder)

## Features
- Teleporting to zones for free (using party members / friends / guildies)
- Teleporting to houses, other player's houses included (free, duh)
- Teleporting to dungeons/arenas/trials (free if any of the party members is already in, paid otherwise)
- Teleporting to specific wayshrines (always paid)

Note that when you're not teleporting to a player or his house, you need to have the destination discovered on current character. Game won't allow you to travel to unknown wayshrine or dungeon.

## Dependencies

- None

## Usage

### General informations

There is no graphical user interface provided, everything is done using a `/tp` command. If you're not a keyboard person, this is probably where our ways part. Have fun clicking trough all the carefully designed context menus and scrolling trough long lists.

`/tp help` as well as `/tp examples` commands are available, although I would recommend reading this very document instead.

**If the teleportation request will cost player any amount of gold, cost will be displayed in chat. You can cancel queued teleportation request at any time by simply moving your character.**

**`/tp` command arguments are separated by a single space.** Unless specified otherwise, **arguments are not case sensitive and will match the fist name that starts with given input**. For example, all of the words listed below:

- Deshaan
- desh
- Desha
- desHAan
- dEsH

will expand to their first match, **Deshaan**. However, the two examples presented below are not equal because of the additional space used in the second command.

- `/tp Deshaan`
- `/tp  Deshaan` (extra space between `/tp` and `Deshaan` is invisble, thanks github...)

Possible matches of every category are sorted (separately per category) in alphabetical order, which means that ie. **Vivec** will match **Vivec's Antlers** instead of **Vivec City** which most of the players would expect. If you want to travel specifically to **Vivec City** wayshrine, you need to either specify at least "**Vivec **" (note the extra space at the end), or create an alias. If you want to target wayshrines only, you can append "** Wayshrine **" at the end to avoid collisions with other names. User-defined aliases will be explained in a [later part of this manual](#aliases).

The input matching order is:

- User defined alias
- Internal commands (help, leader)
- Predefined dungeon/arena/trial alias
- Zone name
- Wayshrine name
- House name
- Full dungeon/arena/trial name

The order was chosen in a way that should generate the least amount of conflicts.

### Known bugs

Once in a blue moon you will get a "**No suitable location found to jump to**" message. It may happen when the player you're attempting to teleport to changed zones and is currently in the loading screen limbo, but the game still thinks that he's in the previous location (outdated cache). There is currently no plan of fixing or working around it. Just wait ~1s and try again.

### Teleporting to zones

To travel to any of the in-game zones, simply type `/tp <zone name prefix>` in chat. There are also [zone name aliases](#zones-httpsenuespnetwikionlinezonesoverworld_zones) available and they work the exact same way as regular zone names.

For example:

- `/tp Deshaan`
- `/tp desh`
- `/tp Vvardenfell`
- `/tp vv`

### Teleporting to houses

Same as zones: `/tp <house name prefix>`.

If you want to travel to other player's house, check the "Teleporting to other player's houses" section instead. If you want to travel outside of _your own_ house, prepend the name with "outside", ie.

- `/tp outside snugpod`

### Teleporting to wayshrines

Same as teleporting to zones: `/tp <wayshrine name prefix>`. If you want to avoid name collisions you can also use `/tp <full wayshrine name> Wayshrine` instead. Wayshrines are sorted alphabetically without the " Wayshrine" suffix, for example `/tp solitude` will take you to `Solitude Wayshrine` instead of `Solitude Docks Wayshrine`. 

### Teleporting to dungeons/arenas/trials

There is a list of [predefined aliases available](#trials-httpsenuespnetwikionlinetrials). You can view it at the end of this guide. Aliases contain all of the common shortcuts that players use (hopefully). **These aliases are still case insensitive, but other than that you have to use an exact match. HR won't expand to HRC, etc.** A few examples below:

- `/tp HRC`
- `/tp MoL`
- `/tp DSA`
- `/tp FG1`
- `/tp CoH2`

Additionally, you can prepend all of the aliases with **n**, **v** or **r** (for normal, veteran and a reset instance). In that case addon will attempt changing dungeon difficulty for you and your group.

- `/tp vHRC`
- `/tp NDSA`
- `/tp vcoh1`
- `/tp rCR`

If for whatever reason you prefer using full(er?) name instead, you're welcome to do the usual `/tp <dungeon name prefix>`.

### Teleporting to players

To travel to a player, first make sure he's in your group / friends / guild and online. This is an in-game restriction that cannot by bypassed. Command syntax is very similar to all other presented up to this point, the only difference being **@** symbol at the beginning of account name. `/tp @<account_name>`. Using character name instead is not supported, because I'm not convinced that it should be. Feel free to make it into a feature request, I might reconsider if you bring actual arguments.

Special `/tp leader` command works exactly the same as built-in `/jumptoleader`, it's just shorter to type (and aliasable, see [below](#aliases)) (yes, it takes you to the group leader). It also displays some extra info in the chat (unlike the built-in one), so you can abuse spamming it and cancelling teleport when waiting on leader to "port in". Though personally I'd spam `/tp <dungeon alias>` instead, maybe someone will be faster than the group leader.

### Teleporting to other players' houses

For group members / friends and guildies, the syntax is the same as when travelling to player, followed by house name. `/tp @account_name house name`. First word is considered account name prefix, everything else house name prefix. You can also use **primary** or **main** instead of house name, this will take you to player's primary residence instead. 
For every other player you need to use the **exact account name** and double **@** instead. For example:

- `/tp @@schrodingerscatgirl Snugpod`

will take you to this addon author's residence. Feel free to visit. For house name, you can still use prefixes instead of full names. 

By the way, did you know that account names in ESO are not case sensitive even though they appear as such? Now you do.

## Aliases

Hey, you. You're finally ~~awake~~ here.

At this point, if your brain hasn't melted yet from reading this huge wall of text, you must be thinking one thing:

> Oh, how convienient. Free teleporting to zones and dungeon aliases are pretty cool, but just imagine typing

> `/tp @@prettylongnameXXX69420_GAMER_69420XXX Hakkvild's High Hall`

> every time you want to visit your friends house. So simple, so elegant! I'm never using in-game menus again!

First - you could probably just do `/tp @pretty hakk`, but if there are name conflicts or that player is not online and in your party / friends / guild, or you still consider it too much writing - there's aliases. 

**You can alias any valid (or invalid...) input for something shorter and easier to remember.** There are 3 commands to operate on aliases:

- `/tp addAlias <alias name> <alias expansion>`
- `/tp delAlias <alias name>`
- `/tp lstAlias` (yes it's `lst`, not `list`)

As their syntax suggests, first is for adding, second for removing and third for listing saved aliases. Aliases are saved account wide, obviously. So, going back to the case of visiting your old friend with a very long name, you can do this (once):

- `/tp add 1 @@prettylongnameXXX69420_GAMER_69420XXX Hakkvild's High Hall`

and then just use `/tp 1` to get there. Obviously, you are not limited to using numbers. Anything works as long as it doesn't contain spaces. Just remember that aliases are **exact matches** and, unlike everything else in this addon: **case sensitive**. They are also first in the order of matching, which means you can even re-alias dungeons if that's what you desire.

Important: **Alias names can not contain spaces**.

As stated above, you can alias every possible command. Some examples below:

- `/tp addAlias fungal2 Fungal Grotto II`
- `/tp addAlias alkosh_farm vMoL`
- `/tp addAlias gf @nonexistentplayer`
- `/tp addAlias 3 @guildmaster primary`
- `/tp addAlias 7 @friend earthtear`
- `/tp addAlias nAA vHoF` (don't do that, it creates mustard gas)
- `/tp addAlias TeleportAuthorHouse @@schrodingerscatgirl Snugpod`

&nbsp;

- `/tp delAlias gf`
- `/tp delAlias nAA` (revert your misdoings to normal)

&nbsp;

- `/tp lstAlias`

## Maintenance

In the case of me ceasing to keep this addon up to date, here's all you need to know:

Pre-defined aliases in `Aliases.lua` as well as hardcoded lists of arenas (`Dungeons.lua`) and zones (`Zones.lua`) are required for everything to work as expected. If a new dungeon / arena / trial / zone is added, someone has to add new aliases and the lists.

> Any further instructions?

`README.md` is updated automatically with new aliases from `Aliases.lua` file. Just call `make` after doing any changes to `Aliases.lua`.

<!--splitter-->

### Zones: ([https://en.uesp.net/wiki/Online:Zones#Overworld_Zones](https://en.uesp.net/wiki/Online:Zones#Overworld_Zones))
|alias|full name|
|-|-|
|Reach                        | The Reach |
|Rift                         | The Rift |
|Arkthzand Cavern             | Blackreach: Arkthzand Cavern |
|Greymoor Caverns             | Blackreach: Greymoor Caverns |
|Elsweyr                      | Northern Elsweyr |
|Skyrim                       | Western Skyrim |
|Deadlands                    | The Deadlands |
|Isle                         | High Isle |

### Trials: ([https://en.uesp.net/wiki/Online:Trials](https://en.uesp.net/wiki/Online:Trials))
|alias|full name|
|-|-|
|as   | Asylum Sanctorium |
|aa   | Aetherian Archive |
|hrc  | Hel Ra Citadel |
|so   | Sanctum Ophidia |
|ss   | Sunspire |
|mol  | Maw of Lorkhaj |
|cr   | Cloudrest |
|hof  | Halls of Fabrication |
|ka   | Kyne's Aegis |
|rg   | Rockgrove |
|dr   | Dreadsail Reef |
|dsr  | Dreadsail Reef |

### Arenas: ([https://en.uesp.net/wiki/Online:Arenas](https://en.uesp.net/wiki/Online:Arenas))
|alias|full name|
|-|-|
|ma   | Maelstrom Arena |
|msa  | Maelstrom Arena |
|dsa  | Dragonstar Arena |
|bp   | Blackrose Prison |
|brp  | Blackrose Prison |
|va   | Vateshran Hollows |
|vh   | Vateshran Hollows |
|vha  | Vateshran Hollows |
|vsa  | Vateshran Hollows |
|vsh  | Vateshran Hollows |
|vsha | Vateshran Hollows |

### Base Game Dungeons: ([https://en.uesp.net/wiki/Online:Group_Dungeons](https://en.uesp.net/wiki/Online:Group_Dungeons))
|alias|full name|
|-|-|
|ac   | Arx Corinium |
|arx  | Arx Corinium |
|bc   | The Banished Cells I |
|bc1  | The Banished Cells I |
|tbc1 | The Banished Cells I |
|bc2  | The Banished Cells II |
|tbc2 | The Banished Cells II |
|bh   | Blackheart Haven |
|bc   | Blessed Crucible |
|coa  | City of Ash I |
|coa1 | City of Ash I |
|coa2 | City of Ash II |
|coh  | Crypt of Hearts I |
|coh1 | Crypt of Hearts I |
|coh2 | Crypt of Hearts II |
|dc1  | Darkshade Caverns I |
|dc2  | Darkshade Caverns II |
|dk   | Direfrost Keep |
|dfk  | Direfrost Keep |
|eh   | Elden Hollow I |
|eh1  | Elden Hollow I |
|eh2  | Elden Hollow II |
|fg   | Fungal Grotto I |
|fg1  | Fungal Grotto I |
|fg2  | Fungal Grotto II |
|sw   | Selene's Web |
|sc   | Spindleclutch I |
|sc1  | Spindleclutch I |
|sc2  | Spindleclutch II |
|ti   | Tempest Island |
|vom  | Vaults of Madness |
|vf   | Volenfell |
|ws   | Wayrest Sewers I |
|ws1  | Wayrest Sewers I |
|ws2  | Wayrest Sewers II |

### DLC Dungeons: ([https://en.uesp.net/wiki/Online:Group_Dungeons](https://en.uesp.net/wiki/Online:Group_Dungeons))
|alias|full name|
|-|-|
|icp  | Imperial City Prison |
|ic   | Imperial City Prison |
|ip   | Imperial City Prison |
|wgt  | White-Gold Tower |
|cos  | Cradle of Shadows |
|rom  | Ruins of Mazzatun |
|maz  | Ruins of Mazzatun |
|mazz | Ruins of Mazzatun |
|bf   | Bloodroot Forge |
|brf  | Bloodroot Forge |
|fh   | Falkreath Hold |
|fkh  | Falkreath Hold |
|fl   | Fang Lair |
|sp   | Scalecaller Peak |
|scp  | Scalecaller Peak |
|mos  | March of Sacrifices |
|mk   | Moon Hunter Keep |
|mhk  | Moon Hunter Keep |
|dom  | Depths of Malatar |
|fv   | Frostvault |
|lom  | Lair of Maarselok |
|mf   | Moongrave Fane |
|mgf  | Moongrave Fane |
|ir   | Icereach |
|ice  | Icereach |
|ug   | Unhallowed Grave |
|uhg  | Unhallowed Grave |
|ct   | Castle Thorn |
|sg   | Stone Garden |
|bdv  | Black Drake Villa |
|bv   | Black Drake Villa |
|bd   | Black Drake Villa |
|dv   | Black Drake Villa |
|tc   | The Cauldron |
|cd   | The Cauldron |
|c    | The Cauldron |
|tdc  | The Dread Cellar |
|dc   | The Dread Cellar |
|rpb  | Red Petal Bastion |
|ca   | Coral Aerie |
|sr   | Shipwright's Regret |
|ere  | Earthen Root Enclave |
|gd   | Graven Deep |
