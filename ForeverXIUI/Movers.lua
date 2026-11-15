-- Drag-to-place for every ForeverXIUI frame. /fxiui move toggles it, and it
-- also turns on while Blizzard's Edit Mode is open so everything can be laid
-- out in one pass. Out of combat only: some roots hold secure buttons.
local _, ns = ...

local Movers = {}
ns.Movers = Movers

local list, byKey = {}, {}
local shown = false

-- default = { point, relativePoint, x, y } against UIParent.
function Movers.Register(key, label, frame, default)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  local m = { key = key, label = label, frame = frame, default = default }

  local o = CreateFrame("Frame", nil, UIParent)
  o:SetFrameStrata("DIALOG")
  o:SetAllPoints(frame)
  o:EnableMouse(true)
  o:Hide()
  local bg = o:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  ns.Style.Fill(bg, "accentSel", 0.35)
  local edge = o:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  ns.Style.Fill(edge, "title", 0.8)
  edge:SetDrawLayer("BACKGROUND", -1)
  local text = ns.Style.Text(o, 11)
  text:SetPoint("CENTER")
  text:SetText(label)

  o:SetScript("OnMouseDown", function(_, button)
    if InCombatLockdown() then return end
    if button == "RightButton" then
      ns.db.positions[key] = nil
      if m.default then Movers.Apply(m)
      else ns.Print("%s reset. Type /reload to put it back in its normal spot.", label) end
      return
    end
    m.downX, m.downY = GetCursorPosition()
    m.dragging = true
    frame:StartMoving()
  end)
  o:SetScript("OnMouseUp", function(_, button)
    if not m.dragging then return end
    m.dragging = nil
    if InCombatLockdown() then return end
    frame:StopMovingOrSizing()
    -- A click without a drag opens this frame's options instead.
    local x, y = GetCursorPosition()
    if button == "LeftButton" and m.downX and math.abs(x - m.downX) + math.abs(y - m.downY) < 4 then
      Movers.Apply(m)
      if ns.OpenConfig then ns.OpenConfig(key) end
      return
    end
    Movers.Save(m)
  end)
  o:SetScript("OnEnter", function()
    GameTooltip:SetOwner(o, "ANCHOR_TOP")
    GameTooltip:AddLine(label)
    GameTooltip:AddLine("Drag to move. Click for its options. Right-click to reset.", 1, 1, 1)
    GameTooltip:Show()
  end)
  o:SetScript("OnLeave", function() GameTooltip:Hide() end)

  m.overlay = o
  list[#list + 1] = m
  byKey[key] = m
  Movers.Apply(m)
  return m
end

-- Save as an offset from the screen centre, in UIParent units, so the frame's
-- own scale can change without it drifting.
function Movers.Save(m)
  local f = m.frame
  local cx, cy = f:GetCenter()
  if not cx then return end
  local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local ux, uy = UIParent:GetCenter()
  ns.db.positions[m.key] = { "CENTER", "CENTER", cx * s - ux, cy * s - uy }
  Movers.Apply(m)
end

-- A mover with no default (the minimap) stays where the game put it until
-- it has been dragged once.
function Movers.Apply(m)
  ns.AfterCombat("move:" .. m.key, function()
    local f = m.frame
    local pos = ns.db.positions[m.key] or m.default
    if not pos then return end
    -- Offsets are in the frame's own units, which include its parents'
    -- scale (the minimap sits inside Blizzard's scaled cluster).
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not s or s == 0 then s = 1 end
    m.applying = true
    f:ClearAllPoints()
    f:SetPoint(pos[1], UIParent, pos[2], (pos[3] or 0) / s, (pos[4] or 0) / s)
    m.applying = nil
  end)
end

function Movers.Saved(key) return ns.db.positions[key] ~= nil end

function Movers.ApplyAll()
  for _, m in ipairs(list) do Movers.Apply(m) end
end

function Movers.ResetAll()
  wipe(ns.db.positions)
  Movers.ApplyAll()
end

function Movers.Show(on)
  if on and InCombatLockdown() then
    ns.Print("can't move frames in combat.")
    return
  end
  local was = shown
  shown = on and true or false
  for _, m in ipairs(list) do m.overlay:SetShown(shown) end
  -- Pretend target and casts so the empty frames can be placed.
  if was ~= shown and not ns.previewOn then ns.ForEachModule("Preview", shown) end
end

function Movers.Toggle()
  Movers.Show(not shown)
  if shown then ns.Print("drag frames to move, click one for its options, right-click one to reset it. /fxiui move again to lock.") end
end

ns.On("PLAYER_REGEN_DISABLED", function()
  if shown then
    Movers.Show(false)
  end
end)

-- Follow Edit Mode. EventRegistry callbacks exist on the Mainline engine;
-- guarded in case Forever renames them.
ns.On("PLAYER_LOGIN", function()
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", function() Movers.Show(true) end, Movers)
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", function() Movers.Show(false) end, Movers)
  end
end)
