-- Restock: help with vendor items that only stock one or a few at a time
-- (the "limited supply" recipes). Every time a vendor is open it notes how
-- many of each limited item it has, and learns roughly how long each one
-- takes to come back. Items you want get a gold edge on the vendor, a sound
-- and a raid-warning line when they're in stock, and a Buy button.
--
-- Buying is always yours: one press of the buy key (Key Bindings > AddOns >
-- ForeverXIUI), one notch of the mouse wheel with "Wheel buy" on, or one
-- click of a Buy button buys one item. Nothing is bought on a timer, on its
-- own, or while the vendor window is shut.
--
-- The log and the wanted list are in their own saved variable
-- (ForeverXIUIRestockDB) so they stay out of profile exports.
local _, ns = ...

local M = ns.AddModule("Restock")

local BIND = "FXIUI_RESTOCK_BUY"
BINDING_HEADER_FOREVERXIUI = "ForeverXIUI"
_G["BINDING_NAME_" .. BIND] = "Buy a wanted limited-stock item (vendor open)"

local RECIPE_CLASS = 9
-- Recipe sub-class -> profession skill line.
local RECIPE_SKILL = { [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185,
  [6] = 171, [7] = 129, [8] = 333, [9] = 356, [10] = 755 }

local function o() return (ns.db and ns.db.restock) or {} end
local function L() return ForeverXIUIRestockDB end

local function Coins(c)
  c = math.floor(c or 0)
  if GetCoinTextureString then return GetCoinTextureString(c) end
  return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

local function Ago(sec)
  sec = math.max(0, math.floor(sec or 0))
  if sec < 90 then return sec .. "s" end
  if sec < 5400 then return math.floor(sec / 60 + 0.5) .. "m" end
  return ("%.1fh"):format(sec / 3600)
end
M.Ago = Ago

---------------------------------------------------------------------------
-- Reading the vendor
---------------------------------------------------------------------------
-- One merchant slot: name, icon, price, stack, numAvailable (-1 = unlimited),
-- purchasable, extended cost. Newer table API first, old one as a fallback.
local function SlotInfo(i)
  local api = C_MerchantFrame and C_MerchantFrame.GetItemInfo
  if api then
    local ok, t = pcall(api, i)
    if ok and type(t) == "table" then
      return t.name, t.texture, t.price, t.stackCount, t.numAvailable,
        t.isPurchasable ~= false, t.hasExtendedCost
    end
  end
  if GetMerchantItemInfo then
    local ok, name, tex, price, stack, avail, purchasable, _, ext = pcall(GetMerchantItemInfo, i)
    if ok then return name, tex, price, stack, avail, purchasable ~= false, ext end
  end
end

local function NumSlots()
  local ok, n = pcall(GetMerchantNumItems)
  return ok and tonumber(n) or 0
end

local function SlotItemID(i)
  local ok, link = pcall(GetMerchantItemLink, i)
  if not ok or type(link) ~= "string" then return end
  local id = tonumber(link:match("item:(%d+)"))
  return id, link
end

-- "npc:<id>" from the vendor's GUID when the game lets us read it,
-- otherwise its name. Zone and map position come along for the list.
local function VendorKey()
  local key, name
  local okN, n = pcall(UnitName, "npc")
  if okN and ns.Readable(n) then name = n end
  local okG, guid = pcall(UnitGUID, "npc")
  if okG and ns.Readable(guid) and type(guid) == "string" then
    local id = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if id then key = "npc:" .. id end
  end
  key = key or (name and ("name:" .. name))
  return key, name
end

local function Where()
  local zone = GetRealZoneText and GetRealZoneText() or nil
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local x, y
  if mapID and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if ok and pos and pos.GetXY then
      local okXY, px, py = pcall(pos.GetXY, pos)
      if okXY and ns.Readable(px) then x, y = px, py end
    end
  end
  return zone, mapID, x, y
end

-- Professions this character has, as skill line -> true.
local function MyProfessions()
  local out = {}
  if not GetProfessions then return out end
  local ok, a, b, c, d, e = pcall(GetProfessions)
  if not ok then return out end
  for _, idx in pairs({ a, b, c, d, e }) do
    if GetProfessionInfo then
      local ok, _, _, _, _, _, _, line = pcall(GetProfessionInfo, idx)
      if ok and line then out[line] = true end
    end
  end
  return out
end

-- Whether the slot's tooltip says "Already known".
local function Known(i)
  local tip = C_TooltipInfo and C_TooltipInfo.GetMerchantItem
  if not tip then return false end
  local ok, data = pcall(tip, i)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
  local known = ITEM_SPELL_KNOWN or "Already known"
  for _, line in ipairs(data.lines) do
    if line.leftText == known then return true end
  end
  return false
end

-- Why an item counts as wanted, or nil.
function M.WantReason(itemID, slot)
  local w = L().want[itemID]
  if w == false then return nil end         -- you unstarred it
  if w then return "starred" end
  if slot and slot.known then return nil end
  local classID, subID = slot and slot.classID, slot and slot.subID
  if classID ~= RECIPE_CLASS then return nil end
  if o().wantAll then return "limited recipe" end
  if o().wantMine and subID and RECIPE_SKILL[subID] and M.profs[RECIPE_SKILL[subID]] then
    return "your profession"
  end
end

---------------------------------------------------------------------------
-- The log: per vendor, per item, what was seen and when.
---------------------------------------------------------------------------
-- entry = { name, max, count, seen (time), out (time seen at 0 / bought last),
--   samples = { seconds from "out" to back in stock, newest last },
--   exact = true when the vendor was open the whole time for the last sample }
local current = {}      -- this visit: list of slots
local openSince         -- time the window opened (for exact samples)
local vendorKey

local function Learn(e, now)
  if not e.out then return end
  local s = now - e.out
  if s < 5 then return end
  e.samples = e.samples or {}
  table.insert(e.samples, math.floor(s))
  while #e.samples > 6 do table.remove(e.samples, 1) end
  e.exact = openSince and e.out >= openSince or false
  e.out = nil
end

-- Best guess at how long this item takes to come back: the shortest sample
-- (others buying it can only make a wait look longer than it is, never
-- shorter, unless it sold out before we looked).
function M.Estimate(e)
  if not (e and e.samples and #e.samples > 0) then return end
  local best = e.samples[1]
  for _, s in ipairs(e.samples) do if s < best then best = s end end
  return best, #e.samples
end

local alerted = {}      -- itemID -> true while it stays in stock this visit

local function Alert(slot)
  if o().alert == false then return end
  local msg = ("%s in stock (%d)"):format(slot.link or slot.name or "?", slot.count)
  if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, "|cffffd100Restock:|r " .. msg, ChatTypeInfo.RAID_WARNING)
  end
  if FlashClientIcon then pcall(FlashClientIcon) end
  local how = GetBindingKey and GetBindingKey(BIND)
  ns.Print("%s. %s", msg, how and ("Press " .. how .. " to buy one.")
    or (o().wheel and "Scroll the wheel to buy one." or "Click Buy, or set a key in Key Bindings > AddOns."))
end

function M.Scan()
  if not (MerchantFrame and MerchantFrame:IsShown()) or o().enabled == false then return end
  local now = time()
  local key, vname = VendorKey()
  vendorKey = key
  local log = L().vendors
  local v = key and log[key]
  if key and not v then
    v = { items = {} }
    log[key] = v
  end
  if v then
    v.name = vname or v.name
    v.zone, v.mapID, v.x, v.y = Where()
    v.seen = now
  end

  local slots = {}
  for i = 1, NumSlots() do
    local name, tex, price, stack, avail, purchasable, ext = SlotInfo(i)
    avail = tonumber(avail)
    if name and avail and avail >= 0 then
      local id, link = SlotItemID(i)
      local slot = { index = i, itemID = id, link = link, name = name, icon = tex, price = price or 0,
        stack = stack or 1, count = avail, purchasable = purchasable, ext = ext }
      if id and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, classID, subID = pcall(C_Item.GetItemInfoInstant, id)
        if ok then slot.classID, slot.subID = classID, subID end
      end
      slot.known = Known(i)
      if id and v then
        local e = v.items[id] or { }
        v.items[id] = e
        e.name, e.icon = name, tex
        e.max = math.max(e.max or 0, avail)
        if e.count and avail > e.count then Learn(e, now) end
        if avail == 0 and not e.out then e.out = now end
        e.count, e.seen = avail, now
        slot.entry = e
      end
      slot.want = id and M.WantReason(id, slot)
      slots[#slots + 1] = slot
    end
  end
  current = slots

  for _, s in ipairs(slots) do
    if s.want and s.count > 0 and s.purchasable then
      if not alerted[s.itemID] then
        alerted[s.itemID] = true
        Alert(s)
      end
    elseif s.itemID then
      alerted[s.itemID] = nil
    end
  end
  M.Draw()
  M.Highlight()
end

-- The first wanted item that can be bought right now.
local function NextBuy()
  local money = GetMoney and GetMoney() or 0
  for _, s in ipairs(current) do
    if s.want and s.count > 0 and s.purchasable and not s.ext and (s.price or 0) <= money then
      return s
    end
  end
end

local lastBuy = 0
-- Buys ONE item. Only ever called from a key press, a wheel notch or a
-- click (hardware events), never from a timer.
function M.BuyOne(slot)
  if not (MerchantFrame and MerchantFrame:IsShown()) then return end
  local now = GetTime()
  if now - lastBuy < 0.4 then return end   -- one buy per press, even on a fast wheel
  M.Scan()
  slot = slot or NextBuy()
  if not slot then
    if now - lastBuy > 3 then ns.Print("restock: nothing you want is in stock here.") end
    lastBuy = now
    return
  end
  -- The slot list can shift; buy by the index the item is at right now.
  local id = SlotItemID(slot.index)
  if id ~= slot.itemID then return end
  lastBuy = now
  local ok = pcall(BuyMerchantItem, slot.index, 1)
  if ok then
    local e = slot.entry
    if e then
      e.bought = (e.bought or 0) + 1
      if slot.count <= 1 then e.out = time() end
    end
    ns.Print("restock: buying %s for %s.", slot.link or slot.name, Coins(slot.price))
  end
end

-- Key binding (Bindings.xml).
function ForeverXIUI_RestockBuy() M.BuyOne() end

---------------------------------------------------------------------------
-- Wheel buy: while the vendor is open, both wheel directions are bound to
-- the buy command (override bindings, cleared when it closes). Over the
-- vendor window itself the wheel still turns its pages.
---------------------------------------------------------------------------
local owner = CreateFrame("Frame")
local wheelOn = false

function M.SetWheel(on)
  on = on and o().wheel and MerchantFrame and MerchantFrame:IsShown() and true or false
  if on == wheelOn then return end
  if InCombatLockdown() then
    ns.AfterCombat("restockWheel", function() M.SetWheel(on) end)
    return
  end
  if on then
    SetOverrideBinding(owner, true, "MOUSEWHEELUP", BIND)
    SetOverrideBinding(owner, true, "MOUSEWHEELDOWN", BIND)
  else
    ClearOverrideBindings(owner)
  end
  wheelOn = on
  M.Draw()
end

---------------------------------------------------------------------------
-- Gold edge on wanted items in the vendor window.
---------------------------------------------------------------------------
local edges = {}
function M.Highlight()
  local per = MERCHANT_ITEMS_PER_PAGE or 10
  local page = (MerchantFrame and MerchantFrame.page) or 1
  local wanted = {}
  if o().enabled ~= false and o().highlight ~= false and MerchantFrame and MerchantFrame.selectedTab ~= 2 then
    for _, s in ipairs(current) do if s.want then wanted[s.index] = s end end
  end
  for i = 1, per do
    local btn = _G["MerchantItem" .. i .. "ItemButton"]
    if btn then
      local edge = edges[i]
      local s = wanted[(page - 1) * per + i]
      if s and not edge then
        edge = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        edge:SetBlendMode("ADD")
        edge:SetPoint("CENTER")
        edge:SetSize(btn:GetWidth() * 1.8, btn:GetHeight() * 1.8)
        edges[i] = edge
      end
      if edge then
        edge:SetShown(s ~= nil)
        if s then
          if s.count > 0 then edge:SetVertexColor(1, 0.82, 0) else edge:SetVertexColor(0.5, 0.5, 0.5) end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Panel under the vendor: each limited item here, stock, when it came back
-- last time, a star (wanted) and a Buy button.
---------------------------------------------------------------------------
local ROWS, ROW_H, WIN_W = 8, 20, 336
local win

local function Due(e)
  local est = M.Estimate(e)
  if not e then return "" end
  if e.count and e.count > 0 then
    return est and ("back in ~" .. Ago(est)) or ""
  end
  if e.out and est then
    local left = e.out + est - time()
    if left > 0 then return "due in ~" .. Ago(left) end
    return "due now?"
  end
  if e.out then return "out " .. Ago(time() - e.out) end
  return ""
end
M.Due = Due

local function Build()
  local f = CreateFrame("Frame", "ForeverXIUIRestockWindow", UIParent)
  f:SetSize(WIN_W, 80)
  f:SetFrameStrata("HIGH")
  f:EnableMouse(true)
  ns.Style.Panel(f, 0.95)

  local title = ns.Style.Text(f, 13)
  title:SetPoint("TOPLEFT", 10, -9)
  title:SetText("Limited stock")
  title:SetTextColor(ns.Style.Color("title"))

  local wheel = CreateFrame("Button", nil, f)
  wheel:SetSize(110, 16)
  wheel:SetPoint("TOPRIGHT", -8, -9)
  wheel.text = ns.Style.Text(wheel, 10)
  wheel.text:SetPoint("RIGHT")
  wheel.text:SetJustifyH("RIGHT")
  wheel:SetScript("OnClick", function()
    o().wheel = not o().wheel
    M.SetWheel(o().wheel)
    M.Draw()
  end)
  wheel:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Wheel buy")
    GameTooltip:AddLine("On: while this vendor is open, one notch of the mouse wheel (away from the vendor window) buys one wanted item that's in stock. Off when the vendor closes.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  wheel:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.wheel = wheel

  f.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(WIN_W - 16, ROW_H)
    row:SetPoint("TOPLEFT", 8, -28 - (i - 1) * ROW_H)
    row:EnableMouse(true)

    local star = CreateFrame("Button", nil, row)
    star:SetSize(16, 16)
    star:SetPoint("LEFT", 0, 0)
    star.tex = star:CreateTexture(nil, "ARTWORK")
    star.tex:SetAllPoints()
    star.tex:SetTexture("Interface\\COMMON\\ReputationStar")
    star.tex:SetTexCoord(0, 0.5, 0, 0.5)
    star:SetScript("OnClick", function()
      local s = row.slot
      if not (s and s.itemID) then return end
      -- starred -> unstarred (false, never auto-wanted) -> back to automatic
      local w = L().want[s.itemID]
      if s.want then L().want[s.itemID] = false
      elseif w == false then L().want[s.itemID] = nil
      else L().want[s.itemID] = true end
      alerted[s.itemID] = nil
      M.Scan()
    end)
    star:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("Want this")
      GameTooltip:AddLine("Gold: wanted (alert, gold edge, the buy key and wheel buy it). Click to cycle: wanted, never, automatic.", 1, 1, 1, true)
      if row.slot and row.slot.want then GameTooltip:AddLine("Now: " .. row.slot.want, 0.6, 0.8, 1) end
      GameTooltip:Show()
    end)
    star:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.star = star

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", star, "RIGHT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local buy = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    buy:SetSize(40, 18)
    buy:SetPoint("RIGHT", 0, 0)
    buy:SetText("Buy")
    buy:SetScript("OnClick", function() if row.slot then M.BuyOne(row.slot) end end)
    row.buy = buy

    row.info = ns.Style.Text(row, 10)
    row.info:SetPoint("RIGHT", buy, "LEFT", -6, 0)
    row.info:SetJustifyH("RIGHT")
    row.info:SetTextColor(0.7, 0.75, 0.85)

    row.name = ns.Style.Text(row, 11)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.info, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
      if self.slot and self.slot.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.slot.link)
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = row
  end

  f.foot = ns.Style.Text(f, 10)
  f.foot:SetPoint("BOTTOMLEFT", 10, 9)
  f.foot:SetPoint("RIGHT", -10, 0)
  f.foot:SetJustifyH("LEFT")
  f.foot:SetTextColor(0.7, 0.75, 0.85)
  f:Hide()
  return f
end

function M.Draw()
  if not win then return end
  if not (MerchantFrame and MerchantFrame:IsShown()) or #current == 0 or o().enabled == false
    or o().panel == false then
    win:Hide()
    return
  end
  local shown = {}
  for _, s in ipairs(current) do if s.want then shown[#shown + 1] = s end end
  for _, s in ipairs(current) do if not s.want then shown[#shown + 1] = s end end
  for i = 1, ROWS do
    local row, s = win.rows[i], shown[i]
    row.slot = s
    if s then
      row.icon:SetTexture(s.icon)
      local c = s.link and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(s.itemID)
      c = c and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[c]
      row.name:SetText(s.name)
      if c then row.name:SetTextColor(c.r, c.g, c.b) else row.name:SetTextColor(1, 1, 1) end
      local stock = s.count > 0 and ("|cff40ff40%d left|r"):format(s.count) or "|cffff5050sold out|r"
      local due = Due(s.entry)
      row.info:SetText(due ~= "" and (stock .. "  " .. due) or stock)
      if s.want then row.star.tex:SetVertexColor(1, 0.82, 0); row.star.tex:SetDesaturated(false)
      else row.star.tex:SetVertexColor(0.6, 0.6, 0.6); row.star.tex:SetDesaturated(true) end
      row.buy:SetEnabled(s.count > 0 and s.purchasable and not s.ext)
      row:SetAlpha(s.known and 0.55 or 1)
      row:Show()
    else
      row:Hide()
    end
  end
  win.wheel.text:SetText(o().wheel and "|cff40ff40wheel buy on|r" or "|cff9aa6bfwheel buy off|r")
  local key = GetBindingKey and GetBindingKey(BIND)
  win.foot:SetText(key and ("Buy key: " .. key .. ". One press buys one.")
    or "Set a buy key in Key Bindings > AddOns > ForeverXIUI.")
  local n = math.min(#shown, ROWS)
  win:SetHeight(28 + n * ROW_H + 26)
  win:ClearAllPoints()
  local junk = ns.modules.Junk and ns.modules.Junk.win
  if junk and junk:IsShown() then
    win:SetPoint("TOPLEFT", junk, "BOTTOMLEFT", 0, -4)
  else
    win:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 6, 0)
  end
  win:Show()
end

---------------------------------------------------------------------------
-- /fxiui restock: every wanted item you've seen, soonest due first.
---------------------------------------------------------------------------
function M.Report()
  local rows = {}
  for _, v in pairs(L().vendors) do
    for id, e in pairs(v.items or {}) do
      local w = L().want[id]
      local recipe = false
      if C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
        recipe = ok and classID == RECIPE_CLASS
      end
      if w == true or (w ~= false and recipe) then
        local est = M.Estimate(e)
        local dueAt = (e.count or 0) > 0 and 0 or (e.out and est and e.out + est) or math.huge
        rows[#rows + 1] = { v = v, e = e, dueAt = dueAt, starred = w == true }
      end
    end
  end
  table.sort(rows, function(a, b) return a.dueAt < b.dueAt end)
  if #rows == 0 then
    ns.Print("restock: no limited recipes seen yet. Open a limited-supply vendor and they'll be logged.")
    return
  end
  ns.Print("restock: limited items you've seen (soonest first):")
  for i = 1, math.min(#rows, 15) do
    local r = rows[i]
    local where = r.v.zone or "?"
    if r.v.x then where = ("%s %.1f %.1f"):format(where, r.v.x * 100, r.v.y * 100) end
    local state = (r.e.count or 0) > 0 and ("%d left %s ago"):format(r.e.count, Ago(time() - (r.e.seen or 0)))
      or Due(r.e)
    local est, n = M.Estimate(r.e)
    print(("  %s%s - %s (%s) - %s%s"):format(r.starred and "* " or "", r.e.name or "?", r.v.name or "?", where,
      state, est and (" [restock ~%s, %d seen]"):format(Ago(est), n) or ""))
  end
end

function M.Forget()
  ForeverXIUIRestockDB.vendors = {}
  ns.Print("restock: vendor log cleared (your starred items are kept).")
end

---------------------------------------------------------------------------
function M:Init()
  ForeverXIUIRestockDB = type(ForeverXIUIRestockDB) == "table" and ForeverXIUIRestockDB or {}
  local db = ForeverXIUIRestockDB
  db.version = db.version or 1
  db.vendors = type(db.vendors) == "table" and db.vendors or {}
  db.want = type(db.want) == "table" and db.want or {}
  M.profs = MyProfessions()
  win = Build()
  M.win = win

  local ticker
  ns.On("MERCHANT_SHOW", function()
    if o().enabled == false then return end
    openSince = time()
    wipe(alerted)
    M.profs = MyProfessions()
    C_Timer.After(0.2, function()
      M.Scan()
      M.SetWheel(o().wheel)
    end)
    -- Belt and braces: re-read the list every 2 s while the vendor is open,
    -- in case Forever doesn't fire MERCHANT_UPDATE when stock comes back.
    -- Reading only; buying still needs a press.
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(2, function()
      if MerchantFrame and MerchantFrame:IsShown() then M.Scan() elseif ticker then ticker:Cancel(); ticker = nil end
    end)
  end)
  ns.On("MERCHANT_UPDATE", function() if o().enabled ~= false then M.Scan() end end)
  ns.On("MERCHANT_CLOSED", function()
    if ticker then ticker:Cancel(); ticker = nil end
    openSince, vendorKey = nil, nil
    current = {}
    M.SetWheel(false)
    if win then win:Hide() end
    M.Highlight()
  end)
  ns.On("SKILL_LINES_CHANGED", function() M.profs = MyProfessions() end)
  if MerchantFrame_UpdateMerchantInfo then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function() M.Highlight() end)
  end
end

function M.Describe()
  local n, items = 0, 0
  for _, v in pairs(L() and L().vendors or {}) do
    n = n + 1
    for _ in pairs(v.items or {}) do items = items + 1 end
  end
  local key = GetBindingKey and GetBindingKey(BIND)
  return ("%s, %d vendors / %d limited items logged, buy key %s, wheel buy %s"):format(
    o().enabled == false and "off" or "on", n, items, key or "not set", o().wheel and "on" or "off")
end
