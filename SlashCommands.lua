-- EquiFastJoin: SlashCommands
local _, EFJ = ...

local L = EFJ.L

-- Slash commands --------------------------------------------------------------
local function EFJ_OpenOptions()
  if InCombatLockdown and InCombatLockdown() then
    if UIErrorsFrame then UIErrorsFrame:AddMessage(L["EFJ: Options blocked in combat"], 1, 0.2, 0.2) end
    return
  end
  if Settings and Settings.OpenToCategory then
    local category = Settings.GetCategory and Settings.GetCategory("EquiFastJoin")
    if category then Settings.OpenToCategory(category.ID or (category.GetID and category:GetID()) ) return end
  end
end

SLASH_EFJ1 = "/efj"
SlashCmdList["EFJ"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "test" then
    EFJ.UI:ShowTest()
  elseif msg == "show" then
    local entries = EFJ.GatherQuickJoinEntries()
    if entries and #entries > 0 then EFJ.UI:ShowQuickJoin(entries) else if EFJ.UI.frame then EFJ.UI.frame:Hide() end end
  elseif msg == "hide" then
    if EFJ.UI.frame then EFJ.UI.frame:Hide() end
  elseif msg == "debug on" then
    EquiFastJoinDB.debug = true; print("EFJ: Debug on")
  elseif msg == "debug off" then
    EquiFastJoinDB.debug = false; print("EFJ: Debug off")
  elseif msg == "options" or msg == "opt" then
    EFJ_OpenOptions()
  else
    print("EFJ: Usage: /efj test | show | hide | options | debug on|off")
  end
end
