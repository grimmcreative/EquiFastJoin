
-- EquiFastJoin - Retail 11.2.0
-- Version 1.7.9 (Event-driven: no manual Search; auto-open on LFG events)

local ADDON_NAME = ...
local EFJ = {}
_G.EquiFastJoin = EFJ

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

-- LFG helpers -----------------------------------------------------------------
-- Forward declare helpers used across sections
local FindLeaderClass
local BuildCategoryColor
local SetMemberIconsFromLFG

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
  -- Ensure result info exists; if not, search+refresh then apply shortly after
  if not C_LFGList.GetSearchResultInfo(id) then
    pcall(function() C_LFGList.Search(0, "", 0, 0) end)
    C_Timer.After(0.2, function()
      pcall(function() C_LFGList.RefreshResults() end)
      C_Timer.After(0.2, doApply)
    end)
    return "applied"
  else
    return doApply() and "applied" or "error"
  end
end

local function TryJoinAndMark(row, id)
  local r = TryJoin(id)
  if r == "applied" then
    if row and row.join then
      row.join:SetEnabled(false)
      row.join:SetAlpha(0.5)
      row.join:SetText("Beworben")
    end
  elseif r == "dialog" then
    -- Keep button enabled; user completes application in Blizzard dialog
  else
    if row and row.join then
      row.join:SetEnabled(true)
      row.join:SetAlpha(1)
    end
  end
end

local function ResultMatchesFilters(res)
  if not res then return false end
  local act = res.activityID and C_LFGList.GetActivityInfoTable(res.activityID) or nil
  local category = act and act.categoryID or nil
  if res.isMythicPlusActivity or (act and act.fullName and act.fullName:find("%+")) then
    return EquiFastJoinDB.showMythicPlus
  end
  if category == 2 then return EquiFastJoinDB.showRaids end
  if category == 1 then return EquiFastJoinDB.showDungeons end
  if category == 3 or category == 4 then return EquiFastJoinDB.showPvP end
  if category == 6 then return EquiFastJoinDB.showCustom end
  return true
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
    if FriendsFrame and ToggleFriendsFrame then ToggleFriendsFrame(1) end
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
    if not e.res or ResultMatchesFilters(e.res) then table.insert(filtered, e) end
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
        SetMemberIconsFromLFG(row, e.lfgID, e.res.numMembers or 0)
      else
        SetQuickJoinMemberIcons(row, e.memberClasses)
      end

      if e.lfgID then
        row.join:SetEnabled(true); row.join:SetAlpha(1)
        row.join:SetText("Beitreten")
        row.join:SetScript("OnClick", function() TryJoinAndMark(row, e.lfgID) end)
      else
        row.join:SetEnabled(false); row.join:SetAlpha(0.4)
        row.join:SetText("Nicht LFG")
        row.join:SetScript("OnClick", nil)
      end

      row:Show()
    else
      row:Hide()
    end
  end
  if #filtered == 0 then
    if self.frame and self.frame:IsShown() then self.frame:Hide() end
    return
  end
  self.frame:Show()
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
        SetMemberIconsFromLFG(row, id, res.numMembers or 0)

        row.join:SetEnabled(true); row.join:SetAlpha(1)
        row.join:SetScript("OnClick", function() TryJoinAndMark(row, id) end)

        row:Show()
        table.insert(self.visibleIDs, id)
      else
        row:Hide()
      end
    else
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
  local act = res.activityID and C_LFGList.GetActivityInfoTable(res.activityID)
  if res.isMythicPlusActivity or (act and act.fullName and act.fullName:find("%+")) then
    return "|cff00ff88" -- green-ish
  elseif act and act.categoryID==2 then
    return "|cffffa000" -- orange (raid)
  elseif act and act.categoryID==1 then
    return "|cff4fb2ff" -- blue (dungeon)
  elseif act and (act.categoryID==3 or act.categoryID==4) then
    return "|cffff4f4f" -- red (pvp)
  elseif act and act.categoryID==6 then
    return "|cffbfbfbf" -- grey (custom/quests)
  end
  return "|cffffffff"
end

