-- Chat windows in the FFXI/XIUI look: Blizzard's chat art removed, a navy
-- gradient window with a steel edge behind each chat frame, and the
-- window's name in the top-right corner like XI's "Window1". Only the look
-- changes; Blizzard's chat (and Prat, if you keep it) still does the work.
local _, ns = ...

local M = ns.AddModule("ChatSkin")

local ART = { "Background", "TopTexture", "BottomTexture", "LeftTexture", "RightTexture",
  "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture" }

local held = {}
local function KeepHidden(tex)
  if held[tex] and tex:GetAlpha() > 0 then tex:SetAlpha(0) end
end

local function HideArt(tex)
  if type(tex) ~= "table" or not tex.IsObjectType or not tex:IsObjectType("Texture") then return end
  tex:SetAlpha(0)
  if not held[tex] then
    held[tex] = true
    hooksecurefunc(tex, "SetAlpha", KeepHidden)
  end
end

local function Piece(cf, name, suffix)
  local t = name and _G[name .. suffix]
  if type(t) ~= "table" then t = cf[suffix] end
  return t
end

local skinned = {}

local function Skin(cf, id)
  if not cf or skinned[cf] then return end
  skinned[cf] = true
  local name = cf:GetName()
  for _, suffix in ipairs(ART) do HideArt(Piece(cf, name, suffix)) end

  local shell = CreateFrame("Frame", nil, cf)
  shell:SetFrameLevel(math.max(0, cf:GetFrameLevel() - 1))
  shell:SetPoint("TOPLEFT", cf, "TOPLEFT", -6, 6)
  shell:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 6, -6)
  ns.Style.Panel(shell, 0.82)

  local label = ns.Style.Text(shell, 10)
  label:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -5, -3)
  label:SetTextColor(ns.Style.Color("title"))
  label:SetAlpha(0.8)
  shell.label = label
  cf.fxiShell = shell

  local function Rename()
    local title = FCF_GetChatWindowInfo and FCF_GetChatWindowInfo(id)
    label:SetText(title or "")
  end
  Rename()
  shell.Rename = Rename

  -- The tab (General, Combat Log, ...): Blizzard's tab art faded, the name
  -- in our font and title colour on a small XI strip. With the tab skinned
  -- the name in the window corner would repeat it, so that goes.
  local tab = name and _G[name .. "Tab"]
  if type(tab) == "table" and tab.GetRegions then
    local text = rawget(tab, "Text") or _G[name .. "TabText"]
    local strip = ns.Style.Header(tab, { size = 11, alpha = 0.9 })
    for _, key in ipairs({ "glow", "Glow", "conversationIcon" }) do
      local g = rawget(tab, key)
      if type(g) == "table" and key ~= "conversationIcon" then ns.Style.FadeArt(g) end
    end
    if strip and type(text) == "table" and text.GetStringWidth then
      strip:ClearAllPoints()
      strip:SetPoint("TOPLEFT", text, "TOPLEFT", -8, 4)
      strip:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 8, -4)
      label:Hide()
    end
  end
end

---------------------------------------------------------------------------
-- The button column beside a chat window (voice, chat menu, scroll
-- buttons): Blizzard's dark backdrop faded so the buttons float, and the
-- column moved to the right of the window. The social (friends) button
-- sits at the top right of General, above the rest of General's column. With "only on
-- mouse-over" the buttons stay hidden until the mouse is over the chat.
---------------------------------------------------------------------------
local columns = {}
local GAP_X = 10

local function RightOf(frame)
  local anchor = frame.fxiAnchor
  if frame.fxiPlacing or not anchor then return end
  frame.fxiPlacing = true
  pcall(function()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", GAP_X, frame.fxiDy or 0)
    if frame.fxiTall then frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", GAP_X, 0) end
  end)
  frame.fxiPlacing = nil
end

local function KeepRightOf(frame, anchor, tall, dy)
  if type(frame) ~= "table" or not frame.SetPoint then return end
  frame.fxiTall, frame.fxiAnchor, frame.fxiDy = tall, anchor, dy
  RightOf(frame)
  if not frame.fxiKeep then
    frame.fxiKeep = true
    hooksecurefunc(frame, "SetPoint", function(f) if not f.fxiPlacing then RightOf(f) end end)
  end
end

local function Social()
  local q = _G.QuickJoinToastButton or _G.FriendsMicroButton
  if type(q) ~= "table" then return end
  KeepRightOf(q, ChatFrame1, false)
  for _, key in ipairs({ "Background", "FriendsButton" }) do
    local r = rawget(q, key)
    if type(r) == "table" and r.IsObjectType and r:IsObjectType("Texture") and key == "Background" then HideArt(r) end
  end
end

