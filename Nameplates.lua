-- XI nameplates: the game's own nameplates in the ForeverXIUI look, so Plater
-- isn't needed. Each plate gets an XI bar on top of it and Blizzard's own
-- plate art is faded (never moved or hidden).
--
-- Enemies: a 120x14 bar with health %, name above, threat colours in
-- combat, grey when someone else has claimed the mob, the XI blue edge on
-- your target, raid marker, and a cast bar under it.
-- Friendly players: just the name, coloured by who they are (party green,
-- your faction blue), with a class icon. Party and raid members also get a
-- thin green line under the name. Friendly NPCs: name only.
--
-- Plater does all of this its own way, so this only runs while Plater is
-- turned off in the AddOns list. Off by default; turning it on or off needs
-- a /reload.
local _, ns = ...

local M = ns.AddModule("Nameplates")

local W, H, CAST_H = 120, 14, 10
local PARTY_W, PARTY_H = 80, 4
local NAME_FONT = "Fonts\\FRIZQT__.TTF"   -- the game's own font: wider and easier to read than Arial Narrow
local GAP = 4                              -- space between a name and its bar

local NAME = {
  party = { 0.35, 0.95, 0.35 },
  friend = { 0.40, 0.70, 1.00 },
  other = { 1.00, 0.60, 0.15 },
  hostile = { 1.00, 0.22, 0.22 },
  npc = { 0.60, 0.90, 0.60 },
  neutral = { 1.00, 0.85, 0.20 },
}
local GREY = { 0.55, 0.55, 0.55 }

local byUnit = {}      -- "nameplate3" -> our frame
local faded = {}

local function o() return ns.db.nameplates end

local function KeepFaded(region)
  if faded[region] and region:GetAlpha() > 0 then region:SetAlpha(0) end
end

local function Fade(region)
  if type(region) ~= "table" or not region.SetAlpha then return end
  region:SetAlpha(0)
  if not faded[region] then
    faded[region] = true
    hooksecurefunc(region, "SetAlpha", KeepFaded)
  end
end

local function InGroup(unit)
  if ns.Bool(UnitIsUnit, unit, "player") then return false end
  return ns.Bool(UnitInParty, unit) or ns.Bool(UnitInRaid, unit) or false
end

---------------------------------------------------------------------------
-- One XI plate (made once per Blizzard plate, reused as units come and go)
---------------------------------------------------------------------------
local function Build(plate)
  local f = CreateFrame("Frame", nil, plate)
  f:SetSize(W, H + 30)
  f:SetPoint("CENTER", plate, "CENTER", 0, 0)
  f:SetFrameStrata(plate:GetFrameStrata())

  local hp = ns.Style.Bar(f, W, H, "hpTarget")
  hp:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.hp = hp

  f.pct = ns.Style.Text(hp, 10)
  f.pct:SetPoint("RIGHT", hp, "RIGHT", -3, 0)
  f.pct:SetJustifyH("RIGHT")

  f.name = f:CreateFontString(nil, "OVERLAY")
  f.name:SetPoint("BOTTOM", hp, "TOP", 0, GAP)
  f.name:SetWordWrap(false)

  f.class = f:CreateTexture(nil, "OVERLAY")
  f.class:SetSize(14, 14)
  f.class:SetPoint("RIGHT", f.name, "LEFT", -2, 0)
  f.class:Hide()

  f.raid = f:CreateTexture(nil, "OVERLAY")
  f.raid:SetSize(18, 18)
  f.raid:SetPoint("RIGHT", hp, "LEFT", -4, 0)
  f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  f.raid:Hide()

  -- Grey layer over the fill for mobs someone else claimed.
  local tap = hp:CreateTexture(nil, "ARTWORK", nil, 7)
  tap:SetTexture("Interface\\Buttons\\WHITE8X8")
  tap:SetVertexColor(GREY[1], GREY[2], GREY[3], 1)
  tap:SetAllPoints(hp:GetStatusBarTexture())
  tap:SetAlpha(0)
  f.tap = tap

  local cast = ns.CastBar.Create(nil, "player", W, CAST_H, true)
  cast:SetParent(f)
  cast:ClearAllPoints()
  cast:SetPoint("TOP", hp, "BOTTOM", 0, -4)
  ns.CastBar.SetUnit(cast, nil)
  f.cast = cast

  plate.fxiPlate = f
  return f
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------
local function Kind(unit)
  local isPlayer = ns.Bool(UnitIsPlayer, unit)
  local friend = ns.Bool(UnitIsFriend, "player", unit)
  local attack = ns.Bool(UnitCanAttack, "player", unit)
  if friend then
    if isPlayer then return InGroup(unit) and "party" or "friend" end
    if ns.Bool(UnitPlayerControlled, unit) then return "pet" end
    return "npc"
  end
  if isPlayer then return attack and "enemyPlayer" or "other" end
  return "enemy"
