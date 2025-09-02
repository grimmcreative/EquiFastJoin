
-- EquiFastJoin - Retail 11.2.0
-- Version 1.8.1 (Event-driven: no manual Search; auto-open on LFG events)

local ADDON_NAME = ...
local EFJ = {}
_G.EquiFastJoin = EFJ
EFJ.State = EFJ.State or { applications = {} }

EquiFastJoinDB = EquiFastJoinDB or nil
local DEFAULTS = {
  debug = false,
  lastDismissSignature = "",
  scale = 1.0,
  lockFrame = false,
  width = 400,
  height = 300,
  point = "CENTER",
  rel = "CENTER",
  x = 0, y = 0,
  -- Filters & UX
  showRaids = true,
  showDungeons = true,
  showMythicPlus = true,
  showPvP = false,
  showCustom = true,
  openOnQuickJoin = true,
  playSound = false,
  showToast = true,
}

local function CopyDefaults(dst, src)
  for k,v in pairs(src) do
    if type(v)=="table" then
      dst[k] = dst[k] or {}
      CopyDefaults(dst[k], v)
    elseif dst[k]==nil then
      dst[k]=v
    end
  end
end

local function DBG(...)
  if EquiFastJoinDB and EquiFastJoinDB.debug then
    print("|cff33ff99[EFJ]|r", ...)
  end
end

-- Helpers ---------------------------------------------------------------------
local function BuildSignature(ids)
  local arr = {}; if type(ids)~="table" then return "" end
  for _,id in ipairs(ids) do table.insert(arr, tostring(id)) end
  table.sort(arr); return table.concat(arr,",")
end

local function ColorizeByClass(name, classEN)
  if not name then return "-" end
  local c = classEN and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classEN]
  if c then return ("|cff%02x%02x%02x%s|r"):format(c.r*255,c.g*255,c.b*255,name) end
  return name
end

-- Robust activity helpers -----------------------------------------------------
local function GetActivityInfoForRes(res)
  if not res then return nil end
  local activityID = res.activityID
  if (not activityID) and type(res.activityIDs) == "table" and #res.activityIDs > 0 then
    activityID = res.activityIDs[1]
  end
  if activityID then
    return C_LFGList.GetActivityInfoTable(activityID)
  end
  return nil
end

local function ClassifyResult(res)
  -- Returns one of: "MPLUS","RAID","DUNGEON","PVP","CUSTOM","OTHER"
  if not res then return "OTHER" end
  local act = GetActivityInfoForRes(res) or {}
  local name = (act and act.fullName) or res.activityText or res.name or ""
  local isMPlus = (res.isMythicPlusActivity == true)
                  or (tonumber(res.keyLevel) and tonumber(res.keyLevel) > 0)
                  or (act and (act.isMythicPlusActivity == true))
                  or (act and act.difficultyID == 8)
                  or (type(name) == "string" and name:find("%+"))
  if isMPlus then return "MPLUS" end
  local categoryID = act.categoryID
  -- Use category mapping for non-M+ content
  if categoryID == 2 then return "RAID" end
  if categoryID == 1 then return "DUNGEON" end
  if categoryID == 3 or categoryID == 4 then return "PVP" end
  if categoryID == 6 then return "CUSTOM" end
  return "OTHER"
end

-- LFG helpers -----------------------------------------------------------------
-- Forward declare helpers used across sections
local FindLeaderClass
local BuildCategoryColor
local SetMemberIconsFromLFG
local GatherQuickJoinEntries
local SetRoleIconsFromLFG

local function BuildActivityText(res)
  if not res then return "Unbekannte Aktivität" end
  local activityID = res.activityID
  if (not activityID) and type(res.activityIDs)=="table" and #res.activityIDs>0 then
    activityID = res.activityIDs[1]
  end
  if activityID then
    local act = C_LFGList.GetActivityInfoTable(activityID)
    if act and act.fullName and act.fullName ~= "" then
      if (res.isMythicPlusActivity or res.keyLevel) then
        local level = res.keyLevel and tonumber(res.keyLevel)
        if level and level > 0 then
          return string.format("%s +%d", act.fullName, level)
        end
      end
      return act.fullName
    end
  end
  if res.name and res.name ~= "" then return res.name end
  if res.isMythicPlusActivity or res.keyLevel then
    local level = res.keyLevel and tonumber(res.keyLevel)
    if level and level > 0 then return ("Mythic+ +%d"):format(level) end
    return "Mythic+"
  end
  return "Unbekannte Aktivität"
end

local function GetFreshResultInfo(id)
  local info = C_LFGList.GetSearchResultInfo(id)
  if not info then return nil end
  if info.isDelisted then return nil end
  info.activityText = BuildActivityText(info)
  return info
end

