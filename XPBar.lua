-- EXP bar (XIUI style): one slim navy bar with your experience, the rested
-- bonus as a lighter stretch past it, and the XP from quests that are ready
-- to hand in as a gold stretch. Text above: level and XP on the left,
-- rested, quest XP, XP per hour and time to level on the right. Hover for
-- kills to level and the session totals.
--
-- Your own XP is not secret, so this reads it directly. XP per hour runs on
-- an "active" clock that stops after 3 minutes without XP, combat or
-- movement, so a long break in town doesn't drag the rate down.
local _, ns = ...

local M = ns.AddModule("XPBar")

local W, H = 480, 7
local IDLE_AFTER = 180
local KILL_SAMPLES = 10

local state = { xp = 0, max = 1, level = 1, rested = 0, questXP = 0, quests = 0 }
local session = { gained = 0, active = 0, kills = {} }
local lastActivity, lastTick = 0, 0
local pendingQuestXP = 0

local function Now() return GetTime() end

local function Num(v)
  v = math.floor((tonumber(v) or 0) + 0.5)
  if BreakUpLargeNumbers then return BreakUpLargeNumbers(v) end
  return tostring(v)
end

local function Duration(sec)
  local m = math.max(1, math.floor(sec / 60 + 0.5))
  if m >= 60 then return ("%dh %02dm"):format(math.floor(m / 60), m % 60) end
  return ("%dm"):format(m)
end

local function MaxLevel()
  local ok, v = pcall(GetMaxPlayerLevel)
  if ok and type(v) == "number" and v > 0 then return v end
  return 60
end

local function AtMax()
  return state.level >= MaxLevel() or (IsXPUserDisabled and IsXPUserDisabled())
end

-- The active clock: counts while you're doing something.
local function Tick()
  local now = Now()
  if UnitAffectingCombat("player") or (IsPlayerMoving and IsPlayerMoving()) then lastActivity = now end
  local idleFrom = lastActivity + IDLE_AFTER
  if lastTick < idleFrom then
    session.active = session.active + math.max(0, math.min(now, idleFrom) - lastTick)
  end
  lastTick = now
end

local function Rate()
  if session.active < 60 or session.gained <= 0 then return nil end
  return session.gained / session.active * 3600
end

local function KillsToLevel()
  local n, sum = #session.kills, 0
  if n == 0 then return nil end
  for _, v in ipairs(session.kills) do sum = sum + v end
  local avg = sum / n
  if avg <= 0 then return nil end
  return math.ceil((state.max - state.xp) / avg)
end

-- XP from quests in your log that are complete and waiting to be handed in.
local function QuestXP()
  local total, count = 0, 0
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and GetQuestLogRewardXP) then return 0, 0 end
  local okN, n = pcall(C_QuestLog.GetNumQuestLogEntries)
  if not okN or type(n) ~= "number" then return 0, 0 end
  for i = 1, n do
    local ok, info = pcall(C_QuestLog.GetInfo, i)
    if ok and info and not info.isHeader and info.questID then
      local okC, done = pcall(C_QuestLog.IsComplete, info.questID)
      if okC and done then
        local okX, xp = pcall(GetQuestLogRewardXP, info.questID)
        if okX and type(xp) == "number" then
          total = total + xp
          count = count + 1
        end
      end
    end
  end
  return total, count
end

-- Kill XP is stored without the rested bonus (rested doubles a kill, paid
-- from the pool), and big one-off gains like discoveries are left out.
local function Classify(amount, restedBefore)
  C_Timer.After(0.5, function()
    local quest = math.min(amount, pendingQuestXP)
    pendingQuestXP = pendingQuestXP - quest
    local rest = amount - quest
    local base = math.max(rest / 2, rest - restedBefore)
    if base > 0 and base < state.max * 0.25 then
      table.insert(session.kills, base)
      while #session.kills > KILL_SAMPLES do table.remove(session.kills, 1) end
    end
  end)
end

local function ReadXP(first)
  local xp, max, level = UnitXP("player") or 0, UnitXPMax("player") or 1, UnitLevel("player") or 1
  local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
  if not first then
    local gained = level > state.level and (state.max - state.xp) + xp or xp - state.xp
    if gained > 0 then
      session.gained = session.gained + gained
      lastActivity = Now()
      Tick()
      Classify(gained, state.rested)
    end
  end
  state.xp, state.max, state.level, state.rested = xp, math.max(1, max), level, rested
end

-- Gold under the EXP bar only when asked for (it normally sits on top of the map).
local function Gold() local g = ns.modules.Gold return g and g.Enabled() and ns.db.goldTracker.onXP and g or nil end

