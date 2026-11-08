-- Every ForeverXIUI option, as a list of pages. Config.lua draws them in
-- the ForeverXIUI window (/fxiui, or click a frame in /fxiui move). The
-- game's Esc > Options > AddOns > ForeverXIUI page only has a button that
-- opens that window. Also the /fxiui slash command.
local _, ns = ...

local M = ns.AddModule("Options")

-- Page items:
--   check:  tbl[key] true/false
--   slider: tbl[key] number (lo..hi by step, shown with fmt)
--   button: runs fn
--   header: a heading line
-- reload = true means the change only shows after a /reload.
-- onChange(value) replaces the usual "apply scale and re-lay-out".
local function C(tbl, key, label, tip, reload)
  return { kind = "check", tbl = tbl, key = key, label = label, tip = tip, reload = reload }
end
local function S(tbl, key, label, lo, hi, step, fmt, tip, default, onChange)
  return { kind = "slider", tbl = tbl, key = key, label = label, lo = lo, hi = hi, step = step,
    fmt = fmt or "%.2f", tip = tip, default = default, onChange = onChange }
end
local function B(label, button, fn, tip)
  return { kind = "button", label = label, button = button, fn = fn, tip = tip }
end
local function H(text) return { kind = "header", label = text } end
local function Col(tbl, key, label, default, tip)
  return { kind = "color", tbl = tbl, key = key, label = label, default = default, tip = tip }
end

local SIZE_LABELS = {
  player = "Player bar size", playerCast = "Your cast bar size", target = "Target bar size",
  targetCast = "Target cast bar size", tot = "Target of target size", party = "Party list size",
  raid = "Raid list size", xp = "EXP bar size", enemy = "Enemy list size", menu = "Menu size",
  totems = "Totem bar size", swing = "Swing timer size", notify = "Notification size",
  loot = "Treasure pool size", reminders = "Buff reminder size", nameplates = "XI nameplate size",
}
local SIZE_ORDER = { "player", "playerCast", "target", "targetCast", "tot", "party", "raid", "xp",
  "enemy", "menu", "totems", "swing", "notify", "loot", "reminders", "nameplates" }

local function Size(key)
  return S(ns.db.frameScale, key, SIZE_LABELS[key], 0.5, 2, 0.05, "%.2f",
    "This frame's size, multiplied with the overall scale.", 1)
end