end

local function TapAlpha(f, unit)
  if ns.Bool(UnitPlayerControlled, unit) then f.tap:SetAlpha(0) return end
  local ok, tapped = pcall(UnitIsTapDenied, unit)
  if not ok then f.tap:SetAlpha(0)
  elseif ns.Readable(tapped) then f.tap:SetAlpha(tapped and 1 or 0)
  elseif f.tap.SetAlphaFromBoolean then pcall(f.tap.SetAlphaFromBoolean, f.tap, tapped, 1, 0)
  else f.tap:SetAlpha(0) end
end

local function BarColor(f, unit, kind)
  if kind == "party" then
    f.hp:SetStatusBarColor(NAME.party[1], NAME.party[2], NAME.party[3])
    return
  end
  if kind == "enemyPlayer" then
    f.hp:SetStatusBarColor(ns.Style.Color("hpClassic"))
    return
  end
  -- Mobs: threat colours while it's fighting, else by reaction.
  local tb = ns.modules.TargetBar
  local key = tb and tb.ThreatColorKey and InCombatLockdown() and tb.ThreatColorKey(unit)
  if key then
    f.hp:SetStatusBarColor(ns.Style.Color(key))
    return
  end
  local ok, reaction = pcall(UnitReaction, unit, "player")
  if ok and ns.Readable(reaction) and type(reaction) == "number" and reaction == 4 then
    f.hp:SetStatusBarColor(NAME.neutral[1], NAME.neutral[2], NAME.neutral[3])
  else
    f.hp:SetStatusBarColor(ns.Style.Color("hpClassic"))
  end
end

local function Highlight(f, unit)
  local isTarget = ns.Bool(UnitIsUnit, unit, "target")
  local edge = f.hp.edge
  if isTarget then
    local r, g, b = ns.Style.Color("edgeLight")
    edge:SetColorTexture(r, g, b, 1)
  else
    edge:SetColorTexture(0, 0, 0, 0.85)
  end
  f:SetAlpha((isTarget or not UnitExists("target") or f.kind == "party") and 1 or (o().otherAlpha or 0.8))
end

local function Raid(f, unit)
  local ok, idx = pcall(GetRaidTargetIndex, unit)
  if ok and ns.Readable(idx) and type(idx) == "number" and SetRaidTargetIconTexture then
    SetRaidTargetIconTexture(f.raid, idx)
    f.raid:Show()
  else
    f.raid:Hide()
  end
end

local function Paint(f)
  local unit = f.unit
  if not unit then return end
  local kind = Kind(unit)
  f.kind = kind
  local scale = tonumber(ns.db.frameScale and ns.db.frameScale.nameplates) or 1
  f:SetScale(scale)

  -- Names: the game font, a solid outline and a full shadow so they read
  -- against busy ground. Size comes from the slider.
  local size = tonumber(o().nameSize) or 13
  if f.nameSize ~= size then
    f.name:SetFont(NAME_FONT, size, "OUTLINE")
    f.name:SetShadowOffset(1, -1)
    f.name:SetShadowColor(0, 0, 0, 1)
    f.class:SetSize(size + 2, size + 2)
    f.nameSize = size
  end

  ns.Values.Name(f.name, unit)
  local c = NAME[kind] or NAME.hostile
  if kind == "enemy" then c = { 1, 1, 1 } end
  if kind == "pet" then c = NAME.npc end
  f.name:SetTextColor(c[1], c[2], c[3])

  local player = kind == "party" or kind == "friend" or kind == "other" or kind == "enemyPlayer"
  if player then
    local ok, _, class = pcall(UnitClass, unit)
    if ok then ns.Style.ClassIcon(f.class, class) else f.class:Hide() end
  else
    f.class:Hide()
  end

  local bar = kind == "enemy" or kind == "enemyPlayer" or (kind == "party" and o().partyBars)
  local nameOnly = not bar
  f.hp:SetShown(bar)
  f.name:SetShown(not (kind == "pet" and o().hidePets))
  f.name:ClearAllPoints()
  if nameOnly then
    f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
  else
    f.name:SetPoint("BOTTOM", f.hp, "TOP", 0, GAP)
  end
  if bar then
    if kind == "party" then f.hp:SetSize(PARTY_W, PARTY_H) else f.hp:SetSize(W, H) end
    f.pct:SetShown(kind ~= "party")
    ns.Values.Health(f.hp, f.pct, unit, "percent", false)
    BarColor(f, unit, kind)
    TapAlpha(f, unit)
  end
  local wantCast = o().castBars and (kind == "enemy" or kind == "enemyPlayer")
  if wantCast then
    if f.cast.unit ~= unit then ns.CastBar.SetUnit(f.cast, unit) end
  elseif f.cast.unit then
    ns.CastBar.SetUnit(f.cast, nil)
  end
  Raid(f, unit)
  Highlight(f, unit)
end

