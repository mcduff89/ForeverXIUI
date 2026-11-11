-- The ForeverXIUI window: every option on one XI window, a page per
-- section down the left. /fxiui opens it, and clicking a frame in move
-- mode (/fxiui move) opens it on that frame's page. The pages themselves
-- are listed in Options.lua (M.Pages).
local _, ns = ...

local M = ns.AddModule("Config")

local W, H, LIST_W, ROW_W = 700, 520, 180, 470
local win, current
local built = {}      -- page name -> content frame

local function Tip(owner, title, text)
  owner:SetScript("OnEnter", function(self)
    if not text or text == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Apply(item)
  if item.onChange then
    item.onChange(item.tbl[item.key])
  elseif item.reload then
    -- Once, not on every step of a slider or colour drag.
    local now = GetTime and GetTime() or 0
    if not M.reloadSaid or now - M.reloadSaid > 10 then
      M.reloadSaid = now
      ns.Print("change saved. Type /reload to apply it.")
    end
  else
    ns.ApplyScale()
    ns.ForEachModule("Relayout")
  end
end

local function LabelText(item)
  if item.reload then return item.label .. " |cff7f8aa6(reload)|r" end
  return item.label
end

---------------------------------------------------------------------------
-- Widgets. Each returns its frame (with :Refresh) and the height it takes.
---------------------------------------------------------------------------
local function MakeCheck(parent, item)
  local b = CreateFrame("CheckButton", nil, parent)
  b:SetSize(22, 22)
  b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local t = ns.Style.Text(b, 12)
  t:SetPoint("LEFT", b, "RIGHT", 4, 0)
  t:SetText(LabelText(item))
  -- The label is clickable too.
  b:SetHitRectInsets(0, -math.min(ROW_W - 30, (t:GetStringWidth() or 200) + 8), 0, 0)
  b.Refresh = function() b:SetChecked(item.tbl[item.key] and true or false) end
  b:SetScript("OnClick", function(self)
    item.tbl[item.key] = self:GetChecked() and true or false
    Apply(item)
  end)
  Tip(b, item.label, item.tip)
  return b, 26
end

local function Round(v, step)
  v = math.floor(v / step + 0.5) * step
  return tonumber(("%.4f"):format(v))
end

local function MakeSlider(parent, item)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(ROW_W - 20, 40)
  local label = ns.Style.Text(f, 12)
  label:SetPoint("TOPLEFT", 4, 0)
  label:SetText(LabelText(item))
  local val = ns.Style.Text(f, 12)
  val:SetPoint("TOPRIGHT", -4, 0)
  val:SetTextColor(ns.Style.Color("title"))

  local s = CreateFrame("Slider", nil, f)
  s:SetOrientation("HORIZONTAL")
  s:SetPoint("TOPLEFT", 4, -18)
  s:SetPoint("TOPRIGHT", -4, -18)
  s:SetHeight(16)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  track:SetColorTexture(ns.Style.Color("edge"))
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(10, 16)
  thumb:SetColorTexture(ns.Style.Color("title"))
  s:SetThumbTexture(thumb)
  s:SetMinMaxValues(item.lo, item.hi)
  s:SetValueStep(item.step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d)
    self:SetValue(math.max(item.lo, math.min(item.hi, (self:GetValue() or 0) + d * item.step)))
  end)

  local busy = false
  local function Show(v) val:SetText(item.fmt:format(v)) end
  s:SetScript("OnValueChanged", function(_, v)
    if busy then return end
    v = Round(v, item.step)
    if item.tbl[item.key] == v then return end
    item.tbl[item.key] = v
    Show(v)
    Apply(item)
  end)
  f.Refresh = function()
    busy = true
    local v = tonumber(item.tbl[item.key]) or item.default or item.lo
    s:SetValue(v)
    Show(v)
    busy = false
  end
  Tip(f, item.label, item.tip)
  f:EnableMouse(true)
  return f, 46
end

local function MakeButton(parent, item)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(ROW_W - 20, 26)
  local t = ns.Style.Text(f, 12)
  t:SetPoint("LEFT", 4, 0)
  t:SetText(item.label or "")
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  b:SetSize(120, 22)
  b:SetPoint("RIGHT", -4, 0)
  b:SetText(item.button)
  b:SetScript("OnClick", function() item.fn() end)
  Tip(b, item.button, item.tip)
  return f, 30
end

