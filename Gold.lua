-- Gold (XIUI's gil tracker): a slim XI strip on top of the minimap (under
-- the menu bar) with your gold on the left and this session's change on
-- the right. Hover for gold per hour and every character's gold on this
-- account; ctrl-click resets the session. Without the XI minimap it has a
-- mover of its own. ("Gold under the EXP bar" puts it back on the EXP bar.)
--
-- The per-character list is kept in ForeverXIUIDB.gold, by realm and name.
local _, ns = ...

local M = ns.AddModule("Gold")

local G, S = 10000, 100
local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"

local session = { start = nil, money = 0, at = 0 }

local function Coins(c, short)
  c = math.floor(math.abs(c or 0))
  local g, s, cp = math.floor(c / G), math.floor((c % G) / S), c % S
  local out = {}
  if g > 0 then out[#out + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g) .. GOLD end
  if s > 0 or (g > 0 and not short) then out[#out + 1] = s .. SILVER end
  if not short or g == 0 then out[#out + 1] = cp .. COPPER end
  return table.concat(out, " ")
end

local function Signed(c)
  if c == 0 then return "|cffaaaaaa0|r" end
  return (c > 0 and "|cff7fd27f+" or "|cffec6c6c-") .. Coins(c, true) .. "|r"
end

local function Me()
  local realm = GetRealmName and GetRealmName() or "?"
  local name = UnitName("player") or "?"
  return realm, name
end

local function Save(money)
  local realm, name = Me()
  ns.db.gold = ns.db.gold or {}
  ns.db.gold[realm] = ns.db.gold[realm] or {}
  local _, class = UnitClass("player")
  ns.db.gold[realm][name] = { money = money, class = class, seen = time() }
end

-- The gold line on the EXP bar: "31g 23s 45c  +4g 52s  +2g 21s/h".
function M.Line()
  local money = GetMoney() or 0
  local change = money - session.money
  local out = Coins(money, true)
  if change ~= 0 then
    out = out .. "  " .. Signed(change)
    local hours = (GetTime() - session.at) / 3600
    if ns.db.goldTracker.showRate and hours > 0.05 then
      out = out .. "  " .. Signed(change / hours) .. "|cffaaaaaa/h|r"
    end
  end
  local bags = M.BagText()
  if bags ~= "" then out = out .. "   " .. bags end
  return out
end

function M.PreviewLine()
  return Coins(312345, true) .. "  " .. Signed(4520) .. "  " .. Signed(2210) .. "|cffaaaaaa/h|r"
end

function M.Reset()
  session.money, session.at = GetMoney() or 0, GetTime()
end

function M.Enabled() return ns.db.modules.gold and true or false end

-- Added to the bottom of the EXP bar's tooltip.
function M.AddTooltip()
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Gold", 0.72, 0.79, 1)
  local money = GetMoney() or 0
  local change = money - session.money
  GameTooltip:AddDoubleLine("This session", Signed(change), 1, 1, 1)
  local hours = (GetTime() - session.at) / 3600
  if hours > 0.05 then GameTooltip:AddDoubleLine("Per hour", Signed(change / hours), 1, 1, 1) end
  local total = 0
  for realm, chars in pairs(ns.db.gold or {}) do
    GameTooltip:AddLine(realm, 0.55, 0.62, 0.8)
    local list = {}
    for name, d in pairs(chars) do list[#list + 1] = { name, d } end
    table.sort(list, function(x, y) return (x[2].money or 0) > (y[2].money or 0) end)
    for _, e in ipairs(list) do
      local c = RAID_CLASS_COLORS and e[2].class and RAID_CLASS_COLORS[e[2].class]
      GameTooltip:AddDoubleLine("  " .. e[1], Coins(e[2].money, true), c and c.r or 1, c and c.g or 1, c and c.b or 1, 1, 1, 1)
      total = total + (e[2].money or 0)
    end
  end
  GameTooltip:AddDoubleLine("All characters", Coins(total, true), 1, 0.82, 0, 1, 1, 1)
end

-- Bag slots used / total, coloured as you run out of room (white, orange
-- at 5 or fewer free, red at 2 or fewer). Plain bags only.
function M.BagCount()
  local bs = ns.modules.BagSkin
  if ns.db.goldTracker.bags == false or not (bs and bs.FreeSlots) then return end
  local free, total = bs.FreeSlots()
  if not free or not total or total == 0 then return end
  local r, g, b = 0.85, 0.88, 0.95
  if free <= 2 then r, g, b = 1, 0.25, 0.25 elseif free <= 5 then r, g, b = 1, 0.6, 0.15 end
  return total - free, total, r, g, b
end

-- For the EXP bar gold line.
function M.BagText()
  local used, total, r, g, b = M.BagCount()
  if not used then return "" end
  return ("|TInterface\\Icons\\INV_Misc_Bag_08:12:12:0:0:64:64:5:59:5:59|t |cff%02x%02x%02x%d/%d|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), used, total)
end

local function Draw(f)
  if f.previewing then return end
  local money = GetMoney() or 0
  local change = money - session.money
  f.money:SetText(Coins(money, true))
  f.change:SetText(change ~= 0 and Signed(change) or "")
  local used, total, r, gg, b = M.BagCount()
  if used then
    f.bags:SetText(("%d/%d"):format(used, total))
    f.bags:SetTextColor(r, gg, b)
    f.bagIcon:Show()
  else
    f.bags:SetText("")
    f.bagIcon:Hide()
  end
end

local function BuildStrip()
  local f = CreateFrame("Frame", "ForeverXIUIGold", UIParent)
  f:SetHeight(18)
  ns.Style.Panel(f, 0.92)
  f.money = ns.Style.Text(f, 11)
  f.money:SetPoint("LEFT", f, "LEFT", 6, 0)
  f.bags = ns.Style.Text(f, 11)
  f.bags:SetPoint("RIGHT", f, "RIGHT", -6, 0)
  f.bagIcon = f:CreateTexture(nil, "OVERLAY")
  f.bagIcon:SetSize(13, 13)
  f.bagIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
  f.bagIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.bagIcon:SetPoint("RIGHT", f.bags, "LEFT", -4, 0)
  -- Session +/- only while the mouse is on the strip.
  f.change = ns.Style.Text(f, 10)
  f.change:SetPoint("LEFT", f.money, "RIGHT", 10, 0)
  f.change:Hide()
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self)
    self.change:Show()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    M.AddTooltip()
    GameTooltip:AddLine("Ctrl-click: reset the session.", 0.55, 0.55, 0.55)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function(self)
    self.change:Hide()
    GameTooltip:Hide()
  end)
  f:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and IsControlKeyDown() then
      M.Reset()
      ns.Print("gold session reset.")
      Draw(self)
    end
  end)
  f:RegisterEvent("PLAYER_MONEY")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(f.RegisterEvent, f, "BAG_UPDATE_DELAYED")
  f:SetScript("OnEvent", Draw)

  -- On top of the XI minimap window, as wide as it; else free to move.
  local map = ns.modules.MapSkin and ns.modules.MapSkin.back
  if map then
    f:SetParent(map)
    f:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 2)
    f:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 2)
  else
    f:SetWidth(170)
    ns.AddRoot(f, "gold")
    ns.Movers.Register("gold", "Gold", f, { "TOPLEFT", "TOPLEFT", 8, -40 })
  end
  Draw(f)
  M.frame = f
end

function M:Init()
  ns.db.goldTracker = ns.db.goldTracker or {}
  session.money, session.at = GetMoney() or 0, GetTime()
  Save(session.money)
  ns.On("PLAYER_MONEY", function() Save(GetMoney() or 0) end)
  -- After the minimap skin has built its window (it loads after this file).
  if ns.db.modules.gold and not ns.db.goldTracker.onXP then
    C_Timer.After(0, function()
      local ok, err = pcall(BuildStrip)
      if not ok then ns.Print("gold strip failed (%s).", tostring(err)) end
    end)
  end
end

function M:Relayout()
  if self.frame and not self.frame.previewing then pcall(Draw, self.frame) end
end

function M:Preview(on)
  local f = self.frame
  if not f then return end
  f.previewing = on and true or nil
  if on then
    f.money:SetText(Coins(312345, true))
    f.change:SetText(Signed(4520))
    f.bags:SetText("36/44")
  else
    Draw(f)
  end
end
