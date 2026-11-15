-- Party list (XIUI style): one navy window, a row per member with class
-- icon and name, HP bar with "1108 (100%)" and a power bar. You are the
-- bottom row. The window grows upward from its bottom edge, like XIUI's
-- "align bottom". In a raid it shows your own group.
--
-- Each member's buffs and debuffs (drawn by the game, Auras.lua) sit on a
-- line under their name: buffs from the left, debuffs from the right. Or,
-- with "under the name" off, beside the window. Their pet sits beside the
-- window on the same line as its owner: left by default, "Flip sides"
-- puts pets right (and outside icons left).
--
-- Rows are secure unit buttons: left-click targets, right-click opens the
-- unit menu. Their order is rebuilt out of combat; a roster change during
-- combat is laid out when combat ends.
local _, ns = ...

local M = ns.AddModule("PartyList")

local W, W_COMPACT = 236, 190
local ROW_H, PAD, TITLE_H = 30, 6, 14
-- Row height: one line taller when the buff/debuff icons sit under the name.
local function RowH() return ROW_H + (ns.Auras and ns.Auras.RowExtra() or 0) end
local UNITS = { "player", "party1", "party2", "party3", "party4" }
local PETS = { "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
local PET_W, PET_GAP = 118, 4
local AURA_WIN_GAP = 4      -- between the party window and the icon window
local AURA_GAP = PAD + AURA_WIN_GAP + 4   -- from the row's edge to the first icon
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
  "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" }

local rows, pets = {}, {}

local function Width() return ns.db.compact and W_COMPACT or W end

local function UpdateRow(row)
  local unit = row.unit
  if not UnitExists(unit) then return end
  ns.Values.Name(row.name, unit)
  if row.lead then row.lead:SetShown(ns.Bool(UnitIsGroupLeader, unit) and IsInGroup() or false) end
  local _, class = UnitClass(unit)
  ns.Style.ClassIcon(row.icon, class)

  if ns.Values.IsOffline(unit) then
    row.name:SetTextColor(0.55, 0.55, 0.55)
    row.hp:SetMinMaxValues(0, 1)
    row.hp:SetValue(0)
    row.hpText:SetText("Offline")
    row.mp:SetValue(0)
    row.mpText:SetText("")
    return
  end
  row.name:SetTextColor(1, 1, 1)
  ns.Values.Health(row.hp, row.hpText, unit, "both", true)
  ns.Values.Power(row.mp, row.mpText, unit, "value")
  if ns.Values.IsDead(unit) then row.hpText:SetText("Dead") end
end

-- The look of a row, shared by the real (secure) rows and the preview rows.
local function BuildParts(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(13, 13)
  row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
  row.name = ns.Style.Text(row, 11)
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  -- Crown after the party (or raid) leader's name.
  row.lead = row:CreateTexture(nil, "OVERLAY")
  row.lead:SetSize(12, 12)
  row.lead:SetPoint("LEFT", row.name, "RIGHT", 3, 0)
  row.lead:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  row.lead:Hide()

  row.hp = ns.Style.Bar(row, 140, 10, "hpHigh")
  row.hp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 3)
  row.hpText = ns.Style.BarText(row.hp, 10)

  row.mp = ns.Style.Bar(row, 76, 10, "mana")
  row.mp:SetPoint("LEFT", row.hp, "RIGHT", 6, 0)
  row.mp:SetPoint("RIGHT", row, "RIGHT", -2, 0)
  row.mpText = ns.Style.BarText(row.mp, 10)
end

local function BuildRow(parent, unit, index)
  local row = CreateFrame("Button", "ForeverXIUIParty" .. index, parent, "SecureUnitButtonTemplate")
  row.unit = unit
  row:SetAttribute("unit", unit)
  row:SetAttribute("*type1", "target")
  row:SetAttribute("*type2", "togglemenu")
  row:RegisterForClicks("AnyUp")

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  ns.Style.Fill(hl, "accent", 0.12)

  BuildParts(row)
  ns.UnitTooltip(row)

  for _, e in ipairs(UNIT_EVENTS) do pcall(row.RegisterUnitEvent, row, e, unit) end
  row:SetScript("OnEvent", UpdateRow)
  row:HookScript("OnShow", UpdateRow)
  return row
