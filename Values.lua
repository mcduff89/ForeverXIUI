-- Health and power onto bars and text without doing arithmetic on them.
--
-- On Forever, health and power can be "secret": a widget will display them,
-- but addon code that adds, divides or compares one throws. So the rule is
-- pass through, never calculate. Percentages and colours come from the
-- game's own curve helpers (C_CurveUtil), which do the maths on its side.
local _, ns = ...

local Values = {}
ns.Values = Values

local percentCurve, percentTried
local function PercentCurve()
  if percentTried then return percentCurve end
  percentTried = true
  if not (C_CurveUtil and C_CurveUtil.CreateCurve) then return nil end
  local ok, curve = pcall(C_CurveUtil.CreateCurve)
  if not ok or not curve then return nil end
  if pcall(function() curve:AddPoint(0, 0); curve:AddPoint(1, 100) end) then
    percentCurve = curve
  end
  return percentCurve
end
Values.PercentCurve = PercentCurve

-- XIUI's four health bands as a stepped colour curve.
local hpCurve, hpTried
local function HealthColorCurve()
  if hpTried then return hpCurve end
  hpTried = true
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
  local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
  if not ok or not curve then return nil end
  local S = ns.Style
  local bands = {
    { 0.00, "hpLow" }, { 0.25, "hpLow" },
    { 0.251, "hpMedLow" }, { 0.50, "hpMedLow" },
    { 0.501, "hpMedHigh" }, { 0.75, "hpMedHigh" },
    { 0.751, "hpHigh" }, { 1.00, "hpHigh" },
  }
  if pcall(function()
    for _, b in ipairs(bands) do
      local r, g, bl = S.Color(b[2])
      curve:AddPoint(b[1], CreateColor(r, g, bl, 1))
    end
  end) then
    hpCurve = curve
  end
  return hpCurve
end

-- Fill a bar. If a secret maximum is refused, keep something drawn.
local barWarned = false
function Values.SetBar(bar, cur, max)
  local okRange = pcall(bar.SetMinMaxValues, bar, 0, max)
  if not okRange then pcall(bar.SetMinMaxValues, bar, 0, 100) end
  local okValue = pcall(bar.SetValue, bar, cur)
  if (not okRange or not okValue) and not barWarned then
    barWarned = true
    ns.Print("a bar refused its values on this client. Run /fxiui check and send me the output.")
  end
end

local function HealthPercent(unit, cur, max)
  local curve = PercentCurve()
  if curve and UnitHealthPercent then
    local ok, pct = pcall(UnitHealthPercent, unit, true, curve)
    if ok and type(pct) ~= "nil" then return pct end
  end
  local ok, pct = pcall(function() return max > 0 and (cur / max * 100) or 0 end)
  if ok then return pct end
  return nil
end

local function PowerPercent(unit, cur, max)
  local curve = PercentCurve()
  if curve and UnitPowerPercent then
    local ok, pct = pcall(UnitPowerPercent, unit, nil, false, curve)
    if ok and type(pct) ~= "nil" then return pct end
  end
  local ok, pct = pcall(function() return max > 0 and (cur / max * 100) or 0 end)
  if ok then return pct end
  return nil
end

-- "1108 (100%)", XIUI's format. mode: "both", "value", "percent", "none".
local function Write(fs, cur, pct, mode)
  if not fs then return end
  if mode == "none" then fs:SetText("") return end
  local ok
  if mode == "percent" and type(pct) ~= "nil" then
    ok = pcall(fs.SetFormattedText, fs, "%.0f%%", pct)
  elseif mode == "value" or type(pct) == "nil" then
    ok = pcall(fs.SetFormattedText, fs, "%s", cur)
  else
    ok = pcall(fs.SetFormattedText, fs, "%s (%.0f%%)", cur, pct)
  end
  if not ok then pcall(fs.SetText, fs, cur) end
end

-- Health onto a bar and its text, coloured by XIUI's bands when `banded`.
function Values.Health(bar, fs, unit, mode, banded)
  local cur, max = UnitHealth(unit), UnitHealthMax(unit)
  Values.SetBar(bar, cur, max)
  local pct = HealthPercent(unit, cur, max)
  Write(fs, cur, pct, mode or "both")

  if banded and not (ns.db and ns.db.look and ns.db.look.hpBands) then
    bar:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpHigh")))
  elseif banded then
    local curve = HealthColorCurve()
    local painted = false
    if curve and UnitHealthPercent then
      painted = pcall(function()
        bar:SetStatusBarColor(UnitHealthPercent(unit, true, curve):GetRGB())
      end)
    end
    if not painted then
      local key = "hpHigh"
      if ns.Readable(pct) then
        if pct <= 25 then key = "hpLow" elseif pct <= 50 then key = "hpMedLow" elseif pct <= 75 then key = "hpMedHigh" end
      end
      bar:SetStatusBarColor(ns.Style.Color(key))
    end
  end
end

function Values.Power(bar, fs, unit, mode)
  local _, token = UnitPowerType(unit)
  local cur, max = UnitPower(unit), UnitPowerMax(unit)
  Values.SetBar(bar, cur, max)
  Write(fs, cur, PowerPercent(unit, cur, max), mode or "both")
  if ns.Readable(token) then
    bar:SetStatusBarColor(ns.Style.PowerRGB(token))
  else
    bar:SetStatusBarColor(ns.Style.PowerRGB("MANA"))
  end
end

-- Name onto a font string. SetText accepts a secret name.
function Values.Name(fs, unit)
  local ok, name = pcall(UnitName, unit)
  if ok and type(name) ~= "nil" then
    pcall(fs.SetText, fs, name)
  else
    fs:SetText("")
  end
end

-- Dead / ghost / offline, as plain booleans (nil when we can't tell).
function Values.IsDead(unit)
  return ns.Bool(UnitIsDeadOrGhost, unit)
end

function Values.IsOffline(unit)
  local connected = ns.Bool(UnitIsConnected, unit)
  return connected == false
end
