-- XI-style action bars: an XI navy window behind each Blizzard action bar
-- (bars 1-8, the pet bar and the stance bar), sized to the buttons that are
-- actually showing, and Blizzard's own bar art (end caps, border) faded.
-- Optional: hold Shift and bar 2 lights up while bar 1 dims (off by default).
--
-- Why fit to the buttons: a Blizzard bar frame is often bigger than its
-- buttons (spare rows, padding, hidden empty slots), which is what made the
-- 0.3 window run on behind the next bar.
--
-- The bars themselves are Blizzard's and are never moved, re-parented or
-- clicked for (that taints Edit Mode on Forever). We only draw plain frames
-- behind them and change alpha. Place and size the bars in Edit Mode.
local _, ns = ...

local M = ns.AddModule("ActionBars")

-- key, bar frame names (first that exists), button name pattern, count.
local BARS = {
  { key = "base",  names = { "MainActionBar", "MainMenuBar" }, button = "ActionButton%d", n = 12 },
  { key = "shift", names = { "MultiBarBottomLeft" }, button = "MultiBarBottomLeftButton%d", n = 12 },
  { key = "bar3",  names = { "MultiBarBottomRight" }, button = "MultiBarBottomRightButton%d", n = 12 },
  { key = "bar4",  names = { "MultiBarRight" }, button = "MultiBarRightButton%d", n = 12 },
  { key = "bar5",  names = { "MultiBarLeft" }, button = "MultiBarLeftButton%d", n = 12 },
  { key = "bar6",  names = { "MultiBar5" }, button = "MultiBar5Button%d", n = 12 },
  { key = "bar7",  names = { "MultiBar6" }, button = "MultiBar6Button%d", n = 12 },
  { key = "bar8",  names = { "MultiBar7" }, button = "MultiBar7Button%d", n = 12 },
  { key = "pet",   names = { "PetActionBar", "PetActionBarFrame" }, button = "PetActionButton%d", n = 10 },
  { key = "stance", names = { "StanceBar", "StanceBarFrame" }, button = "StanceButton%d", n = 10 },
}

-- Blizzard decoration on the bars, faded (never hidden).
local ART = { "BorderArt", "EndCaps", "Background", "ArtFrame", "ActionBarPageNumber" }

local PAD = 4

local function Find(names)
  for _, n in ipairs(names) do
    local f = _G[n]
    if type(f) == "table" and f.GetCenter then return f, n end
  end
end

local slots = {}

-- The box around every button of this bar that is showing, in UIParent
-- units, or nil when none is.
local function ButtonBox(s)
  local l, r, t, b
  local ui = UIParent:GetEffectiveScale()
  for i = 1, s.spec.n do
    local btn = _G[s.spec.button:format(i)]
    if btn and btn.IsVisible and btn:IsVisible() and btn:GetAlpha() > 0.05 then
      local bl, bb, bw, bh = btn:GetRect()
      if bl then
        local k = btn:GetEffectiveScale() / ui
        bl, bb, bw, bh = bl * k, bb * k, bw * k, bh * k
        l = l and math.min(l, bl) or bl
        b = b and math.min(b, bb) or bb
        r = r and math.max(r, bl + bw) or bl + bw
        t = t and math.max(t, bb + bh) or bb + bh
      end
    end
  end
  if not l then return nil end
  return l, r, t, b
end

local function Fit(s)
  local l, r, t, b = ButtonBox(s)
  local back = s.back
  if not l then
    back:Hide()
    s.glow:Hide()
    return
  end
  back:ClearAllPoints()
  back:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - PAD, b - PAD)
  back:SetSize(r - l + PAD * 2, t - b + PAD * 2)
  back:SetAlpha(ns.db.bars.window == false and 0 or 1)
  back:Show()
end

local pending = false
local function FitAll()
  if pending then return end
  pending = true
  C_Timer.After(0.1, function()
    pending = false
    for _, s in pairs(slots) do Fit(s) end
  end)