end

---------------------------------------------------------------------------
-- Pets: a small window right of the owner's row, same line.
---------------------------------------------------------------------------
local function UpdatePet(pet)
  local unit = pet.unit
  if not UnitExists(unit) then return end
  ns.Values.Name(pet.name, unit)
  ns.Values.Health(pet.hp, pet.hpText, unit, "percent", true)
  if ns.Values.IsDead(unit) then pet.hpText:SetText("Dead") end
end

local function BuildPetParts(pet)
  local back = CreateFrame("Frame", nil, pet)
  back:SetAllPoints()
  back:SetFrameLevel(math.max(0, pet:GetFrameLevel() - 1))
  ns.Style.Panel(back, nil, 0)
  pet.back = back
  pet.name = ns.Style.Text(pet, 10)
  pet.name:SetPoint("TOPLEFT", pet, "TOPLEFT", 5, -3)
  pet.name:SetPoint("TOPRIGHT", pet, "TOPRIGHT", -5, -3)
  pet.name:SetJustifyH("LEFT")
  pet.name:SetWordWrap(false)
  pet.name:SetTextColor(ns.Style.Color("title"))
  pet.hp = ns.Style.Bar(pet, PET_W - 10, 8, "hpHigh")
  pet.hp:SetPoint("BOTTOMLEFT", pet, "BOTTOMLEFT", 5, 5)
  pet.hpText = ns.Style.BarText(pet.hp, 9)
end

local function BuildPet(parent, row, index)
  local pet = CreateFrame("Button", "ForeverXIUIPartyPet" .. index, parent, "SecureUnitButtonTemplate")
  pet.unit = PETS[index]
  pet:SetAttribute("unit", pet.unit)
  pet:SetAttribute("*type1", "target")
  pet:SetAttribute("*type2", "togglemenu")
  pet:RegisterForClicks("AnyUp")
  pet:SetSize(PET_W, RowH())
  pet.owner = row
  local hl = pet:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  ns.Style.Fill(hl, "accent", 0.12)
  BuildPetParts(pet)
  ns.UnitTooltip(pet)
  for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS" }) do
    pcall(pet.RegisterUnitEvent, pet, e, pet.unit)
  end
  pcall(pet.RegisterUnitEvent, pet, "UNIT_PET", row.unit)
  pet:SetScript("OnEvent", UpdatePet)
  pet:HookScript("OnShow", UpdatePet)
  RegisterUnitWatch(pet)
  return pet
end

-- Pets go on the side the icons don't use: right by default. Secure: out
-- of combat only.
local function PlacePet(pet, owner)
  pet:ClearAllPoints()
  if ns.db.party.flip then
    pet:SetPoint("TOPRIGHT", owner, "TOPLEFT", -(PAD + PET_GAP), 0)
  else
    pet:SetPoint("TOPLEFT", owner, "TOPRIGHT", PAD + PET_GAP, 0)
  end
end

-- Room kept for the pet column, and whether anyone has a pet out. With no
-- pets the party window sits against the outer edge; when one comes out the
-- window slides over to make room, so the outer edge never moves.
local function PetSpace()
  return ns.db.party.pets and (PET_W + PET_GAP) or 0
end

local function AnyPet()
  if not ns.db.party.pets then return false end
  for i, unit in ipairs(UNITS) do
    if (i == 1 or UnitExists(unit)) and UnitExists(PETS[i]) then return true end
  end
  return false
end

-- x of the party window inside the root frame.
local function BaseX(withPets)
  local space = PetSpace()
  if ns.db.party.flip then return withPets and space or 0 end
  return withPets and 0 or space