-- Attempt to apply to a group with sensible default roles
local function TryJoin(id)
  if not id then return "error" end
  local function OpenApplyDialog()
    local loaded = true
    if not LFGListApplicationDialog or not LFGListApplicationDialog_Show then
      loaded = pcall(LoadAddOn, "Blizzard_LookingForGroupUI") or pcall(LoadAddOn, "Blizzard_LFGList") or false
    end
    if LFGListApplicationDialog_Show and LFGListApplicationDialog then
      LFGListApplicationDialog_Show(LFGListApplicationDialog, id)
      return true
    end
    return false
  end
  -- Prefer the Blizzard dialog for 100% reliability
  if OpenApplyDialog() then return "dialog" end
  if not C_LFGList or not C_LFGList.ApplyToGroup then return "error" end
  local tank, healer, dps = false, false, false
  local spec = GetSpecialization and GetSpecialization()
  if spec then
    local role = GetSpecializationRole(spec)
    if role == "TANK" then tank = true
    elseif role == "HEALER" then healer = true
    else dps = true end
  else
    -- Fallback assume DPS
    dps = true
  end
  local function doApply()
    DBG("ApplyToGroup", id, "roles:", tank and "T" or "-", healer and "H" or "-", dps and "D" or "-")
    local ok, err = pcall(function()
      C_LFGList.ApplyToGroup(id, "", tank, healer, dps)
    end)
    if not ok and UIErrorsFrame and err then
      UIErrorsFrame:AddMessage("EFJ: Bewerbung fehlgeschlagen", 1, 0.2, 0.2)
      DBG("ApplyToGroup error:", err)
      return false
    end
    return true
  end
  -- Avoid applying from a timer (can cause taint). Require fresh info now.
  if not C_LFGList.GetSearchResultInfo(id) then
    -- Try to ensure results are fresh, then ask user to click again or use dialog.
    pcall(function() C_LFGList.Search(0, "", 0, 0) end)
    pcall(function() C_LFGList.RefreshResults() end)
    if UIErrorsFrame then UIErrorsFrame:AddMessage("EFJ: Bitte erneut klicken", 1, 0.8, 0.2) end
    return "retry"
  end
  return doApply() and "applied" or "error"
end

local function TryJoinAndMark(row, id)
  local r = TryJoin(id)
  if r == "applied" then
    if row and row.join then
      row.join:SetEnabled(true)
      row.join:SetAlpha(1)
      row.join:SetText("Abmelden")
      row.join:SetScript("OnClick", function() CancelApplicationAndMark(row, id) end)
    end
  elseif r == "dialog" then
    -- Keep button enabled; user completes application in Blizzard dialog
    C_Timer.After(0.5, function() if row then EFJ.UI:UpdateJoinButton(row, id) end end)
    C_Timer.After(2.0, function() if row then EFJ.UI:UpdateJoinButton(row, id) end end)
  else
    if row and row.join then
      row.join:SetEnabled(true)
      row.join:SetAlpha(1)
    end
  end
end

local function CancelApplicationAndMark(row, id)
  if not id or not C_LFGList or not C_LFGList.CancelApplication then return end
  local ok, err = pcall(function() C_LFGList.CancelApplication(id) end)
  if not ok and UIErrorsFrame and err then
    UIErrorsFrame:AddMessage("EFJ: Abmelden fehlgeschlagen", 1, 0.2, 0.2)
    DBG("CancelApplication error:", err)
    return
  end
  if EFJ.State and EFJ.State.applications then EFJ.State.applications[id] = "cancelled" end
  if row and row.join then
    row.join:SetEnabled(false)
    row.join:SetAlpha(0.5)
    row.join:SetText("Abgemeldet")
  end
end

local function ResultMatchesFilters(res)
  if not res then return false end
  local kind = ClassifyResult(res)
  if kind == "MPLUS" then return EquiFastJoinDB.showMythicPlus end
  if kind == "RAID" then return EquiFastJoinDB.showRaids end
  if kind == "DUNGEON" then return EquiFastJoinDB.showDungeons end
  if kind == "PVP" then return EquiFastJoinDB.showPvP end
  if kind == "CUSTOM" then return EquiFastJoinDB.showCustom end
  return false
end

-- UI --------------------------------------------------------------------------
EFJ.UI = { rows = {}, visibleIDs = {}, mode = "lfg" }
local ROW_HEIGHT = 54
local MAX_ROWS = 30

