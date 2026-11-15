-- Player bar (XIUI style): HP and power side by side, numbers inside the
-- bars as "1108 (100%)". Plus your own cast bar. Neither is secure, so they
-- can update and show/hide in combat freely.
local _, ns = ...

local M = ns.AddModule("PlayerBar")

local BAR_W, BAR_W_COMPACT, BAR_H, GAP = 150, 110, 12, 8

local function Update(f)
  ns.Values.Health(f.hp, f.hpText, "player", "both", true)
  ns.Values.Power(f.mp, f.mpText, "player", "both")
end

local function Layout(f)
  if InCombatLockdown() then return end
  local w = ns.db.compact and BAR_W_COMPACT or BAR_W
  f:SetSize(w * 2 + GAP, BAR_H + 4)
  f.hp:SetSize(w, BAR_H)
  f.mp:SetSize(w, BAR_H)
  f.hp:ClearAllPoints()
  f.hp:SetPoint("LEFT", f, "LEFT", 2, 0)
  f.mp:ClearAllPoints()
  f.mp:SetPoint("LEFT", f.hp, "RIGHT", GAP, 0)
end

function M:Init()
  if ns.db.modules.player then
    -- A secure button like Blizzard's player frame: left-click targets
    -- yourself, right-click opens your own menu.
    local f = CreateFrame("Button", "ForeverXIUIPlayerBar", UIParent, "SecureUnitButtonTemplate")
    f.unit = "player"
    f:SetAttribute("unit", "player")
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    ns.UnitTooltip(f)
    f.hp = ns.Style.Bar(f, BAR_W, BAR_H, "hpHigh")
    f.mp = ns.Style.Bar(f, BAR_W, BAR_H, "mana")
    f.hpText = ns.Style.BarText(f.hp, 11)
    f.mpText = ns.Style.BarText(f.mp, 11)
    Layout(f)

    for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
      "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
      pcall(f.RegisterUnitEvent, f, e, "player")
    end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", Update)
    Update(f)

    self.frame = f
    ns.AddRoot(f, "player")
    ns.Movers.Register("player", "Player bar", f, { "BOTTOM", "BOTTOM", 0, 110 })
  end

  if ns.db.modules.playerCast then
    local c = ns.CastBar.Create("ForeverXIUIPlayerCast", "player", 260, 14, true)
    self.cast = c
    ns.AddRoot(c, "playerCast")
    ns.Movers.Register("playerCast", "Your cast bar", c, { "BOTTOM", "BOTTOM", 0, 312 })
  end
end

function M:Relayout()
  if self.frame then Layout(self.frame) end
end

function M:Preview(on)
  if self.cast then ns.CastBar.Preview(self.cast, on) end
end
