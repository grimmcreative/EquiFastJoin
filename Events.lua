-- EquiFastJoin: Events
local _, EFJ = ...

local ADDON_NAME = ...
local L = EFJ.L
local DBG = EFJ.DBG

-- Events ----------------------------------------------------------------------
local ev = CreateFrame("Frame")
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
    EquiFastJoinDB=EquiFastJoinDB or {}; EFJ.CopyDefaults(EquiFastJoinDB, EFJ.DEFAULTS)
    EFJ.UI:Create()
    if not EFJ.Options or not EFJ.Options.panel then
      EFJ.Options = EFJ.Options or {}
      function EFJ.Options:Create()
        if self.panel then return end
        local panel=CreateFrame("Frame", "EquiFastJoinOptions", UIParent); panel.name="EquiFastJoin"
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(L["EquiFastJoin Options"])

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
            EFJ.ProcessResultsAndMaybeShow("OPT:"..key)
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
          local slider = CreateFrame("Slider", nil, panel, "UISliderTemplateWithLabels")
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
        AddCheck(L["Show Dungeons"], L["Show dungeons"], "showDungeons", 16, y)
        AddCheck(L["Show Raids"], L["Show raids"], "showRaids", 220, y)
        y = y - 28
        AddCheck(L["Show Mythic+"], L["Show M+ groups"], "showMythicPlus", 16, y)
        AddCheck(L["Show PvP"], L["Show PvP groups"], "showPvP", 220, y)
        y = y - 28
        AddCheck(L["Show Custom/Quest"], L["Show custom/quest groups"], "showCustom", 16, y)
        y = y - 28
        AddCheck(L["Auto-open on Quick Join"], L["Opens list on Quick Join suggestions"], "openOnQuickJoin", 16, y)
        y = y - 28
        AddCheck(L["Play Sound"], L["Plays a short sound on open"], "playSound", 16, y)
        AddCheck(L["Toast Message"], L["Shows a RaidWarning toast"], "showToast", 220, y)
        y = y - 28
        AddCheck(L["Lock Frame"], L["Prevents moving the window"], "lockFrame", 16, y)
        y = y - 48
        AddSlider(L["Scale"], "scale", 0.75, 1.50, 0.05, 16, y)
        y = y - 64
        AddButton(L["Test Window"], 16, y, function() EFJ.UI:ShowTest() end)
        AddButton(L["Refresh Now"], 200, y, function() EFJ.ProcessResultsAndMaybeShow("OPT_BTN") end)

        if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
          local category = Settings.RegisterCanvasLayoutCategory(panel, "EquiFastJoin")
          Settings.RegisterAddOnCategory(category)
        end
        self.panel=panel
      end
      EFJ.Options:Create()
    end
    DBG("Addon loaded. Initializing refresh.")
    C_Timer.After(1.0, function()
      pcall(function() if not (InCombatLockdown and InCombatLockdown()) then C_LFGList.RefreshResults() end end)
      C_Timer.After(0.5, function()
        EFJ.ProcessResultsAndMaybeShow("INIT")
      end)
    end)
    C_Timer.NewTicker(10, function()
      pcall(function() if not (InCombatLockdown and InCombatLockdown()) then C_LFGList.RefreshResults() end end)
      EFJ.ProcessResultsAndMaybeShow("TICK")
    end)
  else
    if (event == "LFG_LIST_SEARCH_RESULT_UPDATED"
      or event == "LFG_LIST_SEARCH_RESULTS_RECEIVED"
      or event == "LFG_LIST_ACTIVE_ENTRY_UPDATE") then
      pcall(function() if not (InCombatLockdown and InCombatLockdown()) then C_LFGList.RefreshResults() end end)
    end
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
      if EFJ.UI and EFJ.UI.MarkAppliedByID then
        EFJ.UI:MarkAppliedByID(arg1, arg2)
      end
    end
    C_Timer.After(0.05, function()
      if event == "SOCIAL_QUEUE_UPDATE" and EquiFastJoinDB.openOnQuickJoin and not IsInInstance() and not IsInGroup() and EFJ.HasQuickJoinSuggestions() then
        local entries = EFJ.GatherQuickJoinEntries()
        if entries and #entries > 0 then
          EFJ.UI:ShowQuickJoin(entries)
          return
        end
      end
      EFJ.ProcessResultsAndMaybeShow(event)
    end)
  end
end)
