-- The minimap in the XI look: a square map in a navy window with a steel
-- edge, Blizzard's round border art faded, an XI strip under the map with
-- the zone, your coordinates and the clock, and every button that sat
-- around the map (Blizzard's and the addons' LibDBIcon ones) lined up
-- along the map's left edge, squared off and all one size.
--
-- Only looks: the map's mask texture and the alpha of Blizzard's art. The
-- minimap cluster is an Edit Mode frame and is never moved or re-parented;
-- place it in Edit Mode and the window follows. A /reload is needed to go
-- back to the round map.
local _, ns = ...

local M = ns.AddModule("MapSkin")

-- Round decoration on the minimap, by name or by key on the cluster/map.
local ART_NAMES = { "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture", "MinimapBackdrop",
  "MinimapNorthTag" }
local ART_KEYS = { "BorderTop", "Border", "Background" }

local faded = {}
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

-- Addons that put buttons around the map (LibDBIcon) ask this to know where
-- the edge is.
local function SquareShape() return "SQUARE" end

---------------------------------------------------------------------------
-- The buttons along the map's edge. Buttons are only re-anchored and
-- scaled (never re-parented), and dragging them is turned off so they stay
-- in line. When an addon puts its button back (LibDBIcon does on every
-- update), the edge takes it again. They run down the map's left edge (the
-- right edge if the map is against the left of the screen); any that don't
-- fit carry on in a row under the zone strip.
---------------------------------------------------------------------------
local GAP = 2
local function Slot() return math.floor(tonumber(ns.db.map.buttonSize) or 22) end
local edge, strip, buttons, placing = nil, nil, {}, false

-- Blizzard's round ring and dark circle behind minimap buttons.
local ROUND_FILES = { [136430] = true, [136467] = true, [136477] = true }
local function IsRoundArt(tex)
  local ok, file = pcall(tex.GetTexture, tex)
  if not ok or file == nil then return false end
  if type(file) == "number" then return ROUND_FILES[file] or false end
  file = tostring(file):lower()
  return file:find("trackingborder") or file:find("minimap%-background") or file:find("ui%-minimap%-background")
end

local function Square(b)
  for _, key in ipairs({ "border", "Border", "background", "Background" }) do
    local r = rawget(b, key)
    if type(r) == "table" and r.SetAlpha then Fade(r) end
  end
  for _, r in ipairs({ b:GetRegions() }) do
    local ok, k = pcall(r.GetObjectType, r)
    if ok and k == "Texture" and IsRoundArt(r) then Fade(r) end
  end
  -- A small square XI tile behind the icon.
  if not b.fxiTile then
    local t = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ns.Style.Fill(t, "mapBack", 0.9)
    t:SetPoint("CENTER")
    local size = math.min(b:GetWidth() or 31, b:GetHeight() or 31) * 0.72
    t:SetSize(size, size)
    local e = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    e:SetColorTexture(ns.Style.Color("edge"))
    e:SetPoint("TOPLEFT", t, "TOPLEFT", -1, 1)
    e:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, -1)
    e:SetDrawLayer("BACKGROUND", -8)
    t:SetDrawLayer("BACKGROUND", -7)
    b.fxiTile = t
  end
end

local function IsButton(f)
  local ok, kind = pcall(f.GetObjectType, f)
  return ok and (kind == "Button" or kind == "CheckButton")
end

