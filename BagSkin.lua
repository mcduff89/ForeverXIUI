-- XI bags: Baganator in the ForeverXIUI look. Baganator keeps doing the real
-- work (categories, sorting, search, bank); this only changes how its
-- windows look, through Baganator's own public skin hook
-- (Baganator.API.Skins.RegisterListener), and adds a free-slot line under
-- the backpack (Baganator.API.RegisterRegion). No Baganator code is copied
-- or changed.
--
-- Window: Blizzard's frame art faded, a navy XI panel behind it, title in
-- the XI font and colour.
-- Items: square tiles with a thin black edge (quality colour for green and
-- up), the icon cropped, empty slots a dark navy square.
-- Buttons: Blizzard's red button art faded, a small XI tile behind each.
--
-- Works with Baganator's "Blizzard" skin (the default). Turning it off
-- needs a /reload.
local _, ns = ...

local M = ns.AddModule("BagSkin")

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FRAME_ART = { "NineSlice", "Bg", "TitleBg", "TopTileStreaks", "Inset", "Background",
  "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder",
  "TopRightCorner", "TopLeftCorner", "TopBorder", "PortraitContainer", "portrait" }
local BUTTON_ART = { "Left", "Right", "Middle", "LeftSeparator", "RightSeparator" }

local done = {}
local function o() return ns.db.bags end

local function Fade(region)
  if type(region) == "table" and region.SetAlpha then ns.Style.FadeArt(region) end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function TitleText(frame)
  local tc = rawget(frame, "TitleContainer")
  if type(tc) == "table" and type(rawget(tc, "TitleText")) == "table" then return tc.TitleText end
  if type(rawget(frame, "TitleText")) == "table" then return frame.TitleText end
  if frame.GetTitleText then
    local ok, fs = pcall(frame.GetTitleText, frame)
    if ok and type(fs) == "table" then return fs end
  end
end

-- Fade the textures of a frame (never the frame itself, so anything
-- Baganator puts inside it stays visible).
local function FadeTextures(f)
  if type(f) ~= "table" or not f.GetRegions then return end
  for _, r in ipairs({ f:GetRegions() }) do
    local ok, k = pcall(r.GetObjectType, r)
    if ok and k == "Texture" and not r.fxiOurs then Fade(r) end
  end
  local ns9 = rawget(f, "NineSlice")
  if type(ns9) == "table" then Fade(ns9) end
end

local function SkinWindow(frame)
  for _, key in ipairs(FRAME_ART) do
    local r = rawget(frame, key)
    if type(r) == "table" then
      local ok, k = pcall(r.GetObjectType, r)
      if ok and k == "Texture" then Fade(r)
      elseif key == "NineSlice" or key == "PortraitContainer" then Fade(r)
      else FadeTextures(r) end
    end
  end
  -- Loose background and border textures straight on the window.
  for _, r in ipairs({ frame:GetRegions() }) do
    local ok, k = pcall(r.GetObjectType, r)
    if ok and k == "Texture" and not r.fxiOurs then
      local layer = r:GetDrawLayer()
      if layer == "BACKGROUND" or layer == "BORDER" then Fade(r) end
    end
  end
  local back = CreateFrame("Frame", nil, frame)
  back.fxiOurs = true
  back:SetAllPoints(frame)
  back:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  ns.Style.Panel(back, o().alpha or 0.92)
  frame.fxiBack = back

  local title = TitleText(frame)
  if title then
    ns.Style.Font(title, 13)
    title:SetTextColor(ns.Style.Color("title"))
  end
end

---------------------------------------------------------------------------
-- Item tiles
---------------------------------------------------------------------------
local function EdgeColor(button, quality)
  local edge = button.fxiEdge
  if not edge then return end
  local c = type(quality) == "number" and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c then
    edge:SetColorTexture(c.r, c.g, c.b, 1)
  else
    edge:SetColorTexture(0, 0, 0, 1)
  end
end

local function QualityHook(button, quality)
  if not button or not button.fxiEdge then return end
  if button.IconBorder then button.IconBorder:SetAlpha(0) end
  EdgeColor(button, quality)
end

local function TextureHook(button)
  if button and button.fxiEdge and button.icon then
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

local hooked = false
local function SkinItem(button)
  if not button.icon then return end
  local edge = button:CreateTexture(nil, "BACKGROUND", nil, -7)
  edge.fxiOurs = true
  edge:SetAllPoints(button.icon)
  edge:SetColorTexture(0, 0, 0, 1)
  button.fxiEdge = edge
  -- The icon one pixel in from the edge, cropped.
  pcall(function()
    local w, h = button.icon:GetSize()
    if w and w > 4 then
      edge:ClearAllPoints()
      edge:SetPoint("CENTER", button.icon, "CENTER")
      edge:SetSize(w, h)
      button.icon:SetSize(w - 2, h - 2)
    end
  end)
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if button.IconBorder then button.IconBorder:SetAlpha(0) end
  local nt = button.GetNormalTexture and button:GetNormalTexture()
  if nt then Fade(nt) end
  if button.SlotBackground then
    button.SlotBackground:SetColorTexture(0.06, 0.08, 0.16, 0.85)
    -- Always show the slot square, even with Baganator's "Hide icon
    -- backgrounds" ticked, so empty slots never vanish.
    local sb = button.SlotBackground
    local function Keep() if not sb:IsShown() then sb:Show() end end
    sb:Show()
    hooksecurefunc(sb, "Hide", Keep)
    hooksecurefunc(sb, "SetShown", Keep)
  end
  if not hooked then
    hooked = true
    if SetItemButtonQuality then hooksecurefunc("SetItemButtonQuality", QualityHook) end
    if SetItemButtonTexture then hooksecurefunc("SetItemButtonTexture", TextureHook) end
  end
  if button.SetItemButtonQuality then hooksecurefunc(button, "SetItemButtonQuality", QualityHook) end
  if button.SetItemButtonTexture then hooksecurefunc(button, "SetItemButtonTexture", TextureHook) end
