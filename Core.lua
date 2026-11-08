-- ForeverXIUI core: saved settings, events, the out-of-combat queue and the
-- module list. Everything else hangs off the shared namespace `ns`.
local ADDON, ns = ...

ns.name = ADDON
ns.version = "1.4.1"
ns.DB_VERSION = 5

-- Defaults. New keys are filled in on load, so adding one here is safe for
-- existing saved settings. Renaming or removing one needs a step in Migrate.
ns.defaults = {
  dbVersion = 5,
  scale = 1,
  -- Per-frame size on top of the global scale.
  frameScale = { player = 1, playerCast = 1, target = 1, targetCast = 1, tot = 1, party = 1, raid = 1, xp = 1, enemy = 1, menu = 1, totems = 1, swing = 1, notify = 1, loot = 1, gold = 1, reminders = 1, nameplates = 1, bagDots = 1 },
  compact = false,
  modules = {
    player = true,
    target = true,
    playerCast = true,
    targetCast = true,
    tot = true,          -- target of target
    xp = true,           -- EXP bar
    enemy = true,        -- enemy list by the target bar
    party = true,
    raid = true,
    chat = true,
    totems = true,       -- totem bar (shamans)
    swing = true,        -- swing timer
    gold = true,         -- gold strip on top of the minimap
    notify = true,       -- XI toasts for loot, gold, XP, reputation, invites
    loot = true,         -- treasure pool: group loot rolls in one XI window
    reminders = true,    -- buff reminder (Lightning Shield, weapon imbue)
    nameplates = false,  -- XI nameplates instead of Plater (only while Plater is off)
  },
  hideBlizzard = {
    player = true,
    target = true,
    cast = true,
    party = true,
    raid = true,
    xp = true,           -- Blizzard's XP/reputation bar (only while ForeverXIUI's EXP bar is on)
    totems = true,       -- Blizzard's totem frame by the player frame (while the totem bar is on)
    objectives = true,   -- Blizzard's quest tracker hides while Polestar's window shows
    editBoxes = true,    -- no Minimap / Bags boxes in Edit Mode (move the map with /fxiui move)
    boss = false,        -- Blizzard's boss frames (the enemy list covers them)
  },
  totems = {
    anyClass = false,    -- show the totem bar on non-shamans too
  },
  swing = {
    alwaysShow = false,  -- keep the swing bar faintly visible out of combat
  },
  goldTracker = {
    showRate = true,     -- gold per hour beside the session change
    onXP = false,        -- gold under the EXP bar instead of on top of the minimap
    bags = true,         -- used/total bag slots on the gold strip
  },
  notify = {
    loot = true, gold = true, xp = true, rep = true, invites = true,
    growUp = false,      -- new toasts stack downward from the top (on: upward)
  },
  meter = {
    skin = true,         -- the built-in damage meter in an XI window
  },
  reminders = {
    shield = true,       -- Lightning Shield missing
    imbue = true,        -- weapon imbue missing or running out
    imbueWarn = 120,     -- seconds left before the imbue shows
    hideResting = true,  -- quiet in cities and inns
  },
  nameplates = {
    partyBars = true,    -- party/raid members get a slim green bar
    hidePets = true,     -- no names on other players' pets, minions and totems
    castBars = true,     -- cast bars under enemy plates
    otherAlpha = 0.8,    -- plates that aren't your target, while you have one
    nameSize = 13,       -- name text size on XI nameplates
    distance = 41,       -- how far away plates show (yards); 0 leaves the game's setting alone
    hideFloating = false, -- hide the game's floating names past nameplate range
  },
  tooltip = {
    move = true,         -- the game's tooltip goes to our spot instead of over the party list
    cursor = false,      -- or follows the mouse
  },
  plater = {
    skin = true,         -- easier-to-read Plater in the XI look (written once)
    partyBars = true,    -- party/raid members keep a health bar on their plate
    tapGrey = true,      -- mobs claimed by someone else in grey
    nameColors = true,   -- names by relation (party/faction/other/hostile) + class icon
    applied = 0,
  },
  target = {
    threatColors = true, -- colour the target bar by your threat on it
    alwaysTank = false,  -- use tank colours even without the tank role
    mobInfo = true,      -- "Lv 18 Elite Beast" on the target bar
    auras = true,        -- buffs and debuffs over the target bar
    showDebuffs = true,
    showBuffs = true,
    onlyMine = false,    -- only debuffs you put on it
    auraSize = 20,
  },
  xp = {
    hideAtMax = true,    -- hide the EXP bar at level 60
    showQuest = true,    -- gold stretch for quests ready to hand in
    showRate = true,     -- XP per hour and time to level
  },
  menuSkin = true,       -- XI text menu in place of Blizzard's micro menu
  junk = {
    enabled = true,      -- Baganator junk rule from Auctionator prices
    margin = 0,          -- old silver setting (marginCopper wins once set)
    usePercent = false,  -- margin as a % of the vendor price instead of an amount
    percent = 0,         -- that %
    keepGear = true,     -- never junk weapons/armour unless grey
    autoSell = true,     -- show the sell-junk window when a vendor opens
    keep = {},           -- itemIDs you unticked: never junk
  },
  bagDots = {
    columns = 20,        -- dots per row
    window = true,       -- XI panel behind the dots
  },
  bags = {
    skin = true,         -- Baganator in the XI look
    freeLine = true,     -- "12 / 42 free" under the backpack
    alpha = 0.92,        -- window opacity
  },
  menu = {
    vertical = false,    -- a column of entries (FFXI's main menu) instead of a row
    icons = true,        -- icon tiles, name shown on mouse over (off: text entries)
    bagCount = true,     -- free bag slots on the Bags entry
    hide = {},           -- entries to leave off, by name ("Guild" = true)
  },
  map = {
    skin = true,         -- minimap in an XI window
    square = true,       -- square map (off: Blizzard's round one, inside the window)
    buttonColumn = true, -- line up the buttons around the map along its left edge
    coords = true,       -- your coordinates on the strip under the map
    scale = 1,           -- map size (the slider in the options)
    buttonSize = 22,     -- minimap button size
    hideCalendar = false, -- put away the calendar (day/night) button
  },
  hideBagBar = true,
  look = {
    classicColors = true, -- WoW red health and Blizzard power colours (off = XIUI colours)
    hpBands = false,      -- XIUI's red/orange/yellow steps as health drops
    shine = false,        -- the light gradient over bar fills
    rounded = true,       -- rounded corners on every window
  },
  bars = {
    enabled = true,      -- XI window behind action bars 1-3
    highlight = false,   -- light up bar 2 while Shift is held (off: mcduff89 dropped the idea)
    dim = true,          -- dim bar 1 while Shift is held
    dimAlpha = 0.55,
    glowBase = false,    -- also outline bar 1 when no modifier is held
    hideArt = true,      -- fade Blizzard's end caps and border art on the bars
    window = true,       -- the XI window behind each bar (off: buttons only)
  },
  chat = {
    stack = true,        -- combat log window stacked on top of General, same size
    fontSize = 13,       -- one text size for every chat window
    gap = 30,            -- room for General's tabs between the two windows
    sizeOn = false,      -- true once a chat size slider is used (until then Edit Mode's size is kept)
    width = 430,
    height = 120,
  },     -- fade out Blizzard's bag bar (B still opens bags)
  party = {
    showSolo = true,     -- XIUI "show party list when solo"
    auras = true,        -- buff and debuff icons beside each member
    showBuffs = true,
    showDebuffs = true,
    onlyMyBuffs = false, -- only buffs you cast
    onlyDispellable = false, -- only debuffs you can remove
    auraTimers = true,   -- countdown numbers on the icons (the swipe always shows)
    auraSize = 16,
    auraWindow = false,  -- an XI window behind the icons beside the list
    auraCols = 6,        -- icons per line in the window beside the party list
    auraInside = false,  -- icons on a line under the name (off: their own window beside the list)
    pets = true,         -- each member's pet on their line
    flip = false,        -- false: icons left, pets right; true: the other way round
    rangeFade = true,    -- dim members out of range (about 40 yards)
    rangeAlpha = 0.45,
  },
  raid = {
    hideOwnGroup = true, -- your own group is already in the party list
  },
  hidden = {},           -- other addons' frames hidden with /fxiui hide, by name
  positions = {},        -- filled by the movers; empty means "use the default"
}

local function FillDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      FillDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

-- One step per saved-settings version. Nothing to migrate yet (version 1).
local function Migrate(db)
  db.dbVersion = tonumber(db.dbVersion) or 1
  -- 2 (0.1.4): the menu window turned out not to help; off for everyone.
  if db.dbVersion < 2 then
    db.menuSkin = false
    db.dbVersion = 2
  end
  -- 3 (0.4.0): mcduff89 asked for every Blizzard piece in the XI navy, the menu too.
  if db.dbVersion < 3 then
    db.menuSkin = true
    db.dbVersion = 3
  end
  -- 4 (0.4.1): mcduff89's party layout: timers on, icons beside the window (not
  -- under the name), 14px icons. Pets moved to the right (flip now means left).
  if db.dbVersion < 4 then
    if type(db.party) == "table" then
      db.party.auraTimers = true
      db.party.auraInside = false
      db.party.auraSize = 14
      db.party.flip = false
    end
    db.dbVersion = 4
  end
  -- 5 (0.5.1): no window behind the icons, bigger icons with the timer under each.
  if db.dbVersion < 5 then
    if type(db.party) == "table" then
      db.party.auraWindow = false
      db.party.auraSize = 16
    end
    db.dbVersion = 5
  end
end

function ns.Print(msg, ...)
  if select("#", ...) > 0 then msg = msg:format(...) end
  DEFAULT_CHAT_FRAME:AddMessage("|cff78c4eeForeverXIUI|r " .. tostring(msg))
end

-- pcall that only reports success and the first result.
function ns.Try(fn, ...)
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return true, a, b, c, d end
  return false
end

-- True only for a value we are allowed to read. Use type(), never `== nil`
-- or `if v`, on anything that might be secret: those can throw on Forever.
function ns.Readable(v)
  if type(v) == "nil" then return false end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if not ok or secret then return false end
  end
  return true
end

-- A plain true/false from a call that might return a secret boolean.
function ns.Bool(fn, ...)
  local ok, v = pcall(fn, ...)
  if not ok or not ns.Readable(v) then return nil end
  return v and true or false
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    driver:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end

driver:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok then
      geterrorhandler()(err)
    end
  end
end)