local function SkinButtons(cf, name)
  local bf = (name and _G[name .. "ButtonFrame"]) or rawget(cf, "buttonFrame")
  if type(bf) ~= "table" or not bf.GetRegions or columns[bf] then return end
  columns[bf] = true
  for _, r in ipairs({ bf:GetRegions() }) do
    if r.IsObjectType and r:IsObjectType("Texture") then HideArt(r) end
  end
  HideArt(rawget(bf, "Background"))
  if ns.db.chat.buttonsRight ~= false then
    -- General's column starts under the social button.
    local dy = 0
    local q = _G.QuickJoinToastButton or _G.FriendsMicroButton
    if cf == ChatFrame1 and type(q) == "table" and q.GetHeight then dy = -((q:GetHeight() or 32) + 2) end
    KeepRightOf(bf, cf, true, dy)
  end

  if ns.db.chat.buttonsOnHover then
    bf:SetAlpha(0)
    local t = CreateFrame("Frame", nil, UIParent)
    local acc = 0
    t:SetScript("OnUpdate", function(_, dt)
      acc = acc + dt
      if acc < 0.15 then return end
      acc = 0
      local over = (cf:IsVisible() and cf:IsMouseOver()) or (bf:IsVisible() and bf:IsMouseOver(4, -4, -4, 4))
      bf:SetAlpha(over and 1 or 0)
    end)
  end
end

local function SkinAll()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    Skin(_G["ChatFrame" .. i], i)
    local cf = _G["ChatFrame" .. i]
    if cf then pcall(SkinButtons, cf, cf:GetName()) end
  end
  if ns.db.chat.buttonsRight ~= false then
    pcall(Social)
    -- Blizzard moves the column to whichever side has room; keep it right.
    if type(FCF_UpdateButtonSide) == "function" and not M.sideHooked then
      M.sideHooked = true
      hooksecurefunc("FCF_UpdateButtonSide", function(f)
        local bf = f and ((f:GetName() and _G[f:GetName() .. "ButtonFrame"]) or rawget(f, "buttonFrame"))
        if bf and bf.fxiKeep then RightOf(bf) end
      end)
    end
  end
end

---------------------------------------------------------------------------
-- FFXI-style stacking: the combat log (ChatFrame2) as its own window sat
-- directly on top of General (ChatFrame1), same width and height, and one
-- text size for every window. General is left where Edit Mode puts it (it
-- is an Edit Mode frame, and moving it from addon code taints Edit Mode);
-- the combat log follows it whenever General moves or is resized.
---------------------------------------------------------------------------
local following = false

local function Stack()
  local general, combat = ChatFrame1, ChatFrame2
  if not (general and combat) then return end
  if combat.isDocked and FCF_UnDockFrame then
    pcall(FCF_UnDockFrame, combat)
  end
  if FCF_SetLocked then pcall(FCF_SetLocked, combat, false) end
  combat:ClearAllPoints()
  combat:SetPoint("BOTTOMLEFT", general, "TOPLEFT", 0, ns.db.chat.gap or 30)
  combat:SetSize(general:GetWidth(), general:GetHeight())
  if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, combat) end
  -- SavePosition stores an absolute spot; anchor again so it keeps following.
  combat:ClearAllPoints()
  combat:SetPoint("BOTTOMLEFT", general, "TOPLEFT", 0, ns.db.chat.gap or 30)
  if FCF_SetLocked then pcall(FCF_SetLocked, combat, true) end
  combat:Show()
end

local function EvenFonts()
  local size = tonumber(ns.db.chat.fontSize) or 13
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf then
      if FCF_SetChatWindowFontSize then
        pcall(FCF_SetChatWindowFontSize, nil, cf, size)
      else
        local font, _, flags = cf:GetFont()
        if font then cf:SetFont(font, size, flags) end
      end
    end
  end
end

-- Chat size from the ForeverXIUI sliders: General is resized (never moved),
-- and the combat log copies it through Stack. Only once a slider has been
-- used, so Edit Mode's own size wins until then. Out of combat only.
local function Resize()
  local c = ns.db.chat
  if not c.sizeOn or not ChatFrame1 then return end
  ns.AfterCombat("chatSize", function()
    local w = math.max(200, math.min(1000, tonumber(c.width) or 430))
    local h = math.max(60, math.min(600, tonumber(c.height) or 120))
    pcall(ChatFrame1.SetSize, ChatFrame1, w, h)
  end)
end

function ns.ChatLayout(say)
  Resize()
  if ns.db.chat.stack then Stack() end
  EvenFonts()
  if say then ns.Print("chat windows stacked, text size %d.", tonumber(ns.db.chat.fontSize) or 13) end
end

local function Follow()
  if following or not ChatFrame1 then return end
  following = true
  local pending = false
  local function Again()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
      pending = false
      if ns.db.chat.stack then Stack() end
    end)
  end
  ChatFrame1:HookScript("OnSizeChanged", Again)
  if type(FCF_StopDragging) == "function" then hooksecurefunc("FCF_StopDragging", Again) end
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", Again, M)
  end
end

function M:Init()
  if ns.db.chat.stack or ns.db.chat.fontSize then
    -- After Blizzard has restored the windows' saved spots.
    C_Timer.After(1, function() ns.ChatLayout() end)
    Follow()
  end
  if not ns.db.modules.chat then return end
  SkinAll()
  -- Renamed or newly opened windows.
  if type(FCF_SetWindowName) == "function" then
    hooksecurefunc("FCF_SetWindowName", function(frame)
      if frame and frame.fxiShell then frame.fxiShell.Rename() end
    end)
  end
  if type(FCF_OpenTemporaryWindow) == "function" then
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      for _, cf in ipairs(CHAT_FRAMES or {}) do
        local f = _G[cf]
        if f and not skinned[f] then Skin(f, f:GetID()) end
      end
    end)
  end
end
