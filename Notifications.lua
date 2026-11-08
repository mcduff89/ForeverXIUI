-- Notifications (XIUI's): small XI toasts stacked in a corner for what you
-- loot, gold you pick up, XP, reputation and party invites. Each fades out
-- after a few seconds; several of the same kind close together are merged
-- ("+340 XP" instead of five lines). Only shows things; it never accepts or
-- loots anything for you.
local _, ns = ...

local M = ns.AddModule("Notifications")

local W, H, GAP, MAX = 230, 26, 3, 6
local SHOW, FADE = 4, 0.6

local toasts, pool = {}, {}
local anchor

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"
local function Coins(c)
  c = math.floor(c)
  local g, s, cp = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. GOLD end
  if s > 0 then out[#out + 1] = s .. SILVER end
  if cp > 0 or #out == 0 then out[#out + 1] = cp .. COPPER end
  return table.concat(out, " ")
end

local function Arrange()
  local up = ns.db.notify.growUp
  for i, t in ipairs(toasts) do
    t:ClearAllPoints()
    local y = (i - 1) * (H + GAP)
    if up then t:SetPoint("BOTTOM", anchor, "BOTTOM", 0, y) else t:SetPoint("TOP", anchor, "TOP", 0, -y) end
  end
end

local function Remove(t)
  for i, x in ipairs(toasts) do
    if x == t then table.remove(toasts, i) break end
  end
  t:Hide()
  t.key = nil
  pool[#pool + 1] = t
  Arrange()
end

local function NewToast()
  local t = table.remove(pool)
  if t then return t end
  t = CreateFrame("Frame", nil, anchor)
  t:SetSize(W, H)
  ns.Style.Panel(t, 0.9)
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetSize(H - 8, H - 8)
  t.icon:SetPoint("LEFT", 4, 0)
  t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t.text = ns.Style.Text(t, 11)
  t.text:SetPoint("LEFT", t.icon, "RIGHT", 6, 0)
  t.text:SetPoint("RIGHT", t, "RIGHT", -6, 0)
  t.text:SetJustifyH("LEFT")
  t.text:SetWordWrap(false)
  t:SetScript("OnUpdate", function(self, dt)
    self.age = self.age + dt
    if self.age > SHOW + FADE then Remove(self) return end
    self:SetAlpha(self.age > SHOW and (1 - (self.age - SHOW) / FADE) or 1)
  end)
  return t
end

-- key: toasts with the same key within SHOW seconds are merged through merge(old) -> text.
local function Toast(icon, text, key, merge)
  if not anchor then return end
  if key then
    for _, t in ipairs(toasts) do
      if t.key == key and t.age < SHOW then
        t.value = merge(t.value)
        t.text:SetText(t.render(t.value))
        t.age = 0
        return
      end
    end
  end
  while #toasts >= MAX do Remove(toasts[1]) end
  local t = NewToast()
  t.age, t.key = 0, key
  t.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  t.text:SetText(text)
  t:SetAlpha(1)
  t:Show()
  table.insert(toasts, t)
  Arrange()
  return t
end

-- A merged counter toast: value starts at `amount`, render(value) -> text.
local function Counter(icon, key, amount, render)
  local t = Toast(icon, render(amount), key, function(old) return old + amount end)
  if t then t.value, t.render = amount, render end
end

---------------------------------------------------------------------------
-- What gets a toast
---------------------------------------------------------------------------
local lastMoney, lastXP, lastMax

local function OnLoot(text, ...)
  if not ns.Readable(text) or type(text) ~= "string" then return end
  -- Only your own loot ("You receive loot: ..." / "You create: ...").
  local me = UnitName("player")
  local who = ...
  if ns.Readable(who) and type(who) == "string" and who ~= "" and who:match("^[^-]+") ~= me then return end
  if not text:find("^You ") then return end   -- "You receive loot/item:", "You create:"
  local link = text:match("|c%x+|Hitem:.-|h.-|h|r") or text:match("|Hitem:.-|h.-|h")
  if not link then return end
  local count = tonumber(text:match("x(%d+)%.?$")) or 1
  local id = tonumber(link:match("item:(%d+)"))
  local icon = id and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)))
  Counter(icon, "item:" .. (id or link), count, function(n)
    return n > 1 and (link .. " |cffffffffx" .. n .. "|r") or link
  end)
