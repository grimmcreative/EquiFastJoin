-- EquiFastJoin: Logic
local _, EFJ = ...

local L = EFJ.L
local DBG = EFJ.DBG

-- Core processing -------------------------------------------------------------
local function GatherResults()
  local _,list = C_LFGList.GetSearchResults()
  return (type(list)=="table") and list or {}
end
EFJ.GatherResults = GatherResults

local function HasQuickJoinSuggestions()
  if not C_SocialQueue or not C_SocialQueue.GetAllGroups then return false end
  local groups = C_SocialQueue.GetAllGroups()
  return groups and #groups > 0
end
EFJ.HasQuickJoinSuggestions = HasQuickJoinSuggestions

local function BuildCategoryColor(res)
  local kind = EFJ.ClassifyResult(res)
  if kind == "MPLUS" then return "|cff00ff88" end
  if kind == "RAID" then return "|cffffa000" end
  if kind == "DUNGEON" then return "|cff4fb2ff" end
  if kind == "PVP" then return "|cffff4f4f" end
  if kind == "CUSTOM" then return "|cffbfbfbf" end
  return "|cffffffff"
end
EFJ.BuildCategoryColor = BuildCategoryColor

-- Quick Join helpers ----------------------------------------------------------
local function GatherQuickJoinEntries()
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
    if lfgListID and (not seen[lfgListID]) then
      local res = EFJ.GetFreshResultInfo(lfgListID)
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
        activityText=(res and (res.activityText or res.name)) or L["Quick Join"],
        comment=(res and (res.name or res.comment)) or "",
        memberClasses=memberClasses,
        res=res,
      })
    end
  end
  return out
end
EFJ.GatherQuickJoinEntries = GatherQuickJoinEntries

local function ProcessResultsAndMaybeShow(origin)
  if IsInInstance() or IsInGroup() or IsInRaid() then return end
  if EFJ.UI and EFJ.UI.mode == "quickjoin" then return end
  local ids = GatherResults()
  DBG("Process", origin or "update", "#ids:", #ids)
  if #ids==0 then
    EFJ.UI.visibleIDs = {}
    EFJ.UI:HideIfEmpty()
    return
  end
  local quick = GatherQuickJoinEntries() or {}
  if #quick > 0 then
    local quickSet = {}
    for _, e in ipairs(quick) do if e.lfgID then quickSet[e.lfgID] = true end end
    local filtered = {}
    for _, id in ipairs(ids) do if quickSet[id] then table.insert(filtered, id) end end
    ids = filtered
  else
    ids = {}
  end
  if #ids==0 then
    EFJ.UI.visibleIDs = {}
    EFJ.UI:HideIfEmpty()
    return
  end
  local sig = EFJ.BuildSignature(ids)
  if sig == (EquiFastJoinDB.lastDismissSignature or "") then return end
  EFJ.UI:ShowListFor(ids)
end
EFJ.ProcessResultsAndMaybeShow = ProcessResultsAndMaybeShow