end

---------------------------------------------------------------------------
-- Buttons (the icon row along the top, sort, search options...)
---------------------------------------------------------------------------
local function SkinButton(button)
  local any = false
  for _, key in ipairs(BUTTON_ART) do
    local r = rawget(button, key)
    if type(r) == "table" and r.SetAlpha then Fade(r) any = true end
  end
  if not any then return end
  if button.GetHighlightTexture then
    local hl = button:GetHighlightTexture()
    if hl then hl:SetColorTexture(0.47, 0.77, 0.93, 0.18) end
  end
  local back = CreateFrame("Frame", nil, button)
  back.fxiOurs = true
  back:SetAllPoints(button)
  back:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
  ns.Style.Panel(back, 0.95)
end

---------------------------------------------------------------------------
local SKIN = {
  ButtonFrame = SkinWindow,
  ItemButton = SkinItem,
  IconButton = SkinButton,
  Button = SkinButton,
}

local function OnRegion(details)
  if type(details) ~= "table" then return end
  local region, kind = details.region, details.regionType
  if type(region) ~= "table" or done[region] then return end
  local fn = SKIN[kind]
  if not fn then return end
  done[region] = true
  local ok, err = pcall(fn, region, details.tags)
  if not ok then
    M.errors = (M.errors or 0) + 1
    if not M.warned then
      M.warned = true
      ns.Print("bags: %s", tostring(err))
    end
  end
end

---------------------------------------------------------------------------
-- Free slots, under the backpack (left of the money)
---------------------------------------------------------------------------
local function FreeSlots()
  local C = C_Container
  local numFree = (C and C.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  if not numFree or not numSlots then return end
  local free, total = 0, 0
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local okF, f, bagType = pcall(numFree, bag)
    local okS, n = pcall(numSlots, bag)
    if okF and okS and type(f) == "number" and type(n) == "number" and (bagType == nil or bagType == 0) then
      free, total = free + f, total + n
    end
  end
  return free, total
end
M.FreeSlots = FreeSlots

local function FreeLine()
  local f = CreateFrame("Frame")
  f:SetSize(90, 20)
  local fs = ns.Style.Text(f, 12)
  fs:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.text = fs
  local function Update()
    local free, total = FreeSlots()
    if not free then fs:SetText("") return end
    local r, g, b = 1, 1, 1
    if free <= 2 then r, g, b = 1, 0.25, 0.25 elseif free <= 5 then r, g, b = 1, 0.6, 0.15 end
    fs:SetText(("%d / %d free"):format(free, total))
    fs:SetTextColor(r, g, b)
    local w = math.ceil((fs:GetStringWidth() or 80) + 6)
    if math.abs((f:GetWidth() or 0) - w) > 1 then
      f:SetWidth(w)
      if Baganator and Baganator.API and Baganator.API.RequestLayoutUpdate then
        pcall(Baganator.API.RequestLayoutUpdate)
      end
    end
  end
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do pcall(f.RegisterEvent, f, e) end
  f:SetScript("OnEvent", Update)
  f.Update = Update
  Update()
  return f
end

---------------------------------------------------------------------------
function M:Init()
  if o().skin == false and o().freeLine == false then return end
  local api = Baganator and Baganator.API
  if not api then return end
  if o().skin ~= false and api.Skins and api.Skins.RegisterListener then
    api.Skins.RegisterListener(OnRegion)
    -- Frames Baganator already made before we loaded.
    if api.Skins.GetAllFrames then
      local ok, all = pcall(api.Skins.GetAllFrames)
      if ok and type(all) == "table" then
        for _, details in ipairs(all) do OnRegion(details) end
      end
    end
    self.skinning = true
  end
  if o().freeLine ~= false and api.RegisterRegion then
    local line = FreeLine()
    local ok = pcall(api.RegisterRegion, "ForeverXIUI", "ForeverXIUI_FreeSlots", "backpack", "bottom_left", line)
    self.freeLine = ok and line or nil
  end
end

function M.Describe()
  if not (Baganator and Baganator.API) then return "Baganator not loaded" end
  local n = 0
  for _ in pairs(done) do n = n + 1 end
  return ("skin %s, %d regions styled, free line %s%s"):format(M.skinning and "on" or "off", n,
    M.freeLine and "on" or "off", M.errors and (", " .. M.errors .. " errors") or "")
end
