-- The XIUI look: dark navy panels with a thin steel-blue edge, gradient bar
-- fills, small outlined numbers. Colours are XIUI's defaults.
local _, ns = ...

local Style = {}
ns.Style = Style

local WHITE = "Interface\\Buttons\\WHITE8X8"
Style.FONT = "Fonts\\ARIALN.TTF"

local function Hex(h)
  h = h:gsub("#", "")
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end
Style.Hex = Hex

Style.colors = {
  panelTop    = { Hex("#061c39") },
  panelBottom = { Hex("#01122b") },
  edge        = { Hex("#576c92") },
  edgeLight   = { Hex("#b7c9ff") },
  barBack     = { 0.02, 0.06, 0.13 },
  title       = { Hex("#b7c9ff") },

  -- Health bands (XIUI player bar): 0-25 low, 25-50, 50-75, 75-100 high.
  hpLow     = { Hex("#ec3232") },
  hpMedLow  = { Hex("#ee9c06") },
  hpMedHigh = { Hex("#e8e00c") },
  hpHigh    = { Hex("#e26c6c") },
  hpTarget  = { Hex("#e16c6c") },
  hpClassic = { 0.80, 0.08, 0.08 },

  -- Threat on the target bar.
  threatGood = { Hex("#5aab5a") },
  threatWarn = { Hex("#e8c80c") },
  threatBad  = { Hex("#ec3232") },

  mana   = { Hex("#9abb5a") },
  rage   = { Hex("#d14b4b") },
  energy = { Hex("#e0c040") },
  focus  = { Hex("#e08a3a") },
  tp     = { Hex("#3898ce") },
  cast   = { Hex("#ffaa00") },
  castLocked = { Hex("#9a9a9a") },

  hpText   = { Hex("#ffa7a7") },
  manaText = { Hex("#d4ff97") },
  tpText   = { Hex("#8dc7ff") },
  name     = { 1, 1, 1 },

  -- Highlights and backs used across the frames (themed below).
  accent    = { 0.47, 0.77, 0.93 },   -- hover highlights
  accentSel = { 0.22, 0.60, 0.81 },   -- selected rows, mover boxes
  slotBack  = { 0.06, 0.08, 0.16 },   -- bag slot backs
  mapBack   = { 0.02, 0.07, 0.16 },   -- square backs behind minimap buttons
}

-- Window colour themes. "xi" is XIUI's navy and steel blue; "wow" keeps
-- every layout and shape but in the game's own charcoal and gold; "dark"
-- is neutral near-black and grey. Bars, health and power colours are not
-- part of the theme. Picked once at load (look.theme), so changing it
-- needs a /reload.
Style.THEMES = {
  wow = {
    panelTop    = { 0.13, 0.11, 0.09 },
    panelBottom = { 0.04, 0.035, 0.03 },
    edge        = { 0.55, 0.43, 0.20 },
    edgeLight   = { 1.00, 0.82, 0.35 },
    barBack     = { 0.06, 0.05, 0.04 },
    title       = { 1.00, 0.82, 0.00 },
    accent      = { 1.00, 0.82, 0.20 },
    accentSel   = { 0.75, 0.55, 0.10 },
    slotBack    = { 0.08, 0.07, 0.06 },
    mapBack     = { 0.05, 0.045, 0.04 },
  },
  dark = {
    panelTop    = { 0.10, 0.10, 0.11 },
    panelBottom = { 0.04, 0.04, 0.045 },
    edge        = { 0.27, 0.27, 0.29 },
    edgeLight   = { 0.59, 0.59, 0.61 },
    barBack     = { 0.03, 0.03, 0.035 },
    title       = { 0.90, 0.90, 0.92 },
    accent      = { 0.67, 0.67, 0.71 },
    accentSel   = { 0.40, 0.40, 0.44 },
    slotBack    = { 0.06, 0.06, 0.065 },
    mapBack     = { 0.04, 0.04, 0.045 },
  },
}

-- "custom": the player's own five colours (look.custom, set with the colour
-- picker); the rest are worked out from them.
local function Mix(c, k, to)
  to = to or 0
  return { c[1] + (to - c[1]) * k, c[2] + (to - c[2]) * k, c[3] + (to - c[3]) * k }
