-- The XI menu: Blizzard's micro menu faded out and replaced by a navy window
-- of plain text entries (Character, Spells, Quests, Bags, ...), FFXI style.
--
-- How it opens things without tainting Forever: each entry is a secure
-- button that hands its click to Blizzard's own (now invisible) button
-- ("type" = "click", "clickbutton" = that button), so the game opens the
-- window in its own secure path. Calling ToggleCharacter() and friends from
-- addon code taints the panel manager on Forever, so nothing here does.
-- The game menu can't be opened even that way (Blizzard blocks addons and
-- its button only reacts "if self:IsMouseOver()"), so Blizzard's real menu
-- button sits invisibly over our "Menu" entry and takes the click itself.
--
-- The Bags entry shows how many bag slots are free.
-- The bag bar: faded and taken off the mouse (B and your bag keys still work).
local _, ns = ...

local M = ns.AddModule("MenuSkin")

-- label, Blizzard button(s) to hand the click to (first that exists), icon.
local I = "Interface\\Icons\\"
local ENTRIES = {
  { "Character", { "CharacterMicroButton" }, I .. "INV_Chest_Chain_05" },
  { "Spells", { "SpellbookMicroButton", "PlayerSpellsMicroButton" }, I .. "INV_Misc_Book_09" },
  { "Talents", { "TalentMicroButton" }, I .. "Ability_Marksmanship" },
  { "Professions", { "ProfessionMicroButton" }, I .. "Trade_BlackSmithing" },
  { "Quests", { "QuestLogMicroButton" }, I .. "INV_Misc_Note_01" },
  { "Map", { "@zone" }, I .. "INV_Misc_Map_01" },
  { "Guild", { "GuildMicroButton" }, I .. "INV_Shirt_GuildTabard_01" },
  { "Group", { "LFDMicroButton", "LFGMicroButton" }, I .. "Spell_Holy_PrayerOfFortitude" },
  { "Legacy", { "LegacyMicroButton" }, I .. "INV_Jewelry_Talisman_07" },
  { "Bags", { "MainMenuBarBackpackButton" }, I .. "INV_Misc_Bag_08" },
  { "Menu", { "MainMenuMicroButton" }, I .. "INV_Misc_Gear_01", overlay = true },
}
M.ENTRIES = ENTRIES
local ICON = 26           -- icon tile size
local ICON_GAP = 3

local MICRO_CONTAINERS = { "MicroMenuContainer", "MicroMenu", "MicroButtonAndBagsBar" }
local ENTRY_H, ENTRY_PAD, WIN_PAD = 18, 8, 4

---------------------------------------------------------------------------
-- Fading Blizzard's bars (Edit Mode frames: faded, never hidden or moved).
---------------------------------------------------------------------------
local held = {}
local function KeepFaded(frame)
  if held[frame] and frame:GetAlpha() > 0 then frame:SetAlpha(0) end
end

local function Fade(frame)
  if type(frame) ~= "table" or not frame.SetAlpha then return end
  frame:SetAlpha(0)
  if not held[frame] then
    held[frame] = true
    hooksecurefunc(frame, "SetAlpha", KeepFaded)
  end
end

local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
  "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot", "BagBarExpandToggle" }

local function HideBagBar()
  if type(BagsBar) ~= "table" then return end
  Fade(BagsBar)
  for _, name in ipairs(BAG_BUTTONS) do
    local b = _G[name]
    if type(b) == "table" and b.EnableMouse then pcall(b.EnableMouse, b, false) end
  end
end

-- Micro buttons: faded with their bar and off the mouse, so the invisible
-- buttons don't catch clicks. Our entries click them with :Click(), which
-- doesn't need the mouse.
local function HideMicroMenu(keep)
  for _, name in ipairs(MICRO_CONTAINERS) do
    local c = _G[name]
    if type(c) == "table" and c.GetChildren then
      Fade(c)
      for _, child in ipairs({ c:GetChildren() }) do
        if child ~= keep and child.EnableMouse then pcall(child.EnableMouse, child, false) end
      end
    end
  end
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------
local function Target(names)
  for _, n in ipairs(names) do
    if n == "@zone" then
      local zone = MinimapCluster and rawget(MinimapCluster, "ZoneTextButton") or _G.MinimapZoneTextButton
      if type(zone) == "table" and zone.Click then return zone end
    else
      local b = _G[n]
      if type(b) == "table" and b.Click then return b end
    end
  end