---------------------------------------------------------------------------
-- Out-of-combat queue: secure frames can't be shown, moved or rebuilt while
-- InCombatLockdown() is true, so those jobs wait for PLAYER_REGEN_ENABLED.
---------------------------------------------------------------------------
local queued, queueOrder = {}, {}

function ns.AfterCombat(key, fn)
  if not InCombatLockdown() then
    fn()
    return true
  end
  if not queued[key] then table.insert(queueOrder, key) end
  queued[key] = fn
  return false
end

ns.On("PLAYER_REGEN_ENABLED", function()
  local order = queueOrder
  queueOrder = {}
  for _, key in ipairs(order) do
    local fn = queued[key]
    queued[key] = nil
    if fn then
      local ok, err = pcall(fn)
      if not ok then geterrorhandler()(err) end
    end
  end
end)

---------------------------------------------------------------------------
-- Modules. Each file adds itself with ns.AddModule(name, table) and gets
-- :Init() at login, in file order.
---------------------------------------------------------------------------
ns.modules = {}
ns.moduleOrder = {}

function ns.AddModule(name, mod)
  mod = mod or {}
  mod.name = name
  ns.modules[name] = mod
  table.insert(ns.moduleOrder, name)
  return mod
end

function ns.ForEachModule(method, ...)
  for _, name in ipairs(ns.moduleOrder) do
    local mod = ns.modules[name]
    if mod[method] then
      local ok, err = pcall(mod[method], mod, ...)
      if not ok then geterrorhandler()(err) end
    end
  end