end

local function CustomTheme(c)
  local function C(key, def)
    local v = type(c) == "table" and c[key]
    if type(v) == "table" and v.r then return { v.r, v.g, v.b } end
    return def
  end
  local top    = C("panelTop", Style.colors.panelTop)
  local bottom = C("panelBottom", Style.colors.panelBottom)
  local edge   = C("edge", Style.colors.edge)
  local title  = C("title", Style.colors.title)
  local accent = C("accent", Style.colors.accent)
  return {
    panelTop = top, panelBottom = bottom, edge = edge, title = title, accent = accent,
    edgeLight = Mix(edge, 0.55, 1),
    accentSel = Mix(accent, 0.35, 0),
    barBack   = Mix(bottom, 0.4, 0),
    slotBack  = Mix(top, 0.1, 0),
    mapBack   = Mix(bottom, 0.2, 0),
  }
end

function Style.ApplyTheme(name, custom)
  local t = Style.THEMES[name]
  if name == "custom" then t = CustomTheme(custom) end
  if not t then return end
  for k, v in pairs(t) do Style.colors[k] = { v[1], v[2], v[3] } end
end

-- tex:SetColorTexture in a theme colour, with alpha.
function Style.Fill(tex, key, alpha)
  local r, g, b = Style.Color(key)
  tex:SetColorTexture(r, g, b, alpha or 1)
end

function Style.Color(key)
  local c = Style.colors[key] or Style.colors.name
  return c[1], c[2], c[3]
end

function Style.Font(fs, size, flags)
  fs:SetFont(Style.FONT, size or 11, flags or "OUTLINE")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.8)
  return fs
end