end

-- The window beside the list that holds the buff/debuff icons: as tall as
-- the party window, on the side away from the pets.
local function PlaceAuraWindow(f)
  local a = f.auraWindow
  if not a then return end
  local o = ns.db.party
  local on = o.auraWindow and o.auras and not o.auraInside and (o.showBuffs or o.showDebuffs) and ns.Auras
  if not on then a:Hide() return end
  a:ClearAllPoints()
  a:SetWidth(ns.Auras.WindowWidth())
  local p = f.panelFrame
  if ns.Auras.Side() == "LEFT" then
    a:SetPoint("TOPRIGHT", p, "TOPLEFT", -AURA_WIN_GAP, 0)
    a:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", -AURA_WIN_GAP, 0)
  else
    a:SetPoint("TOPLEFT", p, "TOPRIGHT", AURA_WIN_GAP, 0)
    a:SetPoint("BOTTOMLEFT", p, "BOTTOMRIGHT", AURA_WIN_GAP, 0)
  end
  a:SetShown(p:IsShown())
end

local function Count()
  if not IsInGroup() then
    return ns.db.party.showSolo and 1 or 0
  end
  return 1 + (GetNumSubgroupMembers() or 0)
end

local function Title()
  if IsInRaid() then
    local idx = UnitInRaid("player")
    local group = idx and select(3, GetRaidRosterInfo(idx))
    return group and ("Group " .. group) or "Raid"
  end
  return IsInGroup() and "Party" or "Solo"
end

-- Panel size and title. Not secure, so this also runs in combat.
local function UpdatePanel(f)
  local n = Count()
  f.panelFrame:SetShown(n > 0)
  f.panelFrame:SetHeight(math.max(1, n) * RowH() + PAD * 2)
  f.title:SetText(Title())
  PlaceAuraWindow(f)
end

-- Row order and sizes. Secure: out of combat only.
local function LayoutRows(f)
  local w = Width()
  f:SetSize(w + PetSpace(), #UNITS * RowH() + PAD * 2 + TITLE_H)
  f.panelFrame:SetWidth(w)
  local x = BaseX(AnyPet())
  f.panelFrame:ClearAllPoints()
  f.panelFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 0)
  PlaceAuraWindow(f)
  local n = Count()
  local shown = 0
  for i, row in ipairs(rows) do
    row:SetSize(w - PAD * 2, RowH())
    if ns.Auras then ns.Auras.Apply(row) end
    row.hp:SetWidth((w - PAD * 2) * 0.62)
    row:ClearAllPoints()
    if i == 1 or UnitExists(row.unit) then
      shown = shown + 1
      -- You at the bottom, members stack upward; the bottom edge stays put.
      local y = PAD + (shown - 1) * RowH()
      row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x + PAD, y)
    else
      row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x + PAD, PAD)
    end
  end
end

local function Refresh(f)
  UpdatePanel(f)
  ns.AfterCombat("partyPets", function()
    for _, pet in pairs(pets) do
      pet:SetHeight(RowH())
      PlacePet(pet, pet.owner)
    end
  end)
  ns.AfterCombat("partyLayout", function() LayoutRows(f) end)
  for _, row in ipairs(rows) do
    if row:IsShown() then UpdateRow(row) end
    if ns.Auras then ns.Auras.Refresh(row) end
  end
  for _, pet in pairs(pets) do
    if pet:IsShown() then UpdatePet(pet) end
  end
end

