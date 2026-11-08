-- Junk by price: a junk rule for Baganator that uses your Auctionator scan.
-- An item counts as junk when selling it on the auction house (after the
-- 5% cut) wouldn't beat the vendor by more than the margin you set. Grey
-- items are always junk. Baganator then shows its junk coin on them and
-- puts them in its Junk section. At a vendor a window lists them with a tick
-- box each; untick what you want to keep (remembered), then click Sell.
--
-- Never junk: items that can't be sold to a vendor, items with no
-- Auctionator price (bound gear, things you haven't scanned), epics and up,
-- and (by default) weapons and armour that aren't grey.
local _, ns = ...

local M = ns.AddModule("Junk")

local CALLER = "ForeverXIUI"
local AH_CUT = 0.95

local function o() return ns.db.junk end

local function SellPrice(itemLink, itemID)
  local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not get then return end
  local ok, _, _, quality, _, _, _, _, _, _, _, sell, classID = pcall(get, itemLink or itemID)
  if not ok then return end
  return sell, quality, classID
end

local function AuctionPrice(itemLink, itemID)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not api then return end
  if itemLink and api.GetAuctionPriceByItemLink then
    local ok, p = pcall(api.GetAuctionPriceByItemLink, CALLER, itemLink)
    if ok and type(p) == "number" then return p end
  end
  if itemID and api.GetAuctionPriceByItemID then
    local ok, p = pcall(api.GetAuctionPriceByItemID, CALLER, itemID)
    if ok and type(p) == "number" then return p end
  end
end

local GEAR = { [2] = true, [4] = true }   -- weapon, armour item classes

-- true: junk. Exposed for /fxiui check and testing.
-- Margin in copper (older saves kept it in silver).
function M.Margin()
  local c = tonumber(o().marginCopper)
  if c then return c end
  return (tonumber(o().margin) or 0) * 100
end

local function Coins(c)
  c = math.floor(c or 0)
  if GetCoinTextureString then return GetCoinTextureString(c) end
  return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end
M.Coins = Coins

function M.MarginText()
  if o().usePercent then return ("%d%%"):format(tonumber(o().percent) or 0) end
  return Coins(M.Margin())
end

-- ignoreKeep: the vendor window lists kept items too (unticked).
function M.IsJunk(itemLink, itemID, ignoreKeep)
  if o().enabled == false then return false end
  if not ignoreKeep and itemID and o().keep and o().keep[itemID] then return false end
  local sell, quality, classID = SellPrice(itemLink, itemID)
  if type(sell) ~= "number" or sell <= 0 then return false end
  if quality == 0 then return true end
  if type(quality) == "number" and quality >= 4 then return false end
  if o().keepGear ~= false and GEAR[classID] then return false end
  local ah = AuctionPrice(itemLink, itemID)
  if not ah then return false end
  local margin = M.Margin()
  if o().usePercent then margin = sell * (tonumber(o().percent) or 0) / 100 end
  return ah * AH_CUT <= sell + margin
end

function M.Refresh()
  local api = Baganator and Baganator.API
  if api and api.RequestItemButtonsRefresh then pcall(api.RequestItemButtonsRefresh) end
end

---------------------------------------------------------------------------
-- Margin editor: three boxes for gold, silver and copper.
---------------------------------------------------------------------------
local editor
local function Box(parent, w, label)
  local b = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  b:SetSize(w, 20)
  b:SetAutoFocus(false)
  b:SetNumeric(true)
  b:SetMaxLetters(label == "g" and 4 or 2)
  local t = ns.Style.Text(parent, 12)
  t:SetPoint("LEFT", b, "RIGHT", 3, 0)
  t:SetText(label)
  t:SetTextColor(label == "g" and 1 or 0.8, label == "g" and 0.82 or 0.8, label == "c" and 0.5 or (label == "g" and 0 or 0.85))
  return b
end

function M.EditMargin(anchor)
  if not editor then
    local f = CreateFrame("Frame", "ForeverXIUIJunkMargin", UIParent)
    f:SetSize(250, 96)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    ns.Style.Panel(f, 0.97)
    local title = ns.Style.Text(f, 13)
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Junk margin")
    title:SetTextColor(ns.Style.Color("title"))
    local help = ns.Style.Text(f, 10)
    help:SetPoint("TOPLEFT", 10, -26)
    help:SetPoint("RIGHT", -10, 0)
    help:SetJustifyH("LEFT")
    help:SetText("Junk when the AH beats the vendor by this or less.")
    help:SetTextColor(0.7, 0.75, 0.85)
    f.g = Box(f, 44, "g")
    f.g:SetPoint("TOPLEFT", 16, -44)
    f.s = Box(f, 28, "s")
    f.s:SetPoint("LEFT", f.g, "RIGHT", 22, 0)
    f.c = Box(f, 28, "c")
    f.c:SetPoint("LEFT", f.s, "RIGHT", 22, 0)
    local function Save()
      local g = tonumber(f.g:GetText()) or 0
      local sv = math.min(99, tonumber(f.s:GetText()) or 0)
      local c = math.min(99, tonumber(f.c:GetText()) or 0)
      o().marginCopper = g * 10000 + sv * 100 + c
      f:Hide()
      M.Refresh()
      if M.win and M.win:IsShown() then M.Open() end
      ns.Print("junk margin set to %s.", Coins(o().marginCopper))
    end
    for _, b in ipairs({ f.g, f.s, f.c }) do
      b:SetScript("OnEnterPressed", Save)
      b:SetScript("OnEscapePressed", function() f:Hide() end)
      b:SetScript("OnTabPressed", function(self)
        local nxt = self == f.g and f.s or self == f.s and f.c or f.g
        nxt:SetFocus()
        nxt:HighlightText()
      end)
    end
    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(56, 20)
    ok:SetText("Save")
    ok:SetPoint("BOTTOMRIGHT", -70, 8)
    ok:SetScript("OnClick", Save)
    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetSize(56, 20)
    cancel:SetText("Cancel")
    cancel:SetPoint("BOTTOMRIGHT", -8, 8)
    cancel:SetScript("OnClick", function() f:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverXIUIJunkMargin") end
    editor = f
  end
  local m = M.Margin()
  editor.g:SetText(tostring(math.floor(m / 10000)))
  editor.s:SetText(tostring(math.floor(m / 100) % 100))
  editor.c:SetText(tostring(m % 100))
  editor:ClearAllPoints()
  if anchor then
    editor:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  else
    editor:SetPoint("CENTER")
  end
  editor:Show()
  editor.g:SetFocus()
  editor.g:HighlightText()
end

---------------------------------------------------------------------------
-- The vendor window: everything the rule marks, with a tick box each.
-- Unticking an item keeps it (remembered, and Baganator stops calling it
-- junk); ticking it again lets it be junk. "Sell" sells the ticked ones.
---------------------------------------------------------------------------
local ROWS, ROW_H, WIN_W = 12, 20, 300
local win, list, offset = nil, {}, 0
local selling, earned, count = false, 0, 0

local function Container()
  local C = C_Container
  return (C and C.GetContainerNumSlots) or GetContainerNumSlots, C and C.GetContainerItemInfo,
    (C and C.UseContainerItem) or UseContainerItem
end

-- One entry per item kind: { itemID, link, icon, quality, count, value, slots = {{bag, slot}} }
local function Collect()
  local numSlots, getInfo = Container()
  local byID, out = {}, {}
  if not (numSlots and getInfo) then return out end
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local okN, n = pcall(numSlots, bag)
    for slot = 1, (okN and type(n) == "number" and n or 0) do
      local okI, info = pcall(getInfo, bag, slot)
      if okI and type(info) == "table" and info.itemID and not info.hasNoValue then
        local okJ, junk = pcall(M.IsJunk, info.hyperlink, info.itemID, true)
        if okJ and junk then
          local e = byID[info.itemID]
          if not e then
            local sell, quality = SellPrice(info.hyperlink, info.itemID)
            e = { itemID = info.itemID, link = info.hyperlink, icon = info.iconFileID,
              quality = info.quality or quality, unit = sell or 0, count = 0, slots = {} }
            byID[info.itemID] = e
            out[#out + 1] = e
          end
          e.count = e.count + (info.stackCount or 1)
          e.slots[#e.slots + 1] = { bag, slot }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.unit * a.count > b.unit * b.count end)
  return out
end

local function Kept(e) return o().keep and o().keep[e.itemID] end

local function Draw()
  if not win then return end
  local total, n = 0, 0
  for _, e in ipairs(list) do
    if not Kept(e) then total, n = total + e.unit * e.count, n + 1 end
  end
  offset = math.max(0, math.min(offset, #list - ROWS))
  for i = 1, ROWS do
    local row, e = win.rows[i], list[i + offset]
    row.entry = e
    if e then
      row.check:SetChecked(not Kept(e))
      row.icon:SetTexture(e.icon)
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality or 1]
      local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.itemID)) or e.link or "?"
      row.name:SetText(e.count > 1 and (name .. " x" .. e.count) or name)
      if c then row.name:SetTextColor(c.r, c.g, c.b) else row.name:SetTextColor(1, 1, 1) end
      row.value:SetText(Coins(e.unit * e.count))
      row:SetAlpha(Kept(e) and 0.5 or 1)
      row:Show()
    else
      row:Hide()
    end
  end
  win.marginBtn.text:SetText("|cff9aa6bfmargin|r " .. M.MarginText())
  win.total:SetText(n > 0 and ("%d to sell: %s"):format(n, Coins(total)) or "Nothing ticked")
  win.sell:SetEnabled(n > 0 and not selling)
  local shown = math.min(#list, ROWS)
  win:SetHeight(34 + math.max(1, shown) * ROW_H + 34)
end

local function SellNext()
  if not selling then return end
  local _, getInfo, use = Container()
  local sold = 0
  for _, e in ipairs(list) do
    if not Kept(e) then
      for k = #e.slots, 1, -1 do
        local bag, slot = e.slots[k][1], e.slots[k][2]
        local okI, info = pcall(getInfo, bag, slot)
        if okI and type(info) == "table" and info.itemID == e.itemID and not info.isLocked then
          if pcall(use, bag, slot) then
            earned = earned + e.unit * (info.stackCount or 1)
            count = count + 1
            sold = sold + 1
          end
        end
        table.remove(e.slots, k)
        if sold >= 8 then
          C_Timer.After(0.3, SellNext)
          return
        end
      end
    end
  end
  selling = false
  if count > 0 then
    ns.Print("sold %d junk item%s for %s.", count, count == 1 and "" or "s", Coins(earned))
  end
  C_Timer.After(0.5, function() if win and win:IsShown() then M.Open() end end)
end

local function Build()
  local f = CreateFrame("Frame", "ForeverXIUIJunkWindow", UIParent)
  f:SetSize(WIN_W, 200)
  f:SetFrameStrata("HIGH")
  ns.Style.Panel(f, 0.95)
  f:EnableMouse(true)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, d) offset = offset - d; Draw() end)

  local title = ns.Style.Text(f, 13)
  title:SetPoint("TOPLEFT", 10, -9)
  title:SetText("Sell junk")
  title:SetTextColor(ns.Style.Color("title"))
  local mb = CreateFrame("Button", nil, f)
  mb:SetSize(130, 16)
  mb:SetPoint("TOPRIGHT", -8, -9)
  mb.text = ns.Style.Text(mb, 10)
  mb.text:SetPoint("RIGHT")
  mb.text:SetJustifyH("RIGHT")
  mb:SetScript("OnClick", function(self)
    if o().usePercent then
      ns.Print("junk margin is a percentage; change it in /fxiui > Bags & junk.")
    else
      M.EditMargin(self)
    end
  end)
  mb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Junk margin")
    GameTooltip:AddLine("Click to change. Untick a row to keep that item.", 1, 1, 1)
    GameTooltip:Show()
  end)
  mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.marginBtn = mb

  f.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, f)
    row:SetSize(WIN_W - 16, ROW_H)
    row:SetPoint("TOPLEFT", 8, -30 - (i - 1) * ROW_H)
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("LEFT", 0, 0)
    check:SetScript("OnClick", function(self)
      local e = row.entry
      if not e then return end
      o().keep = o().keep or {}
      o().keep[e.itemID] = (not self:GetChecked()) or nil
      M.Refresh()
      Draw()
    end)
    row.check = check
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", check, "RIGHT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.value = ns.Style.Text(row, 11)
    row.value:SetPoint("RIGHT", -2, 0)
    row.value:SetJustifyH("RIGHT")
    row.name = ns.Style.Text(row, 11)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
      if self.entry and self.entry.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.entry.link)
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self) self.check:Click() end)
    f.rows[i] = row
  end

  f.total = ns.Style.Text(f, 11)
  f.total:SetPoint("BOTTOMLEFT", 10, 12)

  local function Btn(label, w)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(w, 20)
    b:SetText(label)
    return b
  end
  f.close = Btn("Close", 56)
  f.close:SetPoint("BOTTOMRIGHT", -8, 8)
  f.close:SetScript("OnClick", function() f:Hide() end)
  f.sell = Btn("Sell", 56)
  f.sell:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  f.sell:SetScript("OnClick", function()
    if selling then return end
    selling, earned, count = true, 0, 0
    Draw()
    SellNext()
  end)

  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:SetScript("OnEvent", function()
    if f:IsShown() and not selling then list = Collect(); Draw() end
  end)
  f:Hide()
  return f