function Style.Text(parent, size, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  Style.Font(fs, size)
  fs:SetTextColor(1, 1, 1)
  return fs
end

-- Vertical gradient, works on any client that has CreateColor.
local function Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
  if tex.SetGradient and CreateColor then
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
  else
    tex:SetColorTexture(r1, g1, b1, a1)
  end
end
Style.Gradient = Gradient

-- An XIUI "Window1"-style panel behind `frame`: navy gradient, 1px steel
-- edge, a lighter top edge, and softly rounded corners. The corners come
-- from two small textures in media\ (a rounded fill and a rounded ring)
-- drawn nine-sliced, so they stay the same size on any window. Clients
-- without nine-slicing get the old square panel.
local MEDIA = "Interface\\AddOns\\ForeverXIUI\\media\\"
local SLICE = 6
local function CanSlice(tex) return tex.SetTextureSliceMargins ~= nil end

local function SquarePanel(frame, alpha, inset)
  local p = {}
  local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
  bg:SetPoint("TOPLEFT", -inset, inset)
  bg:SetPoint("BOTTOMRIGHT", inset, -inset)
  local t, b = Style.colors.panelTop, Style.colors.panelBottom
  Gradient(bg, "VERTICAL", b[1], b[2], b[3], alpha, t[1], t[2], t[3], alpha)
  p.bg = bg

  local er, eg, eb = Style.Color("edge")
  local function Edge(p1, p2, w, h)
    local e = frame:CreateTexture(nil, "BORDER")
    e:SetColorTexture(er, eg, eb, 0.95)
    e:SetPoint(p1, bg, p1)
    e:SetPoint(p2, bg, p2)
    if w then e:SetWidth(w) end
    if h then e:SetHeight(h) end
    return e
  end
  p.top    = Edge("TOPLEFT", "TOPRIGHT", nil, 1)
  p.bottom = Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
  p.left   = Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
  p.right  = Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
  local lr, lg, lb = Style.Color("edgeLight")
  p.top:SetColorTexture(lr, lg, lb, 0.55)
  return p
end

local function Sliced(frame, layer, sub, file, inset)
  local t = frame:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(MEDIA .. file)
  t:SetTextureSliceMargins(SLICE, SLICE, SLICE, SLICE)
  if t.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
    t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
  end
  t:SetPoint("TOPLEFT", -inset, inset)
  t:SetPoint("BOTTOMRIGHT", inset, -inset)
  return t
end

local function RoundPanel(frame, alpha, inset)
  local p = {}
  local t, b = Style.colors.panelTop, Style.colors.panelBottom
  p.bg = Sliced(frame, "BACKGROUND", -7, "panel", inset)
  p.bg:SetGradient("VERTICAL", CreateColor(b[1], b[2], b[3], alpha), CreateColor(t[1], t[2], t[3], alpha))
  -- The edge: steel, fading up to the light XI top edge.
  local er, eg, eb = Style.Color("edge")
  local lr, lg, lb = Style.Color("edgeLight")
  p.edge = Sliced(frame, "BORDER", 0, "edge", inset)
  p.edge:SetGradient("VERTICAL", CreateColor(er, eg, eb, 0.95),
    CreateColor(er + (lr - er) * 0.45, eg + (lg - eg) * 0.45, eb + (lb - eb) * 0.45, 0.95))
  return p
end

function Style.Panel(frame, alpha, inset)
  alpha = alpha or 0.92
  inset = inset or 0
  local p
  local probe = frame:CreateTexture()
  local round = ns.db == nil or ns.db.look == nil or ns.db.look.rounded ~= false
  if round and CanSlice(probe) and CreateColor then
    local ok, res = pcall(RoundPanel, frame, alpha, inset)
    if ok then p = res end
  end
  probe:Hide()
  p = p or SquarePanel(frame, alpha, inset)
  frame.panel = p
  return p
end

function Style.ShowPanel(frame, shown)
  local p = frame.panel
  if not p then return end
  for _, t in pairs(p) do t:SetShown(shown) end
end

-- A status bar the XIUI way: dark trough, solid fill, and a white sheen
-- over the fill that brightens toward the right end. The sheen gives the
-- two-colour gradient look while the fill colour itself can still come
-- from the game (a secret-safe colour curve).
function Style.Bar(parent, width, height, colorKey)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(width, height)
  bar:SetStatusBarTexture(WHITE)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)

  local back = bar:CreateTexture(nil, "BACKGROUND")
  back:SetPoint("TOPLEFT", -1, 1)
  back:SetPoint("BOTTOMRIGHT", 1, -1)
  local t, b = Style.colors.panelTop, Style.colors.panelBottom
  Gradient(back, "VERTICAL", b[1], b[2], b[3], 1, t[1], t[2], t[3], 1)
  bar.back = back

  local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
  edge:SetPoint("TOPLEFT", -2, 2)
  edge:SetPoint("BOTTOMRIGHT", 2, -2)
  edge:SetColorTexture(0, 0, 0, 0.85)
  bar.edge = edge

  -- Overall alpha caps the sheen, so it stays subtle even on a client
  -- where the gradient's own alpha is ignored (0.1.0 washed out to white).
  local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
  sheen:SetAllPoints(bar:GetStatusBarTexture())
  Gradient(sheen, "HORIZONTAL", 1, 1, 1, 0, 1, 1, 1, 1)
  sheen:SetBlendMode("BLEND")
  sheen:SetAlpha(0.22)
  bar.sheen = sheen
  local shine = ns.db and ns.db.look and ns.db.look.shine
  sheen:SetShown(shine and true or false)

  -- A soft top highlight so thin bars read as rounded.
  local gloss = bar:CreateTexture(nil, "ARTWORK", nil, 3)
  gloss:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPLEFT")
  gloss:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT")
  gloss:SetHeight(math.max(1, math.floor(height / 2)))
  Gradient(gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 1)
  gloss:SetAlpha(0.10)
  bar.gloss = gloss
  gloss:SetShown(shine and true or false)

  if colorKey then bar:SetStatusBarColor(Style.Color(Style.HealthKey(colorKey))) end
  return bar
end

function Style.BarText(bar, size, justify)
  local fs = Style.Text(bar, size or 11)
  if justify == "LEFT" then
    fs:SetPoint("LEFT", bar, "LEFT", 3, 0)
  elseif justify == "CENTER" then
    fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
  else
    fs:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
  end
  fs:SetJustifyH(justify or "RIGHT")
  return fs
end

-- Health colour key after the look settings: WoW red unless XIUI colours.
function Style.HealthKey(key)
  local look = ns.db and ns.db.look
  if look and look.classicColors and (key == "hpHigh" or key == "hpTarget") then
    return "hpClassic"
  end
  return key
end

-- Bar colour for a power token: Blizzard's own power colours, or XIUI's.
function Style.PowerRGB(token)
  local look = ns.db and ns.db.look
  if look and look.classicColors and PowerBarColor and type(token) == "string" then
    local c = PowerBarColor[token]
    if c and c.r then
      -- Blizzard's pure mana blue is very dark behind white text; lift it a touch.
      if token == "MANA" then return 0.0, 0.35, 0.95 end
      return c.r, c.g, c.b
    end
  end
  return Style.Color(Style.PowerColorKey(token))
end

-- Colour for a power type token ("MANA", "RAGE", ...).
function Style.PowerColorKey(token)
  if token == "RAGE" then return "rage" end
  if token == "ENERGY" then return "energy" end
  if token == "FOCUS" then return "focus" end
  return "mana"
end

-- Class icon on a texture. Atlas first, the old sheet second.
function Style.ClassIcon(tex, classToken)
  if type(classToken) ~= "string" or not ns.Readable(classToken) then
    tex:Hide()
    return
  end
  local atlas = "classicon-" .. classToken:lower()
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
    tex:SetAtlas(atlas)
    tex:Show()
    return
  end
  local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
  if coords then
    tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    tex:Show()
  else
    tex:Hide()
  end
end

---------------------------------------------------------------------------
-- XI headers on Blizzard frames (damage meter, chat tabs; later the
-- character, spellbook and talent windows). Blizzard's own art on the
-- header frame is faded and held at 0 (never hidden or moved, so nothing
-- taints), an XI strip goes behind it, and its text gets our font in the
-- title colour. Buttons on the header (their own child frames) are left as
-- they are.
---------------------------------------------------------------------------
local heldArt = {}
local function KeepArtFaded(region)
  if heldArt[region] and region:GetAlpha() > 0 then region:SetAlpha(0) end
end

function Style.FadeArt(region)
  if type(region) ~= "table" or not region.SetAlpha or region.fxiOurs then return end
  region:SetAlpha(0)
  if not heldArt[region] then
    heldArt[region] = true
    hooksecurefunc(region, "SetAlpha", KeepArtFaded)
  end
end

local function Kind(r)
  local ok, k = pcall(r.GetObjectType, r)
  return ok and k or nil
end

-- opts: alpha (strip opacity), size (text size), inset (strip inset), keep
-- (a set of regions not to fade, e.g. an icon), titleColor (false: leave
-- the text colour alone, for tabs that colour themselves).
function Style.Header(header, opts)
  if type(header) ~= "table" or not header.GetRegions or header.fxiHeader then return end
  opts = opts or {}
  local keep = opts.keep or {}
  for _, r in ipairs({ header:GetRegions() }) do
    local k = Kind(r)
    if k == "Texture" and not keep[r] then
      Style.FadeArt(r)
    elseif k == "FontString" then
      local _, size = r:GetFont()
      Style.Font(r, opts.size or math.max(10, math.min(14, math.floor((size or 12) + 0.5))))
      if opts.titleColor ~= false then
        r:SetTextColor(Style.Color("title"))
        local tr, tg, tb = Style.Color("title")
        hooksecurefunc(r, "SetTextColor", function(self, red)
          if red ~= tr and not self.fxiColoring then
            self.fxiColoring = true
            self:SetTextColor(tr, tg, tb)
            self.fxiColoring = nil
          end
        end)
      end
    end
  end
  local strip = CreateFrame("Frame", nil, header)
  strip.fxiOurs = true
  strip:SetFrameLevel(math.max(0, header:GetFrameLevel() - 1))
  local i = opts.inset or 0
  strip:SetPoint("TOPLEFT", header, "TOPLEFT", i, -i)
  strip:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -i, i)
  Style.Panel(strip, opts.alpha or 0.95)
  header.fxiHeader = strip
  return strip
end
