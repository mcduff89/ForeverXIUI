-- Totem bar (shaman): your four totem slots in an XI window, fire, earth,
-- water and air, each with its icon, a timer swipe and the time left under
-- it. Right-click a totem to take it down early (the game's own secure
-- "destroytotem" action, so it works in combat). Empty slots show dimmed.
--
-- Blizzard's own totem frame (by the player frame) is faded when this is on.
local _, ns = ...

local M = ns.AddModule("TotemBar")

local SIZE, GAP, PAD = 28, 4, 4
local SLOTS = 4
-- Blizzard's slot order: 1 fire, 2 earth, 3 water, 4 air. Shown in that order.
local ELEMENT = { "Fire", "Earth", "Water", "Air" }
local EMPTY_ICON = {
  "Interface\\Icons\\Spell_Fire_SearingTotem",
  "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
  "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
  "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
}

local function Short(sec)
  if sec >= 60 then return ("%dm"):format(math.ceil(sec / 60)) end
  return ("%d"):format(math.ceil(sec))
end

local function UpdateSlot(b)
  local ok, have, name, start, duration, icon = pcall(GetTotemInfo, b.slot)
  if not ok then have = false end
  local present = ns.Readable(have) and have and true or false
  b.present = present
  if present then
    pcall(b.icon.SetTexture, b.icon, icon)
    b.icon:SetDesaturated(false)
    b.icon:SetAlpha(1)
    pcall(b.cd.SetCooldown, b.cd, start, duration)
    b.cd:Show()
    -- Our own text only when the times can be read; the swipe works either way.
    if ns.Readable(start) and ns.Readable(duration) then
      b.endsAt = start + duration
    else
      b.endsAt = nil
      b.time:SetText("")
    end
    b.totemName = name
  else
    b.icon:SetTexture(EMPTY_ICON[b.slot])
    b.icon:SetDesaturated(true)
    b.icon:SetAlpha(0.35)
    b.cd:Hide()
    b.endsAt = nil
    b.time:SetText("")
    b.totemName = nil
  end
end

local function BuildSlot(parent, slot)
  local b = CreateFrame("Button", "ForeverXIUITotem" .. slot, parent, "SecureActionButtonTemplate")
  b.slot = slot
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("RightButtonUp", "RightButtonDown")
  b:SetAttribute("useOnKeyDown", false)
  b:SetAttribute("type2", "destroytotem")
  b:SetAttribute("totem-slot", slot)
  local edge = b:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints()
  edge:SetColorTexture(0, 0, 0, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  if b.cd.SetReverse then b.cd:SetReverse(true) end
  if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
  if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
  b.time = ns.Style.Text(b, 10)
  b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(0.47, 0.77, 0.93, 0.2)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.present and pcall(GameTooltip.SetTotem, GameTooltip, self.slot) then
      GameTooltip:AddLine("Right-click to take it down.", 0.6, 0.6, 0.6)
    else
      GameTooltip:AddLine(ELEMENT[self.slot] .. " totem", 0.72, 0.79, 1)
      GameTooltip:AddLine("None down.", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function UpdateAll(f)
  if f.previewing then return end
  for _, b in ipairs(f.slots) do UpdateSlot(b) end
end

function M:Init()
  if not ns.db.modules.totems then return end
  local _, class = UnitClass("player")
  if class ~= "SHAMAN" and not ns.db.totems.anyClass then return end

  local f = CreateFrame("Frame", "ForeverXIUITotemBar", UIParent)
  f:SetSize(SLOTS * SIZE + (SLOTS - 1) * GAP + PAD * 2, SIZE + PAD * 2 + 12)
  local back = CreateFrame("Frame", nil, f)
  back:SetPoint("TOPLEFT")
  back:SetPoint("TOPRIGHT")
  back:SetHeight(SIZE + PAD * 2)
  back:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  ns.Style.Panel(back, 0.9)
  f.back = back
  f.slots = {}
  for i = 1, SLOTS do
    local b = BuildSlot(f, i)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * (SIZE + GAP), -PAD)
    f.slots[i] = b
  end

  f:RegisterEvent("PLAYER_TOTEM_UPDATE")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", UpdateAll)
  -- The time left under each icon, a few times a second.
  local acc = 0
  f:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.2 or self.previewing then return end
    acc = 0
    local now = GetTime()
    for _, b in ipairs(self.slots) do
      if b.endsAt then
        local left = b.endsAt - now
        b.time:SetText(left > 0 and Short(left) or "")
      end
    end
  end)
  UpdateAll(f)

  -- Blizzard's totem frame, faded (an Edit Mode-managed piece of the player frame).
  if ns.db.hideBlizzard.totems and type(TotemFrame) == "table" then
    TotemFrame:SetAlpha(0)
    hooksecurefunc(TotemFrame, "SetAlpha", function(self, a) if a and a > 0 then self:SetAlpha(0) end end)
    if TotemFrame.EnableMouse then pcall(TotemFrame.EnableMouse, TotemFrame, false) end
  end

  self.frame = f
  ns.AddRoot(f, "totems")
  ns.Movers.Register("totems", "Totem bar", f, { "BOTTOM", "BOTTOM", -205, 300 })
end

local FAKE = {
  { "Interface\\Icons\\Spell_Fire_SearingTotem", "38" },
  { "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02", "1m" },
  { "Interface\\Icons\\Spell_Nature_ManaRegenTotem", "52" },
  { "Interface\\Icons\\Spell_Nature_Windfury", "2m" },
}

function M:Preview(on)
  local f = self.frame
  if not f then return end
  f.previewing = on and true or nil
  if not on then UpdateAll(f) return end
  for i, b in ipairs(f.slots) do
    b.icon:SetTexture(FAKE[i][1])
    b.icon:SetDesaturated(false)
    b.icon:SetAlpha(1)
    b.cd:Hide()
    b.time:SetText(FAKE[i][2])
  end
end