local function CreateRow(parent, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(parent:GetWidth()-20, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 4, -(index-1)*ROW_HEIGHT)

  row.iconLeader = row:CreateTexture(nil,"ARTWORK")
  row.iconLeader:SetSize(20,20); row.iconLeader:SetPoint("TOPLEFT",0,-2)

  row.textLeader = row:CreateFontString(nil,"ARTWORK","GameFontNormal")
  row.textLeader:SetPoint("LEFT", row.iconLeader,"RIGHT",4,0)
  row.textLeader:SetJustifyH("LEFT")

  row.classIcons = {}
  local holder = CreateFrame("Frame", nil, row)
  holder:SetSize(128,20); holder:SetPoint("LEFT", row.textLeader,"RIGHT",4,0)
  row.classHolder=holder

  row.textActivity = row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
  row.textActivity:SetPoint("TOPLEFT", row.iconLeader,"BOTTOMLEFT",0,-4)
  row.textActivity:SetWidth(parent:GetWidth()-168)
  row.textActivity:SetJustifyH("LEFT")

  row.textNote = row:CreateFontString(nil,"ARTWORK","GameFontDisableSmall")
  row.textNote:SetPoint("TOPLEFT", row.textActivity,"BOTTOMLEFT",0,-2)
  row.textNote:SetWidth(parent:GetWidth()-168)
  row.textNote:SetJustifyH("LEFT")

  row.join = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.join:SetSize(84,26); row.join:SetPoint("RIGHT",-32,0); row.join:SetText("Beitreten")

  row:Hide(); return row
end

local function UpdateRowWidths(self)
  if not self.frame then return end
  local w = self.frame:GetWidth()
  if self.content then self.content:SetWidth(w-32) end
  for _,row in ipairs(self.rows) do
    row:SetWidth(w-20)
    row.textActivity:SetWidth(w-168)
    row.textNote:SetWidth(w-168)
  end
end

function EFJ.UI:Create()
  if self.frame then return end
  local f = CreateFrame("Frame","EquiFastJoinFrame",UIParent,"BackdropTemplate")
  f:SetSize(EquiFastJoinDB.width or 400, EquiFastJoinDB.height or 300)
  f:ClearAllPoints(); f:SetPoint(EquiFastJoinDB.point or "CENTER", UIParent, EquiFastJoinDB.rel or "CENTER", EquiFastJoinDB.x or 0, EquiFastJoinDB.y or 0)
  f:SetResizable(true); f:SetResizeBounds(300,200, 1200, 900)
  f:SetScale(EquiFastJoinDB.scale or 1.0)
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not EquiFastJoinDB.lockFrame then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point,_,rel,x,y = self:GetPoint()
    EquiFastJoinDB.point, EquiFastJoinDB.rel, EquiFastJoinDB.x, EquiFastJoinDB.y = point, rel, x, y
  end)
  f:SetScript("OnSizeChanged", function(self, w, h)
    EquiFastJoinDB.width, EquiFastJoinDB.height = math.floor(w), math.floor(h)
    UpdateRowWidths(EFJ.UI)
  end)

  f:SetBackdrop({ bgFile="Interface/Tooltips/UI-Tooltip-Background", insets={left=0,right=0,top=0,bottom=0} })
  f:SetBackdropColor(0,0,0,0.5)

  local title = f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
  title:SetPoint("TOPLEFT",8,-8); title:SetText("EquiFastJoin"); f.title=title

  local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
  close:SetPoint("TOPRIGHT",0,0)
  close:SetScript("OnClick", function()
    if #EFJ.UI.visibleIDs>0 then EquiFastJoinDB.lastDismissSignature=BuildSignature(EFJ.UI.visibleIDs) end
    f:Hide()
  end)

  local scroll = CreateFrame("ScrollFrame","EquiFastJoinScroll",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 4,-30)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",-28,4)
  local content = CreateFrame("Frame",nil,scroll)
  content:SetSize(f:GetWidth()-32, ROW_HEIGHT*MAX_ROWS)
  scroll:SetScrollChild(content)
  f.scroll=scroll; f.content=content

  local grip = CreateFrame("Frame", nil, f)
  grip:SetSize(16,16); grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 22)
  local tex = grip:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(true); tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip.tex=tex
  grip:EnableMouse(true)
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT"); tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down") end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up") end)

  self.rows={}
  for i=1,MAX_ROWS do self.rows[i]=CreateRow(content,i) end

  f:Hide(); self.frame=f; self.content=content
end

function EFJ.UI:UpdateJoinButton(row, id)
  if not row or not id then return end
  local cached = EFJ.State and EFJ.State.applications and EFJ.State.applications[id]
  local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo and C_LFGList.GetApplicationInfo(id) or nil
  appStatus = appStatus or cached or "none"
  if appStatus == "applied" or pendingStatus then
    row.join:SetEnabled(true)
    row.join:SetAlpha(1)
    row.join:SetText("Abmelden")
    row.join:SetScript("OnClick", function() CancelApplicationAndMark(row, id) end)
  elseif appStatus == "invited" then
    row.join:SetEnabled(false)
    row.join:SetAlpha(0.6)
    row.join:SetText("Eingeladen")
  else
    row.join:SetEnabled(true)
    row.join:SetAlpha(1)
    row.join:SetText("Beitreten")
    row.join:SetScript("OnClick", function() TryJoinAndMark(row, id) end)
  end
end

