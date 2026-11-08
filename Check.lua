-- /fxiui check: what this Forever client lets addons read right now. Run it
-- out of combat, then again in combat with a mob targeted, and send the
-- output. It only reads; nothing is changed.
local _, ns = ...

local function Say(label, value)
  print(("  %s: |cffffffff%s|r"):format(label, value))
end

local function Describe(fn, ...)
  local ok, v = pcall(fn, ...)
  if not ok then return "error" end
  if type(v) == "nil" then return "nil" end
  if issecretvalue and issecretvalue(v) then return type(v) .. " (secret)" end
  return tostring(v)
end

function ns.Check()
  ns.Print("check (%s):", InCombatLockdown() and "IN combat" or "out of combat")
  local _, build, _, iface = GetBuildInfo()
  Say("build / interface", tostring(build) .. " / " .. tostring(iface))
  Say("issecretvalue exists", tostring(issecretvalue ~= nil))
  Say("C_Secrets exists", tostring(C_Secrets ~= nil))
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    Say("auras secret now", Describe(C_Secrets.ShouldAurasBeSecret))
  end
  Say("C_CurveUtil exists", tostring(C_CurveUtil ~= nil))
  Say("UnitHealthPercent exists", tostring(UnitHealthPercent ~= nil))
  Say("percent curve built", tostring(ns.Values.PercentCurve() ~= nil))
  Say("player health", Describe(UnitHealth, "player"))
  Say("player max health", Describe(UnitHealthMax, "player"))
  Say("player mana", Describe(UnitPower, "player"))
  if UnitExists("target") then
    Say("target name", Describe(UnitName, "target"))
    Say("target health", Describe(UnitHealth, "target"))
    Say("target max health", Describe(UnitHealthMax, "target"))
    Say("target casting", Describe(UnitCastingInfo, "target"))
    if UnitThreatSituation then
      Say("your threat on target", Describe(UnitThreatSituation, "player", "target"))
    else
      Say("your threat on target", "UnitThreatSituation missing")
    end
  else
    Say("target", "none (target a mob and run again)")
  end
  -- Party buffs/debuffs: the game's aura containers, drawn by the game.
  Say("aura containers available", tostring(ns.Auras and ns.Auras.Available() or false))
  if ns.Auras then
    local st = ns.Auras.stats
    Say("party aura rows built / failed", st.built .. " / " .. st.failed)
    if st.lastError then Say("aura error", st.lastError) end
  end
  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType then
    local id = Enum.AddOnRestrictionType.Combat
    if id then Say("combat restriction active", Describe(C_RestrictedActions.IsAddOnRestrictionActive, id)) end
  end
  if UnitExists("target") then
    local tb = ns.modules.TargetBar
    if tb and tb.MobInfo then Say("mob info", (tb.MobInfo("target"))) end
    Say("target of target", Describe(UnitName, "targettarget"))
  end
  Say("pet", Describe(UnitName, "pet"))
  Say("your XP", Describe(UnitXP, "player") .. " / " .. Describe(UnitXPMax, "player"))
  local mapSkin = ns.modules.MapSkin
  if mapSkin and mapSkin.DamageMeterNames then Say("damage meter frames", mapSkin.DamageMeterNames()) end
  if mapSkin and mapSkin.ButtonCount then Say("minimap buttons", mapSkin.ButtonCount()) end
  Say("GetMinimapShape", GetMinimapShape and tostring(GetMinimapShape()) or "nil")
  local swing = ns.modules.SwingTimer
  if swing and swing.Source then Say("swing timer source", swing.Source()) end
  local ok, have = pcall(GetTotemInfo, 1)
  Say("totem slot 1", ok and (ns.Readable(have) and tostring(have) or "secret") or "GetTotemInfo missing")
  Say("money", Describe(GetMoney))
  local bars = ns.modules.ActionBars
  if bars and bars.Names then Say("action bars", bars:Names()) end
  Say("Settings API", tostring(Settings ~= nil and Settings.RegisterAddOnSetting ~= nil))
  Say("Edit Mode callbacks", tostring(EventRegistry ~= nil))
end

---------------------------------------------------------------------------
-- Frame dumps for fitting skins to Forever's own frames (/fxiui map,
-- /fxiui meter), shown in a copy box: click in it, Ctrl+A, Ctrl+C, paste.
---------------------------------------------------------------------------
local function Kind(f)
  local ok, k = pcall(f.GetObjectType, f)
  return ok and k or "?"
end

local function Tex(r)
  local ok, t = pcall(r.GetTexture, r)
  if ok and t ~= nil then return tostring(t) end
  if r.GetAtlas then
    local okA, a = pcall(r.GetAtlas, r)
    if okA and a then return "atlas " .. tostring(a) end
  end
  return ""
end

