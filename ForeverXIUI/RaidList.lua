-- Raid list (XI "alliance" style): compact navy boxes, one per raid group,
-- on the right edge. Each row is name, HP% and a thin HP bar. Your own group
-- is left out by default because the party list already shows it.
--
-- 40 secure unit buttons (raid1..raid40), placed into their group's box out
-- of combat. A roster change during combat is placed when combat ends.
local _, ns = ...

local M = ns.AddModule("RaidList")

local ROW_W, ROW_H, LABEL_H, PAD = 120, 18, 14, 2
local GROUP_W = ROW_W + PAD * 2
local GROUP_H = LABEL_H + ROW_H * 5 + PAD * 2
local GAP, COLS = 6, 2

local rows, boxes = {}, {}

local function UpdateRow(row)
  local unit = row.unit
  if not UnitExists(unit) then return end
  ns.Values.Name(row.name, unit)
  if ns.Values.IsOffline(unit) then
    row.name:SetTextColor(0.55, 0.55, 0.55)
    row.hp:SetMinMaxValues(0, 1)
    row.hp:SetValue(0)
    row.pct:SetText("Off")
    return
  end
  row.name:SetTextColor(1, 1, 1)
  ns.Values.Health(row.hp, row.pct, unit, "percent", true)
  if ns.Values.IsDead(unit) then row.pct:SetText("Dead") end
end

-- The look of a row, shared by the real rows and the preview rows.
local function BuildParts(row)
  row:SetSize(ROW_W, ROW_H)
  row.name = ns.Style.Text(row, 10)
  row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.pct = ns.Style.Text(row, 10)
  row.pct:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -1)
  row.pct:SetTextColor(ns.Style.Color("hpText"))
  row.name:SetPoint("RIGHT", row.pct, "LEFT", -4, 0)

  row.hp = ns.Style.Bar(row, ROW_W - 4, 4, "hpHigh")
  row.hp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 1)
end

local function BuildRow(parent, i)
  local unit = "raid" .. i
  local row = CreateFrame("Button", "ForeverXIUIRaid" .. i, parent, "SecureUnitButtonTemplate")
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

  for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" }) do
    pcall(row.RegisterUnitEvent, row, e, unit)
  end
  row:SetScript("OnEvent", UpdateRow)
  row:HookScript("OnShow", UpdateRow)
  row:Hide() -- shown by its unit watch once it has a place in a group box
  return row
end

local function BuildBox(parent, g)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(GROUP_W, GROUP_H)
  box:SetFrameLevel(math.max(0, parent:GetFrameLevel()))
  ns.Style.Panel(box)
  box.label = ns.Style.Text(box, 10)
  box.label:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -2)
  box.label:SetTextColor(ns.Style.Color("title"))
  box.label:SetText("G" .. g)
  box:Hide()
  return box
end

local function MyGroup()
  local idx = UnitInRaid("player")
  if not idx then return nil end
  return select(3, GetRaidRosterInfo(idx))
end

-- Which raid index sits in which group, and which groups to draw.
local function Roster()
  local byGroup = {}
  if not IsInRaid() then return byGroup end
  for i = 1, 40 do
    local name, _, subgroup = GetRaidRosterInfo(i)
    if name and subgroup then
      byGroup[subgroup] = byGroup[subgroup] or {}
      table.insert(byGroup[subgroup], i)
    end
  end
  return byGroup
end

local function Layout(f)
  local byGroup = Roster()
  local mine = IsInRaid() and MyGroup() or nil
  local used = {}
  local slot = 0
  for g = 1, 8 do
    local box = boxes[g]
    local members = byGroup[g]
    local skip = ns.db.raid.hideOwnGroup and g == mine
    if members and not skip then
      slot = slot + 1
      local col = (slot - 1) % COLS
      local line = math.floor((slot - 1) / COLS)
      box:ClearAllPoints()
      box:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", col * (GROUP_W + GAP), line * (GROUP_H + GAP))
      box:Show()
      for k, i in ipairs(members) do
        local row = rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -(LABEL_H + (k - 1) * ROW_H))
        RegisterUnitWatch(row)
        used[i] = true
      end
    else
      box:Hide()
    end
  end
  for i = 1, 40 do
    if not used[i] then
      UnregisterUnitWatch(rows[i])
      rows[i]:Hide()
    end
  end
