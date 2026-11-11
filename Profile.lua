-- Profiles: export every ForeverXIUI setting (sizes, positions, options) and
-- your current Edit Mode layout as one line of text, and import such a line
-- on another character or PC.
--
-- /fxiui export  shows the line to copy.
-- /fxiui import  opens a box to paste one into, then "Import & reload".
--
-- Not included: the per-character gold tracker totals and Plater's saved
-- backup (they belong to this PC). Importing an Edit Mode layout adds it as a
-- new account layout ("FXI <date>") and makes it active; your old layouts
-- stay in Edit Mode's list.
local _, ns = ...

local M = ns.AddModule("Profile")

local TAG = "!FXI1!"
local EM_SEP = "#EM#"
local SKIP = { gold = true, dbVersion = true, profiles = true }
-- This PC's own state, never exported or imported: Plater's saved backup
-- and whether our Plater look was already written, and the nameplate
-- distance the game had before we changed it.
local LOCAL = { plater = { backup = true, applied = true }, nameplates = { cvarBackup = true }, gather = { cvarBackup = true } }

---------------------------------------------------------------------------
-- A small, data-only serializer (no code is ever run from a pasted line).
---------------------------------------------------------------------------
local function EscStr(s)
  return (s:gsub("[\\\"\n\r\t #|]", function(c)
    return ("\\%03d"):format(c:byte())
  end))
end