local function MakeHeader(parent, item)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(ROW_W - 20, 28)
  local t = ns.Style.Text(f, 13)
  t:SetPoint("BOTTOMLEFT", 2, 6)
  t:SetTextColor(ns.Style.Color("title"))
  t:SetText(item.label)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetPoint("BOTTOMLEFT", 0, 2)
  line:SetPoint("BOTTOMRIGHT", 0, 2)
  line:SetHeight(1)
  line:SetColorTexture(ns.Style.Color("edge"))
  return f, 30
end

-- A colour swatch: click it for the game's colour picker, Reset for the default.
local function OpenPicker(r, g, b, onPick)
  local cp = ColorPickerFrame
  if not cp then return end
  local function Picked()
    local nr, ng, nb = cp:GetColorRGB()
    onPick(nr, ng, nb)
  end
  local function Cancel() onPick(r, g, b) end
  if cp.SetupColorPickerAndShow then
    cp:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
      swatchFunc = Picked, cancelFunc = Cancel })
  else
    cp.hasOpacity = false
    cp.func, cp.swatchFunc, cp.cancelFunc = Picked, Picked, Cancel
    cp.previousValues = { r, g, b }
    if cp.SetColorRGB then cp:SetColorRGB(r, g, b) end
    if ShowUIPanel then ShowUIPanel(cp) else cp:Show() end
  end
  -- Over our window, which sits at FULLSCREEN_DIALOG.
  cp:SetFrameStrata("FULLSCREEN_DIALOG")
  cp:SetFrameLevel(((win and win:GetFrameLevel()) or 1) + 50)
  cp:Raise()
end

local function MakeColor(parent, item)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(ROW_W - 20, 28)
  local t = ns.Style.Text(f, 12)
  t:SetPoint("LEFT", 4, 0)
  t:SetText(LabelText(item))
  local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  reset:SetSize(60, 22)
  reset:SetPoint("RIGHT", -4, 0)
  reset:SetText("Reset")
  local sw = CreateFrame("Button", nil, f)
  sw:SetSize(40, 18)
  sw:SetPoint("RIGHT", reset, "LEFT", -8, 0)
  local edge = sw:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints()
  edge:SetColorTexture(ns.Style.Color("edge"))
  local fill = sw:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  local hl = sw:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.2)

  local function Get()
    local c = item.tbl[item.key]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return item.default[1], item.default[2], item.default[3]
  end
  local function Set(r, g, b)
    item.tbl[item.key] = { r = r, g = g, b = b }
    fill:SetColorTexture(r, g, b, 1)
    Apply(item)
  end
  f.Refresh = function() fill:SetColorTexture(Get()) end
  sw:SetScript("OnClick", function()
    local r, g, b = Get()
    OpenPicker(r, g, b, Set)
  end)
  reset:SetScript("OnClick", function() Set(item.default[1], item.default[2], item.default[3]) end)
  Tip(sw, item.label, item.tip)
  return f, 32
end

