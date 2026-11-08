-- Buff and debuff icons beside a unit row (party list).
--
-- Forever won't let addons read auras in combat: the reads are refused
-- outright. So ForeverXIUI doesn't read them. Each row gets two of the game's
-- own aura containers (CustomAuraContainerTemplate from Blizzard_AuraContainer).
-- The game fills them itself, in or out of combat; we only say which filter,
-- how big, and where. We supply the parts each icon draws into: the picture,
-- the timer swipe, the stack count and, on debuffs, a border in the dispel
-- colour (magic blue, poison green, curse purple, disease brown).
--
-- Icons made by the game are locked to addons while auras are secret, so
-- building and re-styling happen out of combat. Every icon a row will ever
-- need is made up front.
local _, ns = ...

local Auras = {}
ns.Auras = Auras

local MAX = 8          -- icons per line
local SPACING = 2

Auras.stats = { built = 0, failed = 0, lastError = nil }

local loadTried = false
function Auras.Available()
  if _G.CustomAuraContainerGroupDefaultOptions then return true end
  if not loadTried then
    loadTried = true
    local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
    if load then pcall(load, "Blizzard_AuraContainer") end
  end
  return _G.CustomAuraContainerGroupDefaultOptions ~= nil
end

local function Opts()
  return ns.db.party
end

local function Filter(kind)
  local o = Opts()
  if kind == "buffs" then
    return o.onlyMyBuffs and "HELPFUL|PLAYER" or "HELPFUL"
  end
  return o.onlyDispellable and "HARMFUL|RAID" or "HARMFUL"
end

local function Size()
  return math.max(8, math.min(24, tonumber(Opts().auraSize) or 13))
end

-- Beside the list each icon has its timer under it, so icons sit further
-- apart (room for "32m") and debuffs and buffs share one line per member.
local OUT_GAP = 2          -- extra space between icons beside the list (room for the timer)
local DEBUFF_MAX = 3

local function Outside() return not Opts().auraInside end

local function Layout(size)
  local sx = Outside() and (SPACING + OUT_GAP) or SPACING
  return {
    elementSpacing = sx, lineSpacing = SPACING,
    groupSpacing = sx, groupLineSpacing = SPACING,     -- same gap between debuffs and buffs
    elementWidth = size, elementHeight = size,
  }
end

-- One shared font for the stack counts and countdown numbers.
local countFont, timerFont
local function CountFont()
  if not countFont and CreateFont then
    countFont = CreateFont("ForeverXIUIAuraCountFont")
  end
  if countFont then countFont:SetFont(ns.Style.FONT, math.max(7, Size() - 4), "OUTLINE") end
  return countFont
end

-- The countdown: small, and under the icon when beside the list.
local function TimerFont()
  if not timerFont and CreateFont then
    timerFont = CreateFont("ForeverXIUIAuraTimerFont")
  end
  if timerFont then timerFont:SetFont(ns.Style.FONT, Outside() and 8 or math.max(7, Size() - 4), "OUTLINE") end
  return timerFont
end

-- Dress one icon the game just made. pcall: an icon made while auras are
-- secret may refuse, and that should cost a blank square, not an error.
-- cfg (optional, for other frames than the party list): size, timers,
-- under (timer under the icon). Without it the party settings are used.
local function Dress(owner, button, harmful, cfg)
  pcall(function()
    local size = cfg and cfg.size or Size()
    local timers = (cfg and cfg.timers ~= nil) and cfg.timers or Opts().auraTimers
    local under = (cfg and cfg.under ~= nil) and cfg.under or Outside()
    button:SetSize(size, size)

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1, 1)
    border:SetVertexColor(0, 0, 0, 1)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetIcon(icon)

    local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    if cd.SetReverse then cd:SetReverse(true) end
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not timers) end
    if cd.SetCountdownFont and TimerFont() then pcall(cd.SetCountdownFont, cd, "ForeverXIUIAuraTimerFont") end
    if under and cd.GetCountdownFontString then
      local fs = cd:GetCountdownFontString()
      if fs then
        fs:ClearAllPoints()
        fs:SetPoint("TOP", button, "BOTTOM", 0, -1)
      end
    end
    button:SetDurationCooldown(cd)

    local over = CreateFrame("Frame", nil, button)
    over:SetAllPoints()
    over:SetFrameLevel(cd:GetFrameLevel() + 2)
    local count = over:CreateFontString(nil, "OVERLAY")
    if CountFont() then count:SetFontObject(countFont) else ns.Style.Font(count, 9) end
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    button:SetApplicationCount(count)

    if harmful and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and button.AddDispelTypeTexture then
      button:AddDispelTypeTexture(border, {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWithoutDispelType = true,
      })
    end

    owner.fxiCooldowns = owner.fxiCooldowns or {}
    table.insert(owner.fxiCooldowns, cd)
  end)