function EFJ.UI:MarkAppliedByID(id, newStatus)
  if not id then return end
  if EFJ.State and EFJ.State.applications then EFJ.State.applications[id] = newStatus end
  for _, row in ipairs(self.rows) do
    if row:IsShown() and row.resultID == id then
      if newStatus == "applied" or newStatus == "applied_with_role" then
        row.join:SetEnabled(true)
        row.join:SetAlpha(1)
        row.join:SetText("Abmelden")
        row.join:SetScript("OnClick", function() CancelApplicationAndMark(row, id) end)
      elseif newStatus == "invited" then
        row.join:SetEnabled(false)
        row.join:SetAlpha(0.6)
        row.join:SetText("Eingeladen")
      elseif newStatus == "declined" or newStatus == "declined_full" or newStatus == "declined_delisted" or newStatus == "timedout" or newStatus == "cancelled" or newStatus == "none" then
        if EFJ.State and EFJ.State.applications then EFJ.State.applications[id] = nil end
        row.join:SetEnabled(true)
        row.join:SetAlpha(1)
        row.join:SetText("Beitreten")
        row.join:SetScript("OnClick", function() TryJoinAndMark(row, id) end)
      end
      break
    end
  end
end

function EFJ.UI:StartQuickTicker()
  if self.quickTicker then return end
  self.quickTicker = C_Timer.NewTicker(3, function()
    if self.mode ~= "quickjoin" then self:StopQuickTicker(); return end
    local entries = GatherQuickJoinEntries()
    if not entries or #entries == 0 then
      if self.frame and self.frame:IsShown() then self.frame:Hide() end
      self.mode = "none"
      self:StopQuickTicker()
      return
    end
    -- Re-render to remove stale rows
    self:ShowQuickJoin(entries)
  end)
end

function EFJ.UI:StopQuickTicker()
  if self.quickTicker then self.quickTicker:Cancel(); self.quickTicker = nil end
end

-- Show a lightweight banner row for Quick Join or Test
function EFJ.UI:ShowBanner(headline, subline)
  self:Create()
  for i,row in ipairs(self.rows) do row:Hide() end
  local row = self.rows[1]
  row.textLeader:SetText(headline or "Schnellbeitritt")
  row.iconLeader:SetTexture(134400) -- chat bubble
  row.iconLeader:SetTexCoord(0,1,0,1)
  row.textActivity:SetText(subline or "Es sind neue Schnellbeitritt-Vorschläge verfügbar.")
  row.textNote:SetText("")
  row.join:SetText("OK")
  row.join:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then
      if UIErrorsFrame then UIErrorsFrame:AddMessage("EFJ: Nicht im Kampf verfügbar", 1, 0.2, 0.2) end
    else
      if FriendsFrame and ToggleFriendsFrame then ToggleFriendsFrame(1) end
    end
    self.frame:Hide()
  end)
  row.join:SetEnabled(true)
  row:Show()
  self.visibleIDs = {}
  self.mode = "banner"
  self.frame:Show()
end

function EFJ.UI:ShowTest()
  self:ShowBanner("EquiFastJoin Test", "Dies ist ein Testeintrag.")
end

local function SetQuickJoinMemberIcons(row, classes)
  for i,tex in ipairs(row.classIcons) do tex:Hide() end
  local prev, shown = nil, 0
  for _, classEN in ipairs(classes or {}) do
    shown = shown + 1
    local tex=row.classIcons[shown]
    if not tex then tex=row.classHolder:CreateTexture(nil,"ARTWORK"); row.classIcons[shown]=tex; tex:SetSize(16,16) end
    if prev then tex:SetPoint("LEFT",prev,"RIGHT",2,0) else tex:SetPoint("LEFT",row.classHolder,"LEFT",0,0) end
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    local c=CLASS_ICON_TCOORDS[classEN]; if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) else tex:SetTexCoord(0,1,0,1) end
    tex:Show(); prev=tex
    if shown>=6 then break end
  end
end

function EFJ.UI:ShowQuickJoin(entries)
  self:Create()
  self.mode = "quickjoin"
  self.visibleIDs = {}
  local filtered = {}
  for _,e in ipairs(entries) do
    if e.res and ResultMatchesFilters(e.res) then table.insert(filtered, e) end
  end
  for i,row in ipairs(self.rows) do
    local e = filtered[i]
    if e then
      local leaderClass = e.leaderClass -- class of the friend/guildie
      row.textLeader:SetText(ColorizeByClass(e.leaderName, leaderClass))
      if leaderClass and CLASS_ICON_TCOORDS[leaderClass] then
        row.iconLeader:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        local c=CLASS_ICON_TCOORDS[leaderClass]; row.iconLeader:SetTexCoord(c[1],c[2],c[3],c[4])
        row.iconLeader:Show()
      else
        row.iconLeader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        row.iconLeader:SetTexCoord(0,1,0,1)
        row.iconLeader:Show()
      end

      local color = e.res and BuildCategoryColor(e.res) or "|cffffffff"
      row.textActivity:SetText((color.."%s|r"):format(e.activityText or "-"))
      local title = e.res and (e.res.name or e.comment or "") or (e.comment or "")
      row.textNote:SetText(title)
      if e.res and e.lfgID then
        if SetRoleIconsFromLFG then SetRoleIconsFromLFG(row, e.lfgID) end
      else
        for i,tex in ipairs(row.classIcons) do tex:Hide() end
      end

      if e.lfgID then
        row.join:SetEnabled(true); row.join:SetAlpha(1)
        row.join:SetText("Beitreten")
        row.join:SetScript("OnClick", function() TryJoinAndMark(row, e.lfgID) end)
        row.resultID = e.lfgID
        self:UpdateJoinButton(row, e.lfgID)
      else
        row.join:SetEnabled(false); row.join:SetAlpha(0.4)
        row.join:SetText("Nicht LFG")
        row.join:SetScript("OnClick", nil)
        row.resultID = nil
      end

      row:Show()
    else
      row:Hide()
    end
  end
  if #filtered == 0 then
    if self.frame and self.frame:IsShown() then self.frame:Hide() end
    self.mode = "none"
    self:StopQuickTicker()
    return
  end
  self.frame:Show()
  self:StartQuickTicker()
