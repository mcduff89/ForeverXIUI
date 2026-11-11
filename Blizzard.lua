-- Put Blizzard's own frames away where ForeverXIUI replaces them.
--
-- Protected frames (player, target, target-of-target) and Edit Mode managed
-- frames are faded and made deaf, never hidden or re-parented: hiding them
-- from addon code spreads taint into Edit Mode on Forever. Party and raid
-- containers are re-parented under a hidden frame, because Blizzard re-shows
-- them on every roster change. Turning an option back on needs /reload.
local _, ns = ...

local M = ns.AddModule("Blizzard")

local hider = CreateFrame("Frame")
hider:Hide()
local faded = {}

local function KeepFaded(frame)
  if faded[frame] and frame:GetAlpha() > 0 then frame:SetAlpha(0) end
end

local function Fade(frame)
  if type(frame) ~= "table" or not frame.SetAlpha then return end
  if frame.UnregisterAllEvents then pcall(frame.UnregisterAllEvents, frame) end
  frame:SetAlpha(0)
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  if not faded[frame] then
    faded[frame] = true
    hooksecurefunc(frame, "SetAlpha", KeepFaded)
    if frame.HookScript then frame:HookScript("OnShow", KeepFaded) end
  end
end

local function Stash(frame)
  if type(frame) ~= "table" then return end
  if frame.UnregisterAllEvents then pcall(frame.UnregisterAllEvents, frame) end
  local hide = rawget(frame, "HideBase") or frame.Hide
  pcall(hide, frame)
  pcall(frame.SetParent, frame, hider)
end

local function Deafen(frame)
  if type(frame) == "table" and frame.UnregisterAllEvents then
    pcall(frame.UnregisterAllEvents, frame)
  end
end

-- The quest/objective tracker swaps with a guide window (Polestar or
-- RestedXP): hidden while one is showing, back as soon as none is (Polestar
-- hides its window in dungeons, for one). The tracker holds clickable
-- quest-item buttons, so it's hidden outright rather than faded (no
-- invisible buttons to mis-click), and only changed out of combat.
local TRACKERS = { "ObjectiveTrackerFrame", "WatchFrame", "QuestWatchFrame" }
local hiddenByUs = {}
local trackerHooked = {}

-- Guide windows that take the tracker's place: Polestar's and RestedXP's.
local GUIDES = { "PolestarGuideFrame", "RXPFrame" }

local function GuideShowing()
  for _, name in ipairs(GUIDES) do
    local f = _G[name]
    if type(f) == "table" and f.IsVisible and f:IsVisible() and (f:GetAlpha() or 1) > 0.05 then return true end
  end
  return false
end

local function WantTrackerHidden()
  return ns.db.hideBlizzard.objectives ~= false and GuideShowing()
end

local function SyncTrackers()
  if InCombatLockdown() then return end
  local hide = WantTrackerHidden()
  for _, name in ipairs(TRACKERS) do
    local f = _G[name]
    if type(f) == "table" and f.Hide then
      if not trackerHooked[f] then
        trackerHooked[f] = true
        -- The game shows the tracker by itself (new quest, zoning).
        hooksecurefunc(f, "Show", function()
          if WantTrackerHidden() then ns.AfterCombat("tracker:" .. name, SyncTrackers) end
        end)
      end
      if hide and f:IsShown() then
        pcall(f.Hide, f)
        hiddenByUs[f] = true
      elseif not hide and hiddenByUs[f] then
        hiddenByUs[f] = nil
        pcall(f.Show, f)
      end
    end
  end
end
M.SyncTrackers = SyncTrackers

local function HideTrackers()
  if M.trackerTicker then return end
  SyncTrackers()
  -- The guides open and close their windows themselves (dungeons, its own close
  -- button), so check twice a second; it's only a couple of IsVisible calls.
  M.trackerTicker = C_Timer.NewTicker(0.5, SyncTrackers)
  ns.On("PLAYER_REGEN_ENABLED", SyncTrackers)
end
M.HideTrackers = HideTrackers

