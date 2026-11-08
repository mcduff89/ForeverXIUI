-- Treasure pool (XIUI's): every item up for a group roll in one XI window,
-- each with its icon, name in its quality colour, a timer bar, and Need /
-- Greed / Pass buttons (Need only when you can need it). You click the
-- buttons yourself; nothing here rolls for you.
--
-- Blizzard's own roll popups are turned off while this is on (UIParent
-- stops listening for new rolls), so you don't get both.
local _, ns = ...

local M = ns.AddModule("LootRolls")

local W, ROW_H, PAD, TITLE_H = 300, 30, 4, 16
local rows, used = {}, {}
local win

local function QualityColor(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function Layout()
  local list = {}
  for _, r in ipairs(rows) do if r.rollID then list[#list + 1] = r end end
  table.sort(list, function(a, b) return a.rollID < b.rollID end)
  for i, r in ipairs(list) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -(TITLE_H + PAD + (i - 1) * (ROW_H + 2)))
  end
  win:SetHeight(TITLE_H + PAD * 2 + math.max(1, #list) * (ROW_H + 2) - 2)
  win:SetShown(#list > 0 or win.previewing)
end

local function Button(row, label, rollType, x)
  local b = CreateFrame("Button", nil, row)
  b:SetSize(38, 16)
  b:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", x, 2)
  ns.Style.Panel(b, 0.95)
  b.text = ns.Style.Text(b, 10)
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(0.47, 0.77, 0.93, 0.25)
  b:SetScript("OnClick", function()
    if row.rollID and not row.fake then RollOnLoot(row.rollID, rollType) end
  end)
  b.SetUsable = function(self, on)
    self:SetEnabled(on)
    self.text:SetTextColor(on and 1 or 0.4, on and 1 or 0.4, on and 1 or 0.4)
  end
  return b
end

local function NewRow()
  local r = CreateFrame("Frame", nil, win)
  r:SetSize(W - PAD * 2, ROW_H)
  r.iconBtn = CreateFrame("Button", nil, r)
  r.iconBtn:SetSize(ROW_H - 2, ROW_H - 2)
  r.iconBtn:SetPoint("LEFT", 0, 0)
  local edge = r.iconBtn:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints()
  edge:SetColorTexture(0, 0, 0, 1)
  r.edge = edge
  r.icon = r.iconBtn:CreateTexture(nil, "ARTWORK")
  r.icon:SetPoint("TOPLEFT", 1, -1)
  r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.count = ns.Style.Text(r.iconBtn, 10)
  r.count:SetPoint("BOTTOMRIGHT", 0, 1)
  r.iconBtn:SetScript("OnEnter", function(self)
    if not r.rollID then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    pcall(GameTooltip.SetLootRollItem, GameTooltip, r.rollID)
    GameTooltip:Show()
  end)
  r.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.iconBtn:SetScript("OnClick", function()
    if r.rollID and IsModifiedClick and IsModifiedClick() and GetLootRollItemLink then
      local link = GetLootRollItemLink(r.rollID)
      if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end
  end)

  r.name = ns.Style.Text(r, 11)
  r.name:SetPoint("TOPLEFT", r.iconBtn, "TOPRIGHT", 5, -1)
  r.name:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)

  r.bar = ns.Style.Bar(r, 100, 4)
  r.bar:SetPoint("BOTTOMLEFT", r.iconBtn, "BOTTOMRIGHT", 5, 3)
  r.bar:SetPoint("RIGHT", r, "RIGHT", -128, 0)
  r.bar:SetStatusBarColor(0.47, 0.77, 0.93)
  r.bar:SetMinMaxValues(0, 1)

  r.need = Button(r, "Need", 1, -84)
  r.greed = Button(r, "Greed", 2, -42)
  r.pass = Button(r, "Pass", 0, 0)

  r:SetScript("OnUpdate", function(self)
    if not self.rollID or not self.total then return end
    local ok, left = pcall(GetLootRollTimeLeft, self.rollID)
    if ok and type(left) == "number" then self.bar:SetValue(math.max(0, left / self.total)) end
  end)
  rows[#rows + 1] = r
  return r
end

local function FreeRow()
  for _, r in ipairs(rows) do if not r.rollID then return r end end
  return NewRow()
end

local function Start(rollID, rollTime)
  local ok, texture, name, count, quality, _, canNeed, canGreed = pcall(GetLootRollItemInfo, rollID)
  if not ok or not name then return end
  local r = FreeRow()
  r.rollID, r.total = rollID, (rollTime or 60000)
  r.icon:SetTexture(texture)
  r.edge:SetColorTexture(QualityColor(quality))
  r.count:SetText((count or 1) > 1 and count or "")
  r.name:SetText(name)
  r.name:SetTextColor(QualityColor(quality))
  r.need:SetUsable(canNeed and true or false)
  r.greed:SetUsable(canGreed ~= false)
  r.pass:SetUsable(true)
  r.bar:SetValue(1)
  r:Show()
  Layout()
end

local function Stop(rollID)
  for _, r in ipairs(rows) do
    if r.rollID == rollID then
      r.rollID = nil
      r:Hide()
    end
  end
  Layout()
end

function M:Init()
  if not ns.db.modules.loot then return end
  win = CreateFrame("Frame", "ForeverXIUITreasurePool", UIParent)
  win:SetSize(W, TITLE_H + ROW_H + PAD * 2)
  win:SetFrameStrata("HIGH")
  ns.Style.Panel(win, 0.94)
  local title = ns.Style.Text(win, 11)
  title:SetPoint("TOPLEFT", 6, -3)
  title:SetText("Treasure Pool")
  title:SetTextColor(ns.Style.Color("title"))
  win:Hide()

  -- Blizzard's popups off, ours on.
  if UIParent.UnregisterEvent then pcall(UIParent.UnregisterEvent, UIParent, "START_LOOT_ROLL") end
  win:RegisterEvent("START_LOOT_ROLL")
  win:RegisterEvent("CANCEL_LOOT_ROLL")
  win:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
  win:SetScript("OnEvent", function(_, event, rollID, rollTime)
    if event == "START_LOOT_ROLL" then
      Start(rollID, rollTime)
    elseif event == "CANCEL_LOOT_ROLL" then
      Stop(rollID)
    else
      for _, r in ipairs(rows) do r.rollID = nil r:Hide() end
      Layout()
    end
  end)
  -- Rolls already open (after a /reload).
  if GetActiveLootRollIDs then
    local ok, ids = pcall(GetActiveLootRollIDs)
    if ok and type(ids) == "table" then for _, id in ipairs(ids) do Start(id) end end
  end

  self.frame = win
  ns.AddRoot(win, "loot")
  ns.Movers.Register("loot", "Treasure pool", win, { "TOP", "TOP", 0, -180 })
end

local FAKE = {
  { "Interface\\Icons\\INV_Sword_04", "Cruel Barb", 3, true },
  { "Interface\\Icons\\INV_Misc_Bag_10", "Mageweave Bag", 2, false },
}

function M:Preview(on)
  if not win then return end
  win.previewing = on and true or nil
  for _, r in ipairs(rows) do if r.fake then r.fake, r.rollID = nil, nil r:Hide() end end
  if on then
    for i, f in ipairs(FAKE) do
      local r = FreeRow()
      r.fake, r.rollID, r.total = true, -10 + i, nil
      r.icon:SetTexture(f[1])
      r.edge:SetColorTexture(QualityColor(f[3]))
      r.count:SetText("")
      r.name:SetText(f[2])
      r.name:SetTextColor(QualityColor(f[3]))
      r.need:SetUsable(f[4])
      r.greed:SetUsable(true)
      r.pass:SetUsable(true)
      r.bar:SetValue(0.35 + 0.3 * i)
      r:Show()
    end
  end
  Layout()
end
