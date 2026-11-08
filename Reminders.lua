-- Buff reminder: a small XI strip to the right of your cast bar that stays
-- empty while you're covered. When a buff you should have is missing, or
-- running out, its icon shows there with a short label and a gentle pulse.
-- Recast it and the icon goes away. It only reminds you; it never casts.
--
-- Shaman: Lightning Shield and your main-hand weapon imbue.
-- Forever hides your buffs from addons in combat, so Lightning Shield is
-- checked out of combat (and cleared the moment you cast it); in combat it
-- keeps the last thing it knew. The imbue timer comes from the weapon itself.
local _, ns = ...

local M = ns.AddModule("Reminders")

local SIZE, GAP, PAD = 28, 4, 4
local MAX = 4
local f, tiles

local function Known(spell)
  local fn = (C_Spell and C_Spell.GetSpellInfo) or GetSpellInfo
  if not fn then return false end
  local ok, info = pcall(fn, spell)
  return ok and info ~= nil
end

local function SpellIcon(spell, fallback)
  local fn = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
  local ok, tex = pcall(fn, spell)
  return (ok and ns.Readable(tex) and tex) or fallback
end

-- true / false, or nil when the game won't say (in combat).
local function HasBuff(name)
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
    if not ok then return nil end
    if aura == nil then return InCombatLockdown() and nil or false end
    if not ns.Readable(aura) then return nil end
    return true
  end
  if AuraUtil and AuraUtil.FindAuraByName then
    local ok, found = pcall(AuraUtil.FindAuraByName, name, "player", "HELPFUL")
    if not ok or not ns.Readable(found) then return nil end
    return found ~= nil
  end
  return nil
end

local function Short(sec)
  if sec >= 60 then return ("%dm"):format(math.ceil(sec / 60)) end
  return ("%ds"):format(math.ceil(sec))
end

---------------------------------------------------------------------------
-- What to check. Each returns nil (fine) or icon, label.
---------------------------------------------------------------------------
local shieldState          -- last known: true has it, false missing
local SHIELD = "Lightning Shield"

local CHECKS = {}

CHECKS[#CHECKS + 1] = {
  key = "shield", class = "SHAMAN",
  run = function()
    if not Known(SHIELD) then return end
    local has = HasBuff(SHIELD)
    if has ~= nil then shieldState = has end
    if shieldState == false then
      return SpellIcon(SHIELD, "Interface\\Icons\\Spell_Nature_LightningShield"), "Shield"
    end
  end,
}

CHECKS[#CHECKS + 1] = {
  key = "imbue", class = "SHAMAN",
  run = function()
    if not Known("Rockbiter Weapon") or not GetWeaponEnchantInfo then return end
    local ok, has, ms = pcall(GetWeaponEnchantInfo)
    if not ok or not ns.Readable(has) then return end
    -- Only with a weapon in the main hand.
    if not GetInventoryItemLink("player", 16) then return end
    local icon = "Interface\\Icons\\Spell_Nature_RockBiter"
    if not has then return icon, "Imbue" end
    if ns.Readable(ms) and type(ms) == "number" then
      local left = ms / 1000
      if left <= (ns.db.reminders.imbueWarn or 120) then return icon, Short(left) end
    end
  end,
}

---------------------------------------------------------------------------
local function Tile(i)
  local t = CreateFrame("Frame", nil, f)
  t:SetSize(SIZE, SIZE)
  t:SetPoint("LEFT", f, "LEFT", PAD + (i - 1) * (SIZE + GAP), 2)
  local edge = t:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints()
  edge:SetColorTexture(1, 0.3, 0.25, 1)
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetPoint("TOPLEFT", 1, -1)
  t.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  t.label = ns.Style.Text(t, 9)
  t.label:SetPoint("TOP", t, "BOTTOM", 0, -1)
  t.label:SetTextColor(1, 0.55, 0.5)
  local ag = t:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0.45)
  a:SetDuration(0.7)
  t.pulse = ag
  t:Hide()
  return t
end

local function Show(list)
  for i = 1, MAX do
    local t, e = tiles[i], list[i]
    if e then
      t.icon:SetTexture(e[1])
      t.label:SetText(e[2])
      if not t:IsShown() then t:Show() t.pulse:Play() end
    else
      t.pulse:Stop()
      t:Hide()
    end
  end
  f:SetWidth(PAD * 2 + math.max(1, #list) * (SIZE + GAP) - GAP)
  f:SetShown(#list > 0)
end

local function Quiet()
  if UnitIsDeadOrGhost("player") or (UnitOnTaxi and UnitOnTaxi("player")) then return true end
  if ns.db.reminders.hideResting and IsResting() and not InCombatLockdown() then return true end
  return false
end

local function Update()
  if not f or f.previewing then return end
  local list = {}
  if not Quiet() then
    local _, class = UnitClass("player")
    for _, c in ipairs(CHECKS) do
      if (not c.class or c.class == class) and ns.db.reminders[c.key] ~= false then
        local ok, icon, label = pcall(c.run)
        if ok and icon then list[#list + 1] = { icon, label } end
      end
    end
  end
  Show(list)
end

function M:Init()
  if not ns.db.modules.reminders then return end
  f = CreateFrame("Frame", "ForeverXIUIReminders", UIParent)
  f:SetSize(PAD * 2 + SIZE, SIZE + PAD * 2 + 12)
  ns.Style.Panel(f, 0.9)
  tiles = {}
  for i = 1, MAX do tiles[i] = Tile(i) end
  f:Hide()

  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "UNIT_INVENTORY_CHANGED", "PLAYER_UPDATE_RESTING", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "SPELLS_CHANGED" }) do
    pcall(f.RegisterEvent, f, e)
  end
  pcall(f.RegisterUnitEvent, f, "UNIT_AURA", "player")
  pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")
  f:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and ns.Readable(spellID) then
      local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
      local ok, name = pcall(fn, spellID)
      if ok and name == SHIELD then shieldState = true end
    end
    Update()
  end)
  -- Timers count down, and the out-of-combat shield check needs a poll.
  C_Timer.NewTicker(1, Update)

  self.frame = f
  ns.AddRoot(f, "reminders")
  ns.Movers.Register("reminders", "Buff reminder", f, { "BOTTOM", "BOTTOM", 205, 300 })
  Update()
end

function M:Preview(on)
  if not f then return end
  f.previewing = on and true or nil
  if on then
    Show({ { "Interface\\Icons\\Spell_Nature_LightningShield", "Shield" },
      { "Interface\\Icons\\Spell_Nature_RockBiter", "1m" } })
  else
    Update()
  end
end