end

-- Icons on their own line under the name (inside the row), or beside the window.
function Auras.Inside()
  return Opts().auraInside and true or false
end

-- Extra row height the inside line needs: icon size plus a little air.
function Auras.RowExtra()
  local o = Opts()
  if not (o.auras and o.auraInside and (o.showBuffs or o.showDebuffs)) then return 0 end
  return Size() + 2
end

-- How many icons fit on the inside line: buffs take the left 60%, debuffs the rest.
local function InsideCounts(width)
  local step = Size() + SPACING
  local buffs = math.max(1, math.floor((width - 4) * 0.6 / step))
  local debuffs = math.max(1, math.floor((width - 4) * 0.4 / step))
  return math.min(MAX, buffs), math.min(MAX, debuffs)
end

-- Which side of the row the icons go on: right of the party window by
-- default (pets take the left), left when the sides are flipped.
function Auras.Side()
  return Opts().flip and "RIGHT" or "LEFT"
end

-- Icons per line in the window beside the list.
function Auras.Cols()
  return math.max(2, math.min(MAX, tonumber(Opts().auraCols) or 6))
end

-- Width of that window: the icons plus a little edge.
function Auras.WindowWidth()
  return Auras.Cols() * (Size() + SPACING) - SPACING + 8
end

-- Where the two lines go: buffs on the name line, debuffs on the bar line,
-- both growing outward from `anchor`'s edge, `gap` pixels out.
local function Place(owner)
  local b = owner.fxiAuras
  local anchor, gap = b.anchor, b.gap
  local size = Size()
  local flow = AnchorUtil and AnchorUtil.FlowDirection
  if not b.shared then
    -- Under the name: buffs grow right from the left edge, debuffs grow
    -- left from the right edge, one line, no overlap.
    local nb, nd = InsideCounts(anchor:GetWidth() or 200)
    local y = -15
    for kind, box in pairs(b.boxes) do
      box:ClearAllPoints()
      local n = kind == "buffs" and nb or nd
      box:SetAuraGroupMaxFrameCount(kind, n)
      box:SetFlowLayoutMaximumLineSize(n * (size + SPACING))
      if kind == "buffs" then
        box:SetFlowLayoutAnchorPoint("TOPLEFT")
        if flow then box:SetFlowLayoutGrowthDirection(flow.Right, flow.Down) end
        box:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2, y)
      else
        box:SetFlowLayoutAnchorPoint("TOPRIGHT")
        if flow then box:SetFlowLayoutGrowthDirection(flow.Left, flow.Down) end
        box:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -2, y)
      end
    end
    return
  end
  -- Beside the list: one container, debuffs first (nearest the list), then
  -- buffs, one line level with the name, timers underneath.
  local left = Auras.Side() == "LEFT"
  local near = left and "RIGHT" or "LEFT"      -- the icon edge nearest the row
  local edge = left and "LEFT" or "RIGHT"      -- the row edge they hang off
  local dx = left and -gap or gap
  local box = b.boxes.buffs
  local step = size + SPACING + OUT_GAP
  box:ClearAllPoints()
  box:SetAuraGroupMaxFrameCount("debuffs", DEBUFF_MAX)
  box:SetAuraGroupMaxFrameCount("buffs", Auras.Cols())
  box:SetFlowLayoutMaximumLineSize((Auras.Cols() + DEBUFF_MAX + 1) * step)
  box:SetFlowLayoutAnchorPoint("TOP" .. near)
  if flow then box:SetFlowLayoutGrowthDirection(left and flow.Left or flow.Right, flow.Down) end
  box:SetPoint("TOP" .. near, anchor, "TOP" .. edge, dx, -1)
end

---------------------------------------------------------------------------
-- A plain line of icons for any frame (the target bar): one container per
-- group, each growing right from its own anchor point. groups is a list of
-- { kind, filter, max, point, relPoint, x, y }; cfg is size and timers.
-- Out of combat only. Returns the containers by kind.
---------------------------------------------------------------------------
function Auras.Line(owner, unit, groups, cfg)
  if owner.fxiLine or owner.fxiLineFailed then return owner.fxiLine end
  if InCombatLockdown() or not Auras.Available() then return nil end
  local out = {}
  local ok, err = pcall(function()
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    for _, g in ipairs(groups) do
      local box = CreateFrame("AuraContainer", nil, owner, "CustomAuraContainerTemplate")
      box:SetUnit(unit)
      local harmful = g.filter:find("HARMFUL") ~= nil
      local sx = SPACING + (cfg.under and 6 or 0)
      box:AddAuraGroup(g.kind, g.filter, {
        maxFrameCount = g.max,
        initializeFrame = function(button) Dress(owner, button, harmful, cfg) end,
        layout = { elementSpacing = sx, lineSpacing = SPACING, groupSpacing = sx, groupLineSpacing = SPACING,
          elementWidth = cfg.size, elementHeight = cfg.size },
      })
      box:SetFlowLayoutMaximumLineSize(g.max * (cfg.size + sx))
      box:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
      if flow then box:SetFlowLayoutGrowthDirection(flow.Right, flow.Up) end
      box:SetPoint(g.point, owner, g.relPoint, g.x, g.y)
      out[g.kind] = box
    end
  end)
  if not ok then
    owner.fxiLineFailed = true
    Auras.stats.failed = Auras.stats.failed + 1
    Auras.stats.lastError = tostring(err)
    return nil
  end
  owner.fxiLine = out
  return out
