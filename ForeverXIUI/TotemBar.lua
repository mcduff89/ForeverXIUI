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

-- In range or not: a totem that gives you a buff is in range while you
-- have the buff. Which totems give one is learned as you play (the first
-- time its buff is seen), so totems with no buff (Searing, Earthbind,
-- Tremor...) never get marked. Out of range: icon shaded red with an X.
local function Stem(name)
  if not ns.Readable(name) or type(name) ~= "string" then return nil end
  local s = name:gsub("%s+[IVX]+$", ""):gsub("%s+%d+$", ""):gsub("%s+Totem$", "")
  return s
end

local function HasBuff(stem)
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
  for _, n in ipairs({ stem, stem .. " Totem", stem .. " Effect", stem .. " Totem Effect" }) do
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", n, "HELPFUL")
    if not ok then return nil end
    if aura then return true end
  end
  return false
end

local function UpdateRange(b)
  local out = false
  if ns.db.totems.range and b.present then
    local stem = Stem(b.totemName)
    if stem then
      local has = HasBuff(stem)
      local known = ns.db.totems.buffs
      if has then known[stem] = true end
      out = (has == false) and known[stem] == true
    end
  end
  b.buffOut = out
end

-- The X: by distance when we have it (open world), by the buff otherwise.
local function Mark(b)
  local out
  if b.distOut ~= nil then out = b.distOut else out = b.buffOut end
  out = out and b.present and true or false
  b.out = out
  if out then
    b.icon:SetVertexColor(1, 0.3, 0.3)
    b.cross:Show()
  else
    b.icon:SetVertexColor(1, 1, 1)
    b.cross:Hide()
  end
end

-- Distance: where you stood when the totem went down, against where you
-- are now, in yards. UnitPosition is blocked in dungeons and raids, so
-- there the number is hidden and only the buff check above is left.
local RANGE = { ["Tremor"] = 30, ["Poison Cleansing"] = 30, ["Disease Cleansing"] = 30,
  ["Tranquil Air"] = 30, ["Magma"] = 8, ["Earthbind"] = 10, ["Fire Nova"] = 10 }
local function Where()
  if not UnitPosition then return nil end
  local ok, y, x, _, inst = pcall(UnitPosition, "player")
  if not ok or not ns.Readable(y) or not ns.Readable(x) then return nil end
  return x, y, inst
end

local function UpdateDistance(b)
  b.distOut = nil
  if not (ns.db.totems.distance and b.present and b.pos) then b.dist:SetText("") Mark(b) return end
  local x, y, inst = Where()
  if not x or inst ~= b.pos[3] then b.dist:SetText("") Mark(b) return end
  local d = math.sqrt((x - b.pos[1]) ^ 2 + (y - b.pos[2]) ^ 2)
  local max = RANGE[Stem(b.totemName) or ""] or 20
  b.dist:SetText(tostring(math.floor(d + 0.5)))
  if d > max then b.dist:SetTextColor(1, 0.25, 0.25) else b.dist:SetTextColor(0.8, 0.9, 1) end
  b.distOut = d > max
  Mark(b)
end

-- Minimap circle: a soft disc on the minimap around where your totems are,
-- the size of their range, drawn from map coordinates (east/south in
-- yards via the map's world size). Open world only, like the distance.
function M.MapWhere()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetMapWorldSize) then return nil end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or not ns.Readable(mapID) or not mapID then return nil end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not ok2 or not pos then return nil end
  local px, py = pos:GetXY()
  if not ns.Readable(px) or not ns.Readable(py) then return nil end
  return { mapID, px, py }
end

-- Minimap diameter in yards per zoom level (0 = most zoomed out).
local OUTDOOR = { 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 }
local INDOOR = { 300, 240, 180, 120, 80, 50 }

local circle
local function Disc(i)
  circle.discs[i] = circle.discs[i] or (function()
    local t = circle:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    local mask = circle.CreateMaskTexture and circle:CreateMaskTexture()
    if mask then
      mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(t)
      t:AddMaskTexture(mask)
    end
    return t
  end)()
  return circle.discs[i]
end