local function Draw(f)
  if f.previewing then return end
  local gold = Gold()
  f.gold:SetText(gold and gold.Line() or "")
  local hideXP = ns.db.xp.hideAtMax and AtMax()
  -- At max level the gold line stays (on its own) if it's on.
  f:SetShown(ns.db.modules.xp and (not hideXP or gold) and true or false)
  f.bar:SetShown(not hideXP)
  if hideXP then
    f.left:SetText("")
    f.right:SetText("")
    return
  end

  local max = state.max
  f.bar:SetMinMaxValues(0, max)
  f.bar:SetValue(state.xp)
  -- Rested and quest stretches start where your XP ends.
  local w = f.bar:GetWidth()
  local x = w * math.min(1, state.xp / max)
  local restW = w * math.min(1, (state.xp + state.rested) / max) - x
  f.rest:ClearAllPoints()
  f.rest:SetPoint("TOPLEFT", f.bar, "TOPLEFT", x, 0)
  f.rest:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT", x, 0)
  f.rest:SetWidth(math.max(0.01, restW))
  f.rest:SetShown(restW > 0.5)
  local questW = w * math.min(1, (state.xp + state.questXP) / max) - x
  f.quest:ClearAllPoints()
  f.quest:SetPoint("TOPLEFT", f.bar, "TOPLEFT", x, 0)
  f.quest:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT", x, 0)
  f.quest:SetWidth(math.max(0.01, questW))
  f.quest:SetShown(ns.db.xp.showQuest and questW > 0.5)

  f.left:SetFormattedText("Lv %d  EXP %s / %s (%.1f%%)", state.level, Num(state.xp), Num(max), state.xp / max * 100)
  local bits = {}
  if state.rested > 0 then
    local pct = math.floor(state.rested / max * 100 + 0.5)
    bits[#bits + 1] = pct >= 1 and ("|cff8fb8ffRested %d%%|r"):format(pct) or ("|cff8fb8ffRested %s|r"):format(Num(state.rested))
  end
  if ns.db.xp.showQuest and state.questXP > 0 then bits[#bits + 1] = ("|cffe8c80cQuests +%s|r"):format(Num(state.questXP)) end
  local rate = Rate()
  if ns.db.xp.showRate and rate then
    bits[#bits + 1] = ("%s/h"):format(Num(rate))
    bits[#bits + 1] = ("TNL %s"):format(Duration((max - state.xp) / rate * 3600))
  else
    bits[#bits + 1] = ("TNL %s"):format(Num(max - state.xp))
  end
  f.right:SetText(table.concat(bits, "  |cff576c92·|r  "))
end

local function Tooltip(f)
  GameTooltip:SetOwner(f, "ANCHOR_TOP")
  GameTooltip:AddLine(("Level %d experience"):format(state.level), 0.72, 0.79, 1)
  GameTooltip:AddDoubleLine("Current", ("%s / %s"):format(Num(state.xp), Num(state.max)), 1, 1, 1, 1, 1, 1)
  GameTooltip:AddDoubleLine("To level", Num(state.max - state.xp), 1, 1, 1, 1, 1, 1)
  if state.rested > 0 then GameTooltip:AddDoubleLine("Rested", Num(state.rested), 1, 1, 1, 0.56, 0.72, 1) end
  if state.questXP > 0 then
    GameTooltip:AddDoubleLine(("Ready quests (%d)"):format(state.quests), Num(state.questXP), 1, 1, 1, 0.91, 0.78, 0.05)
  end
  local kills = KillsToLevel()
  if kills then GameTooltip:AddDoubleLine("Kills to level", ("about %d"):format(kills), 1, 1, 1, 1, 1, 1) end
  local rate = Rate()
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("This session", Num(session.gained), 0.7, 0.7, 0.7, 1, 1, 1)
  if rate then
    GameTooltip:AddDoubleLine("XP per hour", Num(rate), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Time to level", Duration((state.max - state.xp) / rate * 3600), 0.7, 0.7, 0.7, 1, 1, 1)
  end
  local gold = Gold()
  if gold then gold.AddTooltip() end
  GameTooltip:AddLine("Shift-click: post your XP to chat. Ctrl-click: reset the session.", 0.55, 0.55, 0.55, true)
  GameTooltip:Show()
end

function M:Init()
  if not ns.db.modules.xp then return end
  local f = CreateFrame("Frame", "ForeverXIUIXPBar", UIParent)
  -- Text row above the bar; the gold line (if on) in a row under it.
  local under = (ns.db.modules.gold and ns.db.goldTracker.onXP) and 14 or 0
  f:SetSize(W, H + 16 + under)
  f.bar = ns.Style.Bar(f, W, H)
  f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 2 + under)
  f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 2 + under)
  f.bar:SetStatusBarColor(0.58, 0.32, 0.86)
  -- Stretches drawn over the trough, under the text.
  f.quest = f.bar:CreateTexture(nil, "ARTWORK", nil, -1)
  f.quest:SetColorTexture(0.91, 0.78, 0.05, 0.45)
  f.rest = f.bar:CreateTexture(nil, "ARTWORK", nil, -2)
  f.rest:SetColorTexture(0.25, 0.55, 1, 0.45)
  f.left = ns.Style.Text(f, 11)
  f.left:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", 3, 2)
  f.right = ns.Style.Text(f, 10)
  f.right:SetPoint("BOTTOMRIGHT", f.bar, "TOPRIGHT", -3, 2)
  f.right:SetJustifyH("RIGHT")
  f.gold = ns.Style.Text(f, 10)
  f.gold:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", -3, -3)
  f.gold:SetJustifyH("RIGHT")

  f:EnableMouse(true)
  f:SetScript("OnEnter", Tooltip)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:SetScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then return end
    if IsControlKeyDown() then
      session.gained, session.active, session.kills = 0, 0, {}
      if Gold() then Gold().Reset() end
      ns.Print("EXP and gold session reset.")
      Draw(f)
    elseif IsShiftKeyDown() and ChatEdit_InsertLink then
      ChatEdit_InsertLink(("Level %d: %s / %s XP (%.1f%%), %s to go"):format(state.level, Num(state.xp),
        Num(state.max), state.xp / state.max * 100, Num(state.max - state.xp)))
    end
  end)

  ReadXP(true)
  state.questXP, state.quests = QuestXP()
  lastActivity, lastTick = Now(), Now()

  for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD",
    "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN", "PLAYER_STARTED_MOVING", "PLAYER_MONEY" }) do
    pcall(f.RegisterEvent, f, e)
  end
  f:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_TURNED_IN" then
      local _, xp = ...
      if type(xp) == "number" then
        pendingQuestXP = pendingQuestXP + xp
        C_Timer.After(2, function() pendingQuestXP = math.max(0, pendingQuestXP - xp) end)
      end
    elseif event == "PLAYER_STARTED_MOVING" then
      lastActivity = Now()
      return
    elseif event == "PLAYER_MONEY" then
      -- just redraw (the gold line)
    elseif event == "QUEST_LOG_UPDATE" then
      state.questXP, state.quests = QuestXP()
    else
      ReadXP(false)
    end
    Draw(self)
  end)
  -- The clock and the rate text: once every 5 seconds is plenty.
  local acc = 0
  f:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 5 then return end
    acc = 0
    Tick()
    if ns.db.xp.showRate or Gold() then Draw(self) end
  end)
  Draw(f)

  self.frame = f
  ns.AddRoot(f, "xp")
  ns.Movers.Register("xp", "EXP bar", f, { "BOTTOM", "BOTTOM", 0, 92 })
