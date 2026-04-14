# Testing Patterns

**Analysis Date:** 2026-04-14

## Test Framework

**Runner:**
- Not detected - No test framework configured

**Assertion Library:**
- Not detected - No test library in use

**Run Commands:**
- No automated test suite exists
- Manual testing only: `/efj test` command displays banner (line 484)
- Options button: "Testfenster" (Test Window) in options panel (line 928)

## Test File Organization

**Location:**
- No test files exist in codebase
- Testing is manual via in-game UI testing

**Naming:**
- Not applicable (no test files)

**Structure:**
- Not applicable (no test files)

## Manual Testing Approach

**Built-in Test Commands:**

1. **Banner Test:**
   ```
   /efj test
   ```
   - Displays `EFJ.UI:ShowTest()` which shows a banner with headline "EquiFastJoin Test" and subline "Dies ist ein Testeintrag." (line 483-485)
   - Tests UI rendering without LFG data
   - Button shows "OK" to dismiss

2. **Options Panel Test Button:**
   - Located in options panel UI (line 928)
   - Text: "Testfenster" - Opens test window
   - Triggers: `function() EFJ.UI:ShowTest() end`

3. **Manual Refresh Button:**
   - Located in options panel (line 929)
   - Text: "Jetzt aktualisieren" (Refresh Now)
   - Triggers: `function() ProcessResultsAndMaybeShow("OPT_BTN") end`

4. **Slash Command Suite:**
   ```
   /efj test       # Show test window
   /efj show       # Show Quick Join entries
   /efj hide       # Hide window
   /efj options    # Open options panel
   /efj debug on   # Enable debug logging
   /efj debug off  # Disable debug logging
   ```
   (lines 997-1016)

## Test Structure

**Integration Testing Pattern:**

The addon uses event-driven manual testing:

```lua
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
  -- Event handling logic
end)
```
(lines 838-979)

**Test Verification Points:**
- Visual inspection of UI rendering via test button
- Debug logging output when `EquiFastJoinDB.debug = true`
- Button state transitions (Beitreten → Abmelden → Eingeladen)
- Filter toggling in options panel
- Event-driven updates and LFG result changes

## Mocking

**Framework:**
- Not applicable - No unit test framework

**Patterns:**
- No mocking framework detected
- WoW API calls made directly: `C_LFGList.*`, `C_SocialQueue.*`, `C_Timer.*`
- Protected calls used for error isolation:
  ```lua
  local ok, err = pcall(function()
    C_LFGList.ApplyToGroup(id, "", tank, healer, dps)
  end)
  ```
  (lines 173-175)

**What to Mock (if unit tests added):**
- WoW APIs: `C_LFGList`, `C_SocialQueue`, `C_Timer`
- UI Globals: `UIErrorsFrame`, `RaidWarningFrame`, `CreateFrame`
- WoW Constants: `RAID_CLASS_COLORS`, `CLASS_ICON_TCOORDS`, `InCombatLockdown`

**What NOT to Mock:**
- Local helper functions (should test directly)
- Table operations and string processing
- Event handler logic (should be tested via event simulation)

## Fixtures and Factories

**Test Data:**
- No fixtures defined; manual testing uses live WoW API data
- Test banner uses hardcoded strings:
  ```lua
  function EFJ.UI:ShowTest()
    self:ShowBanner("EquiFastJoin Test", "Dies ist ein Testeintrag.")
  end
  ```
  (line 483-485)

**Location:**
- Test triggering code in main `EquiFastJoin.lua`
- No separate test data directory

## Coverage

**Requirements:**
- No coverage enforcement detected
- Manual coverage via:
  - Debug logging (`/efj debug on` enables verbose output)
  - Options panel testing (toggle each filter)
  - Slash command testing (`/efj test|show|hide|options|debug on|off`)

**View Coverage:**
- No automated coverage tool
- Manual inspection via debug output:
  ```lua
  local function DBG(...)
    if EquiFastJoinDB and EquiFastJoinDB.debug then
      print("|cff33ff99[EFJ]|r", ...)
    end
  end
  ```
  (lines 43-47)

## Test Types

**Manual UI Testing:**
- Scope: Visual verification of UI rendering, button behavior, filter toggles
- Approach:
  1. Enable debug logging: `/efj debug on`
  2. Run test window: `/efj test`
  3. View LFG entries: `/efj show`
  4. Test filters in options panel
  5. Verify button state transitions on application status changes
  6. Test tooltip display and class color rendering

