# Setting up the rest of the layout

ForeverXIUI places its own frames. The Blizzard pieces below are moved in Edit Mode or the chat settings, with no addon code. Mockup: `ForeverXIUI-mockups/layout-v1.png` in the project files.

## Before you start
- Turn off **BetterBlizzFrames** in the AddOns list. It restyles the Blizzard player, target and party frames that ForeverXIUI hides, and the two can fight. Plater stays for nameplates.
- Details! is optional, since the built-in damage meter covers it.

## Edit Mode (Esc > Edit Mode)
`/fxiui move` turns on by itself while Edit Mode is open, so ForeverXIUI's frames can be dragged in the same pass.
1. **Minimap**: drag it to the top-left corner.
2. **Objective (quest) tracker**: drag it under the minimap on the left. Set its height so it stops above the chat.
3. **Damage meter**: drag it to the bottom-right corner.
4. **Action bars**: on Action Bar 1, lower **Icon Size** (around 80%) and **# of Icons** if you want fewer. Turn off any bars you don't use under the Edit Mode checkboxes. Keep them at the bottom centre under your player bar.
5. **Buffs/debuffs**: leave them top right, or move them next to the minimap.
6. Save the layout (Save As > "ForeverXIUI").

## Chat: combat log above, chat below
1. Right-click the **Combat Log** tab > **Unlock Window**, then drag the tab away from the dock so it becomes its own window.
2. Drag it above the General window, bottom left. Resize both to the same width (drag the bottom-right corner).
3. Right-click each tab > **Lock Window**.
4. Timestamps like XI: Esc > Options > Social > Chat Timestamps.

ForeverXIUI's chat skin puts the navy XI window behind both, with the window name in the top-right corner.