end

local function OnMoney()
  local now = GetMoney() or 0
  if lastMoney and now > lastMoney and ns.db.notify.gold then
    Counter("Interface\\Icons\\INV_Misc_Coin_01", "money", now - lastMoney, function(n) return "+" .. Coins(n) end)
  end
  lastMoney = now
end

local function OnXP()
  local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
  if lastXP and ns.db.notify.xp then
    local gained = (max ~= lastMax and xp < lastXP) and (lastMax - lastXP + xp) or (xp - lastXP)
    if gained > 0 then
      Counter("Interface\\Icons\\Spell_Holy_SurgeOfLight", "xp", gained, function(n)
        return ("|cffb98ef2+%s XP|r"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(n) or n)
      end)
    end
  end
  lastXP, lastMax = xp, max
end

local function OnFaction(text)
  if not ns.Readable(text) or type(text) ~= "string" then return end
  local faction, amount = text:match("^Reputation with (.-) increased by (%d+)")
  if faction then
    Counter("Interface\\Icons\\Achievement_Reputation_01", "rep:" .. faction, tonumber(amount), function(n)
      return ("|cff7fd27f+%d|r %s"):format(n, faction)
    end)
  elseif text ~= "" then
    Toast("Interface\\Icons\\Achievement_Reputation_01", text)
  end
end

function M:Init()
  if not ns.db.modules.notify then return end
  anchor = CreateFrame("Frame", "ForeverXIUINotifications", UIParent)
  anchor:SetSize(W, H)
  lastMoney = GetMoney()
  lastXP, lastMax = UnitXP("player"), UnitXPMax("player")

  local f = CreateFrame("Frame")
  for _, e in ipairs({ "CHAT_MSG_LOOT", "PLAYER_MONEY", "PLAYER_XP_UPDATE", "CHAT_MSG_COMBAT_FACTION_CHANGE",
    "PARTY_INVITE_REQUEST" }) do
    pcall(f.RegisterEvent, f, e)
  end
  f:SetScript("OnEvent", function(_, event, ...)
    local o = ns.db.notify
    if event == "CHAT_MSG_LOOT" then
      if o.loot then pcall(OnLoot, ...) end
    elseif event == "PLAYER_MONEY" then
      OnMoney()
    elseif event == "PLAYER_XP_UPDATE" then
      OnXP()
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
      if o.rep then pcall(OnFaction, ...) end
    elseif event == "PARTY_INVITE_REQUEST" then
      local who = ...
      if o.invites then
        Toast("Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
          ("|cffb7c9ffInvite from|r %s"):format(ns.Readable(who) and tostring(who) or "someone"))
      end
    end
  end)

  self.frame = anchor
  ns.AddRoot(anchor, "notify")
  ns.Movers.Register("notify", "Notifications", anchor, { "RIGHT", "RIGHT", -260, 60 })
end

function M:Preview(on)
  if not anchor then return end
  if on then
    Toast("Interface\\Icons\\INV_Misc_Herb_07", "|cffffffff[Mageroyal]|r |cffffffffx3|r")
    Toast("Interface\\Icons\\INV_Misc_Coin_01", "+" .. Coins(1245))
    Toast("Interface\\Icons\\Spell_Holy_SurgeOfLight", "|cffb98ef2+340 XP|r")
    Toast("Interface\\Icons\\Achievement_Reputation_01", "|cff7fd27f+25|r Ironforge")
  end
end