end

SetMemberIconsFromLFG = function(row, id, num)
  for i,tex in ipairs(row.classIcons) do tex:Hide() end
  local prev, shown = nil, 0
  for idx=1,math.min(num or 0, 8) do
    local name,classEN = C_LFGList.GetSearchResultMemberInfo(id, idx)
    if classEN then
      shown = shown + 1
      local tex=row.classIcons[shown]
      if not tex then tex=row.classHolder:CreateTexture(nil,"ARTWORK"); row.classIcons[shown]=tex; tex:SetSize(16,16) end
      if prev then tex:SetPoint("LEFT",prev,"RIGHT",2,0) else tex:SetPoint("LEFT",row.classHolder,"LEFT",0,0) end
      tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
      local c=CLASS_ICON_TCOORDS[classEN]; if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) else tex:SetTexCoord(0,1,0,1) end
      tex:Show(); prev=tex
      if shown>=6 then break end
    end
  end
end

SetRoleIconsFromLFG = function(row, id)
  for i,tex in ipairs(row.classIcons) do tex:Hide() end
  local counts = C_LFGList.GetSearchResultMemberCounts and C_LFGList.GetSearchResultMemberCounts(id)
  if not counts then return end
  local order = {"TANK","HEALER","DAMAGER"}
  local roleAtlas = {
    TANK = "groupfinder-icon-role-micro-tank",
    HEALER = "groupfinder-icon-role-micro-heal",
    DAMAGER = "groupfinder-icon-role-micro-dps",
  }
  local prev, shown = nil, 0
  for _,role in ipairs(order) do
    local rem = counts[role.."_REMAINING"] or 0
    for _ = 1, rem do
      shown = shown + 1
      local tex=row.classIcons[shown]
      if not tex then tex=row.classHolder:CreateTexture(nil,"ARTWORK"); row.classIcons[shown]=tex; tex:SetSize(16,16) end
      if prev then tex:SetPoint("LEFT",prev,"RIGHT",2,0) else tex:SetPoint("LEFT",row.classHolder,"LEFT",0,0) end
      if tex.SetAtlas then
        tex:SetAtlas(roleAtlas[role] or "roleicon-tiny-dps")
      else
        tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
        local l, r, t, b = GetTexCoordsForRole and GetTexCoordsForRole(role)
        if l then tex:SetTexCoord(l, r, t, b) else tex:SetTexCoord(0,1,0,1) end
      end
      tex:Show(); prev=tex
      if shown>=8 then break end
    end
    if shown>=8 then break end
  end
end

local function normalizeName(n)
  if not n then return nil end
  local base = n:match("^[^-]+") or n
  return base
end

FindLeaderClass = function(id, leaderName)
  if not leaderName then return nil end
  local res = C_LFGList.GetSearchResultInfo(id)
  local n = res and res.numMembers or 0
  for i=1,n do
    local name,classEN = C_LFGList.GetSearchResultMemberInfo(id, i)
    if normalizeName(name) == normalizeName(leaderName) then return classEN end
  end
  return nil
end

function EFJ.UI:SetRows(ids)
  self.visibleIDs = {}
  self.mode = "lfg"
  for i,row in ipairs(self.rows) do
    local id = ids[i]
    if id then
      local res = GetFreshResultInfo(id)
      if res and ResultMatchesFilters(res) then
        local leaderName = res.leaderName or "-"
        local leaderClass = FindLeaderClass(id, leaderName)
        row.textLeader:SetText(ColorizeByClass(leaderName, leaderClass))
        if leaderClass and CLASS_ICON_TCOORDS[leaderClass] then
          row.iconLeader:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
          local c=CLASS_ICON_TCOORDS[leaderClass]; row.iconLeader:SetTexCoord(c[1],c[2],c[3],c[4])
          row.iconLeader:Show()
        else
          row.iconLeader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
          row.iconLeader:SetTexCoord(0,1,0,1)
          row.iconLeader:Show()
        end

        local color = BuildCategoryColor(res)
        row.textActivity:SetText((color.."%s|r"):format(res.activityText or "Unbekannte Aktivität"))
        row.textNote:SetText(res.name or res.comment or "")
        if SetRoleIconsFromLFG then SetRoleIconsFromLFG(row, id) end

        row.join:SetEnabled(true); row.join:SetAlpha(1)
        row.join:SetText("Beitreten")
        row.join:SetScript("OnClick", function() TryJoinAndMark(row, id) end)
        row.resultID = id
        self:UpdateJoinButton(row, id)

        row:Show()
        table.insert(self.visibleIDs, id)
      else
        row.resultID = nil
        row:Hide()
      end
    else
      row.resultID = nil
      row:Hide()
    end
  end