end

local function Refresh(f)
  ns.AfterCombat("raidLayout", function() Layout(f) end)
end

function M:Init()
  if not ns.db.modules.raid then return end
  local f = CreateFrame("Frame", "ForeverXIUIRaidList", UIParent, "SecureHandlerStateTemplate")
  f:SetSize(COLS * GROUP_W + (COLS - 1) * GAP, 4 * GROUP_H + 3 * GAP)
  for g = 1, 8 do boxes[g] = BuildBox(f, g) end
  for i = 1, 40 do rows[i] = BuildRow(f, i) end
  RegisterStateDriver(f, "visibility", "[group:raid] show; hide")

  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", Refresh)
  Refresh(f)

  self.frame = f
  ns.AddRoot(f, "raid")
  ns.Movers.Register("raid", "Raid list", f, { "RIGHT", "RIGHT", -20, 0 })
end

function M:Relayout()
  if self.frame and not self.previewing then Refresh(self.frame) end
end

---------------------------------------------------------------------------
-- Preview: a pretend 40-player raid (your group 1 is in the party list, so
-- groups 2-8 here). Plain frames over the real rows. Out of combat only,
-- because the raid list is shown and hidden by a secure state driver.
---------------------------------------------------------------------------
local NAMES = { "Aldric", "Bree", "Cosmo", "Dunk", "Elm", "Fay", "Gorm", "Hale", "Ivo", "Jax",
  "Kip", "Lune", "Moss", "Nyx", "Oro", "Pell", "Quill", "Rook", "Sage", "Tarn", "Ula", "Vex",
  "Wren", "Yarr", "Zed", "Ash", "Bix", "Cael", "Dorn", "Esk", "Fenn", "Grit", "Hob", "Ink", "Jolt" }
local PCTS = { 100, 92, 74, 45, 18, 100, 66, 88, 31, 97 }
local fakes = {}

function M:Preview(on)
  local f = self.frame
  if not f then return end
  if InCombatLockdown() then return end
  self.previewing = on and true or nil
  if on then
    UnregisterStateDriver(f, "visibility")
    f:Show()
  else
    RegisterStateDriver(f, "visibility", "[group:raid] show; hide")
  end
  for i = 1, 40 do rows[i]:SetAlpha(on and 0 or 1) end
  local n = 0
  for g = 2, 8 do
    local box = boxes[g]
    local slot = g - 1
    if on then
      local col = (slot - 1) % COLS
      local line = math.floor((slot - 1) / COLS)
      box:ClearAllPoints()
      box:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", col * (GROUP_W + GAP), line * (GROUP_H + GAP))
      box:Show()
    end
    for k = 1, 5 do
      n = n + 1
      local fake = fakes[n]
      if not fake then
        fake = CreateFrame("Frame", nil, box)
        fake:SetFrameLevel(box:GetFrameLevel() + 5)
        BuildParts(fake)
        fakes[n] = fake
      end
      if on then
        fake:ClearAllPoints()
        fake:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -(LABEL_H + (k - 1) * ROW_H))
        local pct = PCTS[(n % #PCTS) + 1]
        fake.name:SetText(NAMES[n] or "Member")
        fake.pct:SetFormattedText("%d%%", pct)
        fake.hp:SetMinMaxValues(0, 100)
        fake.hp:SetValue(pct)
        if ns.db.look and ns.db.look.hpBands then
          local key = pct <= 25 and "hpLow" or pct <= 50 and "hpMedLow" or pct <= 75 and "hpMedHigh" or "hpHigh"
          fake.hp:SetStatusBarColor(ns.Style.Color(key))
        else
          fake.hp:SetStatusBarColor(ns.Style.Color(ns.Style.HealthKey("hpHigh")))
        end
        fake:Show()
      else
        fake:Hide()
      end
    end
  end
  if not on then
    boxes[1]:Hide()
    for g = 2, 8 do boxes[g]:Hide() end
    Refresh(f)
  end
end