function M:Init()
  if not ns.db.modules.party then return end
  local f = CreateFrame("Frame", "ForeverXIUIPartyList", UIParent)
  f:SetSize(W, #UNITS * RowH() + PAD * 2 + TITLE_H)

  -- The window behind the rows: a plain child frame, so its height can
  -- change in combat even though the rows are secure.
  local panel = CreateFrame("Frame", nil, f)
  panel:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  panel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  panel:SetSize(W, RowH() + PAD * 2)
  ns.Style.Panel(panel)
  f.panelFrame = panel
  f.title = ns.Style.Text(panel, 11)
  f.title:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -4, 1)
  f.title:SetTextColor(ns.Style.Color("title"))

  -- The icon window (plain frame, so it can follow the panel in combat).
  local aw = CreateFrame("Frame", nil, f)
  aw:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  ns.Style.Panel(aw)
  aw:Hide()
  f.auraWindow = aw

  for i, unit in ipairs(UNITS) do
    local row = BuildRow(f, unit, i)
    rows[i] = row
    if unit == "player" then
      if ns.db.party.showSolo then
        row:Show()
      else
        RegisterStateDriver(row, "visibility", "[group] show; hide")
      end
    else
      RegisterUnitWatch(row)
    end
    if ns.db.party.auras and ns.Auras then ns.Auras.Attach(row, unit, row, AURA_GAP) end
    if ns.db.party.pets then pets[i] = BuildPet(f, row, i) end
  end

  -- Range fade (XIUI's): members out of range go dim. Range can be secret
  -- in combat, so it goes straight to SetAlphaFromBoolean when it is.
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.3 then return end
    acc = 0
    local o = ns.db.party
    local dim = tonumber(o.rangeAlpha) or 0.45
    for i, row in ipairs(rows) do
      if row.unit ~= "player" and row:IsShown() and not M.previewing then
        local alpha = 1
        local secret = false
        local ok, inRange, checked = pcall(UnitInRange, row.unit)
        if o.rangeFade and ok then
          if issecretvalue and (issecretvalue(inRange) or issecretvalue(checked)) then
            secret = true
            if row.SetAlphaFromBoolean then
              pcall(row.SetAlphaFromBoolean, row, inRange, 1, dim)
              if pets[i] and pets[i].SetAlphaFromBoolean then pcall(pets[i].SetAlphaFromBoolean, pets[i], inRange, 1, dim) end
            end
          elseif checked and not inRange then
            alpha = dim
          end
        end
        if not secret then
          row:SetAlpha(alpha)
          if pets[i] then pets[i]:SetAlpha(alpha) end
        end
      end
    end
  end)

  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  pcall(f.RegisterEvent, f, "PARTY_LEADER_CHANGED")
  f:RegisterEvent("UNIT_PET")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", Refresh)
  Refresh(f)

  self.frame = f
  ns.AddRoot(f, "party")
  ns.Movers.Register("party", "Party list", f, { "BOTTOM", "BOTTOM", 0, 128 })
end

function M:Relayout()
  if self.frame and not self.previewing then
    Refresh(self.frame)
    if ns.Auras then
      for _, row in ipairs(rows) do ns.Auras.Apply(row) end
    end
  end
end

---------------------------------------------------------------------------
-- Preview: a pretend full party drawn over the real rows, for placing and
-- sizing the list. Plain frames only; the real rows are just faded.
---------------------------------------------------------------------------
local FAKE = {
  { "Duffnar", "SHAMAN", 100, "MANA", 47 },
  { "Yehva", "PALADIN", 88, "MANA", 12 },
  { "Jooppi", "WARLOCK", 61, "MANA", 80, "Voidwalker", 90 },
  { "Harlecin", "HUNTER", 38, "MANA", 55, "Broken Tooth", 72 },
  { "Mortium", "WARRIOR", 19, "RAGE", 30 },
}
local fakes, fakePets = {}, {}