end

local function ToastForIDs(ids)
  if not EquiFastJoinDB.showToast or not RaidWarningFrame then return end
  if #ids == 0 then return end
  local id = ids[1]
  local res = GetFreshResultInfo(id); if not res then return end
  local act = res.activityID and C_LFGList.GetActivityInfoTable(res.activityID)
  local text = res.activityText or "Neuer Eintrag"
  local color = "|cffffffff"
  if res.isMythicPlusActivity or (act and act.fullName and act.fullName:find("%+")) then
    color="|cff00ff88" -- green-ish
  elseif act and act.categoryID==2 then
    color="|cffffa000" -- orange (raid)
  elseif act and act.categoryID==1 then
    color="|cff4fb2ff" -- blue (dungeon)
  elseif act and (act.categoryID==3 or act.categoryID==4) then
    color="|cffff4f4f" -- red (pvp)
  end
  RaidNotice_AddMessage(RaidWarningFrame, ("EquiFastJoin: %s%s|r"):format(color, text), ChatTypeInfo["RAID_WARNING"])
end

function EFJ.UI:ShowListFor(ids)
  self:Create()
  self:StopQuickTicker()
  self:SetRows(ids)
  if #self.visibleIDs==0 then
    if self.frame and self.frame:IsShown() then self.frame:Hide() end
    self.mode = "lfg"
    return
  end
  if EquiFastJoinDB.playSound and PlaySound then
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then PlaySound(SOUNDKIT.IG_MAINMENU_OPEN) else PlaySound(8959) end
  end
  ToastForIDs(self.visibleIDs)
  self.frame:Show()
end

