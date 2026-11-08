-- Target bar (XIUI style): one long slim bar, the target's name above it on
-- the left and HP% on the right. Between them, XIUI-style mob info: level
-- (in the game's difficulty colour), elite/rare, and creature type or class.
-- The target's cast bar sits under it, and the target of target to its right.
-- The bar itself is not secure: it shows and hides with your target, in or
-- out of combat. The target of target is a secure button so a click targets it.
local _, ns = ...

local M = ns.AddModule("TargetBar")

local W, W_COMPACT, H = 390, 300, 16

-- Threat colour for the bar, or nil to keep XIUI's pink.
-- UnitThreatSituation: 0 not tanking, lower threat; 1 not tanking, higher
-- than the tank; 2 tanking but someone is higher; 3 tanking securely.
-- nil means the target isn't fighting you. A secret answer is skipped.
local function IsTank()
  if ns.db.target.alwaysTank then return true end
  local ok, role = pcall(UnitGroupRolesAssigned, "player")
  return ok and ns.Readable(role) and role == "TANK"
end

local function ThreatColorKey(unit)
  if not ns.db.target.threatColors or not UnitThreatSituation then return nil end
  local ok, status = pcall(UnitThreatSituation, "player", unit or "target")
  if not ok or type(status) ~= "number" or not ns.Readable(status) then return nil end
  if IsTank() then
    -- green = you have it, yellow = losing it, red = lost it
    if status == 3 then return "threatGood" end
    if status == 2 then return "threatWarn" end
    return "threatBad"
  end
  -- green = safe, yellow = careful, red = it's on you
  if status == 0 then return "threatGood" end
  if status == 1 then return "threatWarn" end
  return "threatBad"
end
M.ThreatColorKey = ThreatColorKey

---------------------------------------------------------------------------
-- Mob info: "Lv 18 Elite Beast", "Lv 60 Shaman", "Lv ?? Boss". Every read is
-- guarded; anything Forever keeps secret is just left out.
---------------------------------------------------------------------------
local CLASSIFICATION = { elite = "Elite", rareelite = "Rare Elite", rare = "Rare", worldboss = "Boss" }

local function Read(fn, ...)
  if not fn then return nil end
  local ok, v = pcall(fn, ...)
  if ok and ns.Readable(v) then return v end
  return nil
end

local function MobInfo(unit)
  local parts = {}
  local r, g, b = 1, 1, 1
  local level = Read(UnitEffectiveLevel, unit) or Read(UnitLevel, unit)
  local class = Read(UnitClassification, unit)
  if type(level) == "number" then
    if level <= 0 then
      parts[#parts + 1] = "Lv ??"
      r, g, b = 1, 0.1, 0.1
    else
      parts[#parts + 1] = "Lv " .. level
      local color = Read(GetCreatureDifficultyColor, level) or Read(GetQuestDifficultyColor, level)
      if type(color) == "table" and type(color.r) == "number" then r, g, b = color.r, color.g, color.b end
    end
  end
  if type(class) == "string" and CLASSIFICATION[class] then
    parts[#parts + 1] = CLASSIFICATION[class]
  end
  if Read(UnitIsPlayer, unit) then
    local localized = Read(UnitClass, unit)
    if type(localized) == "string" then parts[#parts + 1] = localized end
  else
    local kind = Read(UnitCreatureType, unit)
    if type(kind) == "string" and kind ~= "Not specified" then parts[#parts + 1] = kind end
  end
  return table.concat(parts, " "), r, g, b
end
M.MobInfo = MobInfo

local function Update(f)
  -- Shown and hidden by the game (RegisterUnitWatch), since the bar is a
  -- secure button: click to target, right-click for the unit menu.
  if not UnitExists("target") then return end
  ns.Values.Name(f.name, "target")
  if ns.db.target.mobInfo then
    local text, r, g, b = MobInfo("target")
    f.info:SetText(text)
    f.info:SetTextColor(r, g, b)
  else
    f.info:SetText("")
  end
  ns.Values.Health(f.hp, f.pct, "target", "percent", false)
  f.hp:SetStatusBarColor(ns.Style.Color(ThreatColorKey() or ns.Style.HealthKey("hpTarget")))
  local dead = ns.Values.IsDead("target")
  if dead then f.pct:SetText("Dead") end
end

local function Layout(f)
  if InCombatLockdown() then return end
  local w = ns.db.compact and W_COMPACT or W
  f:SetSize(w, H + 18)
  f.hp:SetSize(w, H)
end

function M:Init()
  if ns.db.modules.target then
    local f = CreateFrame("Button", "ForeverXIUITargetBar", UIParent, "SecureUnitButtonTemplate")
    f.unit = "target"
    f:SetAttribute("unit", "target")
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    ns.UnitTooltip(f)
    f.hp = ns.Style.Bar(f, W, H, "hpTarget")
    f.hp:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2)
    f.hp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 2)

    f.name = ns.Style.Text(f, 13)
    f.name:SetPoint("BOTTOMLEFT", f.hp, "TOPLEFT", 4, 2)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.pct = ns.Style.Text(f, 12)
    f.pct:SetPoint("BOTTOMRIGHT", f.hp, "TOPRIGHT", -4, 2)
    f.pct:SetJustifyH("RIGHT")
    f.pct:SetTextColor(ns.Style.Color("hpText"))
    f.info = ns.Style.Text(f, 11)
    f.info:SetPoint("BOTTOMRIGHT", f.hp, "TOPRIGHT", -44, 2)
    f.info:SetJustifyH("RIGHT")
    f.info:SetWordWrap(false)
    f.name:SetPoint("RIGHT", f.info, "LEFT", -8, 0)
    Layout(f)

    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    pcall(f.RegisterUnitEvent, f, "UNIT_LEVEL", "target")
    pcall(f.RegisterUnitEvent, f, "UNIT_CLASSIFICATION_CHANGED", "target")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, e in ipairs({ "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED", "PLAYER_ROLES_ASSIGNED" }) do
      pcall(f.RegisterEvent, f, e)
    end
    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS" }) do
      pcall(f.RegisterUnitEvent, f, e, "target")
    end
    f:SetScript("OnEvent", function(self, event)
      if event == "PLAYER_TARGET_CHANGED" and ns.Auras then ns.Auras.LineRefresh(self) end
      if not self.previewing then Update(self) end
    end)
    Update(f)
    M.BuildAuras(f)
    RegisterUnitWatch(f)

    self.frame = f
    ns.AddRoot(f, "target")
    ns.Movers.Register("target", "Target bar", f, { "BOTTOM", "BOTTOM", 0, 360 })
  end

  if ns.db.modules.tot then self.tot = M.BuildToT() end

  if ns.db.modules.targetCast then
    local c = ns.CastBar.Create("ForeverXIUITargetCast", "target", 300, 13, true)
    self.cast = c
    ns.AddRoot(c, "targetCast")
    ns.Movers.Register("targetCast", "Target cast bar", c, { "BOTTOM", "BOTTOM", 0, 340 })
  end
end

---------------------------------------------------------------------------
-- Buffs and debuffs over the target bar (XIUI's target buff line): the
-- mob's debuffs (yours, or everyone's) on the line just over the name,
-- its buffs on the line above. Drawn by the game, so they keep working in
-- combat; timers under each icon.
---------------------------------------------------------------------------
local function AuraWants()
  local t = ns.db.target
  return {
    debuffs = { on = t.auras and t.showDebuffs, filter = t.onlyMine and "HARMFUL|PLAYER" or "HARMFUL" },
    buffs = { on = t.auras and t.showBuffs, filter = "HELPFUL" },
  }
end

function M.BuildAuras(f)
  if not ns.Auras or not ns.db.target.auras then return end
  ns.AfterCombat("targetAuras", function()
    local size = math.max(12, math.min(32, tonumber(ns.db.target.auraSize) or 20))
    local line = size + 12      -- icon plus its timer underneath
    local w = AuraWants()
    ns.Auras.Line(f, "target", {
      { kind = "debuffs", filter = w.debuffs.filter, max = 10, point = "BOTTOMLEFT", relPoint = "TOPLEFT", x = 2, y = 14 },
      { kind = "buffs", filter = w.buffs.filter, max = 10, point = "BOTTOMLEFT", relPoint = "TOPLEFT", x = 2, y = 14 + line },
    }, { size = size, timers = true, under = true })
    ns.Auras.LineApply(f, w)
  end)
end

---------------------------------------------------------------------------
-- Target of target: a short bar with the name above it. targettarget has
-- no events of its own, so it re-reads a few times a second while shown.
---------------------------------------------------------------------------
local TOT_W, TOT_H = 120, 8

local function UpdateToT(t)
  if t.previewing or not UnitExists("targettarget") then return end
  ns.Values.Name(t.name, "targettarget")
  ns.Values.Health(t.hp, t.pct, "targettarget", "percent", false)
  local isMe = ns.Bool(UnitIsUnit, "targettarget", "player")
  t.name:SetTextColor(1, isMe and 0.55 or 1, isMe and 0.55 or 1)
  t.hp:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpTarget")))
  if ns.Values.IsDead("targettarget") then t.pct:SetText("Dead") end
end

function M.BuildToT()
  local t = CreateFrame("Button", "ForeverXIUITargetTarget", UIParent, "SecureUnitButtonTemplate")
  t:SetAttribute("unit", "targettarget")
  t:SetAttribute("*type1", "target")
  t:SetAttribute("*type2", "togglemenu")
  t:RegisterForClicks("AnyUp")
  t.unit = "targettarget"
  ns.UnitTooltip(t)
  t:SetSize(TOT_W, TOT_H + 16)
  t.hp = ns.Style.Bar(t, TOT_W, TOT_H, "hpTarget")
  t.hp:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 2)
  t.arrow = ns.Style.Text(t, 10)
  t.arrow:SetPoint("BOTTOMLEFT", t.hp, "TOPLEFT", 0, 2)
  t.arrow:SetText(">>")
  t.arrow:SetTextColor(ns.Style.Color("title"))
  t.name = ns.Style.Text(t, 11)
  t.name:SetPoint("LEFT", t.arrow, "RIGHT", 3, 0)
  t.name:SetJustifyH("LEFT")
  t.name:SetWordWrap(false)
  t.pct = ns.Style.Text(t, 10)
  t.pct:SetPoint("BOTTOMRIGHT", t.hp, "TOPRIGHT", 0, 2)
  t.pct:SetTextColor(ns.Style.Color("hpText"))
  t.name:SetPoint("RIGHT", t.pct, "LEFT", -4, 0)

  t:RegisterEvent("PLAYER_TARGET_CHANGED")
  pcall(t.RegisterUnitEvent, t, "UNIT_TARGET", "target")
  t:SetScript("OnEvent", UpdateToT)
  t:HookScript("OnShow", UpdateToT)
  local elapsed = 0
  t:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    UpdateToT(self)
  end)
  RegisterUnitWatch(t)
  ns.AddRoot(t, "tot")
  ns.Movers.Register("tot", "Target of target", t, { "BOTTOM", "BOTTOM", 268, 360 })
  return t
end

function M:Relayout()
  if self.frame and ns.Auras and self.frame.fxiLine then ns.Auras.LineApply(self.frame, AuraWants()) end
  if self.frame then Layout(self.frame) end
end

-- /fxiui move shows a pretend target so the bar can be placed.
function M:Preview(on)
  local f = self.frame
  if f and not InCombatLockdown() then
    f.previewing = on and true or nil
    if on then
      UnregisterUnitWatch(f)
      f.name:SetText("Target Name")
      f.pct:SetText("62%")
      f.info:SetText(ns.db.target.mobInfo and "Lv 18 Elite Beast" or "")
      f.info:SetTextColor(1, 0.82, 0)
      f.hp:SetMinMaxValues(0, 100)
      f.hp:SetValue(62)
      f:Show()
    else
      RegisterUnitWatch(f)
      Update(f)
    end
  end
  if self.cast then ns.CastBar.Preview(self.cast, on) end
  local t = self.tot
  if t and not InCombatLockdown() then
    t.previewing = on and true or nil
    if on then
      UnregisterUnitWatch(t)
      t.name:SetText("Mortium")
      t.name:SetTextColor(1, 1, 1)
      t.pct:SetText("19%")
      t.hp:SetMinMaxValues(0, 100)
      t.hp:SetValue(19)
      t:Show()
    else
      RegisterUnitWatch(t)
      UpdateToT(t)
    end
  end
end
