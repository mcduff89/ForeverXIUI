-- Tooltip position. The game puts its tooltip (mobs, players, items on the
-- ground) in the bottom-right corner, right over the party list. This gives
-- it a spot of its own you can drag with /fxiui move, or makes it follow the
-- mouse. Only where it sits changes; the tooltip itself is the game's.
local _, ns = ...

local M = ns.AddModule("Tooltip")

local anchor

function M:Init()
  local o = ns.db.tooltip
  if not o.move then return end
  anchor = CreateFrame("Frame", "ForeverXIUITooltipAnchor", UIParent)
  anchor:SetSize(200, 60)
  ns.Movers.Register("tooltip", "Tooltip (grows up from the bottom right)", anchor, { "BOTTOMRIGHT", "BOTTOMRIGHT", -10, 300 })
  self.frame = anchor

  if type(GameTooltip_SetDefaultAnchor) ~= "function" then return end
  hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip, parent)
    if not ns.db.tooltip.move then return end
    if ns.db.tooltip.cursor then
      tip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 20, 10)
    else
      tip:SetOwner(parent, "ANCHOR_NONE")
      tip:ClearAllPoints()
      tip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    end
  end)
end