local function Ser(v, depth, parent)
  local t = type(v)
  if t == "number" then return ("%.17g"):format(v)
  elseif t == "boolean" then return v and "T" or "F"
  elseif t == "string" then return '"' .. EscStr(v) .. '"'
  elseif t == "table" then
    if depth > 20 then return "N" end
    local parts = {}
    for k, val in pairs(v) do
      local kt, vt = type(k), type(val)
      if (kt == "string" or kt == "number") and vt ~= "function" and vt ~= "userdata" and vt ~= "thread"
        and not (depth == 0 and SKIP[k]) and not (depth == 1 and LOCAL[parent] and LOCAL[parent][k]) then
        parts[#parts + 1] = "[" .. Ser(k, depth + 1) .. "]=" .. Ser(val, depth + 1, depth == 0 and k or nil)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "N"
end

local function Parse(s)
  local pos = 1
  local Value
  local function Fail(msg) error(("bad profile text at %d: %s"):format(pos, msg), 0) end
  local function Str()
    local close = s:find('"', pos + 1, true)
    if not close then Fail("unfinished text") end
    local raw = s:sub(pos + 1, close - 1)
    pos = close + 1
    return (raw:gsub("\\(%d%d%d)", function(d) return string.char(tonumber(d)) end))
  end
  Value = function(depth)
    if depth > 25 then Fail("too deep") end
    local c = s:sub(pos, pos)
    if c == '"' then return Str()
    elseif c == "T" then pos = pos + 1 return true
    elseif c == "F" then pos = pos + 1 return false
    elseif c == "N" then pos = pos + 1 return nil
    elseif c == "{" then
      pos = pos + 1
      local t = {}
      while s:sub(pos, pos) ~= "}" do
        if s:sub(pos, pos) ~= "[" then Fail("expected [") end
        pos = pos + 1
        local k = Value(depth + 1)
        if s:sub(pos, pos + 1) ~= "]=" then Fail("expected ]=") end
        pos = pos + 2
        local v = Value(depth + 1)
        if k ~= nil then t[k] = v end
        local sep = s:sub(pos, pos)
        if sep == "," then pos = pos + 1
        elseif sep ~= "}" then Fail("expected , or }") end
      end
      pos = pos + 1
      return t
    else
      local num = s:match("^-?[%d%.]+[eE]?[-+]?%d*", pos)
      if not num or num == "" then Fail("unexpected '" .. c .. "'") end
      pos = pos + #num
      local n = tonumber(num)
      if not n then Fail("bad number") end
      return n
    end
  end
  local v = Value(0)
  if pos <= #s then Fail("extra text") end
  return v
end
M.Ser, M.Parse = function(v) return Ser(v, 0) end, Parse

---------------------------------------------------------------------------
-- Edit Mode
---------------------------------------------------------------------------
local function EditModeString()
  if not (C_EditMode and C_EditMode.ConvertLayoutInfoToString) then return end
  local info
  if EditModeManagerFrame and EditModeManagerFrame.GetActiveLayoutInfo then
    local ok, li = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
    if ok then info = li end
  end
  if type(info) ~= "table" then return end
  local ok, str = pcall(C_EditMode.ConvertLayoutInfoToString, info)
  if ok and type(str) == "string" and str ~= "" then return str end
end

local function PresetCount()
  if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
    local ok, list = pcall(EditModePresetLayoutManager.GetCopyOfPresetLayouts, EditModePresetLayoutManager)
    if ok and type(list) == "table" then return #list end
  end
  return 2
end

-- Adds the layout as a new account layout and makes it the active one.
-- Uses only C_EditMode (saved, then applied on the reload), so Blizzard's
-- Edit Mode window is never driven from addon code.
local function ImportEditMode(str)
  if not (C_EditMode and C_EditMode.ConvertStringToLayoutInfo and C_EditMode.GetLayouts and C_EditMode.SaveLayouts) then
    return false, "this client can't import Edit Mode layouts from addons"
  end
  local ok, info = pcall(C_EditMode.ConvertStringToLayoutInfo, str)
  if not ok or type(info) ~= "table" then return false, "the Edit Mode part didn't read" end
  local okL, all = pcall(C_EditMode.GetLayouts)
  if not okL or type(all) ~= "table" or type(all.layouts) ~= "table" then return false, "couldn't read your layouts" end
  local taken = {}
  for _, l in ipairs(all.layouts) do taken[l.layoutName or ""] = true end
  local base = "FXI " .. date("%m-%d")
  local name, n = base, 1
  while taken[name] do n = n + 1; name = base .. " " .. n end
  info.layoutName = name
  info.layoutType = (Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account) or 1
  table.insert(all.layouts, info)
  local okS, err = pcall(C_EditMode.SaveLayouts, all)
  if not okS then return false, tostring(err) end
  if C_EditMode.SetActiveLayout then
    pcall(C_EditMode.SetActiveLayout, PresetCount() + #all.layouts)
  end
  return true, name
end

---------------------------------------------------------------------------
-- Tidy Edit Mode: untick the "HUD Edit Mode" list entries ForeverXIUI
-- replaces (target, party, raid, cast bar, totem bar, swing timer...), so
-- only the frames still moved in Edit Mode show up there. Those ticks only
-- choose what Edit Mode shows; they never turn a frame on or off in play.
-- Uses C_EditMode.SetAccountSetting, then reloads so the list redraws.
---------------------------------------------------------------------------
local function Replaced()
  local m, h = ns.db.modules, ns.db.hideBlizzard
  return {
    { "targetandfocus", m.target },
    { "partyframes", m.party },
    { "raidframes", m.raid },
    { "castbar", m.playerCast },
    { "totem", m.totems },
    { "swing", m.swing },
    { "statustrackingbar2", m.xp },
    { "bossframes", h.boss },
  }
end

function M.TidyEditMode()
  local E = Enum and Enum.EditModeAccountSetting
  if type(E) ~= "table" or not (C_EditMode and C_EditMode.SetAccountSetting) then
    return nil, "this client can't change the Edit Mode list from addons"
  end
  local done = {}
  for key, id in pairs(E) do
    local k = tostring(key):lower()
    if not k:find("damage") then
      for _, r in ipairs(Replaced()) do
        if r[2] and k:find(r[1], 1, true) then
          if pcall(C_EditMode.SetAccountSetting, id, 0) then done[#done + 1] = tostring(key):gsub("^Show", "") end
          break
        end
      end
    end
  end
  table.sort(done)
  return done
end

function M.RunTidy(reload)
  if InCombatLockdown() then ns.Print("can't change Edit Mode in combat.") return end
  local done, err = M.TidyEditMode()
  if not done then ns.Print("%s.", err) return end
  if #done == 0 then ns.Print("nothing to untick in the Edit Mode list.") return end
  ns.Print("Edit Mode list: unticked %s.", table.concat(done, ", "))
  if reload and ReloadUI then ReloadUI() end
end

---------------------------------------------------------------------------
-- Export / import
---------------------------------------------------------------------------
function M.ExportString()
  local out = TAG .. Ser(ns.db, 0)
  local em = EditModeString()
  if em then out = out .. EM_SEP .. em end
  return out, em ~= nil
end

local box
local function Box()
  if box then return box end
  local f = CreateFrame("Frame", "ForeverXIUIProfile", UIParent)
  f:SetSize(520, 260)
  f:SetPoint("CENTER")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(120)
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  ns.Style.Panel(f, 0.97)
  f.title = ns.Style.Text(f, 13)
  f.title:SetPoint("TOPLEFT", 10, -9)
  f.title:SetTextColor(ns.Style.Color("title"))
  f.help = ns.Style.Text(f, 10)
  f.help:SetPoint("TOPLEFT", 10, -26)
  f.help:SetPoint("RIGHT", -10, 0)
  f.help:SetJustifyH("LEFT")
  f.help:SetTextColor(0.7, 0.75, 0.85)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -46)
  scroll:SetPoint("BOTTOMRIGHT", -30, 36)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontSmall or ChatFontNormal)
  edit:SetWidth(470)
  edit:SetScript("OnEscapePressed", function() f:Hide() end)
  scroll:SetScrollChild(edit)
  f.edit = edit
  f.go = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.go:SetSize(120, 22)
  f.go:SetPoint("BOTTOMRIGHT", -10, 8)
  f.go:SetText("Import & reload")
  f.go:SetScript("OnClick", function() M.Import(edit:GetText()) end)
  if UISpecialFrames then table.insert(UISpecialFrames, "ForeverXIUIProfile") end
  box = f
  return f
end

function M.ShowExport()
  local str, withEM = M.ExportString()
  local f = Box()
  f.title:SetText("ForeverXIUI profile: export")
  f.help:SetText("Ctrl+A, Ctrl+C to copy. Has all ForeverXIUI settings" ..
    (withEM and " and your current Edit Mode layout." or ". (Edit Mode layout not found, so not included.)"))
  f.go:Hide()
  f.edit:SetText(str)
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
end

function M.ShowImport()
  local f = Box()
  f.title:SetText("ForeverXIUI profile: import")
  f.help:SetText("Paste a profile (Ctrl+V), then Import & reload. Replaces your ForeverXIUI settings; an Edit Mode layout in it is added as a new layout.")
  f.go:Show()
  f.edit:SetText("")
  f:Show()
  f.edit:SetFocus()
end

function M.Import(text)
  if InCombatLockdown() then ns.Print("can't import in combat.") return end
  -- Trim only the ends: the Edit Mode part uses spaces between its fields.
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text:sub(1, #TAG) ~= TAG then
    ns.Print("that isn't a ForeverXIUI profile (it should start with %s).", TAG)
    return
  end
  local body = text:sub(#TAG + 1)
  local settings, em = body, nil
  local at = body:find(EM_SEP, 1, true)
  if at then settings, em = body:sub(1, at - 1), body:sub(at + #EM_SEP) end
  settings = settings:gsub("%s", "")
  if em then em = em:gsub("[\r\n]", "") end
  local ok, data = pcall(Parse, settings)
  if not ok or type(data) ~= "table" then
    ns.Print("couldn't read the profile: %s", tostring(data))
    return
  end
  -- Replace the settings, keeping this PC's own gold totals and Plater backup.
  local keepGold = ns.db.gold
  local keep = {}
  for section, keys in pairs(LOCAL) do
    keep[section] = {}
    for key in pairs(keys) do keep[section][key] = type(ns.db[section]) == "table" and ns.db[section][key] or nil end
  end
  for k in pairs(ns.db) do
    if not SKIP[k] then ns.db[k] = nil end
  end
  for k, v in pairs(data) do
    if not SKIP[k] then ns.db[k] = v end
  end
  ns.db.gold = keepGold
  for section, keys in pairs(LOCAL) do
    if type(ns.db[section]) ~= "table" then ns.db[section] = {} end
    for key in pairs(keys) do ns.db[section][key] = keep[section][key] end
  end

  local emMsg = ""
  if em and em ~= "" then
    local okE, res = ImportEditMode(em)
    emMsg = okE and (" Edit Mode layout added as \"" .. res .. "\".") or (" Edit Mode layout not imported (" .. tostring(res) .. ").")
  end
  -- Someone loading a shared profile gets the tidy Edit Mode list too.
  local tidy = M.TidyEditMode()
  if tidy and #tidy > 0 then emMsg = emMsg .. " Edit Mode list tidied." end
  ns.Print("profile imported." .. emMsg)
  -- Straight from the button click, so the game allows the reload.
  if ReloadUI then ReloadUI() end
end

---------------------------------------------------------------------------
-- Saved profiles: whole profile lines kept by name (account-wide), plus
-- the built-in ones in Presets.lua. Loading one is the same as importing it.
---------------------------------------------------------------------------
local function Saved()
  ns.db.profiles = type(ns.db.profiles) == "table" and ns.db.profiles or {}
  return ns.db.profiles
end

function M.List()
  local names, seen = {}, {}
  for name in pairs(ns.PRESETS or {}) do names[#names + 1] = name; seen[name] = true end
  for name in pairs(Saved()) do if not seen[name] then names[#names + 1] = name end end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

function M.IsBuiltIn(name) return ns.PRESETS ~= nil and ns.PRESETS[name] ~= nil end

function M.Save(name)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then ns.Print("give the profile a name.") return end
  if M.IsBuiltIn(name) then ns.Print("%s is a built-in profile; pick another name.", name) return end
  Saved()[name] = (M.ExportString())
  ns.Print("profile saved as %s.", name)
  return true
end

function M.Load(name)
  local text = Saved()[name] or (ns.PRESETS or {})[name]
  if not text then ns.Print("no profile called %s.", tostring(name)) return end
  M.Import(text)
end

function M.Delete(name)
  if M.IsBuiltIn(name) then ns.Print("%s is built in and can't be deleted.", name) return end
  Saved()[name] = nil
  ns.Print("profile %s deleted.", name)
end

-- Just the settings of a profile line, for a fresh install.
function M.SettingsOf(text)
  text = (text or ""):gsub("^%s+", "")
  if text:sub(1, #TAG) ~= TAG then return end
  local body = text:sub(#TAG + 1)
  local at = body:find(EM_SEP, 1, true)
  if at then body = body:sub(1, at - 1) end
  local ok, data = pcall(Parse, (body:gsub("%s", "")))
  if not ok or type(data) ~= "table" then return end
  for k in pairs(SKIP) do data[k] = nil end
  for section, keys in pairs(LOCAL) do
    if type(data[section]) == "table" then for key in pairs(keys) do data[section][key] = nil end end
  end
  return data
end

-- Name box for "Save as".
local nameBox
local function AskName(onDone)
  if not nameBox then
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(300, 96)
    f:SetPoint("CENTER", 0, 120)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(140)
    f:SetToplevel(true)
    f:EnableMouse(true)
    ns.Style.Panel(f, 0.98)
    local t = ns.Style.Text(f, 12)
    t:SetPoint("TOP", 0, -10)
    t:SetText("Save these settings as:")
    local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    e:SetSize(240, 22)
    e:SetPoint("TOP", 0, -32)
    e:SetAutoFocus(true)
    e:SetMaxLetters(32)
    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(100, 22)
    ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 10)
    ok:SetText("Save")
    local no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    no:SetSize(100, 22)
    no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 10)
    no:SetText("Cancel")
    local function Done()
      if f.onDone and f.onDone(e:GetText()) then f:Hide() end
    end
    ok:SetScript("OnClick", Done)
    e:SetScript("OnEnterPressed", Done)
    e:SetScript("OnEscapePressed", function() f:Hide() end)
    no:SetScript("OnClick", function() f:Hide() end)
    f.edit = e
    nameBox = f
  end
  nameBox.onDone = onDone
  nameBox.edit:SetText("")
  nameBox:Show()
  nameBox:Raise()
  nameBox.edit:SetFocus()
end

-- The profile picker for the options window: a drop-down of saved
-- profiles with Load, Save as and Delete.
function M.Picker(parent, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 64)
  local selected

  local drop = CreateFrame("Button", nil, f)
  drop:SetSize(220, 22)
  drop:SetPoint("TOPLEFT", 4, -4)
  ns.Style.Panel(drop, 0.95)
  local label = ns.Style.Text(drop, 12)
  label:SetPoint("LEFT", 8, 0)
  local arrow = ns.Style.Text(drop, 12)
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetText("v")
  arrow:SetTextColor(ns.Style.Color("title"))

  -- The list opens on UIParent so the options page can't clip it.
  local list = CreateFrame("Frame", nil, UIParent)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetFrameLevel(130)
  list:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
  list:SetWidth(220)
  list:EnableMouse(true)
  list:Hide()
  ns.Style.Panel(list, 0.98)
  list.rows = {}

  local load, del
  local function Paint()
    label:SetText(selected and (selected .. (M.IsBuiltIn(selected) and " |cff7f8aa6(built in)|r" or "")) or "|cff7f8aa6Pick a profile|r")
    if load then load:SetEnabled(selected ~= nil) end
    if del then del:SetEnabled(selected ~= nil and not M.IsBuiltIn(selected)) end
  end

  local function Fill()
    local names = M.List()
    for i, name in ipairs(names) do
      local r = list.rows[i]
      if not r then
        r = CreateFrame("Button", nil, list)
        r:SetSize(212, 20)
        r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        ns.Style.Fill(hl, "accent", 0.2)
        r.text = ns.Style.Text(r, 12)
        r.text:SetPoint("LEFT", 6, 0)
        list.rows[i] = r
      end
      r.text:SetText(name .. (M.IsBuiltIn(name) and " |cff7f8aa6(built in)|r" or ""))
      r:SetScript("OnClick", function() selected = name; list:Hide(); Paint() end)
      r:Show()
    end
    for i = #names + 1, #list.rows do list.rows[i]:Hide() end
    list:SetHeight(math.max(1, #names) * 20 + 8)
  end

  drop:SetScript("OnClick", function()
    if list:IsShown() then list:Hide() else Fill(); list:Show(); list:Raise() end
  end)
  f:SetScript("OnHide", function() list:Hide() end)

  local function Btn(text, x, fn, tip)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(100, 22)
    b:SetPoint("TOPLEFT", x, -34)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(text)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  load = Btn("Load", 4, function() if selected then M.Load(selected) end end,
    "Loads every setting and the Edit Mode layout in this profile, then reloads.")
  Btn("Save as...", 110, function()
    AskName(function(name)
      if M.Save(name) then selected = name; Paint(); return true end
    end)
  end, "Saves your current settings and Edit Mode layout under a name, for this account.")
  del = Btn("Delete", 216, function()
    if selected and not M.IsBuiltIn(selected) then M.Delete(selected); selected = nil; Paint() end
  end, "Removes the picked profile (not the built-in ones).")

  f.Refresh = Paint
  Paint()
  return f, 64
end

function M.Describe()
  return "/fxiui export, /fxiui import, /fxiui tidy"
end
