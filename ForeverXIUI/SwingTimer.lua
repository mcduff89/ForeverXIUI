-- Swing timer: a slim bar under your cast bar that fills from one main-hand
-- swing to the next, with the time left on the right. For Enhancement:
-- time Stormstrike and shocks between swings.
--
-- Where the swings come from: the combat log, if Forever lets addons read
-- it (your SWING_DAMAGE / SWING_MISSED resets the bar on the real swing).
-- If it doesn't, the bar runs on your weapon speed from the moment
-- auto-attack starts and keeps cycling while you fight, so it can drift a
-- little after a parry or a pause out of range. /fxiui check says which.
local _, ns = ...

local M = ns.AddModule("SwingTimer")

local W, H = 260, 5

local state = { start = nil, speed = nil, attacking = false, source = "estimate" }

local function Speed()
  local ok, main = pcall(UnitAttackSpeed, "player")
  if ok and type(main) == "number" and ns.Readable(main) and main > 0 then return main end
  return nil
end

local function Swing()
  local speed = Speed()
  if not speed then return end
  state.start, state.speed = GetTime(), speed
end

-- Combat log: only if Forever lets addons register and read it.
local logWorks = false
local function TryCombatLog(f)
  if not CombatLogGetCurrentEventInfo then return end
  local ok = pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
  if ok then logWorks = true end
end

local function OnLog()
  local ok, _, sub, _, src = pcall(CombatLogGetCurrentEventInfo)
  if not ok or not ns.Readable(sub) or not ns.Readable(src) then return end
  if src ~= UnitGUID("player") then return end
  if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
    -- Off-hand swings carry isOffHand; shamans have no off-hand here, but skip them anyway.
    local isOff
    if sub == "SWING_DAMAGE" then isOff = select(21, CombatLogGetCurrentEventInfo())
    else isOff = select(13, CombatLogGetCurrentEventInfo()) end
    if isOff == true then return end
    state.source = "combat log"
    Swing()
  end
end

function M:Init()
  if not ns.db.modules.swing then return end
  local f = CreateFrame("Frame", "ForeverXIUISwingTimer", UIParent)
  f:SetSize(W, H + 12)
  f.bar = ns.Style.Bar(f, W, H)
  f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 1)
  f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
  f.bar:SetStatusBarColor(0.85, 0.85, 0.85)
  f.bar:SetMinMaxValues(0, 1)
  f.label = ns.Style.Text(f, 9)
  f.label:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", 2, 1)
  f.label:SetText("Swing")
  f.label:SetTextColor(ns.Style.Color("title"))
  f.time = ns.Style.Text(f, 9)
  f.time:SetPoint("BOTTOMRIGHT", f.bar, "TOPRIGHT", -2, 1)

  for _, e in ipairs({ "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "PLAYER_REGEN_ENABLED",
    "UNIT_ATTACK_SPEED", "PLAYER_TARGET_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
  end
  TryCombatLog(f)
  f:SetScript("OnEvent", function(self, event, unit)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      OnLog()
    elseif event == "PLAYER_ENTER_COMBAT" then      -- auto-attack on
      state.attacking = true
      if not state.start then Swing() end
    elseif event == "PLAYER_LEAVE_COMBAT" then      -- auto-attack off
      state.attacking = false
    elseif event == "PLAYER_REGEN_ENABLED" then
      state.attacking = false
      state.start = nil
    elseif event == "UNIT_ATTACK_SPEED" and unit == "player" and state.start then
      -- Haste changed mid-swing: keep how far through the swing we are.
      local new = Speed()
      if new and state.speed then
        local done = (GetTime() - state.start) / state.speed
        state.speed = new
        state.start = GetTime() - done * new
      end
    end
  end)

  local acc = 0
  f:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.03 then return end
    acc = 0
    if self.previewing then return end
    if not state.start or not state.speed then
      self:SetAlpha(ns.db.swing.alwaysShow and 0.4 or 0)
      self.bar:SetValue(0)
      self.time:SetText("")
      return
    end
    local now = GetTime()
    local p = (now - state.start) / state.speed
    if p >= 1 then
      if state.attacking and not (logWorks and state.source == "combat log") then
        -- No combat log: assume the next swing went off on time.
        state.start = state.start + state.speed
        state.speed = Speed() or state.speed
        p = (now - state.start) / state.speed
      elseif not state.attacking then
        state.start = nil
        return
      else
        p = 1
      end
    end
    self:SetAlpha(1)
    self.bar:SetValue(math.min(1, math.max(0, p)))
    self.time:SetFormattedText("%.1f", math.max(0, state.speed * (1 - p)))
  end)

  self.frame = f
  ns.AddRoot(f, "swing")
  ns.Movers.Register("swing", "Swing timer", f, { "BOTTOM", "BOTTOM", 0, 296 })
end

function M.Source()
  if not CombatLogGetCurrentEventInfo then return "estimate (no combat log on this client)" end
  return logWorks and ("combat log (last: " .. state.source .. ")") or "estimate (combat log refused)"
end

function M:Preview(on)
  local f = self.frame
  if not f then return end
  f.previewing = on and true or nil
  if on then
    f:SetAlpha(1)
    f.bar:SetValue(0.6)
    f.time:SetText("1.1")
  end
end
