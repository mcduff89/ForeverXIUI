-- Enemy list (XIUI style): the mobs you and your group are fighting, in a
-- small navy window by the target bar. Each line: raid marker, name, HP%,
-- and a thin HP bar. Your target is outlined; the name turns yellow when
-- you're pulling ahead of the tank and red when the mob is on you.
--
-- It reads the enemy nameplates (nameplate1-40), so enemy nameplates must
-- be on (V key, or Options > Nameplates) and a mob only shows while its
-- plate is on screen. Health is secret on Forever; it goes straight into
-- the bar and text, which accept secrets.
--
-- Display only: a click can't target a nameplate unit from addon code in
-- combat (the units behind the tokens change), so use Tab, or click the
-- mob or its plate as usual.
local _, ns = ...

local M = ns.AddModule("EnemyList")

local W, ROW_H, PAD, TITLE_H, MAX_ROWS = 180, 20, 4, 14, 8
local GROUP = { "player", "party1", "party2", "party3", "party4" }

local function Read(fn, ...)
  if not fn then return nil end
  local ok, v = pcall(fn, ...)
  if ok and ns.Readable(v) then return v end
  return nil
end

-- Is this plate a mob that's fighting us? Threat first (on anyone in the
-- group's threat table), then "hostile and in combat with a group member
-- targeted" as a fallback when threat reads are refused.
local function Engaged(unit)
  if not Read(UnitCanAttack, "player", unit) then return false end
  if Read(UnitIsDeadOrGhost, unit) then return false end
  local units = IsInRaid() and {} or GROUP
  for _, who in ipairs(units) do
    if UnitExists(who) then
      local status = Read(UnitThreatSituation, who, unit)
      if type(status) == "number" then return true end
    end
  end
  if Read(UnitAffectingCombat, unit) then
    local tt = unit .. "target"
    if UnitExists(tt) and (Read(UnitInParty, tt) or Read(UnitIsUnit, tt, "player") or Read(UnitInRaid, tt)) then
      return true
    end
  end
  return false
end

-- Name colour from your threat on that mob (non-tank view), like the
-- target bar: white safe, yellow careful, red it's on you.
local function NameColor(unit)
  local status = Read(UnitThreatSituation, "player", unit)
  if type(status) ~= "number" then return 1, 1, 1 end
  local tank = false
  local ok, role = pcall(UnitGroupRolesAssigned, "player")
  if (ok and ns.Readable(role) and role == "TANK") or ns.db.target.alwaysTank then tank = true end
  if tank then
    if status == 3 then return 1, 1, 1 end
    if status == 2 then return ns.Style.Color("threatWarn") end
    return ns.Style.Color("threatBad")
  end
  if status == 0 then return 1, 1, 1 end
  if status == 1 then return ns.Style.Color("threatWarn") end
  return ns.Style.Color("threatBad")
end

local rows = {}
local order = {}      -- unit token -> first-seen counter, so lines don't jump
local seen = 0

local function BuildRow(parent, i)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(W - PAD * 2, ROW_H)
  row.mark = row:CreateTexture(nil, "OVERLAY")
  row.mark:SetSize(12, 12)
  row.mark:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
  row.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  row.mark:Hide()
  row.name = ns.Style.Text(row, 11)
  row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -1)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.pct = ns.Style.Text(row, 10)
  row.pct:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -1)
  row.pct:SetJustifyH("RIGHT")
  row.pct:SetTextColor(ns.Style.Color("hpText"))
  row.name:SetPoint("RIGHT", row.pct, "LEFT", -4, 0)
  row.hp = ns.Style.Bar(row, W - PAD * 2 - 4, 4, "hpTarget")
  row.hp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 2)
  row.hp:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
  -- Outline for your current target.
  row.sel = CreateFrame("Frame", nil, row)
  row.sel:SetAllPoints()
  local lr, lg, lb = ns.Style.Color("edgeLight")
  for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
    local t = row.sel:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(lr, lg, lb, 0.9)
    t:SetPoint(e[1])
    t:SetPoint(e[2])
    if e[3] then t:SetWidth(e[3]) end
    if e[4] then t:SetHeight(e[4]) end
  end
  row.sel:Hide()
  rows[i] = row
  return row
