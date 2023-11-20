### 1.1.2
- fixed built-in alias expansions for zone names (ie. Deadlands -> The Deadlands, etc.)
- calling `/tp` without arguments will now tell you to use `/tp --help` instead of matching the first node on the list
- sub-zones are now searchable as well (ie. Fargrave)

### 1.1.1
- added support for Endless Archive (alias: EA)
- minor fixes and qol improvements
- fixed command conflict with Pithka's Achievement Tracker - now Teleport's `/tp` command will always be preferred if both addons are installed

### 1.1.0
- added alias for Sanity's Edge trial (SE)
- Zone list is no longer dependent on addon updates - as a side effect added Necrom and Telvanni Peninsula
- expanded surveymaps feature to include paid teleport
- minor ui rework, chat messages are now colorful, less versatile and cleaner
- major rework of how things are handled internally

### 1.0.16
- added Bal Sunnar and Scrivener's Hall
- removed some old, unused aliases
- changed addAlias, delAlias and lstAlias commands to --add, --remove and --list
- changed SurveyMaps command to surveymaps
- updated readme

### 1.0.15
- added Galen zone (yes, finally applies here as well)
- added a new feature - travel to a reset instance 
`rDungeonAlias`, similar to previously available `nDungeonAlias` or `vDungeonAlias`, ie.
- `nKA` - normal Kyne's Aegis
- `rCA` - reset instance of Coral Aerie
- `vSS` - veteran Sunspire
Resets the instance or assumes that instance was already reset by a group leader. 
This is always a paid teleport. Same as with other paid teleports, you can 
mitigate the cost by having a wayshrine menu open.

### 1.0.14
- added Earthen Root Enclave and Graven Deep dungeons (finally)
- added a new feature - travel to survey map zones from your inventory 
`/tp SurveyMaps` - it can be aliased just like any other command

### 1.0.13
- added Rockgrove (finally)
- updated for Deadlands
- updated for Waking Flame
- updated for Ascending Tide
- updated for High Isle
- player names can now be clicked (left and right click) for player interactions
- fixed a minor issue regarding teleporting to zones that prevent fast travel

### 1.0.11
- updated for Blackwood

### 1.0.10
- added two new dungeons
- added the ability to teleport outside of owned houses

### 1.0.9
- improved alphabetical sorting for wayshrines, now the " Wayshrine" suffix is ignored
- some internal changes and refactoring that shouldn't affect end-user experience

### 1.0.8
- restored the ability to travel to houses you don't own (preview mode)

### 1.0.7
- changed how wayshrines are handled (restored "wayshrine" suffix in names)
- fixed group difficulty settings being read incorrectly at times
- added zone aliases
- other minor or major improvements not directly visible to the users

### 1.0.6
- improved dungeon difficulty changing for groups
- fixed dungeon difficulty changing when not in a group

### 1.0.5
- added "The Reach" to the zones list

### 1.0.4
- fixed an issue with aliases starting with 'n' or 'v' (Vateshran Hollows)

### 1.0.3
- updated for Markarth

### 1.0.2
- fixed pre-defined aliases being broken for trials and dungeons (thanks to my trigger-happy regex replace)

### 1.0.1
- added sanity check for addAlias
- minor refactoring, stop leaking global variables all over the place

### 1.0
- initial release