end

function M:Relayout()
  if self.frame then Draw(self.frame) end
end

function M:Preview(on)
  local f = self.frame
  if not f then return end
  f.previewing = on and true or nil
  if on then
    f:Show()
    f.bar:Show()
    f.gold:SetText(Gold() and Gold().PreviewLine() or "")
    f.bar:SetMinMaxValues(0, 100)
    f.bar:SetValue(43)
    local w = f.bar:GetWidth()
    f.rest:ClearAllPoints()
    f.rest:SetPoint("TOPLEFT", f.bar, "TOPLEFT", w * 0.43, 0)
    f.rest:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT", w * 0.43, 0)
    f.rest:SetWidth(w * 0.2)
    f.rest:Show()
    f.quest:ClearAllPoints()
    f.quest:SetPoint("TOPLEFT", f.bar, "TOPLEFT", w * 0.43, 0)
    f.quest:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT", w * 0.43, 0)
    f.quest:SetWidth(w * 0.12)
    f.quest:Show()
    f.left:SetText("Lv 18  EXP 4,214 / 9,800 (43.0%)")
    f.right:SetText("|cff8fb8ffRested 20%|r  |cff576c92·|r  |cffe8c80cQuests +1,180|r  |cff576c92·|r  5,400/h  |cff576c92·|r  TNL 1h 02m")
  else
    Draw(f)
  end
end