end

-- Show or hide a line's groups and set their filters. Out of combat only.
function Auras.LineApply(owner, wants)
  local line = owner.fxiLine
  if not line then return end
  ns.AfterCombat("line:" .. tostring(owner:GetName() or owner), function()
    for kind, box in pairs(line) do
      local w = wants[kind]
      pcall(function()
        if w and w.filter then box:SetAuraGroupFilterString(kind, w.filter) end
        box:SetEnabled(w and w.on and true or false)
        box:SetShown(w and w.on and true or false)
      end)
    end
  end)
end

function Auras.LineRefresh(owner)
  for _, box in pairs(owner.fxiLine or {}) do
    if box:IsShown() then pcall(box.UpdateAllAuras, box) end
  end
end

-- Give `owner` (a unit row) its two containers. Out of combat only.
function Auras.Attach(owner, unit, anchor, gap)
  if owner.fxiAuras or owner.fxiAurasFailed then return owner.fxiAuras end
  if InCombatLockdown() or not Auras.Available() then return nil end
  local boxes = {}
  local ok, err = pcall(function()
    local size = Size()
    local shared
    if Outside() then
      shared = CreateFrame("AuraContainer", nil, owner, "CustomAuraContainerTemplate")
      shared:SetUnit(unit)
    end
    for _, kind in ipairs({ "debuffs", "buffs" }) do
      local box = shared
      if not box then
        box = CreateFrame("AuraContainer", nil, owner, "CustomAuraContainerTemplate")
        box:SetUnit(unit)
      end
      local harmful = kind == "debuffs"
      box:AddAuraGroup(kind, Filter(kind), {
        maxFrameCount = MAX,
        initializeFrame = function(button) Dress(owner, button, harmful) end,
        layout = Layout(size),
      })
      boxes[kind] = box
    end
  end)
  if not ok then
    owner.fxiAurasFailed = true
    Auras.stats.failed = Auras.stats.failed + 1
    Auras.stats.lastError = tostring(err)
    return nil
  end
  Auras.stats.built = Auras.stats.built + 1
  owner.fxiAuras = { boxes = boxes, unit = unit, anchor = anchor or owner, gap = gap or 4,
    shared = boxes.buffs == boxes.debuffs }
  Auras.Apply(owner)
  return owner.fxiAuras
end

-- Re-read the settings onto a row's containers. Out of combat only.
function Auras.Apply(owner)
  local b = owner.fxiAuras
  if not b then return end
  ns.AfterCombat("auras:" .. tostring(owner:GetName() or owner), function()
    pcall(function()
      local o = Opts()
      local size = Size()
      CountFont()
      TimerFont()
      local wantBox = {}
      for kind, box in pairs(b.boxes) do
        box:SetAuraGroupFilterString(kind, Filter(kind))
        box:SetAuraGroupLayout(kind, Layout(size))
        local want = o.auras and ((kind == "buffs" and o.showBuffs) or (kind == "debuffs" and o.showDebuffs))
        wantBox[box] = wantBox[box] or (want and true or false)
      end
      for box, want in pairs(wantBox) do
        box:SetEnabled(want)
        box:SetShown(want)
      end
      for _, cd in ipairs(owner.fxiCooldowns or {}) do
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not o.auraTimers) end
      end
      Place(owner)
      -- One kind turned off in the shared line: give it no icons.
      if b.shared then
        if not o.showDebuffs then pcall(b.boxes.debuffs.SetAuraGroupMaxFrameCount, b.boxes.debuffs, "debuffs", 0) end
        if not o.showBuffs then pcall(b.boxes.buffs.SetAuraGroupMaxFrameCount, b.boxes.buffs, "buffs", 0) end
      end
    end)
  end)
end