end
M.FitAll = FitAll

local fadedArt = {}
local function KeepFaded(region)
  if fadedArt[region] and region:GetAlpha() > 0 then region:SetAlpha(0) end
end

local function FadeArt(bar)
  for _, key in ipairs(ART) do
    local region = bar[key]
    if type(region) == "table" and region.SetAlpha then
      region:SetAlpha(0)
      if not fadedArt[region] then
        fadedArt[region] = true
        hooksecurefunc(region, "SetAlpha", KeepFaded)
      end
    end
  end
end

local function Build(spec, bar)
  local back = CreateFrame("Frame", nil, UIParent)
  back:SetFrameStrata("BACKGROUND")
  ns.Style.Panel(back, 0.85)

  -- The live-bar glow (Shift highlight, off by default).
  local glow = CreateFrame("Frame", nil, UIParent)
  glow:SetFrameStrata("BACKGROUND")
  glow:SetPoint("TOPLEFT", back, "TOPLEFT", -2, 2)
  glow:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", 2, -2)
  local lr, lg, lb = ns.Style.Color("edgeLight")
  for _, e in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
    { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
  }) do
    local t = glow:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(lr, lg, lb, 0.9)
    t:SetPoint(e[1])
    t:SetPoint(e[2])
    if e[3] then t:SetWidth(e[3]) end
    if e[4] then t:SetHeight(e[4]) end
  end
  glow:Hide()

  local s = { spec = spec, bar = bar, back = back, glow = glow }
  slots[spec.key] = s
  if ns.db.bars.hideArt then FadeArt(bar) end

  -- Re-fit when the bar or its buttons change (Edit Mode, vehicles, empty
  -- slots showing while you drag a spell).
  bar:HookScript("OnShow", FitAll)
  bar:HookScript("OnHide", FitAll)
  bar:HookScript("OnSizeChanged", FitAll)
  for i = 1, spec.n do
    local btn = _G[spec.button:format(i)]
    if btn and btn.HookScript then
      btn:HookScript("OnShow", FitAll)
      btn:HookScript("OnHide", FitAll)
    end
  end
end

local current
local function Highlight()
  local live = IsShiftKeyDown() and "shift" or "base"
  if live == current then return end
  current = live
  local dim = tonumber(ns.db.bars.dimAlpha) or 0.55
  local any = live ~= "base"
  for _, key in ipairs({ "base", "shift" }) do
    local s = slots[key]
    if s then
      local on = key == live
      s.glow:SetShown(s.back:IsShown() and on and (any or ns.db.bars.glowBase))
      if ns.db.bars.dim then s.bar:SetAlpha((on or not any) and 1 or dim) end
    end
  end
end

function M:Init()
  if not ns.db.bars.enabled then return end
  for _, spec in ipairs(BARS) do
    local bar = Find(spec.names)
    if bar then Build(spec, bar) end
  end
  if not next(slots) then
    ns.Print("couldn't find Blizzard's action bars on this client; the bar skin is off.")
    return
  end
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID",
    "ACTIONBAR_SLOT_CHANGED", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_BONUS_ACTIONBAR",
    "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    pcall(ns.On, e, FitAll)
  end
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", FitAll, M)
  end
  FitAll()

  if not ns.db.bars.highlight then return end
  ns.On("MODIFIER_STATE_CHANGED", Highlight)
  ns.On("PLAYER_REGEN_ENABLED", Highlight)
  current = nil
  Highlight()
end

function M:Relayout()
  if next(slots) then FitAll() end
  current = nil
  if next(slots) and ns.db.bars.highlight then Highlight() end
end

-- For /fxiui check.
function M:Names()
  local out = {}
  for _, spec in ipairs(BARS) do
    local _, n = Find(spec.names)
    if n then table.insert(out, n) end
  end
  return table.concat(out, " ")
end