-- Quick Join helpers ----------------------------------------------------------
local function GatherQuickJoinEntries()
  if not C_SocialQueue or not C_SocialQueue.GetAllGroups then return {} end
  local groups = C_SocialQueue.GetAllGroups() or {}
  local out = {}
  for _, guid in ipairs(groups) do
    local players = C_SocialQueue.GetGroupMembers(guid)
    local queues = C_SocialQueue.GetGroupQueues and C_SocialQueue.GetGroupQueues(guid)
    local firstQueue = queues and queues[1] or nil
    local lfgListID = (firstQueue and firstQueue.queueData and firstQueue.queueData.queueType == 'lfglist') and firstQueue.queueData.lfgListID or nil
    local res = lfgListID and GetFreshResultInfo(lfgListID) or nil
    local leaderName, leaderClass, actText, comment, numMembers
    local memberClasses = {}
    if players and #players>0 then
      -- Show first member as headline (friend/guildie)
      local m = players[1]
      local name
      if SocialQueueUtil_GetRelationshipInfo then
        local n = SocialQueueUtil_GetRelationshipInfo(m.guid, nil, m.clubId)
        name = type(n) == 'string' and n:gsub("|r", "") or nil
      end
      if not name then
        local n, _, _, _, classFile = GetPlayerInfoByGUID(m.guid)
        name = n or "-"
      end
      leaderName = name
      local _, _, _, _, classFile = GetPlayerInfoByGUID(m.guid)
      leaderClass = classFile
      -- Gather known class icons (friends/guildies in that group)
      for i=1,math.min(#players,8) do
        local n, _, _, _, classFile = GetPlayerInfoByGUID(players[i].guid)
        if classFile then table.insert(memberClasses, classFile) end
      end
    end
    if res then
      actText = res.activityText or res.name or "Unbekannte Aktivität"
      comment = res.comment or ""
      numMembers = res.numMembers or 0
    elseif firstQueue and firstQueue.queueData and SocialQueueUtil_GetQueueName then
      actText = SocialQueueUtil_GetQueueName(firstQueue.queueData)
      comment = ""
      numMembers = 0
    end
    table.insert(out, { guid=guid, lfgID=lfgListID, leaderName=leaderName or "-", leaderClass=leaderClass, activityText=actText or "-", comment=comment or "", memberClasses=memberClasses, res=res })
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
ev:SetScript("OnEvent", function(_,event,arg1)
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
        AddCheck("Bei Schnellbeitritt auto-öffnen", "Öffnet Liste bei QuickJoin Vorschlägen", "openOnQuickJoin", 220, y)
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

        if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
        self.panel=panel
      end
      EFJ.Options:Create()
    end
    DBG("Addon geladen. Initialisiere Suche & Aktualisierung.")
    -- Initial broad search to populate results
    C_Timer.After(1.0, function()
      pcall(function() C_LFGList.Search(0, "", 0, 0) end)
      C_Timer.After(0.5, function()
        pcall(function() C_LFGList.RefreshResults() end)
        ProcessResultsAndMaybeShow("INIT")
      end)
    end)
    -- Periodically refresh search results so new entries appear
    C_Timer.NewTicker(10, function()
      pcall(function() C_LFGList.RefreshResults() end)
      ProcessResultsAndMaybeShow("TICK")
    end)
  else
    -- On relevant activity or quick-join updates, refresh and re-evaluate
    if event == "SOCIAL_QUEUE_UPDATE"
      or event == "LFG_LIST_SEARCH_RESULT_UPDATED"
      or event == "LFG_LIST_SEARCH_RESULTS_RECEIVED"
      or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
      pcall(function() C_LFGList.RefreshResults() end)
    end
    C_Timer.After(0.05, function()
      if event == "SOCIAL_QUEUE_UPDATE" and EquiFastJoinDB.openOnQuickJoin and not IsInInstance() and not IsInGroup() and HasQuickJoinSuggestions() then
        local entries = GatherQuickJoinEntries()
        if entries and #entries > 0 then
          EFJ.UI:ShowQuickJoin(entries)
          return
        end
      end
      ProcessResultsAndMaybeShow(event)
    end)
  end
end)

-- Slash commands --------------------------------------------------------------
local function EFJ_OpenOptions()
  if Settings and Settings.OpenToCategory then
    local category = Settings.GetCategory and Settings.GetCategory("EquiFastJoin")
    if category then Settings.OpenToCategory(category.ID) return end
  end
  if InterfaceOptionsFrame and InterfaceOptionsFrame_OpenToCategory and EFJ.Options and EFJ.Options.panel then
    InterfaceOptionsFrame_OpenToCategory(EFJ.Options.panel)
    InterfaceOptionsFrame_OpenToCategory(EFJ.Options.panel)
  end
end

SlashCmdList = SlashCmdList or {}
SLASH_EFJ1 = "/efj"
SlashCmdList["EFJ"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "test" then
    EFJ.UI:ShowTest()
  elseif msg == "show" then
    ProcessResultsAndMaybeShow("SLASH")
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