function M:Preview(on)
  local f = self.frame
  if not f then return end
  self.previewing = on and true or nil
  local w = Width()
  for i, data in ipairs(FAKE) do
    local fake = fakes[i]
    if not fake then
      fake = CreateFrame("Frame", nil, f)
      fake:SetFrameLevel(f:GetFrameLevel() + 5)
      BuildParts(fake)
      fakes[i] = fake
    end
    if on then
      fake:SetSize(w - PAD * 2, RowH())
      fake.hp:SetWidth((w - PAD * 2) * 0.62)
      fake:ClearAllPoints()
      fake:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", BaseX(ns.db.party.pets) + PAD, PAD + (i - 1) * RowH())
      fake.name:SetText(data[1])
      fake.lead:SetShown(i == #FAKE)
      ns.Style.ClassIcon(fake.icon, data[2])
      local maxHp = 1100
      local hp = math.floor(maxHp * data[3] / 100)
      fake.hp:SetMinMaxValues(0, maxHp)
      fake.hp:SetValue(hp)
      fake.hpText:SetFormattedText("%d (%d%%)", hp, data[3])
      if ns.db.look and ns.db.look.hpBands then
        local key = data[3] <= 25 and "hpLow" or data[3] <= 50 and "hpMedLow" or data[3] <= 75 and "hpMedHigh" or "hpHigh"
        fake.hp:SetStatusBarColor(ns.Style.Color(key))
      else
        fake.hp:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpHigh")))
      end
      fake.mp:SetMinMaxValues(0, 100)
      fake.mp:SetValue(data[5])
      fake.mp:SetStatusBarColor(ns.Style.PowerRGB(data[4]))
      fake.mpText:SetText(data[4] == "RAGE" and data[5] or data[5] * 7)
      fake:Show()
    else
      fake:Hide()
    end
    if ns.Auras then ns.Auras.Preview(fake, on, fake, AURA_GAP, i) end

    -- Pretend pet on the owner's line.
    local fp = fakePets[i]
    if on and data[6] and ns.db.party.pets then
      if not fp then
        fp = CreateFrame("Frame", nil, f)
        fp:SetFrameLevel(f:GetFrameLevel() + 5)
        fp:SetSize(PET_W, RowH())
        BuildPetParts(fp)
        fakePets[i] = fp
      end
      PlacePet(fp, fake)
      fp.name:SetText(data[6])
      fp.hp:SetMinMaxValues(0, 100)
      fp.hp:SetValue(data[7])
      fp.hp:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpHigh")))
      fp.hpText:SetFormattedText("%d%%", data[7])
      fp:Show()
    elseif fp then
      fp:Hide()
    end
  end
  for _, row in ipairs(rows) do row:SetAlpha(on and 0 or 1) end
  for _, pet in pairs(pets) do pet:SetAlpha(on and 0 or 1) end
  if on then
    f.panelFrame:Show()
    f.panelFrame:ClearAllPoints()
    f.panelFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", BaseX(ns.db.party.pets), 0)
    f.panelFrame:SetWidth(w)
    f.panelFrame:SetHeight(#FAKE * RowH() + PAD * 2)
    f.title:SetText("Party (preview)")
    PlaceAuraWindow(f)
  else
    Refresh(f)
  end
end

---------------------------------------------------------------------------
-- Group tools: Blizzard's raid/party manager (role check, ready check,
-- countdown, world markers, Leave Party), which normally slides out
-- sideways from the top left. Here clicking the party list's "Party"
-- title opens it upward from there, in the XI look.
-- It holds secure buttons (world markers), so it is only moved, opened
-- or closed out of combat.
---------------------------------------------------------------------------
local G = ns.AddModule("GroupTools")

local function Mgr() return _G.CompactRaidFrameManager end

local function Toggles(m)
  local t = {}
  for _, k in ipairs({ "toggleButton", "toggleButtonForward", "toggleButtonBack" }) do
    local b = rawget(m, k)
    if type(b) == "table" then t[#t + 1] = b end
  end
  return t
end

local function IsOpen(m)
  local d = rawget(m, "displayFrame")
  return d and d:IsShown() or false
end

function G.Place()
  local m, tab = Mgr(), G.tab
  if not (m and tab) then return end
  if InCombatLockdown() then ns.AfterCombat("groupTools", G.Place) return end
  G.placing = true
  pcall(function()
    m:ClearAllPoints()
    m:SetPoint("BOTTOMRIGHT", tab, "TOPRIGHT", 0, 2)
  end)
  G.placing = nil
end

local function SetOpen(open)
  local m = Mgr()
  if not m then return end
  if InCombatLockdown() then ns.Print("group tools open after combat.") return end
  local fn = open and (m.Expand or _G.CompactRaidFrameManager_Expand)
    or (m.Collapse or _G.CompactRaidFrameManager_Collapse)
  if fn then pcall(fn, m) end
  local d = rawget(m, "displayFrame")
  if d and d:IsShown() ~= open then pcall(d.SetShown, d, open) end
  G.Place()
  G.Refresh()
end

function G.Refresh()
  local m, tab = Mgr(), G.tab
  if not (m and tab) then return end
  tab:SetShown(m:IsShown())
  local open = IsOpen(m)
  tab.text:SetText(open and "-" or "+")
  if G.bg then G.bg:SetShown(open) end
end

local function Skin(m)
  -- Blizzard's frame art (border, background) faded; buttons and text kept.
  for _, r in ipairs({ m:GetRegions() }) do
    if r.IsObjectType and r:IsObjectType("Texture") then ns.Style.FadeArt(r) end
  end
  local d = rawget(m, "displayFrame")
  if d then
    for _, r in ipairs({ d:GetRegions() }) do
      if r.IsObjectType and r:IsObjectType("Texture") then ns.Style.FadeArt(r) end
    end
    local bg = CreateFrame("Frame", nil, m)
    bg:SetPoint("TOPLEFT", d, "TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 4, -4)
    bg:SetFrameLevel(math.max(0, d:GetFrameLevel() - 1))
    ns.Style.Panel(bg, 0.92)
    G.bg = bg
  end
  -- Blizzard's slide-out arrow: our tab does that now.
  for _, b in ipairs(Toggles(m)) do
    b:SetAlpha(0)
    b:EnableMouse(false)
    hooksecurefunc(b, "SetAlpha", function(s) if s:GetAlpha() > 0 then s:SetAlpha(0) end end)
  end
  if m.EnableMouse then m:EnableMouse(false) end
end

function G:Init()
  if ns.db.party.groupTools == false or not ns.db.modules.party then return end
  local m, party = Mgr(), _G.ForeverXIUIPartyList
  if not (m and party) then return end

  -- The party list's own "Party" title is the button: a small +/- beside it.
  local title = party.title
  local tab = CreateFrame("Button", nil, party)
  tab:SetPoint("TOPLEFT", title, "TOPLEFT", -16, 3)
  tab:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 3, -3)
  tab:SetFrameLevel(party:GetFrameLevel() + 20)
  tab.text = ns.Style.Text(tab, 12)
  tab.text:SetPoint("RIGHT", title, "LEFT", -3, 0)
  tab.text:SetTextColor(ns.Style.Color("title"))
  local hl = tab:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  ns.Style.Fill(hl, "accent", 0.15)
  tab:SetScript("OnClick", function() SetOpen(not IsOpen(m)) end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Group tools")
    GameTooltip:AddLine("Click for role and ready checks, countdown, raid markers and Leave Party.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  G.tab = tab

  local ok, err = pcall(Skin, m)
  if not ok then ns.Print("group tools: %s", tostring(err)) end

  hooksecurefunc(m, "SetPoint", function() if not G.placing then G.Place() end end)
  m:HookScript("OnShow", G.Refresh)
  m:HookScript("OnHide", G.Refresh)
  local d = rawget(m, "displayFrame")
  if d then
    d:HookScript("OnShow", G.Refresh)
    d:HookScript("OnHide", G.Refresh)
  end
  -- Start closed.
  if not InCombatLockdown() and IsOpen(m) then SetOpen(false) end
  G.Place()
  G.Refresh()
end