end

ns.On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  if ForeverXIUIDB == nil then
    -- Fresh install: start from the built-in default profile (Duff's
    -- settings). Its Edit Mode layout isn't applied here; load the
    -- profile from the Profiles page for that.
    ForeverXIUIDB = {}
    local pr, preset = ns.modules.Profile, ns.PRESETS and ns.PRESETS[ns.DEFAULT_PRESET or ""]
    if pr and pr.SettingsOf and preset then
      local ok, data = pcall(pr.SettingsOf, preset)
      if ok and type(data) == "table" then
        for k, v in pairs(data) do ForeverXIUIDB[k] = v end
        ForeverXIUIDB.dbVersion = ns.DB_VERSION
        ns.startedFromPreset = ns.DEFAULT_PRESET
      end
    end
  end
  Migrate(ForeverXIUIDB)
  FillDefaults(ForeverXIUIDB, ns.defaults)
  ForeverXIUIDB.dbVersion = ns.DB_VERSION
  ns.db = ForeverXIUIDB
end)

ns.On("PLAYER_LOGIN", function()
  ns.ForEachModule("Init")
  ns.ApplyScale()
  ns.Print("v%s loaded. /fxiui for options, /fxiui move to place frames.", ns.version)
  if ns.startedFromPreset then
    ns.Print("first run: set up with the %s profile. Load it from /fxiui > Profiles to get its Edit Mode layout too.", ns.startedFromPreset)
  end
end)

-- /fxiui preview: pretend party, raid, target and casts, to lay things out.
function ns.SetPreview(on)
  if on and InCombatLockdown() then
    ns.Print("preview is out of combat only.")
    return
  end
  ns.previewOn = on and true or nil
  ns.ForEachModule("Preview", on and true or false)
  if on then
    ns.Print("preview on: pretend party, raid, target and casts. /fxiui preview again to turn it off.")
  else
    ns.Print("preview off.")
  end
end

ns.On("PLAYER_REGEN_DISABLED", function()
  if ns.previewOn then ns.SetPreview(false) end
end)

-- Hover tooltip for a unit button (party, pets, raid, target of target).
function ns.UnitTooltip(frame)
  frame:HookScript("OnEnter", function(self)
    local unit = self.unit or self:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self) else GameTooltip:SetOwner(self, "ANCHOR_RIGHT") end
    pcall(GameTooltip.SetUnit, GameTooltip, unit)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Scale for every module root. Secure roots can't be rescaled in combat.
ns.roots = {}
function ns.AddRoot(frame, key)
  frame.fxiKey = key
  table.insert(ns.roots, frame)
end

function ns.ApplyScale()
  ns.AfterCombat("scale", function()
    local s = tonumber(ns.db and ns.db.scale) or 1
    local per = ns.db and ns.db.frameScale or {}
    for _, f in ipairs(ns.roots) do
      local k = tonumber(f.fxiKey and per[f.fxiKey]) or 1
      f:SetScale(math.max(0.3, s * k))
    end
    if ns.Movers then ns.Movers.ApplyAll() end
  end)
end