-- A row of buttons, one per choice; the picked one is lit.
local function MakeChoice(parent, item)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(ROW_W - 20, 28)
  local t = ns.Style.Text(f, 12)
  t:SetPoint("LEFT", 4, 0)
  t:SetText(LabelText(item))
  local btns = {}
  local prev
  for i = #item.choices, 1, -1 do
    local value, text = item.choices[i][1], item.choices[i][2]
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(70, 22)
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("RIGHT", -4, 0) end
    b:SetText(text)
    b.value = value
    b:SetScript("OnClick", function()
      item.tbl[item.key] = value
      f.Refresh()
      Apply(item)
    end)
    Tip(b, item.label, item.tip)
    btns[#btns + 1] = b
    prev = b
  end
  f.Refresh = function()
    for _, b in ipairs(btns) do
      local on = item.tbl[item.key] == b.value
      if b.LockHighlight then if on then b:LockHighlight() else b:UnlockHighlight() end end
      local fs = b.GetFontString and b:GetFontString()
      if fs then
        if on then fs:SetTextColor(ns.Style.Color("title")) else fs:SetTextColor(1, 1, 1) end
      end
    end
  end
  return f, 32
end

local function MakeCustom(parent, item) return item.build(parent, ROW_W - 20) end

local MAKERS = { check = MakeCheck, slider = MakeSlider, button = MakeButton, header = MakeHeader, custom = MakeCustom, color = MakeColor, choice = MakeChoice }

local function BuildPage(page)
  local c = CreateFrame("Frame", nil, win.scroll)
  c:SetWidth(ROW_W)
  c.widgets = {}
  local y = -4
  for _, item in ipairs(page.items) do
    local make = MAKERS[item.kind]
    if make then
      local ok, w, h = pcall(make, c, item)
      if ok and w then
        w:SetPoint("TOPLEFT", c, "TOPLEFT", 4, y)
        y = y - h
        c.widgets[#c.widgets + 1] = w
      end
    end
  end
  c:SetHeight(-y + 10)
  c:Hide()
  return c
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Select(name)
  if not win then return end
  local page
  for _, p in ipairs(win.pages) do if p.name == name then page = p end end
  page = page or win.pages[1]
  if current then current:Hide() end
  local c = built[page.name]
  if not c then
    c = BuildPage(page)
    built[page.name] = c
  end
  win.scroll:SetScrollChild(c)
  c:Show()
  for _, w in ipairs(c.widgets) do if w.Refresh then pcall(w.Refresh) end end
  win.scroll:SetVerticalScroll(0)
  current = c
  win.pageTitle:SetText(page.name)
  for _, b in ipairs(win.tabs) do b.sel:SetShown(b.page == page.name) end
end

local function Build(pages)
  local f = CreateFrame("Frame", "ForeverXIUIConfig", UIParent)
  f.pages = pages
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  ns.Style.Panel(f, 0.97)

  local title = ns.Style.Text(f, 15)
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("|cff78c4eeForever|rXIUI  |cff7f8aa6" .. tostring(ns.version or "") .. "|r")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)

  -- Page list.
  f.tabs = {}
  local y = -44
  for _, page in ipairs(f.pages) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(LIST_W - 20, 22)
    b:SetPoint("TOPLEFT", 12, y)
    local sel = b:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints()
    ns.Style.Fill(sel, "accentSel", 0.3)
    sel:Hide()
    b.sel = sel
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    ns.Style.Fill(hl, "accent", 0.15)
    local t = ns.Style.Text(b, 12)
    t:SetPoint("LEFT", 6, 0)
    t:SetText(page.name)
    b.page = page.name
    b:SetScript("OnClick", function() Select(page.name) end)
    f.tabs[#f.tabs + 1] = b
    y = y - 24
  end

  local move = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  move:SetSize(LIST_W - 20, 22)
  move:SetPoint("BOTTOMLEFT", 12, 12)
  move:SetText("Move frames")
  move:SetScript("OnClick", function() ns.Movers.Toggle() end)
  Tip(move, "Move frames", "Drag any ForeverXIUI frame. Click one to jump to its options. Also /fxiui move.")

  local divider = f:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", LIST_W, -40)
  divider:SetPoint("BOTTOMLEFT", LIST_W, 12)
  divider:SetWidth(1)
  divider:SetColorTexture(ns.Style.Color("edge"))

  f.pageTitle = ns.Style.Text(f, 14)
  f.pageTitle:SetPoint("TOPLEFT", LIST_W + 14, -40)
  f.pageTitle:SetTextColor(ns.Style.Color("title"))

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", LIST_W + 8, -64)
  scroll:SetPoint("BOTTOMRIGHT", -30, 14)
  f.scroll = scroll

  if UISpecialFrames then table.insert(UISpecialFrames, "ForeverXIUIConfig") end
  return f
end

-- Which page a move-mode frame's options are on.
local function PageFor(key)
  for _, p in ipairs(win.pages) do
    for _, k in ipairs(p.movers) do if k == key then return p.name end end
  end
end

-- what: a page name, a mover key, or nil for the last page shown.
function M.Open(what)
  local opts = ns.modules.Options
  if not (opts and opts.Pages) then return end
  if not win then
    local ok, pages = pcall(opts.Pages)
    if not ok then ns.Print("options: %s", tostring(pages)) return end
    local okB, f = pcall(Build, pages)
    if not okB then ns.Print("options window: %s", tostring(f)) return end
    win = f
  end
  local name = what and (PageFor(what) or what)
  win:Show()
  if name or not current then
    Select(name or win.pages[1].name)
  else
    for _, w in ipairs(current.widgets) do if w.Refresh then pcall(w.Refresh) end end
  end
end

function M.Toggle()
  if win and win:IsShown() then win:Hide() else M.Open() end
end

ns.OpenConfig = function(...) return M.Open(...) end