-- Edit Mode boxes for frames you never move there. Only the box (the
-- frame's Selection overlay) is made invisible and click-through; the
-- minimap and bag bar themselves are untouched, and Edit Mode itself is
-- never driven from here.
local EDIT_BOXES = { "MinimapCluster", "BagsBar", "MicroMenuContainer" }
local boxHooked = {}

local function MuteBox(sel)
  if sel:GetAlpha() > 0 then sel:SetAlpha(0) end
  if sel.EnableMouse then pcall(sel.EnableMouse, sel, false) end
end

function M.HideEditBoxes()
  for _, name in ipairs(EDIT_BOXES) do
    local f = _G[name]
    local sel = type(f) == "table" and rawget(f, "Selection")
    if type(sel) == "table" and sel.SetAlpha and not boxHooked[sel] then
      boxHooked[sel] = true
      MuteBox(sel)
      hooksecurefunc(sel, "SetAlpha", function(s) if s:GetAlpha() > 0 then s:SetAlpha(0) end end)
      if sel.HookScript then sel:HookScript("OnShow", MuteBox) end
    end
  end
end

local function HideBoss()
  Fade(_G.BossTargetFrameContainer)
  for i = 1, (MAX_BOSS_FRAMES or 5) do
    local f = _G["Boss" .. i .. "TargetFrame"]
    if f then Fade(f) end
  end
end

local function HideAll()
  local h = ns.db.hideBlizzard
  if h.player and ns.db.modules.player then
    Fade(PlayerFrame)
  end
  if h.target and ns.db.modules.target then
    Fade(TargetFrame)
    Fade(TargetFrameToT)
  end
  if h.cast and ns.db.modules.playerCast then
    for _, name in ipairs({ "PlayerCastingBarFrame", "CastingBarFrame", "GamepadPlayerCastingBarFrame" }) do
      Fade(_G[name])
    end
  end
  if h.party and ns.db.modules.party then
    if PartyFrame then
      if PartyFrame.PartyMemberFramePool then
        for member in PartyFrame.PartyMemberFramePool:EnumerateActive() do Deafen(member) end
      end
      for i = 1, 4 do Deafen(PartyFrame["MemberFrame" .. i]) end
      Stash(PartyFrame)
    end
    Stash(CompactPartyFrame)
  end
  if h.xp and ns.db.modules.xp then M.HideStatusBars() end
  HideTrackers()
  if h.editBoxes ~= false then M.HideEditBoxes() end
  if h.boss then HideBoss() end
  if h.raid and ns.db.modules.raid then
    -- Only the frames. The side panel (ready check, markers) stays.
    Stash(CompactRaidFrameContainer)
  end
end

---------------------------------------------------------------------------
-- Blizzard's XP and reputation bars (Edit Mode frames: faded, never hidden).
-- The game puts their alpha back to 1 by itself, without going through
-- SetAlpha in Lua, so the hook alone misses it: every bar inside each
-- container is faded too, and it's re-checked when XP or reputation
-- changes and twice a second while anything has crept back.
---------------------------------------------------------------------------
local statusFrames = {}

local function StatusFrames()
  wipe(statusFrames)
  local function add(f)
    if type(f) == "table" and f.SetAlpha then statusFrames[#statusFrames + 1] = f end
  end
  add(_G.MainStatusTrackingBarContainer)
  add(_G.SecondaryStatusTrackingBarContainer)
  local mgr = _G.StatusTrackingBarManager
  if type(mgr) == "table" then
    for _, c in ipairs(mgr.barContainers or {}) do
      add(c)
      for _, bar in pairs(c.bars or {}) do
        add(bar)
        if type(bar) == "table" then add(bar.ExhaustionTick) end
      end
    end
  end
  return statusFrames
end

local function Silence()
  for _, f in ipairs(StatusFrames()) do
    if f:GetAlpha() > 0 then f:SetAlpha(0) end
    if f.EnableMouse then pcall(f.EnableMouse, f, false) end
    if not faded[f] then
      faded[f] = true
      hooksecurefunc(f, "SetAlpha", KeepFaded)
      if f.HookScript then f:HookScript("OnShow", KeepFaded) end
    end
  end
end

function M.HideStatusBars()
  Silence()
  if M.statusWatch then return end
  local w = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION",
    "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING" }) do
    pcall(w.RegisterEvent, w, e)
  end
  w:SetScript("OnEvent", function() C_Timer.After(0, Silence) end)
  local acc = 0
  w:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.5 then return end
    acc = 0
    for _, f in ipairs(statusFrames) do
      if f:GetAlpha() > 0 then f:SetAlpha(0) end
    end
  end)
  local mgr = _G.StatusTrackingBarManager
  if type(mgr) == "table" and type(mgr.UpdateBarsShown) == "function" then
    hooksecurefunc(mgr, "UpdateBarsShown", function() C_Timer.After(0, Silence) end)
  end
  M.statusWatch = w
end

function M:Init()
  ns.AfterCombat("blizzard", HideAll)
end

-- The raid frames load on demand.
ns.On("ADDON_LOADED", function(_, name)
  if name == "Blizzard_CompactRaidFrames" and ns.db and ns.db.hideBlizzard.raid and ns.db.modules.raid then
    ns.AfterCombat("blizzardRaid", function() Stash(CompactRaidFrameContainer) end)
  end
end)