-- The person behind the unit changed (roster shuffle): start over.
function Auras.Refresh(owner)
  local b = owner and owner.fxiAuras
  if not b then return end
  for _, box in pairs(b.boxes) do
    if box:IsShown() then pcall(box.UpdateAllAuras, box) end
  end
end

---------------------------------------------------------------------------
-- Preview icons: plain textures, so /fxiui preview shows where they land.
---------------------------------------------------------------------------
local FAKE_BUFFS = {
  "Interface\\Icons\\Spell_Nature_LightningShield",
  "Interface\\Icons\\Spell_Holy_WordFortitude",
  "Interface\\Icons\\Spell_Nature_Regeneration",
  "Interface\\Icons\\Spell_Holy_MagicalSentry",
  "Interface\\Icons\\Spell_Nature_Rejuvenation",
}
local FAKE_DEBUFFS = {
  { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", { 0.2, 0.6, 1 } },     -- magic
  { "Interface\\Icons\\Ability_Creature_Poison_02", { 0, 0.6, 0 } },        -- poison
  { "Interface\\Icons\\Spell_Shadow_CurseOfTounges", { 0.6, 0, 1 } },       -- curse
  { "Interface\\Icons\\Ability_Creature_Disease_02", { 0.6, 0.4, 0 } },     -- disease
}

local function FakeIcon(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.border = f:CreateTexture(nil, "BACKGROUND")
  f.border:SetAllPoints()
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetPoint("TOPLEFT", 1, -1)
  f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.timer = f:CreateFontString(nil, "OVERLAY")
  ns.Style.Font(f.timer, 8)
  return f
end

local FAKE_TIMES = { "32m", "9m", "45s", "2m", "12m", "1h" }

-- seed picks how many of each, so the preview rows don't all match.
function Auras.Preview(owner, on, anchor, gap, seed)
  owner.fxiFake = owner.fxiFake or { buffs = {}, debuffs = {} }
  local fake = owner.fxiFake
  local o = Opts()
  local size = Size()
  seed = seed or 1
  local nb = on and o.auras and o.showBuffs and (1 + seed % #FAKE_BUFFS) or 0
  local nd = on and o.auras and o.showDebuffs and (seed % 3) or 0
  nb, nd = math.min(nb, Auras.Cols()), math.min(nd, Auras.Cols())
  local left = Auras.Side() == "LEFT"
  local near, edge = left and "RIGHT" or "LEFT", left and "LEFT" or "RIGHT"
  local stepOut = size + SPACING + OUT_GAP
  local function X(i) local x = gap + (i - 1) * stepOut return left and -x or x end
  local ndShown = math.min(nd, DEBUFF_MAX)
  local inside = Auras.Inside()
  if inside then
    local mb, md = InsideCounts(anchor:GetWidth() or 200)
    nb, nd = math.min(nb, mb), math.min(nd, md)
  end
  local function Spot(t, kind, i)
    t:ClearAllPoints()
    local step = (i - 1) * (size + SPACING)
    if inside and kind == "buffs" then
      t:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2 + step, -15)
    elseif inside then
      t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -2 - step, -15)
    else
      -- One line beside the list: debuffs nearest, then buffs.
      local slot = kind == "buffs" and (ndShown + i) or i
      local extra = 0
      t:SetPoint("TOP" .. near, anchor, "TOP" .. edge, X(slot) + extra, -1)
    end
    t.timer:ClearAllPoints()
    if inside then
      t.timer:SetPoint("CENTER", t, "CENTER", 0, 0)
    else
      t.timer:SetPoint("TOP", t, "BOTTOM", 0, -1)
    end
    t.timer:SetText(o.auraTimers and FAKE_TIMES[((seed + i) % #FAKE_TIMES) + 1] or "")
  end
  if not inside then nd = ndShown end
  for i = 1, math.max(nb, #fake.buffs) do
    local t = fake.buffs[i]
    if i <= nb then
      if not t then t = FakeIcon(owner); fake.buffs[i] = t end
      t:SetSize(size, size)
      Spot(t, "buffs", i)
      t.border:SetColorTexture(0, 0, 0, 1)
      t.icon:SetTexture(FAKE_BUFFS[i])
      t:Show()
    elseif t then
      t:Hide()
    end
  end
  for i = 1, math.max(nd, #fake.debuffs) do
    local t = fake.debuffs[i]
    if i <= nd then
      if not t then t = FakeIcon(owner); fake.debuffs[i] = t end
      local d = FAKE_DEBUFFS[((seed + i) % #FAKE_DEBUFFS) + 1]
      t:SetSize(size, size)
      Spot(t, "debuffs", i)
      t.border:SetColorTexture(d[2][1], d[2][2], d[2][3], 1)
      t.icon:SetTexture(d[1])
      t:Show()
    elseif t then
      t:Hide()
    end
  end
end
