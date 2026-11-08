-- XIUI cast bar: amber gradient fill, spell name left, time right.
--
-- Another unit's cast is secret on Forever (name, icon, start and end), so
-- the bar is built from setters only: its range is the raw start and end in
-- milliseconds and its value is our own clock. The time label needs a sum,
-- so it is tried once per cast and left blank if refused. Nothing read from
-- a cast is ever tested with `if`.
local _, ns = ...

local Cast = {}
ns.CastBar = Cast

local UPDATE_EVERY = 0.02 -- seconds; OnUpdate is throttled by elapsed time

local function NowMs() return GetTime() * 1000 end

local function Label(info, now)
  local left = (info.endMs - now) / 1000
  if left < 0 then left = 0 end
  return ("%.1f"):format(left)
end

local function Finished(info, now)
  return now >= info.endMs
end

local function Stop(bar)
  bar.info = nil
  bar:Hide()
end

local function OnUpdate(bar, elapsed)
  bar.acc = (bar.acc or 0) + elapsed
  if bar.acc < UPDATE_EVERY then return end
  bar.acc = 0
  local info = bar.info
  if not info then bar:Hide() return end
  local now = NowMs()
  bar.status:SetValue(now)
  if not info.secretTime then
    local ok, text = pcall(Label, info, now)
    if ok then
      bar.time:SetText(text)
    else
      info.secretTime = true
      bar.time:SetText("")
    end
  end
  local ok, done = pcall(Finished, info, now)
  if ok and done then Stop(bar) end
  -- Not ok: the end time is secret. The STOP event ends it instead, and a
  -- safety timeout covers a lost event.
  if not ok and GetTime() - info.began > 30 then Stop(bar) end
end

local function Read(unit, channel)
  local r
  if channel then
    r = { UnitChannelInfo(unit) }
  else
    r = { UnitCastingInfo(unit) }
  end
  if type(r[1]) == "nil" then return nil end
  local info = { name = r[1], icon = r[3], startMs = r[4], endMs = r[5], channel = channel, began = GetTime() }
  if channel then info.locked = r[7] else info.locked = r[8] end
  return info
end

local function Begin(bar, channel)
  local info = Read(bar.unit, channel)
  if not info then Stop(bar) return end
  bar.info = info
  pcall(bar.text.SetText, bar.text, info.name)
  if bar.icon then
    if type(info.icon) ~= "nil" then
      pcall(bar.icon.SetTexture, bar.icon, info.icon)
      bar.icon:Show()
    else
      bar.icon:Hide()
    end
  end
  bar.time:SetText("")
  local okRange = pcall(bar.status.SetMinMaxValues, bar.status, info.startMs, info.endMs)
  if not okRange then Stop(bar) return end
  if bar.status.SetReverseFill then bar.status:SetReverseFill(channel and true or false) end
  -- Uninterruptible is a secret boolean on other units: ask inside pcall.
  local ok, locked = pcall(function() return info.locked and true or false end)
  if ok and locked then
    bar.status:SetStatusBarColor(ns.Style.Color("castLocked"))
  else
    bar.status:SetStatusBarColor(ns.Style.Color("cast"))
  end
  bar.status:SetValue(NowMs())
  bar.acc = UPDATE_EVERY
  bar:Show()
end

local START = {
  UNIT_SPELLCAST_START = false, UNIT_SPELLCAST_DELAYED = false,
  UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true,
}
local STOP = {
  UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
  UNIT_SPELLCAST_CHANNEL_STOP = true,
}

local function OnEvent(bar, event, unit)
  if bar.previewing then return end
  if event == "PLAYER_TARGET_CHANGED" then
    Cast.Refresh(bar)
    return
  end
  if START[event] ~= nil then
    Begin(bar, START[event])
  elseif STOP[event] then
    local info = bar.info
    if not info or bar.previewing then return end
    if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      if info.channel then Stop(bar) end
    elseif not info.channel and type((UnitCastingInfo(bar.unit))) == "nil" then
      -- Only when nothing is casting any more: a quick recast's START can
      -- arrive before the old cast's STOP.
      Stop(bar)
    end
  end
end

function Cast.Refresh(bar)
  if type((UnitCastingInfo(bar.unit))) ~= "nil" then
    Begin(bar, false)
  elseif type((UnitChannelInfo(bar.unit))) ~= "nil" then
    Begin(bar, true)
  else
    Stop(bar)
  end
end

-- unit: "player" or "target". Returns the root frame (non-secure).
function Cast.Create(name, unit, width, height, withIcon)
  local bar = CreateFrame("Frame", name, UIParent)
  bar:SetSize(width, height)
  bar.unit = unit

  local status = ns.Style.Bar(bar, width, height, "cast")
  status:SetAllPoints()
  bar.status = status

  bar.text = ns.Style.BarText(status, height >= 14 and 11 or 10, "LEFT")
  bar.time = ns.Style.BarText(status, height >= 14 and 11 or 10, "RIGHT")
  bar.text:SetPoint("RIGHT", bar.time, "LEFT", -4, 0)
  bar.text:SetWordWrap(false)

  if withIcon then
    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(height + 2, height + 2)
    icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.icon = icon
  end

  for e in pairs(START) do bar:RegisterUnitEvent(e, unit) end
  for e in pairs(STOP) do bar:RegisterUnitEvent(e, unit) end
  if unit == "target" then bar:RegisterEvent("PLAYER_TARGET_CHANGED") end
  bar:SetScript("OnEvent", OnEvent)
  bar:SetScript("OnUpdate", OnUpdate)
  bar:Hide()
  return bar
end

-- Point a bar at another unit (nameplate bars are reused as plates come
-- and go). nil parks it.
function Cast.SetUnit(bar, unit)
  bar:UnregisterAllEvents()
  bar.unit = unit
  bar.info = nil
  if not unit then bar:Hide() return end
  for e in pairs(START) do pcall(bar.RegisterUnitEvent, bar, e, unit) end
  for e in pairs(STOP) do pcall(bar.RegisterUnitEvent, bar, e, unit) end
  local ok = pcall(Cast.Refresh, bar)
  if not ok then Stop(bar) end
end

-- A pretend cast for lining things up with /fxiui move.
function Cast.Preview(bar, on)
  bar.previewing = on and true or nil
  if on then
    bar.info = { name = "Preview", startMs = NowMs(), endMs = NowMs() + 1e9, began = GetTime() }
    bar.text:SetText(bar.unit == "player" and "Healing Wave" or "Target cast")
    bar.time:SetText("1.5")
    bar.status:SetMinMaxValues(0, 1)
    bar.status:SetValue(0.6)
    bar:SetScript("OnUpdate", nil)
    bar:Show()
  else
    bar:SetScript("OnUpdate", OnUpdate)
    Cast.Refresh(bar)
  end
end
