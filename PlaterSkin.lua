-- Plater, easier to read, in the ForeverXIUI look. Plater keeps doing all the
-- work (secret health, threat colours, casts, auras); ForeverXIUI only writes
-- some of its settings into your current Plater profile:
--   * Bigger text (names 12-13, health % and cast names 11), all with an
--     outline and a shadow, in Arial Narrow.
--   * Friendly players show just their name in class colour, no thin bar.
--     Friendly NPC names (name-only already) go from 9 to 12.
--   * Party and raid members keep a health bar (100x8), so you can tell
--     them apart from everyone else.
--   * Player names by who they are instead of class colour: party green,
--     your faction blue, the other faction orange (red when you can attack
--     them), with a class icon in front of every player's name.
--   * Enemy bars a little bigger (120x14, 130x16 in combat) with health %.
--   * The XI look: flat fill, navy background, steel edge, XI cast colours
--     and the XI blue target highlight.
--
-- It writes them once, so anything you change in Plater afterwards sticks.
-- Every value it changes is saved first: /fxiui plater undo puts them back,
-- /fxiui plater writes the XI ones again.
local _, ns = ...

local M = ns.AddModule("PlaterSkin")

local STYLE = 3          -- bump when the look below changes (each step is written once)
local FLAT = "ForeverXIUI Flat"
local FONT = "Arial Narrow"

local function Navy(a) local c = ns.Style.colors.panelBottom return { c[1], c[2], c[3], a } end

local function RegisterMedia()
  local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
  if lsm then
    lsm:Register("statusbar", FLAT, "Interface\\Buttons\\WHITE8X8")
    lsm:Register("font", "ForeverXIUI", ns.Style.FONT)
  end
end

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