end

local function Paint(e, hover)
  if hover then
    if e.label then
      -- Under the icon (the menu usually sits at the top of the screen);
      -- above it only when the menu has been moved to the bottom.
      local tag = e.label
      tag:ClearAllPoints()
      local bottom = e:GetBottom()
      if bottom and bottom < 60 then
        tag:SetPoint("BOTTOM", e, "TOP", 0, 4)
      else
        tag:SetPoint("TOP", e, "BOTTOM", 0, -4)
      end
      tag:Show()
    else e.text:SetTextColor(ns.Style.Color("edgeLight")) end
    e.hl:Show()
  else
    if e.label then e.label:Hide() else e.text:SetTextColor(1, 1, 1) end
    e.hl:Hide()
  end
end

-- Icon tile: the picture in a thin black edge, and its name in a small XI
-- strip over it while the mouse is on it.
local function IconParts(e, label, icon)
  e:SetSize(ICON, ICON)
  local edge = e:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints()
  edge:SetColorTexture(0, 0, 0, 1)
  local tex = e:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", 1, -1)
  tex:SetPoint("BOTTOMRIGHT", -1, 1)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  e.icon = tex
  local tag = CreateFrame("Frame", nil, e)
  tag:SetFrameStrata("TOOLTIP")
  ns.Style.Panel(tag, 0.95)
  local fs = ns.Style.Text(tag, 11)
  fs:SetPoint("CENTER")
  fs:SetText(label)
  tag:SetSize(math.ceil((fs:GetStringWidth() or 40) + 12), 16)
  tag:SetPoint("TOP", e, "BOTTOM", 0, -4)
  tag:Hide()
  e.label = tag
end

local function BuildEntry(win, label, target, overlay, icon)
  local e = CreateFrame("Button", nil, win, "SecureActionButtonTemplate")
  e:RegisterForClicks("AnyUp", "AnyDown")
  if ns.db.menu.icons then
    IconParts(e, label, icon)
  else
    e:SetHeight(ENTRY_H)
    e.text = ns.Style.Text(e, 12)
    e.text:SetPoint("CENTER")
    e.text:SetText(label)
    e:SetWidth(math.ceil((e.text:GetStringWidth() or 40) + ENTRY_PAD * 2))
  end
  e.hl = e:CreateTexture(nil, "OVERLAY")
  e.hl:SetAllPoints()
  ns.Style.Fill(e.hl, "accent", 0.18)
  e.hl:Hide()
  e:SetScript("OnEnter", function(self) Paint(self, true) end)
  e:SetScript("OnLeave", function(self) Paint(self, false) end)

  if overlay then
    -- Blizzard's own button, invisible, on top of the entry.
    target:SetParent(e)
    target:ClearAllPoints()
    target:SetAllPoints(e)
    target:SetFrameLevel(e:GetFrameLevel() + 10)
    if target.EnableMouse then target:EnableMouse(true) end
    target:SetAlpha(0)
    held[target] = true
    hooksecurefunc(target, "SetAlpha", KeepFaded)
    local placing = false
    hooksecurefunc(target, "SetPoint", function()
      if placing then return end
      ns.AfterCombat("menuOverlay", function()
        placing = true
        target:ClearAllPoints()
        target:SetAllPoints(e)
        placing = false
      end)
    end)
    target:HookScript("OnEnter", function() Paint(e, true) end)
    target:HookScript("OnLeave", function() Paint(e, false) end)
  else
    e:SetAttribute("type", "click")
    e:SetAttribute("clickbutton", target)
    e:SetAttribute("useOnKeyDown", false)
  end
  return e
end