function EFJ.UI:HideIfEmpty()
  if self.frame and self.frame:IsShown() and (#self.visibleIDs==0) then
    self.frame:Hide()
  end
end

-- Core processing -------------------------------------------------------------
local function GatherResults()
  local _,list = C_LFGList.GetSearchResults()
  return (type(list)=="table") and list or {}
end

local function HasQuickJoinSuggestions()
  if not C_SocialQueue or not C_SocialQueue.GetAllGroups then return false end
  local groups = C_SocialQueue.GetAllGroups()
  return groups and #groups > 0
end

BuildCategoryColor = function(res)
  local kind = ClassifyResult(res)
  if kind == "MPLUS" then return "|cff00ff88" end -- green-ish
  if kind == "RAID" then return "|cffffa000" end -- orange
  if kind == "DUNGEON" then return "|cff4fb2ff" end -- blue
  if kind == "PVP" then return "|cffff4f4f" end -- red
  if kind == "CUSTOM" then return "|cffbfbfbf" end -- grey
  return "|cffffffff"
end

-- Quick Join helpers ----------------------------------------------------------
GatherQuickJoinEntries = function()
  if not C_SocialQueue or not C_SocialQueue.GetAllGroups then return {} end
  local groups = C_SocialQueue.GetAllGroups() or {}
  local out = {}
  local seen = {}
  for _, guid in ipairs(groups) do
    local players = C_SocialQueue.GetGroupMembers(guid)
    local queues = C_SocialQueue.GetGroupQueues and C_SocialQueue.GetGroupQueues(guid)
    local lfgListID, chosenQueue
    if type(queues) == "table" then
      for _, q in ipairs(queues) do
        if type(q) == "table" and q.eligible and q.queueData and q.queueData.queueType == 'lfglist' and q.queueData.lfgListID then
          lfgListID = q.queueData.lfgListID
          chosenQueue = q
          break
        end
      end
    end
    -- Only show QuickJoin entries that map to an eligible LFG listing
    if lfgListID and (not seen[lfgListID]) then
      local res = GetFreshResultInfo(lfgListID)
      if res then
        seen[lfgListID] = true
        local leaderName, leaderClass
        local memberClasses = {}
        if players and #players>0 then
          local m = players[1]
          local name
          if SocialQueueUtil_GetRelationshipInfo then
            local n = SocialQueueUtil_GetRelationshipInfo(m.guid, nil, m.clubId)
            name = type(n) == 'string' and n:gsub("|r", "") or nil
          end
          if not name then
            local n2 = GetPlayerInfoByGUID(m.guid)
            name = (type(n2)=="string" and n2) or (type(n2)=="table" and n2[1]) or "-"
          end
          leaderName = name
          local _, _, _, _, classFile = GetPlayerInfoByGUID(m.guid)
          leaderClass = classFile
          for i=1,math.min(#players,8) do
            local _, _, _, _, classFile2 = GetPlayerInfoByGUID(players[i].guid)
            if classFile2 then table.insert(memberClasses, classFile2) end
          end
        end
        table.insert(out, {
          guid=guid,
          lfgID=lfgListID,
          leaderName=leaderName or "-",
          leaderClass=leaderClass,
          activityText=res.activityText or res.name or "Unbekannte Aktivität",
          comment=res.name or res.comment or "",
          memberClasses=memberClasses,
          res=res,
        })
      end
    end
  end
  return out
end

local function ProcessResultsAndMaybeShow(origin)
  if IsInInstance() or IsInGroup() or IsInRaid() then return end
  -- If QuickJoin view is active, don't override it with LFG updates
  if EFJ.UI and EFJ.UI.mode == "quickjoin" then return end
  local ids = GatherResults()
  DBG("Process", origin or "update", "#ids:", #ids)
  if #ids==0 then
    EFJ.UI.visibleIDs = {}
    EFJ.UI:HideIfEmpty()
    return
  end
  -- Only show results that also appear in QuickJoin suggestions
  local quick = GatherQuickJoinEntries() or {}
  if #quick > 0 then
    local quickSet = {}
    for _, e in ipairs(quick) do if e.lfgID then quickSet[e.lfgID] = true end end
    local filtered = {}
    for _, id in ipairs(ids) do if quickSet[id] then table.insert(filtered, id) end end
    ids = filtered
  else
    -- If there are no QuickJoin suggestions, don't show generic LFG lists
    ids = {}
  end
  if #ids==0 then
    EFJ.UI.visibleIDs = {}
    EFJ.UI:HideIfEmpty()
    return
  end
  local sig = BuildSignature(ids)
  if sig == (EquiFastJoinDB.lastDismissSignature or "") then return end
  EFJ.UI:ShowListFor(ids)
end

-- Events ----------------------------------------------------------------------
local ev=CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("SOCIAL_QUEUE_UPDATE")
ev:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
ev:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
ev:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
ev:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_,event,...)
  local arg1, arg2, arg3, arg4 = ...
  if event=="ADDON_LOADED" and arg1==ADDON_NAME then
    EquiFastJoinDB=EquiFastJoinDB or {}; CopyDefaults(EquiFastJoinDB,DEFAULTS)
    EFJ.UI:Create()
    if not EFJ.Options or not EFJ.Options.panel then
      -- Minimal options shim (in case earlier panel already exists in your build keep as-is)
      EFJ.Options = EFJ.Options or {}
      function EFJ.Options:Create()
        if self.panel then return end
        local panel=CreateFrame("Frame", "EquiFastJoinOptions", UIParent); panel.name="EquiFastJoin"
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("EquiFastJoin Optionen")

        local function AddCheck(text, tooltip, key, x, y)
          local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
          cb:SetPoint("TOPLEFT", x, y)
          cb.text = cb.text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
          cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
          cb.text:SetText(text)
          cb.tooltip = tooltip
          cb:SetChecked(EquiFastJoinDB[key])
          cb:SetScript("OnClick", function(self)
            EquiFastJoinDB[key] = self:GetChecked() and true or false
            ProcessResultsAndMaybeShow("OPT:"..key)
          end)
          return cb
        end

        local function AddButton(text, x, y, onClick)
          local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
          btn:SetPoint("TOPLEFT", x, y)
          btn:SetSize(160, 24)
          btn:SetText(text)
          btn:SetScript("OnClick", onClick)
          return btn
        end

        local function AddSlider(label, key, minV, maxV, step, x, y)
          local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
          text:SetPoint("TOPLEFT", x, y)
          text:SetText(label)
          local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
          slider:SetPoint("TOPLEFT", x, y - 18)
          slider:SetMinMaxValues(minV, maxV)
          slider:SetValueStep(step)
          slider:SetObeyStepOnDrag(true)
          slider:SetValue(EquiFastJoinDB[key] or 1.0)
          local low = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
          low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
          low:SetText(tostring(minV))
          local high = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
          high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
          high:SetText(tostring(maxV))
          slider:SetScript("OnValueChanged", function(self, value)
            EquiFastJoinDB[key] = tonumber(string.format("%.2f", value))
            if EFJ.UI.frame then EFJ.UI.frame:SetScale(EquiFastJoinDB.scale or 1.0) end
          end)
          return slider
        end

        local y = -48
        AddCheck("Dungeons anzeigen", "Zeigt Dungeon-Gruppen", "showDungeons", 16, y)
        AddCheck("Raids/Schlachtzüge anzeigen", "Zeigt Raid-Gruppen", "showRaids", 220, y)
        y = y - 28
        AddCheck("Mythic+ anzeigen", "Zeigt M+ Gruppen", "showMythicPlus", 16, y)
        AddCheck("PvP anzeigen", "Zeigt PvP-Gruppen", "showPvP", 220, y)
        y = y - 28
        AddCheck("Benutzerdefiniert/Quest anzeigen", "Zeigt benutzerdefinierte/Quest-Gruppen", "showCustom", 16, y)
        y = y - 28
        AddCheck("Bei Schnellbeitritt auto-öffnen", "Öffnet Liste bei QuickJoin Vorschlägen", "openOnQuickJoin", 16, y)
        y = y - 28
        AddCheck("Sound abspielen", "Spielt einen kurzen Sound beim Öffnen", "playSound", 16, y)
        AddCheck("Toast Nachricht", "Zeigt eine RaidWarning Toast", "showToast", 220, y)
        y = y - 28
        AddCheck("Rahmen sperren", "Verhindert Verschieben des Fensters", "lockFrame", 16, y)
        y = y - 48
        AddSlider("Skalierung", "scale", 0.75, 1.50, 0.05, 16, y)
        y = y - 64
        AddButton("Testfenster", 16, y, function() EFJ.UI:ShowTest() end)
        AddButton("Jetzt aktualisieren", 200, y, function() ProcessResultsAndMaybeShow("OPT_BTN") end)

        -- Register options in new Settings UI (Retail) or old Interface Options
        if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
          local category = Settings.RegisterCanvasLayoutCategory(panel, "EquiFastJoin")
          Settings.RegisterAddOnCategory(category)
        elseif InterfaceOptions_AddCategory then
          InterfaceOptions_AddCategory(panel)
        end
        self.panel=panel
      end
      EFJ.Options:Create()
    end
    DBG("Addon geladen. Initialisiere Aktualisierung.")
    -- Initial search and periodic refresh for LFG results
    C_Timer.After(1.0, function()
      pcall(function() C_LFGList.Search(0, "", 0, 0) end)
      C_Timer.After(0.5, function()
        pcall(function() C_LFGList.RefreshResults() end)
        ProcessResultsAndMaybeShow("INIT")
      end)
    end)
    C_Timer.NewTicker(10, function()
      pcall(function() C_LFGList.RefreshResults() end)
      ProcessResultsAndMaybeShow("TICK")
    end)
  else
    -- On relevant activity or quick-join updates, refresh and re-evaluate
    if (event == "LFG_LIST_SEARCH_RESULT_UPDATED"
      or event == "LFG_LIST_SEARCH_RESULTS_RECEIVED"
      or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE") then
      pcall(function() C_LFGList.RefreshResults() end)
    end
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
      -- arg1 = searchResultID, arg2 = newStatus
      if EFJ.UI and EFJ.UI.MarkAppliedByID then
        EFJ.UI:MarkAppliedByID(arg1, arg2)
      end
    end
    C_Timer.After(0.05, function()
      if event == "SOCIAL_QUEUE_UPDATE" and EquiFastJoinDB.openOnQuickJoin and not IsInInstance() and not IsInGroup() and HasQuickJoinSuggestions() then
        local entries = GatherQuickJoinEntries()
        if entries and #entries > 0 then
          EFJ.UI:ShowQuickJoin(entries)
          return
        end
      end
      -- Otherwise show regular LFG results if available
      ProcessResultsAndMaybeShow(event)
    end)
  end
end)

-- Slash commands --------------------------------------------------------------
local function EFJ_OpenOptions()
  if InCombatLockdown and InCombatLockdown() then
    if UIErrorsFrame then UIErrorsFrame:AddMessage("EFJ: Optionen im Kampf gesperrt", 1, 0.2, 0.2) end
    return
  end
  if Settings and Settings.OpenToCategory then
    local category = Settings.GetCategory and Settings.GetCategory("EquiFastJoin")
    if category then Settings.OpenToCategory(category.ID or (category.GetID and category:GetID()) ) return end
  end
  if InterfaceOptionsFrame and InterfaceOptionsFrame_OpenToCategory and EFJ.Options and EFJ.Options.panel then
    InterfaceOptionsFrame_OpenToCategory(EFJ.Options.panel)
    InterfaceOptionsFrame_OpenToCategory(EFJ.Options.panel)
  end
end

SLASH_EFJ1 = "/efj"
SlashCmdList["EFJ"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "test" then
    EFJ.UI:ShowTest()
  elseif msg == "show" then
    local entries = GatherQuickJoinEntries()
    if entries and #entries > 0 then EFJ.UI:ShowQuickJoin(entries) else if EFJ.UI.frame then EFJ.UI.frame:Hide() end end
  elseif msg == "hide" then
    if EFJ.UI.frame then EFJ.UI.frame:Hide() end
  elseif msg == "debug on" then
    EquiFastJoinDB.debug = true; print("EFJ: Debug an")
  elseif msg == "debug off" then
    EquiFastJoinDB.debug = false; print("EFJ: Debug aus")
  elseif msg == "options" or msg == "opt" then
    EFJ_OpenOptions()
  else
    print("EFJ: Verwende /efj test | show | hide | options | debug on|off")
  end
end