local function Skip(b)
  local cluster = MinimapCluster
  if b.fxiOurs then return true end
  if cluster and (b == rawget(cluster, "ZoneTextButton")) then return true end
  if b == _G.MinimapZoneTextButton or b == _G.TimeManagerClockButton then return true end
  if b == rawget(Minimap, "ZoomIn") or b == rawget(Minimap, "ZoomOut") then return true end
  for _, junk in ipairs({ "ExpansionLandingPageMinimapButton", "GarrisonLandingPageMinimapButton" }) do
    if b == _G[junk] then return true end
  end
  -- Map pins (GatherLite's 12px node markers and the like) are not buttons.
  local name = b:GetName() or ""
  if name:find("^GatherLite%d") then return true end
  if name:find("^TomTom") then return true end
  -- Waypoint and node pins placed through HereBeDragons (TomTom, Questie,
  -- gathering addons): they belong on the map, not in the button column.
  local hbd = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
  if hbd and type(hbd.minimapPins) == "table" and hbd.minimapPins[b] then return true end
  if rawget(b, "point") ~= nil and (rawget(b, "arrow") ~= nil or rawget(b, "icon") ~= nil) then return true end   -- TomTom
  local w = b:GetWidth() or 0
  return w < 20 or w > 48
end

local Layout

local function Take(b, anyKind)
  if type(b) ~= "table" or buttons[b] or not b.GetObjectType then return end
  if not anyKind and (not IsButton(b) or Skip(b)) then return end
  buttons[b] = true
  if b.RegisterForDrag then pcall(b.RegisterForDrag, b) end   -- no drag
  pcall(Square, b)
  hooksecurefunc(b, "SetPoint", function() if not placing then Layout() end end)
  b:HookScript("OnShow", function() Layout() end)
  b:HookScript("OnHide", function() Layout() end)
end

-- The tracking magnifier sits inside the map's top-right corner, button
-- size, instead of in the column.
local tucking = false
local function PutTracking()
  local t = M.tracking
  if not t or tucking or not Minimap then return end
  tucking = true
  pcall(function()
    -- On the map itself, so it draws over the map, not under it.
    if t:GetParent() ~= Minimap then t:SetParent(Minimap) end
    local w = math.max(t:GetWidth() or 0, t:GetHeight() or 0, 1)
    local parent = t:GetParent() or UIParent
    local mapEff, parentEff = Minimap:GetEffectiveScale(), parent:GetEffectiveScale()
    local scale = Slot() * mapEff / (w * parentEff)
    t:SetScale(scale)
    local pad = 3 * mapEff / (parentEff * scale)
    t:ClearAllPoints()
    t:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -pad, -pad)
    local strata, level = Minimap:GetFrameStrata(), Minimap:GetFrameLevel() + 10
    t:SetFrameStrata(strata)
    t:SetFrameLevel(level)
    for _, child in ipairs({ t:GetChildren() }) do
      pcall(child.SetFrameStrata, child, strata)
      pcall(child.SetFrameLevel, child, level + 1)
    end
  end)
  tucking = false
end

function M.TuckTracking(t)
  if M.tracking == t then return end
  M.tracking = t
  buttons[t] = nil
  pcall(Square, t)
  hooksecurefunc(t, "SetPoint", function() if not tucking then PutTracking() end end)
  PutTracking()
end

-- The mail (and crafting order) icons: Blizzard keeps them in
-- MinimapCluster.IndicatorFrame, which stays where the old cluster was
-- (top middle of the screen) once the map moves. They go just left of the
-- gold strip on top of the map (or the map's top-left corner without it).
-- Small icons left in the map's holder frame (the day/night icon on
-- Forever) go just right of the strip, or are hidden ("Hide the day/night
-- icon").
local putting = false
local extras = {}

local function GoldStrip()
  local g = _G.ForeverXIUIGold
  if type(g) == "table" and g:IsShown() then return g end
end

local function OverMap(f)
  local strata, level = Minimap:GetFrameStrata(), Minimap:GetFrameLevel() + 10
  f:SetFrameStrata(strata)
  f:SetFrameLevel(level)
  for _, child in ipairs({ f:GetChildren() }) do
    pcall(child.SetFrameStrata, child, strata)
    pcall(child.SetFrameLevel, child, level + 1)
  end
end

local function PutIndicator()
  if putting or not Minimap then return end
  putting = true
  local g = GoldStrip()
  local f = M.indicator
  if f then
    pcall(function()
      if f:GetParent() ~= Minimap then f:SetParent(Minimap) end
      f:ClearAllPoints()
      if g then
        f:SetPoint("RIGHT", g, "LEFT", -3, 0)
      else
        f:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 3, -3)
      end
      OverMap(f)
    end)
  end
  local prev = g
  for _, e in ipairs(extras) do
    pcall(function()
      if ns.db.map.hideDayNight then
        e:SetAlpha(0)
        if e.EnableMouse then e:EnableMouse(false) end
        return
      end
      e:SetAlpha(1)
      if e:GetParent() ~= Minimap then e:SetParent(Minimap) end
      local h = math.max(e:GetHeight() or 0, 1)
      e:SetScale(math.min(1, 20 / h))
      e:ClearAllPoints()
      if prev then
        e:SetPoint("LEFT", prev, "RIGHT", 3, 0)
      else
        e:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -3, -(Slot() + 6))
      end
      OverMap(e)
      prev = e
    end)
  end
  putting = false