end

local function Fill(row, unit)
  ns.Values.Name(row.name, unit)
  row.name:SetTextColor(NameColor(unit))
  ns.Values.Health(row.hp, row.pct, unit, "percent", false)
  row.hp:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpTarget")))
  local mark = Read(GetRaidTargetIndex, unit)
  if type(mark) == "number" and SetRaidTargetIconTexture then
    SetRaidTargetIconTexture(row.mark, mark)
    row.mark:Show()
  else
    row.mark:Hide()
  end
  row.sel:SetShown(Read(UnitIsUnit, unit, "target") and true or false)
end

local function Place(f, n)
  for i = 1, MAX_ROWS do
    local row = rows[i]
    if i <= n then
      row:ClearAllPoints()
      -- Bottom-up, like the party list: the first mob sits at the bottom.
      row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, PAD + (i - 1) * ROW_H)
      row:Show()
    else
      row:Hide()
    end
  end
  f.panel:SetHeight(math.max(1, n) * ROW_H + PAD * 2)
  f.panel:SetShown(n > 0)
end

local function Update(f)
  if f.previewing then return end
  local list = {}
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if UnitExists(unit) and Engaged(unit) then
      if not order[unit] then seen = seen + 1; order[unit] = seen end
      list[#list + 1] = unit
    else
      order[unit] = nil
    end
  end
  table.sort(list, function(a, b) return order[a] < order[b] end)
  local n = math.min(#list, MAX_ROWS)
  for i = 1, n do Fill(rows[i], list[i]) end
  Place(f, n)
  f.count:SetText(#list > 0 and ("Enemies " .. #list) or "")
end

function M:Init()
  if not ns.db.modules.enemy then return end
  local f = CreateFrame("Frame", "ForeverXIUIEnemyList", UIParent)
  f:SetSize(W, MAX_ROWS * ROW_H + PAD * 2 + TITLE_H)
  local panel = CreateFrame("Frame", nil, f)
  panel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  panel:SetWidth(W)
  ns.Style.Panel(panel)
  panel:Hide()
  f.panel = panel
  f.count = ns.Style.Text(panel, 10)
  f.count:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -4, 1)
  f.count:SetTextColor(ns.Style.Color("title"))
  for i = 1, MAX_ROWS do BuildRow(f, i):Hide() end

  for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
    "UNIT_THREAT_LIST_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "RAID_TARGET_UPDATE" }) do
    pcall(f.RegisterEvent, f, e)
  end
  f:SetScript("OnEvent", Update)
  -- Health and threat change constantly; a few times a second is plenty.
  local acc = 0
  f:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    Update(self)
  end)
  Update(f)

  self.frame = f
  ns.AddRoot(f, "enemy")
  ns.Movers.Register("enemy", "Enemy list", f, { "BOTTOM", "BOTTOM", -300, 340 })
end

local FAKE = { { "Harvest Reaper", 62, 8 }, { "Kobold Miner", 100 }, { "Kobold Tunneler", 35 }, { "Tunnel Rat Scout", 88 } }

function M:Preview(on)
  local f = self.frame
  if not f then return end
  f.previewing = on and true or nil
  if not on then Update(f) return end
  for i, d in ipairs(FAKE) do
    local row = rows[i]
    row.name:SetText(d[1])
    row.name:SetTextColor(i == 3 and 0.91 or 1, i == 3 and 0.78 or 1, i == 3 and 0.05 or 1)
    row.pct:SetText(d[2] .. "%")
    row.hp:SetMinMaxValues(0, 100)
    row.hp:SetValue(d[2])
    row.hp:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpTarget")))
    if d[3] and SetRaidTargetIconTexture then
      SetRaidTargetIconTexture(row.mark, d[3])
      row.mark:Show()
    else
      row.mark:Hide()
    end
    row.sel:SetShown(i == 1)
  end
  Place(f, #FAKE)
  f.count:SetText("Enemies " .. #FAKE)
end