local function Health(f)
  if not f.unit or not f.hp:IsShown() then return end
  ns.Values.Health(f.hp, f.pct, f.unit, "percent", false)
end

---------------------------------------------------------------------------
-- Plates coming and going
---------------------------------------------------------------------------
local function Added(unit)
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" then return end   -- forbidden (friendly, in instances)
  local f = plate.fxiPlate or Build(plate)
  Fade(plate.UnitFrame)
  f.unit = unit
  byUnit[unit] = f
  f:Show()
  local okP, err = pcall(Paint, f)
  if not okP and not M.warned then
    M.warned = true
    ns.Print("nameplate: %s", tostring(err))
  end
end

local function Removed(unit)
  local f = byUnit[unit]
  if not f then return end
  byUnit[unit] = nil
  f.unit = nil
  ns.CastBar.SetUnit(f.cast, nil)
  f:Hide()
end

---------------------------------------------------------------------------
-- How far plates reach, and the game's floating names past that range.
-- These are game settings (CVars); the old values are kept so turning the
-- options off puts them back. The game won't change them in combat.
---------------------------------------------------------------------------
local FLOATING = { "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameNPC",
  "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
  "UnitNameFriendlyMinionName", "UnitNameEnemyPetName", "UnitNameEnemyGuardianName",
  "UnitNameEnemyTotemName", "UnitNameEnemyMinionName" }

local function GetCV(name)
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  local ok, v = pcall(get, name)
  if ok then return v end
end

local function SetCV(name, value)
  local set = (C_CVar and C_CVar.SetCVar) or SetCVar
  if GetCV(name) == nil then return false end   -- not on this client
  return pcall(set, name, tostring(value))
end

local function Backup(name)
  local b = o().cvarBackup
  if not b then b = {}; o().cvarBackup = b end
  if b[name] == nil then b[name] = GetCV(name) end
end

local function Restore(name)
  local b = o().cvarBackup
  if b and b[name] ~= nil then
    if SetCV(name, b[name]) then b[name] = nil end
  end
end

function M.ApplyCVars()
  if InCombatLockdown() then M.cvarsPending = true return end
  M.cvarsPending = nil
  local d = tonumber(o().distance)
  if d and d > 0 then
    Backup("nameplateMaxDistance")
    SetCV("nameplateMaxDistance", d)
  else
    Restore("nameplateMaxDistance")
  end
  for _, name in ipairs(FLOATING) do
    if o().hideFloating then
      Backup(name)
      SetCV(name, 0)
    else
      Restore(name)
    end
  end
end

local function PlaterOn()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Plater"))
    or (IsAddOnLoaded and IsAddOnLoaded("Plater"))
  return loaded and true or false
end

function M:Init()
  if not ns.db.modules.nameplates or not C_NamePlate then return end
  if PlaterOn() then
    C_Timer.After(3, function()
      ns.Print("XI nameplates are on, but so is Plater. Turn Plater off in the AddOns list (or XI nameplates off in /fxiui) and /reload.")
    end)
    return
  end

  M.ApplyCVars()

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
    "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_THREAT_LIST_UPDATE",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FLAGS" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then Added(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then Removed(unit)
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
      local f = unit and byUnit[unit]
      if f then pcall(Health, f) end
    elseif event == "PLAYER_TARGET_CHANGED" then
      for _, f in pairs(byUnit) do pcall(Highlight, f, f.unit) end
    elseif event == "PLAYER_REGEN_ENABLED" and M.cvarsPending then
      M.ApplyCVars()
      for _, f in pairs(byUnit) do pcall(Paint, f) end
    elseif event == "RAID_TARGET_UPDATE" then
      for _, f in pairs(byUnit) do pcall(Raid, f, f.unit) end
    elseif unit and byUnit[unit] then
      pcall(Paint, byUnit[unit])
    else
      for _, f in pairs(byUnit) do pcall(Paint, f) end
    end
  end)
  -- Threat and claimed-grey change without an event we can count on.
  C_Timer.NewTicker(0.25, function()
    for _, f in pairs(byUnit) do
      if f.hp:IsShown() then
        pcall(BarColor, f, f.unit, f.kind)
        pcall(TapAlpha, f, f.unit)
      end
    end
  end)
  -- Plates already up (after a /reload).
  if C_NamePlate.GetNamePlates then
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if ok and type(plates) == "table" then
      for _, plate in ipairs(plates) do
        local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if u then Added(u) end
      end
    end
  end
  self.active = true
end

function M:Relayout()
  if not self.active then return end
  M.ApplyCVars()
  for _, f in pairs(byUnit) do pcall(Paint, f) end
end

function M.Describe()
  if not ns.db.modules.nameplates then return "off" end
  if PlaterOn() then return "waiting (Plater is on)" end
  local n = 0
  for _ in pairs(byUnit) do n = n + 1 end
  return ("on, %d plates"):format(n)
end
