-- Spell ranks: after you train a higher rank, every action button that still
-- has a lower rank of that spell gets the new one. Forever doesn't do this
-- itself. Changing action buttons isn't allowed in combat, so the swap waits
-- for combat to end (ns.AfterCombat), and it never runs while something is on
-- your cursor. Buttons you want to keep at a low rank on purpose: hover one
-- and type /fxiui ranks keep (that exact rank is then left alone everywhere).
--
-- Unverified on Forever: whether the spellbook lists every rank, and whether
-- C_Spell.GetSpellSubtext says "Rank N". /fxiui ranks check prints what the
-- game reports, so it can be fixed from that if a swap doesn't happen.
local _, ns = ...

local M = ns.AddModule("Ranks")

local failed = {}     -- [slot..":"..oldID] = true: tried once, the game kept the old one
local pending         -- a scan is waiting on a timer
local retries = 0

local function DB() return ns.db and ns.db.ranks end

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and ns.Readable(n) then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and ns.Readable(n) then return n end
  end
end

local function RankNumber(text)
  if type(text) ~= "string" or text == "" then return nil end
  return tonumber(text:match("(%d+)"))
end

local function SubText(id)
  if C_Spell and C_Spell.GetSpellSubtext then
    local ok, s = pcall(C_Spell.GetSpellSubtext, id)
    if ok and ns.Readable(s) then return s end
  end
  if GetSpellSubtext then
    local ok, s = pcall(GetSpellSubtext, id)
    if ok and ns.Readable(s) then return s end
  end
end

local function RankOf(id) return RankNumber(SubText(id)) end

---------------------------------------------------------------------------
-- The spellbook: every learned, active spell, and the highest rank of each.
---------------------------------------------------------------------------
-- Calls fn(index, bank, spellID, name, subName) for each learned spell.
local function EachBookSpell(fn)
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
      local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
      if info and not info.shouldHide then
        local first = (info.itemIndexOffset or 0) + 1
        for i = first, first + (info.numSpellBookItems or 0) - 1 do
          local ok, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
          if ok and item and item.spellID and not item.isPassive and not item.isOffSpec
            and (SPELL == nil or item.itemType == SPELL) then
            fn(i, bank, item.spellID, item.name, item.subName)
          end
        end
      end
    end
    return
  end
  -- Classic-style spellbook, in case Forever still has it.
  if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    local book = BOOKTYPE_SPELL or "spell"
    for tab = 1, GetNumSpellTabs() do
      local _, _, offset, count = GetSpellTabInfo(tab)
      for i = offset + 1, offset + count do
        local name, sub, id = GetSpellBookItemName(i, book)
        if id and not (IsPassiveSpell and IsPassiveSpell(i, book)) then
          fn(i, book, id, name, sub)
        end
      end
    end
  end
end

-- best[name] = { id, rank, index, bank }; inBook[id] = that spell's entry.
local function ReadBook()
  local best, inBook = {}, {}
  EachBookSpell(function(index, bank, id, name, sub)
    name = name or SpellName(id)
    if not name then return end
    local entry = { id = id, rank = RankNumber(sub) or RankOf(id), index = index, bank = bank }
    inBook[id] = entry
    local b = best[name]
    if not b then
      best[name] = entry
    elseif entry.rank and b.rank then
      if entry.rank > b.rank then best[name] = entry end
    elseif index > b.index then
      best[name] = entry    -- no rank text: later in the book is the newer rank
    end
  end)
  return best, inBook
end

-- The rank to put on this button instead, or nil to leave it.
local function Upgrade(id, best, inBook)
  local name = SpellName(id)
  local b = name and best[name]
  if not b or b.id == id then return nil end
  local keep = DB() and DB().keep
  if keep and keep[id] then return nil end
  local cur = inBook[id]
  local curRank = (cur and cur.rank) or RankOf(id)
  if curRank and b.rank then
    if b.rank > curRank then return b, name, curRank end
    return nil
  end
  if cur and b.index > cur.index then return b, name, curRank end
  return nil   -- can't tell which is higher: leave it alone
end

---------------------------------------------------------------------------
-- Swapping
---------------------------------------------------------------------------
local MAX_SLOT = 180

local function PickUp(b)
  if C_SpellBook and C_SpellBook.PickupSpellBookItem and type(b.bank) == "number" then
    pcall(C_SpellBook.PickupSpellBookItem, b.index, b.bank)
  elseif PickupSpellBookItem then
    pcall(PickupSpellBookItem, b.index, b.bank)
  end
  if GetCursorInfo() then return true end
  local fn = (C_Spell and C_Spell.PickupSpell) or PickupSpell
  if fn then pcall(fn, b.id) end
  return GetCursorInfo() ~= nil
end

local function Swap(slot, oldID, b)
  if not PickUp(b) then return false end
  PlaceAction(slot)
  ClearCursor()
  local kind, newID = GetActionInfo(slot)
  return kind == "spell" and newID ~= oldID
end

local function Plural(n, one, many) return n == 1 and one or many end