end
M.PutIndicator = PutIndicator

function M.TuckIndicator(f)
  if M.indicator == f then return end
  M.indicator = f
  buttons[f] = nil
  hooksecurefunc(f, "SetPoint", function() if not putting then PutIndicator() end end)
  PutIndicator()
end

-- Small leftovers in the map's holder frame (not the map, not our frames,
-- not Forever's coordinates or the lined-up buttons).
local function TuckExtras()
  local holder = Minimap.GetParent and Minimap:GetParent()
  if type(holder) ~= "table" or holder == UIParent or holder == MinimapCluster or not holder.GetChildren then return end
  local coords = rawget(holder, "PlayerCoords")
  for _, c in ipairs({ holder:GetChildren() }) do
    if c ~= Minimap and c ~= coords and not c.fxiOurs and not buttons[c] and c ~= M.tracking
      and c ~= M.indicator and not c.fxiExtra then
      local w, h = c:GetWidth() or 0, c:GetHeight() or 0
      if w >= 10 and w <= 48 and h >= 10 and h <= 48 then
        c.fxiExtra = true
        extras[#extras + 1] = c
        hooksecurefunc(c, "SetPoint", function() if not putting then PutIndicator() end end)
      end
    end
  end
  PutIndicator()
end
M.TuckExtras = TuckExtras

local function Collect()
  for _, root in ipairs({ Minimap, MinimapCluster, _G.MinimapBackdrop }) do
    if type(root) == "table" and root.GetChildren then
      for _, child in ipairs({ root:GetChildren() }) do Take(child) end
    end
  end
  -- The calendar (day/night) button: bigger than other buttons on some
  -- clients, so it's taken by name rather than by size. Or put away.
  local cal = _G.GameTimeFrame
  if type(cal) == "table" and cal.Hide then
    if ns.db.map.hideCalendar then
      if not M.calHidden then
        M.calHidden = true
        cal:Hide()
        hooksecurefunc(cal, "Show", function(f) if ns.db.map.hideCalendar then f:Hide() end end)
      end
    else
      Take(cal, true)
    end
  end
  -- The looking-for-group eye: it lives on Blizzard's micro menu, which the
  -- XI menu fades out, so it's moved onto the map and joins the column.
  -- The game still shows it only while you're queued.
  for _, name in ipairs({ "QueueStatusButton", "MiniMapLFGFrame", "LFGMinimapFrame" }) do
    local q = _G[name]
    if type(q) == "table" and q.SetParent and not buttons[q] then
      if q:GetParent() ~= Minimap then pcall(q.SetParent, q, Minimap) end
      if q.EnableMouse then pcall(q.EnableMouse, q, true) end
      if q.SetAlpha then pcall(q.SetAlpha, q, 1) end
      Take(q, true)
    end
  end
  -- Blizzard's tracking (magnifier) and mail icons sit in small holder frames.
  local cluster = MinimapCluster
  if cluster then
    local tracking = rawget(cluster, "Tracking") or _G.MiniMapTracking
    if type(tracking) == "table" and (tracking.GetWidth and (tracking:GetWidth() or 0) >= 10) then M.TuckTracking(tracking) end
  end
  pcall(TuckExtras)
  local indicator = cluster and rawget(cluster, "IndicatorFrame")
  if type(indicator) == "table" and indicator.SetPoint then
    M.TuckIndicator(indicator)
  elseif type(_G.MiniMapMailFrame) == "table" then
    Take(_G.MiniMapMailFrame, true)
  end
  -- LibDBIcon keeps its buttons in a list; some addons parent them elsewhere.
  local lib = LibStub and LibStub("LibDBIcon-1.0", true)
  if lib and type(lib.objects) == "table" then
    for _, b in pairs(lib.objects) do if type(b) == "table" then Take(b) end end
  end
end

Layout = function()
  if not edge or placing then return end
  placing = true
  local ok, err = pcall(function()
    local SLOT = Slot()
    local list = {}
    for b in pairs(buttons) do
      if b:IsShown() then list[#list + 1] = b end
    end
    table.sort(list, function(a, b) return (a:GetName() or "~") < (b:GetName() or "~") end)
    -- Everything is measured in the map window's own units, so the column
    -- is part of the map: it grows and shrinks with it (the map size
    -- slider and Edit Mode's size alike).
    local edgeEff = edge:GetEffectiveScale()
    local function Rel(f) return ((f and f.GetEffectiveScale) and f:GetEffectiveScale() or edgeEff) / edgeEff end
    -- Down the left edge first, then the right edge, then a second column
    -- further out on each side. Only the right side if the map is against
    -- the left of the screen.
    local left = edge:GetLeft()
    local rightOnly = left ~= nil and left < SLOT + GAP * 2
    local sides = rightOnly and { "RIGHT" } or { "LEFT", "RIGHT" }
    local room = math.max(1, math.floor(((edge:GetHeight() or 150) + GAP) / (SLOT + GAP)))
    for i, b in ipairs(list) do
      local w = math.max(b:GetWidth() or SLOT, b:GetHeight() or SLOT, 1)
      local scale = SLOT / w / Rel(b:GetParent())
      pcall(b.SetScale, b, scale)
      local unit = SLOT / w                     -- one button unit, in map units
      pcall(b.ClearAllPoints, b)
      local n = i - 1
      local row = n % room
      local col = math.floor(n / room)          -- 0 left, 1 right, 2 left again, ...
      local side = sides[(col % #sides) + 1]
      local out = math.floor(col / #sides)      -- how far out from the map
      local x = (GAP + out * (SLOT + GAP)) / unit
      local y = -(row * (SLOT + GAP)) / unit
      if side == "RIGHT" then
        pcall(b.SetPoint, b, "TOPLEFT", edge, "TOPRIGHT", x, y)
      else
        pcall(b.SetPoint, b, "TOPRIGHT", edge, "TOPLEFT", -x, y)
      end
    end
  end)
  placing = false
  PutTracking()
  PutIndicator()
  if not ok then
    M.errors = M.errors or {}
    M.errors.layout = tostring(err)
    ns.Print("minimap buttons: %s", tostring(err))
  end
end

-- Map size slider: scales the map itself (our window, strip and gold strip
-- are on it, so they follow). The map's place stays Edit Mode's.
local function ApplyMapScale()
  if not Minimap then return end
  ns.AfterCombat("mapscale", function()
    local s = tonumber(ns.db.map.scale) or 1
    s = math.max(0.5, math.min(2, s))
    -- Leave the map's own scale alone until the slider is moved off 1.
    if not M.baseScale then
      if math.abs(s - 1) < 0.001 then return end
      M.baseScale = Minimap:GetScale() or 1
    end
    pcall(Minimap.SetScale, Minimap, M.baseScale * s)
    M.mapScaled = s
  end)
end
M.ApplyMapScale = ApplyMapScale

function M:Relayout()
  if not ns.db.map.skin then return end
  ApplyMapScale()
  if Layout then Layout() end
end

function M.CollectButtons()
  if not edge then return end
  Collect()
  Layout()
end

-- For /fxiui check and /fxiui map.
function M.ButtonCount()
  if not edge then return "off" end
  local n, shown = 0, 0
  for b in pairs(buttons) do
    n = n + 1
    if b:IsShown() then shown = shown + 1 end
  end
  return ("%d on the map edge (%d shown)"):format(n, shown)
end

---------------------------------------------------------------------------
-- The strip under the map: zone (coloured like the game's PvP colours),
-- your coordinates, and the clock. Click the zone for the world map and the
-- clock for Blizzard's clock options; both hand the click to Blizzard's own
-- (now invisible) buttons, so nothing taints.
---------------------------------------------------------------------------
local PVP = {
  sanctuary = { 0.41, 0.8, 0.94 }, friendly = { 0.1, 1, 0.1 }, hostile = { 1, 0.1, 0.1 },
  contested = { 1, 0.7, 0 }, arena = { 1, 0.1, 0.1 }, combat = { 1, 0.1, 0.1 },
}

local function ZoneColor()
  local fn = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
  local ok, kind = pcall(fn or function() end)
  local c = ok and type(kind) == "string" and PVP[kind]
  if c then return c[1], c[2], c[3] end
  return ns.Style.Color("title")
end

local function Coords()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or not ns.Readable(id) or not id then return nil end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, id, "player")
  if not ok2 or not pos or not pos.GetXY then return nil end
  local x, y = pos:GetXY()
  if not ns.Readable(x) or not x or (x == 0 and y == 0) then return nil end
  return ("%.1f, %.1f"):format(x * 100, y * 100)
end

local function Clock()
  if GameTime_GetTime then
    local ok, t = pcall(GameTime_GetTime, false)
    if ok and type(t) == "string" then return t end
  end
  return date("%H:%M")
end

local function ClickZone(parent, target)
  local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
  b.fxiOurs = true
  b:RegisterForClicks("AnyUp", "AnyDown")
  if type(target) == "table" and target.Click then
    b:SetAttribute("type", "click")
    b:SetAttribute("clickbutton", target)
    b:SetAttribute("useOnKeyDown", false)
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  ns.Style.Fill(hl, "accent", 0.15)
  return b
end

local function BuildStrip(back)
  local cluster = MinimapCluster
  local zoneBtn = cluster and (rawget(cluster, "ZoneTextButton") or _G.MinimapZoneTextButton)
  local clockBtn = _G.TimeManagerClockButton

  local s = CreateFrame("Frame", "ForeverXIUIMapStrip", back)
  s.fxiOurs = true
  s:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -2)
  s:SetPoint("TOPRIGHT", back, "BOTTOMRIGHT", 0, -2)
  s:SetHeight(18)
  ns.Style.Panel(s, 0.92)

  s.clock = ns.Style.Text(s, 11)
  s.clock:SetPoint("RIGHT", s, "RIGHT", -6, 0)
  s.coords = ns.Style.Text(s, 10)
  s.coords:SetTextColor(0.8, 0.84, 0.92)
  s.coords:SetPoint("RIGHT", s.clock, "LEFT", -8, 0)
  s.zone = ns.Style.Text(s, 11)
  s.zone:SetPoint("LEFT", s, "LEFT", 6, 0)
  s.zone:SetPoint("RIGHT", s.coords, "LEFT", -6, 0)
  s.zone:SetJustifyH("LEFT")
  if s.zone.SetWordWrap then s.zone:SetWordWrap(false) end

  -- Click areas over the zone and the clock.
  local z = ClickZone(s, zoneBtn)
  -- (Secure buttons can only be anchored to frames, not to text.)
  z:SetPoint("TOPLEFT", s, "TOPLEFT")
  z:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -46, 0)
  z:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(GetZoneText and GetZoneText() or "", ZoneColor())
    local sub = GetSubZoneText and GetSubZoneText()
    if sub and sub ~= "" then GameTooltip:AddLine(sub, 1, 1, 1) end
    GameTooltip:AddLine("Click for the world map.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  z:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local c = ClickZone(s, clockBtn)
  c:SetPoint("TOPRIGHT", s, "TOPRIGHT")
  c:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", -46, 0)
  c:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Clock", ns.Style.Color("title"))
    GameTooltip:AddDoubleLine("Local time", date("%H:%M"), 1, 1, 1, 1, 1, 1)
    if GetGameTime then
      local h, m = GetGameTime()
      GameTooltip:AddDoubleLine("Realm time", ("%02d:%02d"):format(h, m), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine("Click for clock options.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  c:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Blizzard's zone text and clock: faded and off the mouse (ours take the clicks).
  for _, f in ipairs({ zoneBtn, clockBtn }) do
    if type(f) == "table" then
      Fade(f)
      if f.EnableMouse then pcall(f.EnableMouse, f, false) end
    end
  end

  local function Update()
    s.zone:SetText(GetMinimapZoneText and GetMinimapZoneText() or "")
    s.zone:SetTextColor(ZoneColor())
    s.coords:SetText(ns.db.map.coords and Coords() or "")
    s.clock:SetText(Clock())
  end
  s:RegisterEvent("ZONE_CHANGED")
  s:RegisterEvent("ZONE_CHANGED_INDOORS")
  s:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  s:RegisterEvent("PLAYER_ENTERING_WORLD")
  s:SetScript("OnEvent", Update)
  local acc = 0
  s:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    Update()
  end)
  Update()
  return s
end

-- Blizzard's own zone box, clock box and any coordinates frame in the
-- minimap cluster: faded and off the mouse, so only our strip shows. The map
-- itself, the mail/crafting indicators, the dungeon difficulty flag and the
-- buttons we line up are left alone.
local KEEP_KEYS = { "Minimap", "IndicatorFrame", "InstanceDifficulty", "MailFrame", "Selection" }
local function FadeClusterExtras()
  local cluster = MinimapCluster
  if type(cluster) ~= "table" then return end
  local keep = { [Minimap] = true }
  -- The map can sit inside a holder frame (MinimapContainer); keep every
  -- frame between the cluster and the map.
  local p = Minimap.GetParent and Minimap:GetParent()
  while type(p) == "table" and p ~= cluster and p ~= UIParent do
    keep[p] = true
    p = p.GetParent and p:GetParent()
  end
  for _, k in ipairs(KEEP_KEYS) do
    local f = rawget(cluster, k)
    if type(f) == "table" then keep[f] = true end
  end
  for _, n in ipairs({ "MiniMapMailFrame", "MiniMapInstanceDifficulty", "GuildInstanceDifficulty" }) do
    if type(_G[n]) == "table" then keep[_G[n]] = true end
  end
  for _, r in ipairs({ cluster:GetRegions() }) do Fade(r) end
  for _, child in ipairs({ cluster:GetChildren() }) do
    -- Never a frame that holds the map, one of our frames or a lined-up button.
    local holds = false
    if child.GetChildren then
      for _, c in ipairs({ child:GetChildren() }) do
        if c == Minimap or buttons[c] or c.fxiOurs then holds = true break end
      end
    end
    if not keep[child] and not holds and not buttons[child] and not child.fxiOurs then
      Fade(child)
      if child.EnableMouse then pcall(child.EnableMouse, child, false) end
    end
  end
  -- Forever's own coordinates under the map (MinimapContainer.PlayerCoords):
  -- our strip shows them, so theirs is faded while ours are on.
  local holder = Minimap.GetParent and Minimap:GetParent()
  local coords = type(holder) == "table" and rawget(holder, "PlayerCoords")
  if type(coords) == "table" and ns.db.map.coords then Fade(coords) end
  for _, n in ipairs({ "MinimapZoneTextButton", "TimeManagerClockButton", "MinimapToggleButton" }) do
    local f = _G[n]
    if type(f) == "table" and not buttons[f] then
      Fade(f)
      if f.EnableMouse then pcall(f.EnableMouse, f, false) end
    end
  end
end
M.FadeClusterExtras = FadeClusterExtras

function M:Init()
  if not ns.db.map.skin or type(Minimap) ~= "table" then return end
  local map = Minimap

  if ns.db.map.square and map.SetMaskTexture then
    pcall(map.SetMaskTexture, map, "Interface\\Buttons\\WHITE8X8")
    GetMinimapShape = SquareShape
  end
  for _, name in ipairs(ART_NAMES) do Fade(_G[name]) end
  local cluster = MinimapCluster
  for _, key in ipairs(ART_KEYS) do
    if cluster then Fade(cluster[key]) end
    if key ~= "Background" then Fade(map[key]) end
  end

  ApplyMapScale()

  -- The window: a plain frame behind the map.
  local back = CreateFrame("Frame", nil, map)
  back:SetFrameLevel(math.max(0, map:GetFrameLevel() - 1))
  back:SetPoint("TOPLEFT", map, "TOPLEFT", -4, 4)
  back:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 4, -4)
  ns.Style.Panel(back, 0.95)
  self.back = back

  -- Drag the map with /fxiui move (the window, strip, gold and buttons all
  -- hang off it). Until it's dragged once, it stays where Edit Mode puts it.
  -- Blizzard re-anchors the map when its layout updates, so a dragged map
  -- is put back each time.
  M.Step("mover", function()
    local mover = ns.Movers.Register("map", "Minimap", map, nil)
    hooksecurefunc(map, "SetPoint", function()
      if not mover.applying and ns.Movers.Saved("map") then ns.Movers.Apply(mover) end
    end)
  end)

  -- Each step on its own, so one that Forever doesn't like can't stop the rest.
  if ns.db.map.buttonColumn then edge = back end
  M.Step("zone strip", function()
    strip = BuildStrip(back)
    self.strip = strip
  end)
  -- Blizzard's clock loads on demand; fade it once it exists.
  ns.On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_TimeManager" and _G.TimeManagerClockButton then
      Fade(_G.TimeManagerClockButton)
      pcall(_G.TimeManagerClockButton.EnableMouse, _G.TimeManagerClockButton, false)
    end
  end)

  -- Buttons first, then Blizzard's boxes (so a button is never faded with
  -- them). Again over the first seconds, as addons make their buttons late.
  local function Pass()
    if ns.db.map.buttonColumn then M.Step("buttons", M.CollectButtons) end
    M.Step("blizzard boxes", FadeClusterExtras)
  end
  Pass()
  for _, t in ipairs({ 1, 3, 8, 15 }) do C_Timer.After(t, Pass) end
end

-- What went wrong, if anything (shown in /fxiui map and printed once).
M.errors = {}
function M.Step(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    M.errors[#M.errors + 1] = name .. ": " .. tostring(err)
    ns.Print("map skin: the %s step failed (%s). /fxiui map shows details.", name, tostring(err))
  end
  return ok
end

-- /fxiui map: gather the buttons again and show what the minimap is made of.
function M.Dump()
  M.Step("buttons", M.CollectButtons)
  local out = { "ForeverXIUI " .. ns.version .. " minimap", "buttons: " .. M.ButtonCount(),
    "strip: " .. (strip and ((strip:IsShown() and "shown " or "hidden ") .. tostring((strip.zone:GetText()))) or "not built"),
    "GetMinimapShape: " .. tostring((GetMinimapShape and GetMinimapShape())) }
  for _, e in ipairs(M.errors) do out[#out + 1] = "ERROR " .. e end
  local lib = LibStub and LibStub("LibDBIcon-1.0", true)
  if lib and lib.objects then
    local names = {}
    for n in pairs(lib.objects) do names[#names + 1] = n end
    out[#out + 1] = "LibDBIcon: " .. table.concat(names, ", ")
  end
  out[#out + 1] = ""
  ns.DumpFrame(MinimapCluster, out, 0, 2, "MinimapCluster")
  ns.DumpFrame(Minimap, out, 0, 1, "Minimap")
  ns.ShowCopy("Minimap layout", out)
end

-- For /fxiui check: is the built-in damage meter here (MeterSkin skins it).
function M.DamageMeterNames()
  local m = ns.modules.MeterSkin
  return m and m.Describe and m.Describe() or "none found"
end