---------------------------------------------------------------------------
-- Free bag slots on the Bags entry, like a stack count: white, orange at 5
-- or fewer, red at 2 or fewer. Only plain bags count (not ammo, soul or
-- profession bags).
---------------------------------------------------------------------------
local function FreeSlots()
  local free, total = 0, 0
  local C = C_Container
  local numFree = (C and C.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  if not numFree or not numSlots then return end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local okF, f, bagType = pcall(numFree, bag)
    local okS, n = pcall(numSlots, bag)
    if okF and okS and type(f) == "number" and type(n) == "number" and (bagType == nil or bagType == 0) then
      free, total = free + f, total + n
    end
  end
  return free, total
end

local function BagCount(e)
  local fs = e:CreateFontString(nil, "OVERLAY")
  ns.Style.Font(fs, e.icon and 12 or 10, "OUTLINE")
  fs:SetShadowColor(0, 0, 0, 1)
  if e.icon then
    fs:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -1, 2)
  else
    fs:SetPoint("TOPRIGHT", e, "TOPRIGHT", -1, -1)
  end
  local function Update()
    if ns.db.menu.bagCount == false then fs:Hide() return end
    local free = FreeSlots()
    if not free then fs:Hide() return end
    fs:SetText(free)
    if free <= 2 then fs:SetTextColor(1, 0.25, 0.25)
    elseif free <= 5 then fs:SetTextColor(1, 0.6, 0.15)
    else fs:SetTextColor(1, 1, 1) end
    fs:Show()
  end
  local ev = CreateFrame("Frame", nil, e)
  for _, name in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(ev.RegisterEvent, ev, name)
  end
  ev:SetScript("OnEvent", Update)
  e.bagCount, e.UpdateBagCount = fs, Update
  Update()
end

local function Arrange(win, entries)
  local vertical = ns.db.menu.vertical
  local icons = ns.db.menu.icons
  local gap = icons and ICON_GAP or 0
  local x, y, w, h = WIN_PAD, -WIN_PAD, 0, 0
  for i, e in ipairs(entries) do
    e:ClearAllPoints()
    e:SetPoint("TOPLEFT", win, "TOPLEFT", x, y)
    local last = i == #entries
    if vertical then
      y = y - e:GetHeight() - (last and 0 or gap)
      w = math.max(w, e:GetWidth())
    else
      x = x + e:GetWidth() + (last and 0 or gap)
      h = math.max(h, e:GetHeight())
    end
  end
  if vertical then
    if not icons then for _, e in ipairs(entries) do e:SetWidth(w) end end
    win:SetSize(w + WIN_PAD * 2, -y + WIN_PAD)
  else
    win:SetSize(x + WIN_PAD, h + WIN_PAD * 2)
  end
end

function M:Init()
  if ns.db.hideBagBar then ns.AfterCombat("hideBagBar", HideBagBar) end
  if not ns.db.menuSkin then return end
  ns.AfterCombat("xiMenu", function()
    local win = CreateFrame("Frame", "ForeverXIUIMenu", UIParent)
    win:SetFrameStrata("MEDIUM")
    ns.Style.Panel(win, 0.92)
    local entries, keep = {}, nil
    local hide = ns.db.menu.hide or {}
    for _, spec in ipairs(ENTRIES) do
      -- Any entry can be left off; Esc still opens the game menu.
      local target = not hide[spec[1]] and Target(spec[2])
      if target then
        local ok, e = pcall(BuildEntry, win, spec[1], target, spec.overlay, spec[3])
        if ok and e then
          entries[#entries + 1] = e
          if spec[1] == "Bags" then pcall(BagCount, e) end
          if spec.overlay then keep = target end
        end
      end
    end
    if #entries == 0 then
      win:Hide()
      ns.Print("couldn't find Blizzard's menu buttons; the XI menu is off.")
      return
    end
    Arrange(win, entries)
    HideMicroMenu(keep)
    self.frame, self.entries = win, entries
    ns.AddRoot(win, "menu")
    ns.Movers.Register("menu", "Menu", win, { "TOPLEFT", "TOPLEFT", 8, -4 })
    ns.ApplyScale()
  end)
end

function M:Relayout()
  if self.frame then
    for _, e in ipairs(self.entries) do
      if e.UpdateBagCount then e.UpdateBagCount() end
    end
    ns.AfterCombat("xiMenuLayout", function() Arrange(self.frame, self.entries) end)
  end
end