end

function M.Open()
  if o().enabled == false or o().autoSell == false then return end
  list = Collect()
  if #list == 0 then
    if win then win:Hide() end
    return
  end
  win = win or Build()
  M.win = win
  win:ClearAllPoints()
  if MerchantFrame and MerchantFrame:IsShown() then
    win:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 6, 0)
  else
    win:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
  end
  offset = 0
  win:Show()
  Draw()
end

local function Closed()
  selling = false
  if win then win:Hide() end
end

function M:Init()
  ns.On("MERCHANT_SHOW", function() C_Timer.After(0.1, M.Open) end)
  ns.On("MERCHANT_CLOSED", Closed)
  local api = Baganator and Baganator.API
  if not (api and api.RegisterJunkPlugin) then return end
  if not (Auctionator and Auctionator.API and Auctionator.API.v1) then return end
  local ok = pcall(api.RegisterJunkPlugin, "ForeverXIUI: Auctionator price", "foreverxiui_price",
    function(_, _, itemID, itemLink)
      local okJ, junk = pcall(M.IsJunk, itemLink, itemID)
      return okJ and junk or false
    end)
  self.active = ok
end

function M:Relayout()
  if self.active then M.Refresh() end
end

function M.Describe()
  if not M.active then return "off (needs Baganator and Auctionator)" end
  local live = Baganator.API.IsJunkPluginActive and Baganator.API.IsJunkPluginActive("foreverxiui_price")
  return ("on, margin %s, %s"):format(M.MarginText(),
    live and "chosen in Baganator" or "not chosen in Baganator yet (Customise > Junk)")
end
