EvenBetterScoreboard (successor to BetterBetterScoreboard) is a self-contained battlegrounds
addon -- it does not require, and does not touch, Better Scoreboard or BetterBetterScoreboard.
Disable/remove both of those if you have them installed, since all three hook the same base-game
controls and would collide. It also absorbs BattlegroundModeSaver's functionality (see below),
so that addon can be removed too:

- Damage/heal numbers (stacked next to Score) and class icons on the battlegrounds scoreboard,
  with the row height pinned back to what the base game intended. The base game's own separate
  Damage/Heals/game-type (flag) columns are hidden and the window narrowed to match. Big lobbies
  (9v9, 6v6v6) fit without a scrollbar: the list grows with the screen height, and rows are
  spaced tighter when needed.
- Shows just one name per scoreboard row -- character or account name, whichever the game's own
  "Prefer Player Character Names" setting says.
- An "EBS BG Queue" tab in the Group & Activity Finder (positioned right after Battlegrounds)
  for queuing multiple battleground types at once, styled like the game's own activity-finder
  lists: checkboxes with a hover highlight, your current veterancy rank (icon, rank, name, XP
  bar -- same as the Battlegrounds screen's own display) below the hint text, and Join Queue +
  View Veterancy buttons sharing the same position and spacing as the built-in panels, so
  everything lines up with them. Queue names are colored the same way they read in-game
  (Competitive gold, Standard/Weekly/Weekend green). Your ticked queues are remembered between
  sessions. The Join Queue button greys out whenever it wouldn't do anything -- no queue ticked, already
  searching/queued, mid ready check, the Group Finder in use, or during the cooldown below --
  same as the built-in Join Queue button. The checkboxes themselves lock while you're already
  queued/searching or mid ready check too (same as the built-in filter list) -- they keep showing
  what you're queued for, just can't be changed until you leave the queue; the decline/timeout
  cooldown by itself does not lock them. The queue list stays live too: it refreshes on level up,
  campaign switches, and holiday/weekly events starting or ending, so a queue unlocking, a weekly
  appearing, or one disappearing mid-session shows up without a /reloadui.
- "Queue <name>" shortcut buttons above Join Queue / View Veterancy (e.g. "Queue 4v4
  Competitive", "Queue Big Team Battles"), one per queue currently on offer -- a queue's Solo and
  Group variants share one button (matched by name with "Solo"/"Group" removed). One click
  selects every variant and joins the queue immediately. Up to 6, 2 per row. They grey out under the same
  conditions as Join Queue -- already queued/searching, mid ready check, the Group Finder in use,
  or on the cooldown below.
- A "Requeue automatically" checkbox on the panel. Off by default and never saved (always resets
  on /reloadui or relog). When checked, explicitly declining a ready check requeues you for the
  same queues once the cooldown below ends. A ready check timing out, or manually leaving the
  queue, never triggers a requeue, even with the checkbox on. Its current state also shows as an
  "Auto requeue: On/Off" row right above "Status: Queued" in the Group & Activity Finder window,
  so it's visible from there too.
- A cooldown timer (30s) that replaces the "Status: Queued / Actual:" text in the Group &
  Activity Finder window after declining a ready check (or letting it time out), so you can see
  when you're allowed to requeue again; the "Join Queue" button above is disabled for the same
  duration. Accepting a ready check does not trigger this. By design, the timer only shows up
  while that window happens to be open -- those labels don't exist anywhere else.
- For anyone who prefers the built-in Battlegrounds queue screen over the "EBS BG Queue" panel
  above: its mode dropdown now remembers your last selection and restores it automatically, across
  UI reloads and relogs, account-wide (not per-character). Ported from the standalone
  BattlegroundModeSaver addon -- no chat messages, no separate addon needed.
- Optional settings panel (requires LibAddonMenu-2.0, under Settings -> Even Better Scoreboard):
  a "Player name display" dropdown (Default/respect game settings, @UserID, Character Name,
  @UserID (Character Name), or Character Name (@UserID)) for the scoreboard's name column; a
  "Remember last battleground mode in vanilla finder" checkbox (on by default) toggling the
  built-in Battlegrounds screen's mode memory described above; a "Show quick queue buttons"
  checkbox (on by default) for the "Queue ..." shortcuts; and 4 colorpickers --
  Competitive queue color, Standard queue color (also used for Weekly/Weekend), Healing Done
  color, and Damage Done color -- all defaulting to the colors described above. Every setting is
  account-wide and applies immediately, no reload needed. If LibAddonMenu-2.0 isn't installed,
  this panel is simply skipped and everything keeps working with its defaults.