function M.UpdateCircle()
  if not circle then return end
  local f = M.frame
  local n = 0
  local here = ns.db.totems.circle and M.MapWhere()
  if here and f and Minimap then
    local w, h = C_Map.GetMapWorldSize(here[1])
    local zoom = (Minimap.GetZoom and Minimap:GetZoom() or 0) + 1
    local diam = ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[zoom] or 466.6667
    local scale = (Minimap:GetWidth() or 140) / diam      -- pixels per yard
    local rot = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rot and GetPlayerFacing and GetPlayerFacing() or 0
    if not ns.Readable(facing) then facing = 0 end
    local seen = {}
    for _, b in ipairs(f.slots) do
      local p = b.present and b.mapPos
      if p and p[1] == here[1] and w and w > 0 then
        local key = ("%.4f:%.4f"):format(p[2], p[3])
        local r = RANGE[Stem(b.totemName) or ""] or 20
        if seen[key] then
          seen[key].r = math.max(seen[key].r, r)
        else
          seen[key] = { dx = (p[2] - here[2]) * w, dy = (p[3] - here[3]) * h, r = r }
          n = n + 1
          seen[n] = seen[key]
        end
      end
    end
    for i = 1, n do
      local c = seen[i]
      local dx, dy = c.dx, -c.dy      -- east, north in yards
      if rot and facing ~= 0 then
        local cs, sn = math.cos(facing), math.sin(facing)
        dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs   -- turn the world so you face up
      end
      local t = Disc(i)
      local size = c.r * 2 * scale
      t:ClearAllPoints()
      t:SetSize(size, size)
      t:SetPoint("CENTER", circle, "CENTER", dx * scale, dy * scale)
      local ar, ag, ab = ns.Style.Color("accent")
      t:SetVertexColor(ar, ag, ab, 0.22)
      t:Show()
    end
  end
  for i = n + 1, #circle.discs do circle.discs[i]:Hide() end
end

local function BuildCircle()
  if circle or not Minimap then return end
  circle = CreateFrame("Frame", nil, Minimap)
  circle:SetAllPoints(Minimap)
  circle:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 1)
  if circle.SetClipsChildren then circle:SetClipsChildren(true) end
  circle.discs = {}
  local acc = 0
  circle:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.05 then return end
    acc = 0
    M.UpdateCircle()
  end)
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
    -- A new totem in this slot: remember where you are.
    local mark = (ns.Readable(start) and start) or name
    if mark ~= b.placedMark then
      b.placedMark = mark
      local x, y, inst = Where()
      b.pos = x and { x, y, inst } or nil
      b.mapPos = M.MapWhere()
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
    b.placedMark, b.pos, b.mapPos = nil, nil, nil
  end
  UpdateRange(b)
  UpdateDistance(b)
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
  b.cross = b:CreateFontString(nil, "OVERLAY")
  b.cross:SetFont(STANDARD_TEXT_FONT, 22, "THICKOUTLINE")
  b.cross:SetPoint("CENTER", b.icon, "CENTER", 0, 0)
  b.cross:SetText("X")
  b.cross:SetTextColor(1, 0.15, 0.15)
  b.cross:Hide()
  b.dist = ns.Style.Text(b, 10)
  b.dist:SetPoint("BOTTOM", b, "TOP", 0, 1)
  b.time = ns.Style.Text(b, 10)
  b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  ns.Style.Fill(hl, "accent", 0.2)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.present and pcall(GameTooltip.SetTotem, GameTooltip, self.slot) then
      if self.out then GameTooltip:AddLine("Out of range: you don't have its buff.", 1, 0.3, 0.3) end
      GameTooltip:AddLine("Right-click to take it down.", 0.6, 0.6, 0.6)
    else
      GameTooltip:AddLine(ELEMENT[self.slot] .. " totem", ns.Style.Color("title"))
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
  pcall(f.RegisterUnitEvent, f, "UNIT_AURA", "player")
  pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")
  f:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      -- Totemic Call / Projection bring your totems to where you stand.
      local spellID = select(3, ...)
      local name = ns.Readable(spellID) and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
      if ns.Readable(name) and type(name) == "string" and (name == "Totemic Call" or name == "Totemic Projection") then
        local x, y, inst = Where()
        local mp = M.MapWhere()
        for _, b in ipairs(self.slots) do if b.present then b.pos = x and { x, y, inst } or nil; b.mapPos = mp end end
      end
    elseif event == "UNIT_AURA" then
      if not self.previewing then for _, b in ipairs(self.slots) do UpdateRange(b); Mark(b) end end
    else
      UpdateAll(self)
    end
  end)
  -- The time left under each icon, a few times a second.
  local acc = 0
  f:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 0.2 or self.previewing then return end
    acc = 0
    local now = GetTime()
    for _, b in ipairs(self.slots) do
      UpdateDistance(b)
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
  BuildCircle()
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
    b.icon:SetVertexColor(1, 1, 1)
    b.cross:SetShown(i == 3)
    b.dist:SetText(i == 3 and "24" or "12")
    b.dist:SetTextColor(i == 3 and 1 or 0.8, i == 3 and 0.25 or 0.9, i == 3 and 0.25 or 1)
    if i == 3 then b.icon:SetVertexColor(1, 0.3, 0.3) end
    b.icon:SetAlpha(1)
    b.cd:Hide()
    b.time:SetText(FAKE[i][2])
  end
end