-- Built fresh each time the window opens, so it always points at the
-- current saved settings (an import replaces them).
function M.Pages()
  local db = ns.db
  local m = db.modules
  local pages = {}
  local function Page(name, movers, items)
    pages[#pages + 1] = { name = name, movers = movers or {}, items = items }
  end
  local function Pr() return ns.modules.Profile end

  Page("General", nil, {
    S(db, "scale", "Overall scale", 0.6, 1.6, 0.05, "%.2f", "Size of every ForeverXIUI frame.", 1),
    C(db, "compact", "Compact mode", "Narrower bars."),
    C(db.look, "classicColors", "WoW health and power colours", "Red health, Blizzard's mana/rage/energy colours. Off: XIUI's colours.", true),
    C(db.look, "hpBands", "Health changes colour as it drops", "XIUI's red, orange and yellow steps.", true),
    C(db.look, "rounded", "Rounded corners", "Softly rounded corners on every ForeverXIUI window.", true),
    C(db.look, "shine", "Shine on bars", "The light gradient over the fills.", true),
    H("Layout"),
    B("Move frames", "Move", function() ns.Movers.Toggle() end,
      "Drag any ForeverXIUI frame. Click one to jump to its options here. Also /fxiui move."),
    B("Pretend party and raid", "Preview", function() ns.SetPreview(not ns.previewOn) end,
      "Shows a full pretend party and raid to place and size them. Also /fxiui preview."),
    B("Edit Mode list", "Tidy", function() local pr = Pr(); if pr then pr.RunTidy(true) end end,
      "Unticks the HUD Edit Mode entries ForeverXIUI replaces (target and focus, party, raid, cast bar, totem bar, swing timer, status bar 2, and boss frames when those are hidden), then reloads. Importing a profile does this too. Also /fxiui tidy."),
  })

  Page("Profiles", nil, {
    H("Saved profiles"),
    { kind = "custom", build = function(parent, width)
      local pr = Pr()
      if pr and pr.Picker then return pr.Picker(parent, width) end
    end },
    H("Share"),
    B("Profile line", "Export", function() local pr = Pr(); if pr then pr.ShowExport() end end,
      "Every ForeverXIUI setting and your current Edit Mode layout as one line of text to copy. Also /fxiui export."),
    B("", "Import", function() local pr = Pr(); if pr then pr.ShowImport() end end,
      "Paste a profile line to load it (and its Edit Mode layout), then reload. Also /fxiui import."),
  })

  local sizes = {}
  for _, key in ipairs(SIZE_ORDER) do sizes[#sizes + 1] = Size(key) end
  Page("Sizes", nil, sizes)

  Page("Player & target", { "player", "playerCast", "target", "targetCast", "tot", "enemy" }, {
    Size("player"), Size("playerCast"), Size("target"), Size("targetCast"), Size("tot"), Size("enemy"),
    H("Frames"),
    C(m, "player", "Player bar", "Your HP and power bars.", true),
    C(m, "target", "Target bar", "Your target's name and HP.", true),
    C(m, "playerCast", "Your cast bar", nil, true),
    C(m, "targetCast", "Target cast bar", "May stay empty on Forever if target casts are hidden from addons.", true),
    C(m, "tot", "Target of target", "Who your target is attacking, right of the target bar. Click it to target them.", true),
    C(m, "enemy", "Enemy list", "The mobs you and your group are fighting, by the target bar. Needs enemy nameplates on (V).", true),
    H("Target bar"),
    C(db.target, "threatColors", "Threat colours on the target bar",
      "Green safe, yellow careful, red it's on you. As a tank: green you have it, yellow losing it, red lost it."),
    C(db.target, "alwaysTank", "Always use tank threat colours", "Otherwise tank colours are used only when your group role is Tank."),
    C(db.target, "auras", "Buffs and debuffs over the target bar", "Drawn by the game, so they keep working in combat.", true),
    C(db.target, "showDebuffs", "Target debuffs"),
    C(db.target, "showBuffs", "Target buffs"),
    C(db.target, "onlyMine", "Only my debuffs on the target"),
    C(db.target, "mobInfo", "Mob info on the target bar", "Level in the game's difficulty colour, elite or rare, and creature type."),
  })

  local p = db.party
  Page("Party & raid", { "party", "raid" }, {
    Size("party"), Size("raid"),
    H("Frames"),
    C(m, "party", "Party list", nil, true),
    C(m, "raid", "Raid list", "Other raid groups, on the right.", true),
    C(db.party, "groupTools", "Group tools on the party title",
      "Blizzard's group panel (role check, ready check, countdown, raid markers, Leave Party) opens upward when you click \"Party\" above the party list, instead of sliding out at the top left. XI look.", true),
    C(p, "showSolo", "Show party list when solo", nil, true),
    C(db.raid, "hideOwnGroup", "Leave my group out of the raid list", "It's already in the party list."),
    H("Buffs and debuffs"),
    C(p, "auras", "Buffs and debuffs on the party list", "Drawn by the game, so they keep working in combat.", true),
    C(p, "showBuffs", "Party buffs"),
    C(p, "showDebuffs", "Party debuffs", "Coloured border: blue magic, green poison, purple curse, brown disease."),
    C(p, "onlyMyBuffs", "Only buffs I cast"),
    C(p, "onlyDispellable", "Only debuffs I can remove"),
    C(p, "auraTimers", "Countdown numbers on buff icons"),
    C(p, "auraInside", "Buffs and debuffs under the name",
      "A line under each name: buffs from the left, debuffs from the right. Off: beside the party list, timer under each icon.", true),
    C(p, "auraWindow", "Window behind the buff icons", "An XI window behind the icons beside the party list."),
    H("Layout"),
    C(p, "pets", "Pets on the party list", "Each pet on the same line as its owner. The party window slides over to make room when someone has a pet out.", true),
    C(p, "rangeFade", "Dim party members out of range"),
    C(p, "flip", "Flip sides", "Pets left of the party window and the buff/debuff window right."),
  })

  Page("Minimap & gold", { "map", "gold" }, {
    S(db.map, "scale", "Minimap size", 0.5, 2, 0.05, "%.2f", "The minimap with its XI window, zone strip and gold strip.", 1),
    S(db.map, "buttonSize", "Minimap button size", 14, 36, 1, "%d px", "The addon buttons along the map's edge.", 22),
    C(db.map, "skin", "XI minimap", "Minimap and zone name in the XI window.", true),
    C(db.map, "square", "Square minimap", nil, true),
    C(db.map, "buttonColumn", "Minimap buttons along the map edge", "Blizzard's and your addons' minimap buttons, squared off and lined up down the map's left edge.", true),
    C(db.map, "coords", "Coordinates under the map", "On the strip with the zone and clock."),
    C(db.map, "hideCalendar", "Hide the calendar button", "The day/night calendar button. Off: it sits with the other minimap buttons.", true),
    H("Gold"),
    C(m, "gold", "Gold tracker", "Your gold on a strip on top of the minimap, with this session's change. Hover it for gold per hour and every character.", true),
    C(db.goldTracker, "onXP", "Gold under the EXP bar instead", "Puts the gold line back under the EXP bar.", true),
    C(db.goldTracker, "showRate", "Show gold per hour"),
    C(db.goldTracker, "bags", "Bag slots next to your gold", "Used / total bag slots on the gold strip: orange at 5 or fewer free, red at 2 or fewer."),
  })

  Page("EXP bar & notifications", { "xp", "notify", "loot" }, {
    Size("xp"), Size("notify"), Size("loot"),
    H("EXP bar"),
    C(m, "xp", "EXP bar", "Experience with rested, quests ready to hand in, XP per hour and time to level.", true),
    C(db.xp, "hideAtMax", "Hide the EXP bar at max level"),
    C(db.xp, "showQuest", "Show XP from finished quests", "Gold stretch on the bar for quests ready to hand in."),
    C(db.xp, "showRate", "Show XP per hour and time to level"),
    H("Notifications"),
    C(m, "notify", "Notifications", "Small XI toasts for loot, gold, XP, reputation and party invites.", true),
    C(db.notify, "loot", "Toast: items you loot"),
    C(db.notify, "gold", "Toast: gold you pick up"),
    C(db.notify, "xp", "Toast: XP"),
    C(db.notify, "rep", "Toast: reputation"),
    C(db.notify, "invites", "Toast: party invites"),
    C(db.notify, "growUp", "Toasts stack upward"),
    H("Treasure pool"),
    C(m, "loot", "Treasure pool", "Group loot rolls in one XI window with Need/Greed/Pass, instead of Blizzard's popups.", true),
  })

  local menuItems = {
    Size("menu"),
    H("Action bars"),
    C(db.bars, "enabled", "XI action bars", "XI window behind every action bar, sized to its buttons.", true),
    C(db.bars, "window", "Window behind the action bars", "The XI window behind each bar. Off: just the buttons."),
    C(db.bars, "hideArt", "Hide Blizzard action bar art", "The end caps and border art on the main bar.", true),
    C(db.bars, "highlight", "Light up bar 2 while Shift is held", nil, true),
    C(db.bars, "dim", "Dim bar 1 while Shift is held"),
    C(db.bars, "glowBase", "Outline bar 1 when no key is held"),
    C(db, "hideBagBar", "Hide Blizzard bag bar", "B and your bag keys still open bags.", true),
    H("Menu"),
    C(db, "menuSkin", "XI menu", "Replaces Blizzard's menu bar with an XI window.", true),
    C(db.menu, "vertical", "XI menu as a column", "FFXI's main menu layout.", true),
    C(db.menu, "icons", "XI menu icons", "Icon tiles with the name on mouse over. Off: text entries.", true),
    C(db.menu, "bagCount", "Free bag slots on the Bags button", "White, orange at 5 or fewer, red at 2 or fewer."),
  }
  -- One box per menu button (ticked = shown).
  db.menu.hide = db.menu.hide or {}
  db.menu.show = db.menu.show or {}
  local menuMod = ns.modules.MenuSkin
  for _, spec in ipairs(menuMod and menuMod.ENTRIES or {}) do
    local name = spec[1]
    db.menu.show[name] = not db.menu.hide[name]
    local item = C(db.menu.show, name, "Menu button: " .. name, "Untick to leave this button off the XI menu.", true)
    item.onChange = function(value)
      db.menu.hide[name] = not value or nil
      ns.Print("change saved. Type /reload to apply it.")
    end
    menuItems[#menuItems + 1] = item
  end
  Page("Action bars & menu", { "menu" }, menuItems)

  Page("Bags & junk", nil, {
    C(db.bags, "skin", "Baganator in the XI look", "Navy XI window, square item tiles with a thin quality edge, XI buttons. Baganator still does the sorting and categories.", true),
    C(db.bags, "freeLine", "Free slots under the bags", "\"12 / 42 free\" at the bottom of Baganator's backpack.", true),
    H("Junk"),
    C(db.junk, "enabled", "Junk by Auctionator price",
      "Marks items as junk in Baganator when the auction house (after its 5% cut) wouldn't pay more than the vendor plus the margin below. Greys are always junk. Pick \"ForeverXIUI: Auctionator price\" in Baganator's Customise > Junk."),
    C(db.junk, "autoSell", "Junk window at vendors", "Opening a vendor shows everything this rule marks as junk with a tick box each. Untick what you want to keep (remembered), then click Sell."),
    C(db.junk, "keepGear", "Never junk weapons and armour (unless grey)", "So unbound green gear you might wear or want to check isn't marked."),
    C(db.junk, "usePercent", "Use a % margin instead of an exact amount",
      "Off: junk when the auction house beats the vendor by the gold/silver/copper amount or less. On: by the % of the vendor price below or less."),
    S(db.junk, "percent", "Junk margin %", 0, 300, 5, "%d%%",
      "Used when the % box is ticked. 50%: an item the vendor buys for 10s is junk unless the auction house (after its cut) pays more than 15s.", 0),
    B("Junk margin (gold/silver/copper)", "Set margin", function() local j = ns.modules.Junk; if j then j.EditMargin() end end,
      "Junk when the auction house (after its cut) beats the vendor by this or less. Also /fxiui junk."),
  })

  local function ChatLayout() if ns.ChatLayout then ns.ChatLayout() end end
  local function ChatSize() db.chat.sizeOn = true; ChatLayout() end
  Page("Chat & damage meter", nil, {
    C(m, "chat", "Chat window skin", nil, true),
    C(db.chat, "buttonsRight", "Chat buttons to the right of the chat", "The voice and chat menu buttons float right of General, the social button right of the combat log. Off: Blizzard's spot.", true),
    C(db.chat, "buttonsOnHover", "Chat buttons only on mouse-over", "The column left of the chat (friends, voice, chat menu) stays hidden until the mouse is over the chat window.", true),
    C(db.meter, "skin", "XI damage meter", "The built-in damage meter in the XI window. Move it in Edit Mode.", true),
    C(db.chat, "stack", "Stack the combat log on top of General",
      "Same width, height and text size, like FFXI's two chat logs. The combat log follows General."),
    S(db.chat, "fontSize", "Chat text size", 9, 20, 1, "%d", "Text size in every chat window.", 13, ChatLayout),
    S(db.chat, "width", "Chat window width", 200, 1000, 10, "%d", "Sizes General and the combat log stacked on it together.", 430, ChatSize),
    S(db.chat, "height", "Chat window height", 60, 600, 5, "%d", "Sizes General and the combat log stacked on it together.", 120, ChatSize),
  })

  Page("Shaman", { "totems", "swing", "reminders" }, {
    Size("totems"), Size("swing"), Size("reminders"),
    H("Totems and swing"),
    C(m, "totems", "Totem bar", "Your four totems with timers. Right-click one to take it down.", true),
    C(db.totems, "anyClass", "Totem bar on every class", "Off: shamans only.", true),
    C(m, "swing", "Swing timer", "A slim bar that fills from one melee swing to the next.", true),
    C(db.swing, "alwaysShow", "Keep the swing timer visible out of combat"),
    H("Buff reminder"),
    C(m, "reminders", "Buff reminder", "Shows Lightning Shield or your weapon imbue when they're missing or running out.", true),
    C(db.reminders, "shield", "Remind: Lightning Shield"),
    C(db.reminders, "imbue", "Remind: weapon imbue (missing or under 2 min)"),
    C(db.reminders, "hideResting", "No reminders in cities and inns"),
  })

  Page("Nameplates & tooltip", { "tooltip" }, {
    H("Gathering"),
    C(db.gather, "interact", "Interact with the nearest object",
      "Your Interact key picks the nearest herb, ore, chest or poster all around you, up to 30 yards (SoftTargetInteract 3, Arc 2, Range 30). Off puts your old settings back."),
    C(db.gather, "icons", "Icon over the object you'd interact with",
      "Shows the gather or interact icon over that herb, ore or object (SoftTargetIconGameObject 1, SoftTargetIconInteract 1). Off puts your old settings back."),
    H("Plater"),
    C(db.plater, "skin", "Easier-to-read Plater",
      "Bigger outlined names, names only on friendly players, bigger enemy bars with health %, in the XI look. Written into Plater once; /fxiui plater undo puts your old settings back.", true),
    C(db.plater, "partyBars", "Plater: health bars on party members", "Your party and raid get a class-coloured health bar on their nameplate; other friendly players stay name only."),
    C(db.plater, "tapGrey", "Plater: grey for mobs claimed by someone else", "A mob another player or group tagged first shows grey instead of red."),
    C(db.plater, "nameColors", "Plater: names by who they are, with class icons",
      "Party green, your faction blue, the other faction orange, attackable players red, and a class icon in front of every player's name. Needs a /reload to turn off fully."),
    H("XI nameplates (only while Plater is off)"),
    C(m, "nameplates", "XI nameplates (instead of Plater)",
      "ForeverXIUI's own nameplates in the XI look: enemy bars with health %, threat colours, grey for claimed mobs, cast bars, and friendly names by relation with class icons.", true),
    Size("nameplates"),
    S(db.nameplates, "nameSize", "XI nameplates: name text size", 9, 20, 1, "%d", "Just the names, on top of the size above.", 13),
    S(db.nameplates, "distance", "XI nameplates: distance (yards)", 0, 60, 1, "%d",
      "How far away plates show. The game caps this (often at 41); 0 leaves the game's own setting.", 41),
    C(db.nameplates, "partyBars", "XI nameplates: green bars on party members"),
    C(db.nameplates, "hidePets", "XI nameplates: no names on pets, minions and totems"),
    C(db.nameplates, "castBars", "XI nameplates: enemy cast bars"),
    Col(db.nameplates, "objectColor", "XI nameplates: clickable objects colour", { 1, 0.82, 0 },
      "Wanted posters, chests, mailboxes and other things you can click show just their name, in this colour. Default is quest yellow."),
    C(db.nameplates, "hideFloating", "XI nameplates: hide the game's far-away names", "Past nameplate range the game shows plain floating names. On: nothing shows until the XI plate does."),
    H("Tooltip"),
    C(db.tooltip, "move", "Move the tooltip", "The game's tooltip gets its own spot (drag it in move mode) instead of the bottom-right corner over your party list.", true),
    C(db.tooltip, "cursor", "Tooltip follows the mouse", "Instead of the fixed spot."),
  })

  local h = db.hideBlizzard
  Page("Blizzard frames", nil, {
    C(h, "player", "Hide Blizzard player frame", nil, true),
    C(h, "target", "Hide Blizzard target frame", nil, true),
    C(h, "cast", "Hide Blizzard cast bar", nil, true),
    C(h, "party", "Hide Blizzard party frames", nil, true),
    C(h, "raid", "Hide Blizzard raid frames", "The raid side panel (ready check, markers) stays.", true),
    C(h, "xp", "Hide Blizzard XP and reputation bar", "Only while the ForeverXIUI EXP bar is on.", true),
    C(h, "totems", "Hide Blizzard totem frame", "Only while the ForeverXIUI totem bar is on.", true),
    C(h, "boss", "Hide Blizzard boss frames", "The boss health frames on the right in boss fights. The enemy list shows bosses that have a nameplate near you.", true),
    C(h, "editBoxes", "No Minimap, Bags and menu boxes in Edit Mode", "Their boxes go invisible and click-through in Edit Mode. Move the minimap in ForeverXIUI's move mode instead.", true),
    C(h, "objectives", "Swap the quest tracker with Polestar", "Blizzard's quest tracker hides while Polestar's guide window is showing and comes back when it isn't (in dungeons, or when you close Polestar)."),
  })

  return pages
end

-- The game's own options list just points to the ForeverXIUI window.
function M:Init()
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then return end
  pcall(function()
    local cat = Settings.RegisterVerticalLayoutCategory("ForeverXIUI")
    if CreateSettingsButtonInitializer and SettingsPanel and SettingsPanel.GetLayout then
      SettingsPanel:GetLayout(cat):AddInitializer(CreateSettingsButtonInitializer("ForeverXIUI options", "Open",
        function() if ns.OpenConfig then ns.OpenConfig() end end,
        "Every ForeverXIUI option is in its own window. Also /fxiui.", true))
    end
    Settings.RegisterAddOnCategory(cat)
  end)
end

local function Help()
  ns.Print("commands:")
  print("  /fxiui  - open the ForeverXIUI window")
  print("  /fxiui move  - drag frames, click one for its options (also on while Edit Mode is open)")
  print("  /fxiui tidy  - untick the Edit Mode list entries ForeverXIUI replaces")
  print("  /fxiui preview  - show a pretend full party and raid (also on with /fxiui move)")
  print("  /fxiui reset  - put every frame back to the default layout")
  print("  /fxiui compact  - toggle compact mode")
  print("  /fxiui scale 1.2  - size of everything; /fxiui scale party 1.1  - one frame")
  print("  /fxiui chat  - re-stack the combat log on General and even out text size")
  print("  /fxiui chat 430 120  - size both chat windows (width height); /fxiui chat off - back to Edit Mode's size")
  print("  /fxiui map  - line the minimap buttons up again and show the minimap layout")
  print("  /fxiui hide  - hide the box under the mouse (e.g. another addon's coordinates); /fxiui unhide to bring them back")
  print("  /fxiui meter  - list what the damage meter is made of (to fit its skin)")
  print("  /fxiui plater - set Plater up to be easier to read again; /fxiui plater undo puts your old settings back")
  print("  /fxiui check  - test what Forever lets addons read (run it in combat too)")
end

SLASH_FOREVERXIUI1 = "/fxiui"
SLASH_FOREVERXIUI2 = "/foreverxiui"
SlashCmdList.FOREVERXIUI = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "move" or msg == "unlock" or msg == "lock" then
    ns.Movers.Toggle()
  elseif msg == "reset" then
    if InCombatLockdown() then ns.Print("not in combat.") return end
    ns.Movers.ResetAll()
    ns.Print("frames reset to the default layout.")
  elseif msg == "compact" then
    ns.db.compact = not ns.db.compact
    ns.ForEachModule("Relayout")
    ns.Print("compact mode %s.", ns.db.compact and "on" or "off")
  elseif msg:match("^scale") then
    local what, value = msg:match("^scale%s+(%a*)%s*([%d%.]+)$")
    value = tonumber(value)
    if not value or value < 0.3 or value > 3 then
      ns.Print("usage: /fxiui scale 1.2  or  /fxiui scale party 1.1 (player, playercast, target, targetcast, tot, party, raid, xp, enemy, menu, totems, swing, notify, loot)")
      return
    end
    local keys = { player = "player", playercast = "playerCast", target = "target", targetcast = "targetCast", tot = "tot", party = "party", raid = "raid", xp = "xp", enemy = "enemy", menu = "menu", totems = "totems", swing = "swing", notify = "notify", loot = "loot" }
    if what == nil or what == "" then
      ns.db.scale = value
    elseif keys[what] then
      ns.db.frameScale[keys[what]] = value
    else
      ns.Print("unknown frame '%s'.", what)
      return
    end
    ns.ApplyScale()
    ns.Print("scale set.")
  elseif msg == "preview" or msg == "test" then
    ns.SetPreview(not ns.previewOn)
  elseif msg:match("^chat") then
    local w, h = msg:match("^chat%s+(%d+)%s+(%d+)$")
    if msg:match("^chat%s+off$") then
      ns.db.chat.sizeOn = false
      ns.Print("chat size back to Edit Mode's. /reload to see it.")
      return
    end
    if w then
      ns.db.chat.width, ns.db.chat.height, ns.db.chat.sizeOn = tonumber(w), tonumber(h), true
    end
    if ns.ChatLayout then ns.ChatLayout(true) end
  elseif msg == "map" then
    local ms = ns.modules.MapSkin
    if ms and ms.Dump then ms.Dump() end
  elseif msg == "hide" then
    ns.HideUnderMouse()
  elseif msg == "unhide" then
    ns.UnhideAll()
  elseif msg == "export" then
    local pr = ns.modules.Profile
    if pr then pr.ShowExport() end
  elseif msg == "import" then
    local pr = ns.modules.Profile
    if pr then pr.ShowImport() end
  elseif msg == "tidy" then
    local pr = ns.modules.Profile
    if pr then pr.RunTidy(true) end
  elseif msg == "junk" then
    local j = ns.modules.Junk
    if j and j.EditMargin then j.EditMargin() end
  elseif msg == "meter" then
    local ms = ns.modules.MeterSkin
    if ms and ms.Dump then ms.Dump() end
  elseif msg == "plater" or msg == "plater undo" then
    local ps = ns.modules.PlaterSkin
    if ps then
      if msg == "plater undo" then ps.Undo() else ns.db.plater.skin = true ps.Apply(true) end
    end
  elseif msg == "check" then
    ns.Check()
  elseif msg == "help" then
    Help()
  else
    if msg == "" and ns.modules.Config then
      ns.modules.Config.Toggle()
      return
    end
    Help()
  end
end