**Event Integration Testing:**
- Scope: Verifies event-driven updates work correctly
- Approach:
  1. Wait for `SOCIAL_QUEUE_UPDATE` events when Quick Join suggestions arrive
  2. Verify `ProcessResultsAndMaybeShow()` is called (check debug output)
  3. Confirm `LFG_LIST_APPLICATION_STATUS_UPDATED` updates button state
  4. Validate row layout recalculates on dynamic height changes

**Combat Lockdown Testing:**
- Scope: Ensures protected action guards work
- Approach:
  1. Test joining while in combat (should fail with message: "EFJ: Beitritt im Kampf gesperrt")
  2. Test cancelling while in combat (same guard at line 209)
  3. Verify options cannot open in combat (line 983)

**E2E Testing:**
- Framework: Not automated
- Approach: Manual end-to-end:
  1. Login to character
  2. Ensure Quick Join suggestions available
  3. Click "Beitreten" button
  4. Verify Blizzard LFG dialog opens (preferred) or application completes
  5. Verify button state changes to "Abmelden"
  6. Test cancellation
  7. Test filter toggles hide/show entries

## Common Testing Scenarios

**Quick Join Rendering:**
```lua
-- Gathers Quick Join entries from C_SocialQueue API
local entries = GatherQuickJoinEntries()
-- Filters by current settings (showRaids, showDungeons, etc.)
-- Displays via EFJ.UI:ShowQuickJoin(entries)
```
(lines 746-802, 969-971)

**LFG Status Updates:**
```lua
-- Triggered by LFG_LIST_APPLICATION_STATUS_UPDATED event
if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
  if EFJ.UI and EFJ.UI.MarkAppliedByID then
    EFJ.UI:MarkAppliedByID(arg1, arg2)
  end
end
```
(lines 961-966)

**Button State Transitions:**
```lua
-- Verifies button updates based on application status
function EFJ.UI:UpdateJoinButton(row, id)
  local cached = EFJ.State and EFJ.State.applications and EFJ.State.applications[id]
  local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo and C_LFGList.GetApplicationInfo(id) or nil
  appStatus = appStatus or cached or "none"
  if appStatus == "applied" or pendingStatus then
    -- Button becomes "Abmelden" (Leave)
  elseif appStatus == "invited" then
    -- Button becomes "Eingeladen" (Invited) - disabled
  else
    -- Button becomes "Beitreten" (Join)
  end
end
```
(lines 391-411)

**Dynamic Row Height Calculation:**
```lua
-- Tests height adjustment for multi-line text
function EFJ.UI:ComputeRowHeight(row)
  if not row or not row:IsShown() then return ROW_HEIGHT end
  local hActivity = math.ceil(row.textActivity:GetStringHeight() or 0)
  local hNote = math.ceil(row.textNote:GetStringHeight() or 0)
  local contentH = math.max(iconH + 4 + hActivity + 2 + hNote, 26)
  local h = math.max(ROW_HEIGHT, contentH + 6)
  row:SetHeight(h)
  return h
end
```
(lines 279-298)

**Filter Application:**
```lua
-- Test each filter toggle updates visibility
function ResultMatchesFilters(res)
  if not res then return false end
  local kind = ClassifyResult(res)
  if kind == "MPLUS" then return EquiFastJoinDB.showMythicPlus end
  if kind == "RAID" then return EquiFastJoinDB.showRaids end
  if kind == "DUNGEON" then return EquiFastJoinDB.showDungeons end
  if kind == "PVP" then return EquiFastJoinDB.showPvP end
  if kind == "CUSTOM" then return EquiFastJoinDB.showCustom end
  return false
end
```
(lines 227-236)

## Debugging Support

**Debug Mode:**
- Enabled via: `/efj debug on`
- Disabled via: `/efj debug off`
- Output format: `[EFJ]` prefix in console (line 45)
- Logs API calls, event processing, and status changes

**Example Debug Output:**
```
[EFJ] ApplyToGroup <id> roles: T - D
[EFJ] Process update #ids: 5
[EFJ] Addon geladen. Initialisiere Aktualisierung.
```

---

*Testing analysis: 2026-04-14*
