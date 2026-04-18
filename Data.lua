-- EquiFastJoin: Data
local _, EFJ = ...

local L = EFJ.L
local DBG = EFJ.DBG

-- Helpers ---------------------------------------------------------------------
local function BuildSignature(ids)
  local arr = {}; if type(ids)~="table" then return "" end
  for _,id in ipairs(ids) do table.insert(arr, tostring(id)) end
  table.sort(arr); return table.concat(arr,",")
end
EFJ.BuildSignature = BuildSignature

local function ColorizeByClass(name, classEN)
  if not name then return "-" end
  local c = classEN and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classEN]
  if c then return ("|cff%02x%02x%02x%s|r"):format(c.r*255,c.g*255,c.b*255,name) end
  return name
end
EFJ.ColorizeByClass = ColorizeByClass

-- Robust activity helpers -----------------------------------------------------
local function GetActivityInfoForRes(res)
  if not res then return nil end
  if type(res.activityIDs) == "table" and #res.activityIDs > 0 then
    return C_LFGList.GetActivityInfoTable(res.activityIDs[1])
  end
  return nil
end
EFJ.GetActivityInfoForRes = GetActivityInfoForRes

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
  if categoryID == 2 then return "RAID" end
  if categoryID == 1 then return "DUNGEON" end
  if categoryID == 3 or categoryID == 4 then return "PVP" end
  if categoryID == 6 then return "CUSTOM" end
  local gps = res.generalPlaystyle
  if gps and not (issecretvalue and issecretvalue(gps)) then
    return "OTHER"
  end
  return "OTHER"
end
EFJ.ClassifyResult = ClassifyResult

local function BuildActivityText(res)
  if not res then return L["Unknown Activity"] end
  local act = GetActivityInfoForRes(res)
  if act then
    if act.fullName and act.fullName ~= "" then
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
  return L["Unknown Activity"]
end
EFJ.BuildActivityText = BuildActivityText

local function GetFreshResultInfo(id)
  local info = C_LFGList.GetSearchResultInfo(id)
  if not info then return nil end
  if not (issecretvalue and issecretvalue(info.isDelisted)) and info.isDelisted then return nil end
  info.activityText = BuildActivityText(info)
  return info
end
EFJ.GetFreshResultInfo = GetFreshResultInfo

-- Join logic ------------------------------------------------------------------
-- Forward declare for mutual reference
local CancelApplicationAndMark

local function TryJoin(id)
  if not id then return "error" end
  if InCombatLockdown and InCombatLockdown() then
    if UIErrorsFrame then UIErrorsFrame:AddMessage(L["EFJ: Join blocked in combat"], 1, 0.2, 0.2) end
    return "combat"
  end
  local function OpenApplyDialog()
    if not LFGListApplicationDialog or not LFGListApplicationDialog_Show then
      local _LoadAddOn = C_AddOns.LoadAddOn
      pcall(_LoadAddOn, "Blizzard_LFGList")
      pcall(_LoadAddOn, "Blizzard_LookingForGroupUI")
    end
    if LFGListApplicationDialog_Show and LFGListApplicationDialog then
      LFGListApplicationDialog_Show(LFGListApplicationDialog, id)
      return true
    end
    return false
  end
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
    dps = true
  end
  local function doApply()
    DBG("ApplyToGroup", id, "roles:", tank and "T" or "-", healer and "H" or "-", dps and "D" or "-")
    local ok, err = pcall(function()
      C_LFGList.ApplyToGroup(id, "", tank, healer, dps)
    end)
    if not ok and UIErrorsFrame and err then
      local msg = L["EFJ: Application failed"]
      if type(err) == "string" and err:find("[Bb]locked") then
        msg = L["EFJ: Action blocked (Taint)"]
      end
      UIErrorsFrame:AddMessage(msg, 1, 0.2, 0.2)
      DBG("ApplyToGroup error:", err)
      return false
    end
    return true
  end
  return doApply() and "applied" or "error"
end

local function TryJoinAndMark(row, id)
  local r = TryJoin(id)
  if r == "applied" then
    if row and row.join then
      row.join:SetEnabled(true)
      row.join:SetAlpha(1)
      row.join:SetText(L["Leave"])
      row.join:SetScript("OnClick", function() CancelApplicationAndMark(row, id) end)
    end
  elseif r == "dialog" then
    C_Timer.After(0.5, function() if row then EFJ.UI:UpdateJoinButton(row, id) end end)
    C_Timer.After(2.0, function() if row then EFJ.UI:UpdateJoinButton(row, id) end end)
  else
    if row and row.join then
      row.join:SetEnabled(true)
      row.join:SetAlpha(1)
    end
  end
end
EFJ.TryJoinAndMark = TryJoinAndMark

CancelApplicationAndMark = function(row, id)
  if not id or not C_LFGList or not C_LFGList.CancelApplication then return end
  if InCombatLockdown and InCombatLockdown() then
    if UIErrorsFrame then UIErrorsFrame:AddMessage(L["EFJ: Leave blocked in combat"], 1, 0.2, 0.2) end
    return
  end
  local ok, err = pcall(function() C_LFGList.CancelApplication(id) end)
  if not ok and UIErrorsFrame and err then
    UIErrorsFrame:AddMessage(L["EFJ: Leave failed"], 1, 0.2, 0.2)
    DBG("CancelApplication error:", err)
    return
  end
  if EFJ.State and EFJ.State.applications then EFJ.State.applications[id] = "cancelled" end
  if row and row.join then
    row.join:SetEnabled(false)
    row.join:SetAlpha(0.5)
    row.join:SetText(L["Left"])
  end
end
EFJ.CancelApplicationAndMark = CancelApplicationAndMark

-- Filters ---------------------------------------------------------------------
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
EFJ.ResultMatchesFilters = ResultMatchesFilters

-- Member/role icon helpers (formerly forward-declared) ------------------------
local function normalizeName(n)
  if not n then return nil end
  local base = n:match("^[^-]+") or n
  return base
end

local function FindLeaderClass(id, leaderName)
  if not leaderName then return nil end
  local res = C_LFGList.GetSearchResultInfo(id)
  local n = res and res.numMembers or 0
  for i=1,n do
    local name,classEN = C_LFGList.GetSearchResultMemberInfo(id, i)
    if normalizeName(name) == normalizeName(leaderName) then return classEN end
  end
  return nil
end
EFJ.FindLeaderClass = FindLeaderClass

local function SetMemberIconsFromLFG(row, id, num)
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
EFJ.SetMemberIconsFromLFG = SetMemberIconsFromLFG

local function SetRoleIconsFromLFG(row, id)
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
EFJ.SetRoleIconsFromLFG = SetRoleIconsFromLFG
