# Teleport

**Teleport** is a general purpose teleportation addon. It's main aim is to make teleportation a quick and pleasant experience, very different to what game offers - minutes, if not _seconds (!!!)_ of looking trough menus, icons and lists. Ugh. The only extra feature it offers over in-game menus is teleporting to a specific house of any player. I took some ideas from [BeamMeUp](https://www.esoui.com/downloads/info2143-BeamMeUp-TeleporterFastTravel.html) as well from [Travelleer](https://www.esoui.com/downloads/info1744-Traveller-FastTravelRedesigned.html), you may want to check them out before deciding on what to use. **Teleport** is not supposed to replace any of the addons mentioned above, it just takes a different approach to mostly the same problem (ok now that I look at **Traveler**'s readme it seems painfully similar, sorry not sorry).

## Features
- Teleporting to zones for free (using party members / friends / guildies quick and)
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
- `/tp  Deshaan`

Technically, `/tp  ` as well as `/tp addAlias     ` are perfectly valid commands. The first will attempt to teleport you to a location which name starts with a space and the other will alias a single space to a double space.

Possible matches of every category are sorted (separately per category) in alphabetical order, which means that ie. **Vivec** will match **Vivec's Antlers** instead of **Vivec City** which most of the players would expect. If you want to travel specifically to **Vivec City** wayshrine, you need to either specify at least "**Vivec **" (note the extra space at the end), or create an alias. Aliases will be explained in a later part of this manual.

The input matching order is:

- User defined alias
- Internal commands (help, leader)
- Predefined dungeon/arena/trial alias
- Zone name
- Wayshrine name
- House name
- Dungeon name

The order was chosen in a way that should generate the least amount of conflicts.

### Known bugs

Once in a blue moon you will get a "**No suitable location to jump to**" (or something similar, can't really reproduce it on demand) message. It may happen when the player you're attempting to teleport to changed zones and is currently in the loading screen limbo, but the game still thinks that he's in the previous location (outdated cache). There is currently no plan of fixing or working around it. Just wait ~1s and try again.

### Teleporting to zones

To travel to any of the in-game zones, simply type `/tp <zone name prefix>` in chat.

For example:

- `/tp Deshaan`
- `/tp desh`
- `/tp Vvardenfell`
- `/tp vv`

### Teleporting to houses

Same as zones: `/tp <house name prefix>`.

If you want to travel to other player's house, check the "Teleporting to other player's houses" section instead.

### Teleporting to wayshrines

Same as teleporting to zones: `/tp <wayshrine name prefix>`.

### Teleporting to dungeons/arenas/trials

There is a list of predefined aliases available. You can view it at the end of this guide. Aliases contain (hopefully) all of the common shortcuts that players use. **Predefined aliases are still case insensitive, but other than that you have to use an exact match. HR won't expand to HRC, etc.** A few examples below:

- `/tp HRC`
- `/tp MoL`
- `/tp DSA`
- `/tp FG1`
- `/tp CoH2`

Additionally, you can prepend all of the aliases with **n** or **v** (for normal and veteran). In that case addon will attempt changing dungeon difficulty for you and your group. Note that this is currently a little bit **bRoKEn**. You can thank ZOS for that, hopefully next game update will resolve it and I will finally be able to adjust this feature to work as initially intended. Basically, don't bother unless you're in group and you're a group leader. Also, note that changing difficulty when someone from the team is in arena/dungeon/trial will kick them. Again, blame ZOS, not me.

If for whatever reason you prefer using full(er?) name instead, you're welcome to do the usual `/tp <dungeon name prefix>`.

### Teleporting to players

To travel to a player, first make sure he's in your group / friends / guild and online. This is an in-game restriction that cannot by bypassed. Command syntax is very similar to all other presented up to this point, the only difference being **@** symbol at the beginning of account name. `/tp @<account_name>`. Using character name instead is not supported, because I'm not convinced that it should be. Feel free to make it into a feature request, I might reconsider if you bring actual arguments.

Special `/tp leader` command works exactly the same as built-in `/jumptoleader`, it's just shorter to type (and aliasable, see below). (Yes, it takes you to the group leader. It also displays some extra info in the chat (unlike the build one), so you can abuse spamming it and cancelling teleport when waiting on leader to "port in". Though personally I'd spam `/tp dungeon_alias` instead, maybe someone will be faster than the group leader.

### Teleporting to other players' houses

For group members / friends and guildies, the syntax is the same as when travelling to player, only followed by house name. `/tp @account_name house name`. First word is considered account name prefix, everything else house name prefix. You can also use **primary** or **main** instead of house name, this will take you to player's primary residence instead. This shouldn't be a problem because ESO doesn't allow for account names with spaces. If you were thinking about opening a feature request mentioned above - think again. 

For every other player you need to use the **exact account name** and double **@** instead. For example:

- `/tp @@schrodingerscatgirl Snugpod`

will take you to this addon author's residence. Feel free to visit. For house name, you can still use prefixes all you want. 

By the way, did you know that account names in ESO are not case sensitive even though they appear as such? Now you do.

## Aliases

Hey, you. You're finally ~~awake~~ here.

At this point, if your brain hasn't melted from reading this huge wall of text, you must be thinking one thing:

> Oh, how convienient. Free teleporting to zones and dungeon aliases are pretty cool, but just imagine typing

> `/tp @@prettylongnameXXX69240_GAMER_69420XXX Hakkvild's High Hall`

> every time you want to visit your friends house. So simple, so elegant, I'm never using in-game menus again!

First - you could probably just do `/tp @pretty hakk`, but if there are name conflicts or that player is not online and in your party / friends / guild, or you still consider it too much writing - there's aliases. 

**You can alias any valid (or invalid...) input for something shorter and easier to remember.** There are 3 commands to operate on aliases:

- `/tp addAlias <alias name> <alias expansion>`
- `/tp delAlias <alias name>`
- `/tp lstAlias` (yes it's `lst`, not `list`)

As their syntax suggests, first is for adding, second for removing and third for listing saved aliases. Aliases are saved account wide, obviously. So, going back to the case of visiting your old friend with a very long name, you can do this (once):

- `/tp add 1 @@prettylongnameXXX69240_GAMER_69420XXX Hakkvild's High Hall`

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

Pre-defined aliases in `Aliases.lua` and a hardcoded list of arenas in `Dungeons.lua` are required for everything to work as expected. If a new dungeon / arena / trial is added, someone has to update the aliases and the list of arenas.
Technically, users could add their own aliases for new dungeons, ie.

`/tp addAlias ct CastleThorn`

but some features such as dungeon difficulty changing, or aliases being case insensitive won't work. Also, if ZOS decides to bless us with a fourth arena, teleporting to it won't work at all unless someone adds it to the list in `Dungeons.lua`. If you're really that interested in _why_, go ahead and check the commends in `Dungeons.lua` file. Enjoy your brain smoothening experience provided to you by Zenimax™.

> Any further instructions?

Nope, if you can't figure out the correct syntax by just looking at the code - just leave the maintenance of this addon to someone else.

## List of aliases:

