-- Damage meter skin: the game's built-in damage meter in an XI window.
-- Only looks: a navy panel with the steel edge behind each meter window,
-- and Blizzard's own background art faded. The meter is an Edit Mode frame,
-- so it is never moved, re-parented or hidden; place it in Edit Mode and
-- the window follows.
--
-- Blizzard hasn't documented the meter's frame names for addons, so this
-- looks in a few places (the global name, Edit Mode's registered system)
-- and skins every window it finds. /fxiui check says what it found.
local _, ns = ...

local M = ns.AddModule("MeterSkin")

local NAMES = { "DamageMeter", "DamageMeterFrame" }
local DECOR = { "NineSlice", "Background", "Bg", "BackgroundTexture", "Backdrop", "Border" }

local faded, skinned, found = {}, {}, {}
local Kind

local function KeepFaded(region)
  if faded[region] and region:GetAlpha() > 0 then region:SetAlpha(0) end
end

local function Fade(region)
  if type(region) ~= "table" or not region.SetAlpha or region.fxiOurs then return end
  region:SetAlpha(0)
  if not faded[region] then
    faded[region] = true
    hooksecurefunc(region, "SetAlpha", KeepFaded)
  end
end

Kind = function(f)
  local ok, k = pcall(f.GetObjectType, f)
  return ok and k or nil
end

-- The window's header: a child frame along its top edge (the "Damage Done"
-- strip with the dropdown and buttons), or a key Blizzard may give it.
local HEADER_KEYS = { "Header", "HeaderBar", "TitleBar", "Title", "TitleContainer" }
local headers = {}

local function FindHeader(win)
  for _, key in ipairs(HEADER_KEYS) do
    local h = rawget(win, key)
    if type(h) == "table" and h.GetRegions and Kind(h) ~= "FontString" then return h end
  end
  local top, w = win:GetTop(), win:GetWidth() or 0
  if not top then return nil end
  for _, child in ipairs({ win:GetChildren() }) do
    if not child.fxiOurs and Kind(child) == "Frame" then
      local ct, ch, cw = child:GetTop(), child:GetHeight() or 0, child:GetWidth() or 0
      if ct and math.abs(ct - top) <= 4 and ch >= 14 and ch <= 34 and cw >= w * 0.5 then return child end
    end
  end
end

local function NearTop(r, wt)
  local rt = r.GetTop and r:GetTop()
  return rt and math.abs(rt - wt) <= 6 and (r:GetHeight() or 0) <= 34
end

-- Forever's meter (from /fxiui meter): each DamageMeterSessionWindowN has a
-- Header texture (the gold bar) with DamageMeterTypeDropdown ("Damage
-- Done"), SessionDropdown, SettingsDropdown and MinimizeButton over it.
local function Restyle(fs, title)
  if type(fs) ~= "table" or Kind(fs) ~= "FontString" then return end
  ns.Style.Font(fs, 12)
  if title then fs:SetTextColor(ns.Style.Color("title")) end
end

local function SkinBlizzardHeader(win)
  local hdr = rawget(win, "Header")
  if type(hdr) ~= "table" or Kind(hdr) ~= "Texture" then return false end
  Fade(hdr)
  local strip = CreateFrame("Frame", nil, win)
  strip.fxiOurs = true
  strip:SetFrameLevel(win:GetFrameLevel())
  strip:SetAllPoints(hdr)
  ns.Style.Panel(strip, 0.95)
  local typeDD = rawget(win, "DamageMeterTypeDropdown")
  if type(typeDD) == "table" then
    Restyle(rawget(typeDD, "TypeName"), true)
    -- Keep the text our colour when the meter type changes.
    local fs = rawget(typeDD, "TypeName")
    if type(fs) == "table" and fs.SetTextColor then
      local tr, tg, tb = ns.Style.Color("title")
      hooksecurefunc(fs, "SetTextColor", function(self, red)
        if red ~= tr and not self.fxiColoring then
          self.fxiColoring = true
          self:SetTextColor(tr, tg, tb)
          self.fxiColoring = nil
        end
      end)
    end
  end
  local session = rawget(win, "SessionDropdown")
  if type(session) == "table" then
    Restyle(rawget(session, "SessionName"), false)
    Restyle(rawget(session, "Text"), false)
    Fade(rawget(session, "Background"))
  end
  Restyle(rawget(win, "SessionTimer"), false)
  headers[win] = strip
  return true
end

local function SkinHeader(win)
  if headers[win] then return end
  if SkinBlizzardHeader(win) then return end
  local wt = win.GetTop and win:GetTop()
  if not wt then return end             -- not laid out yet; tried again later
  local h = FindHeader(win)
  if h then
    ns.Style.Header(h, { size = 12 })
    headers[win] = h
  else
    -- No header frame: the bar is drawn on the window itself. Our own strip
    -- along the top, and the title text restyled.
    local strip = CreateFrame("Frame", nil, win)
    strip.fxiOurs = true
    strip:SetFrameLevel(win:GetFrameLevel())
    strip:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    strip:SetHeight(22)
    ns.Style.Panel(strip, 0.95)
    headers[win] = strip
  end
  -- Header art laid right on the window, and its title text.
  for _, r in ipairs({ win:GetRegions() }) do
    local k = Kind(r)
    if k == "Texture" and not r.fxiOurs and NearTop(r, wt) then
      Fade(r)
    elseif k == "FontString" and NearTop(r, wt) then
      ns.Style.Font(r, 12)
      r:SetTextColor(ns.Style.Color("title"))
    end
  end
end

-- One meter window: fade its decoration, put our panel just under it.
local function Skin(win)
  if type(win) ~= "table" or not win.GetFrameLevel then return end
  if skinned[win] then SkinHeader(win) return end
  local w = win.GetWidth and win:GetWidth() or 0
  if w < 60 then return end          -- buttons and bits, not a window
  skinned[win] = true
  for _, key in ipairs(DECOR) do
    local r = rawget(win, key)
    if type(r) == "table" and (Kind(r) == "Texture" or key == "NineSlice") then Fade(r) end
  end
  local back = CreateFrame("Frame", nil, win)
  back.fxiOurs = true
  back:SetFrameLevel(math.max(0, win:GetFrameLevel() - 1))
  back:SetPoint("TOPLEFT", win, "TOPLEFT", -2, 2)
  back:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 2, -2)
  ns.Style.Panel(back, 0.9)
  found[#found + 1] = win:GetName() or "window"
  SkinHeader(win)
  win:HookScript("OnShow", function() C_Timer.After(0, function() SkinHeader(win) end) end)
end

local function Roots()
  local out = {}
  for _, n in ipairs(NAMES) do
    if type(_G[n]) == "table" then out[#out + 1] = _G[n] end
  end
  if EditModeManagerFrame and EditModeManagerFrame.GetRegisteredSystemFrame
    and Enum and Enum.EditModeSystem and Enum.EditModeSystem.DamageMeter then
    local ok, f = pcall(EditModeManagerFrame.GetRegisteredSystemFrame, EditModeManagerFrame,
      Enum.EditModeSystem.DamageMeter)
    if ok and type(f) == "table" then out[#out + 1] = f end
  end
  return out
end

function M.Apply()
  if not ns.db.meter.skin then return end
  for _, root in ipairs(Roots()) do
    -- The meter's windows are its children (one per session window);
    -- if it has none that look like windows, skin the meter itself.
    local before = #found
    if root.GetChildren then
      for _, child in ipairs({ root:GetChildren() }) do
        local editMode = child == rawget(root, "Selection") or rawget(child, "system") ~= nil
        if not child.fxiOurs and not editMode and Kind(child) == "Frame" and (child:GetHeight() or 0) > 40 then Skin(child) end
      end
    end
    if #found == before then Skin(root) end
    if not headers[root] and root.GetTop and rawget(root, "Header") then SkinHeader(root) end
  end
end

function M:Init()
  if not ns.db.meter.skin then return end
  M.Apply()
  -- The meter loads on demand; skin it when it does, and when new windows open.
  ns.On("ADDON_LOADED", function(_, name)
    if type(name) == "string" and name:find("DamageMeter") then C_Timer.After(0.2, M.Apply) end
  end)
  ns.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, M.Apply) end)
  ns.On("PLAYER_REGEN_DISABLED", M.Apply)
  for _, t in ipairs({ 1, 4 }) do C_Timer.After(t, M.Apply) end
end

-- /fxiui meter: what the meter is made of, to fit the skin to it.
function M.Dump()
  M.Apply()
  local roots = Roots()
  local out = { "ForeverXIUI " .. ns.version .. " damage meter", "skinned: " .. M.Describe() }
  if #roots == 0 then out[#out + 1] = "no meter frame found (is the meter open?)" end
  for _, r in ipairs(roots) do
    out[#out + 1] = ""
    ns.DumpFrame(r, out, 0, 4)
  end
  ns.ShowCopy("Damage meter layout", out)
end

function M.Describe()
  local roots = {}
  for _, r in ipairs(Roots()) do roots[#roots + 1] = (r.GetName and r:GetName()) or "unnamed" end
  if #roots == 0 then return "none found (open the meter once, then check again)" end
  return ("%s; skinned %d: %s"):format(table.concat(roots, " "), #found,
    #found > 0 and table.concat(found, " ") or "-")
end