-- verbose: also say when there was nothing to do (the "Update now" button).
function M.Run(verbose)
  local db = DB()
  if not db then return end
  if not verbose and not db.enabled then return end
  if InCombatLockdown() then
    ns.AfterCombat("ranks", function() M.Run(verbose) end)
    if verbose then ns.Print("spell ranks: will update when combat ends.") end
    return
  end
  if GetCursorInfo() then
    -- Something is on the cursor (you're dragging a spell). Try again shortly.
    retries = retries + 1
    if retries <= 10 then C_Timer.After(2, function() M.Run(verbose) end) end
    return
  end
  retries = 0

  local best, inBook = ReadBook()
  local done, total, broke = {}, 0, 0
  for slot = 1, MAX_SLOT do
    if HasAction(slot) then
      local kind, id = GetActionInfo(slot)
      if kind == "spell" and type(id) == "number" and not failed[slot .. ":" .. id] then
        local b, name, curRank = Upgrade(id, best, inBook)
        if b then
          if Swap(slot, id, b) then
            local d = done[name] or { from = curRank, to = b.rank, n = 0 }
            d.n = d.n + 1
            done[name] = d
            total = total + 1
          else
            failed[slot .. ":" .. id] = true
            broke = broke + 1
          end
        end
      end
    end
  end

  if db.chat or verbose then
    for name, d in pairs(done) do
      local what = (d.from and d.to) and ("Rank %d to Rank %d"):format(d.from, d.to) or "new rank"
      ns.Print("%s: %s on %d %s.", name, what, d.n, Plural(d.n, "button", "buttons"))
    end
  end
  if broke > 0 then
    ns.Print("spell ranks: the game kept the old rank on %d %s. Type /fxiui ranks check and send the output to get it fixed.",
      broke, Plural(broke, "button", "buttons"))
  elseif verbose and total == 0 then
    ns.Print("spell ranks: every button already has your highest rank.")
  end
end

-- SPELLS_CHANGED comes in bursts at the trainer: wait a moment, scan once.
local function Soon()
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = nil
    M.Run(false)
  end)
end

---------------------------------------------------------------------------
-- /fxiui ranks keep: the button under the mouse keeps its exact rank.
---------------------------------------------------------------------------
local function ButtonUnderMouse()
  local f
  if GetMouseFoci then
    local list = GetMouseFoci()
    f = list and list[1]
  elseif GetMouseFocus then
    f = GetMouseFocus()
  end
  for _ = 1, 3 do
    if not f then return nil end
    local slot = f.action
    if type(slot) ~= "number" and f.GetAttribute then
      local ok, a = pcall(f.GetAttribute, f, "action")
      if ok then slot = tonumber(a) end
    end
    if type(slot) == "number" and slot > 0 then return slot end
    f = f.GetParent and f:GetParent()
  end
end

function M.ToggleKeep()
  local slot = ButtonUnderMouse()
  if not slot then
    ns.Print("put the mouse over an action button, then type /fxiui ranks keep.")
    return
  end
  local kind, id = GetActionInfo(slot)
  if kind ~= "spell" or type(id) ~= "number" then
    ns.Print("that button has no spell on it.")
    return
  end
  local keep = DB().keep
  local name = SpellName(id) or ("spell " .. id)
  local rank = RankOf(id)
  local label = rank and ("%s Rank %d"):format(name, rank) or name
  if keep[id] then
    keep[id] = nil
    ns.Print("%s will be swapped for new ranks again.", label)
  else
    keep[id] = true
    ns.Print("%s stays at this rank on every button. Same command again to undo.", label)
  end
end

---------------------------------------------------------------------------
-- /fxiui ranks check: what the game reports, for fixing this on Forever.
---------------------------------------------------------------------------
function M.Report()
  local best, inBook = ReadBook()
  local out, n = {}, 0
  for _ in pairs(inBook) do n = n + 1 end
  out[#out + 1] = ("ForeverXIUI %s spell ranks check, %d learned spells in the book"):format(ns.version, n)
  out[#out + 1] = ("API: C_SpellBook %s, GetSpellSubtext %s"):format(
    tostring(C_SpellBook ~= nil), tostring(C_Spell ~= nil and C_Spell.GetSpellSubtext ~= nil))
  out[#out + 1] = "Highest rank per spell (id, rank):"
  local names = {}
  for name in pairs(best) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local b = best[name]
    out[#out + 1] = ("  %s %d %s"):format(name, b.id, b.rank and ("R" .. b.rank) or "R?")
  end
  out[#out + 1] = "Buttons with a spell (slot, spell, id, subtext):"
  for slot = 1, MAX_SLOT do
    if HasAction(slot) then
      local kind, id = GetActionInfo(slot)
      if kind == "spell" and type(id) == "number" then
        local b = Upgrade(id, best, inBook)
        out[#out + 1] = ("  %d %s %d \"%s\"%s%s%s%s"):format(slot, SpellName(id) or "?", id, SubText(id) or "nil",
          inBook[id] and " in book" or " not in book",
          b and (" -> " .. b.id) or "",
          DB().keep[id] and " (kept)" or "",
          failed[slot .. ":" .. id] and " (failed)" or "")
      end
    end
  end
  if ns.ShowCopy then
    ns.ShowCopy("Spell ranks check", out)
  else
    for _, l in ipairs(out) do ns.Print(l) end
  end
end

function M:Init()
  local f = CreateFrame("Frame")
  for _, ev in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB" }) do
    pcall(f.RegisterEvent, f, ev)   -- not every event exists on every client
  end
  f:SetScript("OnEvent", function(_, event)
    if event ~= "SPELLS_CHANGED" then wipe(failed) end   -- a new spell: worth trying again
    Soon()
  end)
  -- Catch ranks trained before this was installed (or on another bar set).
  C_Timer.After(3, function() M.Run(false) end)
end
