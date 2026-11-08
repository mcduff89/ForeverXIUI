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
    ns.Print("change saved. Type /reload to apply it.")
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

local MAKERS = { check = MakeCheck, slider = MakeSlider, button = MakeButton, header = MakeHeader }

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
    sel:SetColorTexture(0.22, 0.6, 0.81, 0.3)
    sel:Hide()
    b.sel = sel
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.47, 0.77, 0.93, 0.15)
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