function ns.DumpFrame(f, out, depth, maxDepth, label)
  depth, maxDepth = depth or 0, maxDepth or 2
  if type(f) ~= "table" or not f.GetObjectType then return end
  local pad = string.rep("  ", depth)
  local name = (f.GetName and f:GetName()) or label or "?"
  local w = f.GetWidth and math.floor((f:GetWidth() or 0) + 0.5) or 0
  local h = f.GetHeight and math.floor((f:GetHeight() or 0) + 0.5) or 0
  local shown = f.IsShown and (f:IsShown() and "" or " hidden") or ""
  local alpha = f.GetAlpha and (" a" .. string.format("%.1f", f:GetAlpha() or 1)) or ""
  out[#out + 1] = ("%s%s [%s] %dx%d%s%s%s"):format(pad, name, Kind(f), w, h, alpha, shown, f.fxiOurs and " (ours)" or "")
  local keys = {}
  for k, v in pairs(f) do
    if type(k) == "string" and type(v) == "table" and v.GetObjectType and not k:find("^fxi") then keys[#keys + 1] = k end
  end
  table.sort(keys)
  if #keys > 0 then out[#out + 1] = pad .. "  keys: " .. table.concat(keys, ", ", 1, math.min(#keys, 20)) end
  if f.GetRegions then
    for _, r in ipairs({ f:GetRegions() }) do
      local k = Kind(r)
      if k == "Texture" then
        out[#out + 1] = ("%s  - tex %s a%.1f %s"):format(pad, r:GetName() or "", r:GetAlpha() or 1, Tex(r))
      elseif k == "FontString" then
        out[#out + 1] = ("%s  - text \"%s\""):format(pad, tostring(r:GetText() or ""))
      end
    end
  end
  if depth < maxDepth and f.GetChildren then
    for _, c in ipairs({ f:GetChildren() }) do
      if not c.fxiOurs then ns.DumpFrame(c, out, depth + 1, maxDepth) end
    end
  end
end

local copy
function ns.ShowCopy(title, lines)
  if not copy then
    copy = CreateFrame("Frame", "ForeverXIUICopy", UIParent)
    copy:SetSize(560, 380)
    copy:SetPoint("CENTER")
    copy:SetFrameStrata("DIALOG")
    copy:EnableMouse(true)
    copy:SetMovable(true)
    copy:RegisterForDrag("LeftButton")
    copy:SetScript("OnDragStart", copy.StartMoving)
    copy:SetScript("OnDragStop", copy.StopMovingOrSizing)
    ns.Style.Panel(copy, 0.97)
    copy.title = ns.Style.Text(copy, 12)
    copy.title:SetPoint("TOPLEFT", 10, -8)
    copy.title:SetTextColor(ns.Style.Color("title"))
    local close = CreateFrame("Button", nil, copy, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local scroll = CreateFrame("ScrollFrame", nil, copy, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -28)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontSmall or ChatFontNormal)
    box:SetWidth(510)
    box:SetScript("OnEscapePressed", function() copy:Hide() end)
    scroll:SetScrollChild(box)
    copy.box = box
  end
  copy.title:SetText(title .. "  (click the text, Ctrl+A, Ctrl+C, then paste it to Claude)")
  copy.box:SetText(table.concat(lines, "\n"))
  copy:Show()
  copy.box:SetFocus()
  copy.box:HighlightText()
end

---------------------------------------------------------------------------
-- /fxiui hide: fade the small frame under the mouse (another addon's
-- coordinates box, say) and remember it by name; /fxiui unhide brings them
-- all back. Only the look changes; nothing is closed or disabled.
---------------------------------------------------------------------------
local held = {}
local function Hold(f)
  f:SetAlpha(0)
  if not held[f] then
    held[f] = true
    hooksecurefunc(f, "SetAlpha", function(self, a)
      if held[self] and ns.db.hidden[self:GetName() or ""] and a and a > 0 then self:SetAlpha(0) end
    end)
  end
end

local function Ours(f)
  local n = f.GetName and f:GetName() or ""
  return f.fxiOurs or n:find("^ForeverXIUI")
end

local function Under()
  local x, y = GetCursorPosition()
  local best, bestArea
  local seen = 0
  local function Walk(f, depth)
    seen = seen + 1
    if seen > 4000 or depth > 4 then return end
    for _, c in ipairs({ f:GetChildren() }) do
      if c:IsVisible() and (c:GetAlpha() or 0) > 0.05 and not Ours(c) then
        local l, b, w, h = c:GetRect()
        local sc = c:GetEffectiveScale()
        if l and w and w > 4 and h > 4 then
          l, b, w, h = l * sc, b * sc, w * sc, h * sc
          if x >= l and x <= l + w and y >= b and y <= b + h then
            local area = w * h
            if area < 360 * 160 * sc * sc and (c.GetName and c:GetName()) and (not bestArea or area < bestArea) then
              best, bestArea = c, area
            end
          end
        end
        Walk(c, depth + 1)
      end
    end
  end
  Walk(UIParent, 0)
  return best
end

function ns.HideUnderMouse()
  local f = Under()
  if not f then
    ns.Print("nothing small with a name under the mouse. Point at the box, then type /fxiui hide.")
    return
  end
  ns.db.hidden[f:GetName()] = true
  Hold(f)
  ns.Print("hid %s. /fxiui unhide brings it back.", f:GetName())
end

function ns.UnhideAll()
  for name in pairs(ns.db.hidden) do
    local f = _G[name]
    ns.db.hidden[name] = nil
    if type(f) == "table" and f.SetAlpha then f:SetAlpha(1) end
  end
  ns.Print("hidden frames are back.")
end

local function ApplyHidden()
  for name in pairs(ns.db.hidden or {}) do
    local f = _G[name]
    if type(f) == "table" and f.SetAlpha then Hold(f) end
  end
end
ns.On("PLAYER_ENTERING_WORLD", function()
  ApplyHidden()
  for _, t in ipairs({ 2, 6, 15 }) do C_Timer.After(t, ApplyHidden) end
end)