-- Set p[...path] = value, saving the old value the first time.
local saved
local function Set(root, path, value)
  local t = root
  for i = 1, #path - 1 do
    t = t[path[i]]
    if type(t) ~= "table" then return end
  end
  local key = path[#path]
  local id = table.concat(path, ".")
  if saved[id] == nil then saved[id] = { v = Copy(t[key]) } end
  t[key] = Copy(value)
end

local TEXTS = { "actorname", "big_actorname", "spellname", "spellpercent", "level", "percent" }
local SIZES = {
  enemynpc       = { actorname = 12, spellname = 11, spellpercent = 10, percent = 11 },
  enemyplayer    = { actorname = 12, spellname = 11, spellpercent = 10, percent = 11 },
  friendlynpc    = { actorname = 12, big_actorname = 12, spellname = 11 },
  friendlyplayer = { actorname = 13, big_actorname = 12, spellname = 11 },
}

local function Write(p)
  local function S(path, v) Set(p, path, v) end
  -- The XI look.
  S({ "health_statusbar_texture" }, FLAT)
  S({ "health_statusbar_bgtexture" }, FLAT)
  S({ "health_statusbar_bgcolor" }, Navy(0.92))
  S({ "health_selection_overlay" }, FLAT)
  S({ "health_selection_overlay_alpha" }, 0.08)
  S({ "cast_statusbar_texture" }, FLAT)
  S({ "cast_statusbar_bgtexture" }, FLAT)
  S({ "cast_statusbar_bgcolor" }, Navy(0.92))
  local cr, cg, cb = ns.Style.Color("cast")
  S({ "cast_statusbar_color" }, { cr, cg, cb, 1 })
  local lr, lg, lb = ns.Style.Color("castLocked")
  S({ "cast_statusbar_color_nointerrupt" }, { lr, lg, lb, 1 })
  local er, eg, eb = ns.Style.Color("edge")
  S({ "border_color" }, { er, eg, eb, 1 })
  S({ "border_thickness" }, 1)
  local hr, hg, hb = ns.Style.Color("edgeLight")
  S({ "target_highlight_color" }, { hr, hg, hb, 1 })

  for kind, sizes in pairs(SIZES) do
    local c = p.plate_config and p.plate_config[kind]
    if type(c) == "table" then
      for _, t in ipairs(TEXTS) do
        if c[t .. "_text_font"] ~= nil then S({ "plate_config", kind, t .. "_text_font" }, FONT) end
        if c[t .. "_text_outline"] ~= nil then S({ "plate_config", kind, t .. "_text_outline" }, "OUTLINE") end
        if c[t .. "_text_shadow_color"] ~= nil then S({ "plate_config", kind, t .. "_text_shadow_color" }, { 0, 0, 0, 1 }) end
        if sizes[t] and c[t .. "_text_size"] ~= nil then S({ "plate_config", kind, t .. "_text_size" }, sizes[t]) end
      end
    end
  end

  -- Friendly players: name only, in class colour.
  local fp = p.plate_config and p.plate_config.friendlyplayer
  if type(fp) == "table" then
    S({ "plate_config", "friendlyplayer", "only_thename" }, true)
    S({ "plate_config", "friendlyplayer", "only_damaged" }, false)
    if fp.actorname_use_class_color ~= nil then S({ "plate_config", "friendlyplayer", "actorname_use_class_color" }, true) end
  end

  -- Enemies: a bit bigger, with health %.
  for _, kind in ipairs({ "enemynpc", "enemyplayer" }) do
    local c = p.plate_config and p.plate_config[kind]
    if type(c) == "table" then
      if c.health then S({ "plate_config", kind, "health" }, { 120, 14 }) end
      if c.health_incombat then S({ "plate_config", kind, "health_incombat" }, { 130, 16 }) end
      if c.cast then S({ "plate_config", kind, "cast" }, { 120, 12 }) end
      if c.cast_incombat then S({ "plate_config", kind, "cast_incombat" }, { 130, 14 }) end
      if c.percent_text_enabled ~= nil then S({ "plate_config", kind, "percent_text_enabled" }, true) end
      if c.percent_text_color then S({ "plate_config", kind, "percent_text_color" }, { 1, 1, 1, 1 }) end
    end
  end
end

-- Step 2: party and raid members keep a health bar (everyone else stays
-- name only), so a thicker friendly bar that you can read.
local function Write2(p)
  local fp = p.plate_config and p.plate_config.friendlyplayer
  if type(fp) ~= "table" then return end
  if fp.health then Set(p, { "plate_config", "friendlyplayer", "health" }, { 100, 8 }) end
  if fp.health_incombat then Set(p, { "plate_config", "friendlyplayer", "health_incombat" }, { 100, 8 }) end
end

-- Step 3: names coloured by relation (done per plate below); here the
-- class/guild/friend name colours go off and the bars get the same colours.
local NAME = {
  party = { 0.35, 0.95, 0.35 },
  friend = { 0.40, 0.70, 1.00 },
  other = { 1.00, 0.60, 0.15 },
  hostile = { 1.00, 0.22, 0.22 },
}
local function Write3(p)
  local pc = p.plate_config
  if type(pc) ~= "table" then return end
  local function C(c) return { c[1], c[2], c[3], 1 } end
  if type(pc.friendlyplayer) == "table" then
    for k, v in pairs({ actorname_use_class_color = false, actorname_use_guild_color = false,
      actorname_use_friends_color = false, actorname_text_color = C(NAME.friend), fixed_class_color = C(NAME.party) }) do
      if pc.friendlyplayer[k] ~= nil then Set(p, { "plate_config", "friendlyplayer", k }, v) end
    end
  end
  if type(pc.enemyplayer) == "table" then
    for k, v in pairs({ actorname_use_class_color = false, actorname_text_color = C(NAME.hostile),
      use_playerclass_color = false, fixed_class_color = C(NAME.hostile) }) do
      if pc.enemyplayer[k] ~= nil then Set(p, { "plate_config", "enemyplayer", k }, v) end
    end
  end
  -- Only party members have a friendly bar now: green, not class colour.
  if p.use_playerclass_color ~= nil then Set(p, { "use_playerclass_color" }, false) end
end

local function InGroup(unit)
  if not unit or ns.Bool(UnitIsUnit, unit, "player") then return false end
  return ns.Bool(UnitInParty, unit) or ns.Bool(UnitInRaid, unit) or false
end

-- Plater shows friendly players as names only (our step 1). Party and raid
-- members get their bar back. Plater re-checks this every tick per plate.
local wrapped
local function WrapPartyBars()
  if wrapped or type(Plater.ParseHealthSettingForPlayer) ~= "function" or type(Plater.ShowHealthBar) ~= "function" then return end
  wrapped = true
  local orig = Plater.ParseHealthSettingForPlayer
  Plater.ParseHealthSettingForPlayer = function(plateFrame, force, ...)
    local o = ns.db.plater
    local uf = plateFrame and plateFrame.unitFrame
    local unit = plateFrame and (plateFrame.namePlateUnitToken or (uf and uf.namePlateUnitToken))
    if o.skin and o.partyBars and uf and InGroup(unit) then
      if plateFrame.IsFriendlyPlayerWithoutHealthBar or force then pcall(Plater.ShowHealthBar, uf) end
      return
    end
    return orig(plateFrame, force, ...)
  end
end

-- After Plater sets a plate's text: the relation colour on the name, and
-- a class icon in front of it for players.
local hooked
local function PlayerName(plateFrame)
  local o = ns.db.plater
  if type(plateFrame) ~= "table" then return end
  if not (o.skin and o.nameColors) then
    if plateFrame.fxiClassIcon then plateFrame.fxiClassIcon:Hide() end
    return
  end
  local uf = plateFrame.unitFrame
  local unit = plateFrame.namePlateUnitToken or (uf and uf.namePlateUnitToken)
  local fs = plateFrame.CurrentUnitNameString
  local icon = plateFrame.fxiClassIcon
  local isPlayer = unit and ns.Bool(UnitIsPlayer, unit)
  if not isPlayer or type(fs) ~= "table" or not fs.SetTextColor then
    if icon then icon:Hide() end
    return
  end
  local c
  if InGroup(unit) then c = NAME.party
  elseif ns.Bool(UnitIsFriend, "player", unit) then c = NAME.friend
  elseif ns.Bool(UnitCanAttack, "player", unit) then c = NAME.hostile
  else c = NAME.other end
  fs:SetTextColor(c[1], c[2], c[3], 1)

  local parent = fs:GetParent()
  if not icon then
    icon = plateFrame:CreateTexture(nil, "OVERLAY")
    plateFrame.fxiClassIcon = icon
  end
  if icon:GetParent() ~= parent then icon:SetParent(parent) end
  icon:SetDrawLayer("OVERLAY", 7)
  local size = math.max(10, (select(2, fs:GetFont()) or 12) + 2)
  icon:SetSize(size, size)
  icon:ClearAllPoints()
  icon:SetPoint("RIGHT", fs, "LEFT", -2, 0)
  local ok, _, class = pcall(UnitClass, unit)
  if ok then ns.Style.ClassIcon(icon, class) else icon:Hide() end
end

local function HookNames()
  if hooked or type(Plater.UpdatePlateText) ~= "function" then return end
  hooked = true
  hooksecurefunc(Plater, "UpdatePlateText", function(plateFrame) pcall(PlayerName, plateFrame) end)
  -- Plater shows/hides the bar (and swaps which name string is used) here.
  for _, fn in ipairs({ "ShowHealthBar", "HideHealthBar" }) do
    if type(Plater[fn]) == "function" then
      hooksecurefunc(Plater, fn, function(unitFrame)
        if type(unitFrame) == "table" then pcall(PlayerName, unitFrame.PlateFrame) end
      end)
    end
  end
end

local function Refresh()
  if Plater.RefreshDBUpvalues then pcall(Plater.RefreshDBUpvalues) end
  if Plater.UpdateAllPlates then pcall(Plater.UpdateAllPlates, true) end
  if Plater.FullRefreshAllPlates then pcall(Plater.FullRefreshAllPlates) end
end

local function Ready(loud)
  if type(Plater) ~= "table" or not (Plater.db and Plater.db.profile) then
    if loud then ns.Print("Plater isn't loaded.") end
    return false
  end
  return true
end

function M.Apply(force)
  if not Ready(force) then return false end
  RegisterMedia()
  if not force and (ns.db.plater.applied or 0) >= STYLE then return true end
  ns.db.plater.backup = ns.db.plater.backup or {}
  saved = ns.db.plater.backup
  local applied = force and 0 or (ns.db.plater.applied or 0)
  local ok, err = pcall(function()
    if applied < 1 then Write(Plater.db.profile) end
    if applied < 2 then Write2(Plater.db.profile) end
    if applied < 3 then Write3(Plater.db.profile) end
  end)
  if not ok then
    ns.Print("couldn't restyle Plater (%s).", tostring(err))
    return false
  end
  ns.db.plater.applied = STYLE
  WrapPartyBars()
  HookNames()
  Refresh()
  ns.Print("Plater set up to be easier to read. Changes you make in Plater stay; /fxiui plater undo puts your old settings back.")
  return true
end

function M.Undo()
  if not Ready(true) then return end
  local b = ns.db.plater.backup
  if not b or not next(b) then ns.Print("nothing to undo.") return end
  local p = Plater.db.profile
  for id, e in pairs(b) do
    local t, parts = p, {}
    for part in id:gmatch("[^%.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do t = type(t) == "table" and t[parts[i]] or nil end
    if type(t) == "table" then t[parts[#parts]] = Copy(e.v) end
  end
  ns.db.plater.backup = nil
  ns.db.plater.applied = STYLE          -- don't re-apply on the next login
  ns.db.plater.skin = false
  Refresh()
  ns.Print("Plater is back to your old settings (and ForeverXIUI won't touch it again unless you /fxiui plater).")
end

-- Mobs tagged by someone else ("claimed") in grey. Plater has a grey for
-- this but its check doesn't fire on Forever (the tag can come back as a
-- secret value). A grey layer over each plate's fill shows or hides by the
-- game's own answer, secret or not.
local GREY = { 0.55, 0.55, 0.55 }
local function TapLayer(uf)
  local hb = uf and uf.healthBar
  if not hb or not hb.GetStatusBarTexture then return end
  local layer = hb.fxiTapped
  if not layer then
    layer = hb:CreateTexture(nil, "ARTWORK", nil, 7)
    layer:SetTexture("Interface\\Buttons\\WHITE8X8")
    layer:SetVertexColor(GREY[1], GREY[2], GREY[3], 1)
    hb.fxiTapped = layer
  end
  local fill = hb:GetStatusBarTexture()
  if fill and layer.fxiFill ~= fill then
    layer:ClearAllPoints()
    layer:SetAllPoints(fill)
    layer.fxiFill = fill
  end
  return layer
end

local function TapPass()
  if not (ns.db.plater.skin and ns.db.plater.tapGrey) or not C_NamePlate then return end
  local ok, plates = pcall(C_NamePlate.GetNamePlates)
  if not ok or type(plates) ~= "table" then return end
  for _, plate in ipairs(plates) do
    local uf = plate.unitFrame
    local unit = uf and (uf.namePlateUnitToken or uf.unit)
    local layer = unit and TapLayer(uf)
    if layer then
      if ns.Bool(UnitIsPlayer, unit) or ns.Bool(UnitPlayerControlled, unit) then
        layer:SetAlpha(0)
      else
        local okT, tapped = pcall(UnitIsTapDenied, unit)
        if not okT then
          layer:SetAlpha(0)
        elseif ns.Readable(tapped) then
          layer:SetAlpha(tapped and 1 or 0)
        elseif layer.SetAlphaFromBoolean then
          pcall(layer.SetAlphaFromBoolean, layer, tapped, 1, 0)
        else
          layer:SetAlpha(0)
        end
      end
    end
  end
end
M.TapPass = TapPass

function M:Init()
  if not ns.db.plater.skin then return end
  C_Timer.NewTicker(0.25, function() pcall(TapPass) end)
  -- Plater sets its profile up at login; wait a moment after that. Our flat
  -- texture has to be registered every login (Plater looks it up by name).
  C_Timer.After(2, function()
    if type(Plater) ~= "table" then return end
    RegisterMedia()
    WrapPartyBars()
    HookNames()
    if (ns.db.plater.applied or 0) >= STYLE then Refresh() else M.Apply(false) end
  end)
end
