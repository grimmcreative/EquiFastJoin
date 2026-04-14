# Architecture

**Analysis Date:** 2026-04-14

## Pattern Overview

**Overall:** Event-driven monolithic addon with immediate UI rendering (no manual search)

**Key Characteristics:**
- Single-file Lua architecture (World of Warcraft addon pattern)
- Event-based refresh on LFG/Social Queue changes
- Separation of concerns: Data gathering, filtering, and UI rendering
- Two parallel data flows: Quick Join suggestions and generic LFG listings
- Combat-aware state management (operations blocked during combat)

## Layers

**UI Layer:**
- Purpose: Render list frames, buttons, and row content; manage user interactions
- Location: `EquiFastJoin.lua` (lines 238-722)
- Contains: Frame creation, row rendering, event handlers for button clicks
- Depends on: WoW API (CreateFrame, fonts, textures), data from Core Processing
- Used by: Slash commands, event handlers

**Core Processing Layer:**
- Purpose: Gather LFG results, filter by activity type and user preferences, determine what to show
- Location: `EquiFastJoin.lua` (lines 723-835)
- Contains: `ProcessResultsAndMaybeShow()`, `GatherResults()`, `GatherQuickJoinEntries()`, filter logic
- Depends on: WoW LFGList API, Social Queue API, configuration database
- Used by: Event system

**Data Access Layer:**
- Purpose: Query WoW APIs for LFG listings, Quick Join suggestions, application status
- Location: `EquiFastJoin.lua` (lines 49-237)
- Contains: Helper functions wrapping C_LFGList and C_SocialQueue APIs
- Depends on: World of Warcraft client APIs
- Used by: Core Processing, UI rendering

**State Management:**
- Purpose: Persist configuration, track application status, cache UI state
- Location: `EquiFastJoin.lua` (lines 6-41 for globals; lines 850-951 for persistence)
- Contains: `EquiFastJoinDB`, `EFJ.State.applications`, UI visibility state
- Depends on: WoW SavedVariables system
- Used by: All layers

**Options Layer:**
- Purpose: Provide user configuration UI for filters, sound, window settings
- Location: `EquiFastJoin.lua` (lines 853-940)
- Contains: CheckButton controls, sliders, button handlers for options panel
- Depends on: WoW Settings API or InterfaceOptions API
- Used by: Event handler on ADDON_LOADED

## Data Flow

**Quick Join Flow (Triggered by SOCIAL_QUEUE_UPDATE):**

1. Event fires when player's friends/guild/community group activity changes
2. `GatherQuickJoinEntries()` queries C_SocialQueue for all eligible groups
3. Filter by `openOnQuickJoin` setting; match LFG list IDs to actual postings
4. `EFJ.UI:ShowQuickJoin(entries)` renders rows with leader name (class-colored), activity type (color-coded), role icons
5. User clicks "Beitreten" → `TryJoinAndMark()` opens Blizzard dialog or applies directly
6. Button state updates on `LFG_LIST_APPLICATION_STATUS_UPDATED` event
7. 3-second ticker auto-refreshes and hides frame when no more suggestions

**General LFG Flow (Triggered by LFG_LIST_SEARCH_RESULTS_RECEIVED):**

1. Event fires on LFG search completion or update
2. `ProcessResultsAndMaybeShow()` gathers results and cross-checks with Quick Join entries
3. Only shows results that also exist in Quick Join (unless no Quick Join available)
4. Filter by user's activity preferences (Dungeons, Raids, M+, PvP, Custom)
5. `EFJ.UI:ShowListFor()` renders filtered results with role icons
6. Dismissal signature prevents re-showing same list after close

**Application Status Flow:**

1. User clicks "Beitreten" or "Abmelden"
2. `TryJoin()` attempts Blizzard dialog first (safer); falls back to `C_LFGList.ApplyToGroup()`
3. Status tracked in `EFJ.State.applications[id]`
4. On `LFG_LIST_APPLICATION_STATUS_UPDATED`, `MarkAppliedByID()` updates button text/state
5. Fallback polling (0.5s, 2.0s) ensures UI sync if event is delayed

**State Management:**

- `EquiFastJoinDB`: Persisted via WoW SavedVariables; stores filters, window position/size, scale, sound/toast prefs
- `EFJ.State.applications`: Runtime cache of join status (applied/invited/declined/etc.)
- `EFJ.UI.visibleIDs`: Current list of displayed result IDs; used for dismissal tracking
- `EFJ.UI.mode`: Tracks current view ("quickjoin", "lfg", "banner", "none")

## Key Abstractions

**Activity Classification:**
- Purpose: Normalize WoW's variable activity metadata into canonical types
- Examples: `ClassifyResult()` (line 76), `BuildActivityText()` (line 104)
- Pattern: Checks activityID, categoryID, difficultyID, name patterns to return "MPLUS", "RAID", "DUNGEON", "PVP", "CUSTOM", "OTHER"

**Color Coding:**
- Purpose: Provide visual category distinction in list and toasts
- Examples: `BuildCategoryColor()` (line 735), class colors via `ColorizeByClass()` (line 56)
- Pattern: Maps activity type → hex color; maps WoW class file names → RAID_CLASS_COLORS

**Row Rendering:**
- Purpose: Dynamically create and populate individual list entries
- Examples: `CreateRow()` (line 244), `EFJ.UI:SetRows()` (line 633), `EFJ.UI:ShowQuickJoin()` (line 502)
- Pattern: Create frame template once, reuse by showing/hiding and updating text/textures; compute height based on content

**Role Icons:**
- Purpose: Display remaining open slots (Tank/Healer/DPS) or party composition
- Examples: `SetRoleIconsFromLFG()` (line 584), `SetMemberIconsFromLFG()` (line 566)
- Pattern: Query `C_LFGList.GetSearchResultMemberCounts()` or `GetSearchResultMemberInfo()`; render texture atlases sequentially

## Entry Points

**Addon Load (ADDON_LOADED):**
- Location: `EquiFastJoin.lua` (line 850)
- Triggers: When WoW loads addon after login
- Responsibilities: Initialize DB defaults, create UI frame, register options panel, set up periodic refresh (10-second ticker), perform initial LFG refresh

**User Input (Slash Commands):**
- Location: `EquiFastJoin.lua` (line 997)
- Triggers: `/efj test|show|hide|options|debug on|off`
- Responsibilities: Show test banner, display current Quick Join/LFG, open options panel, toggle debug logging

**User UI Interaction (Button Clicks):**
- Location: `EquiFastJoin.lua` (lines 409, 422, 538)
- Triggers: Click "Beitreten"/"Abmelden" button in row
- Responsibilities: `TryJoinAndMark()` applies to group or cancels application; updates button state immediately; falls back to polling if dialog used

**WoW Events:**
- Location: `EquiFastJoin.lua` (line 838)
- Registered: ADDON_LOADED, PLAYER_ENTERING_WORLD, SOCIAL_QUEUE_UPDATE, LFG_LIST_SEARCH_RESULTS_RECEIVED, LFG_LIST_SEARCH_RESULT_UPDATED, LFG_LIST_ACTIVE_ENTRY_UPDATE, LFG_LIST_APPLICATION_STATUS_UPDATED, GROUP_ROSTER_UPDATE, ZONE_CHANGED_NEW_AREA
- Triggers: WoW client fires when game state changes
- Responsibilities: Refresh LFG results, gather Quick Join suggestions, update application UI state, hide frame if user joins/forms group

## Error Handling

**Strategy:** Graceful fallback with user feedback

**Patterns:**
- Combat lockdown check: All apply/cancel operations check `InCombatLockdown()` and show error message in UIErrorsFrame
- Protected API fallback: Try Blizzard dialog first; fall back to direct `ApplyToGroup()` if dialog unavailable
- Nil checks: All data access wrapped in existence checks (e.g., `if not res then return nil`)
- pcall wrapping: High-risk API calls wrapped in `pcall()` to prevent addon crashes (lines 149, 173, 945, 959)
- Stale data handling: `GetFreshResultInfo()` checks `isDelisted` flag before using cached result

## Cross-Cutting Concerns

**Logging:** Debug logging via `DBG()` function (line 43); enabled/disabled by `EquiFastJoinDB.debug`; outputs to chat with "[EFJ]" prefix

**Validation:** Activity classification validates against WoW metadata and name patterns; role counts validated non-negative; leader name normalized to remove realm suffix

**Authentication:** Not applicable (WoW client context); operations blocked by combat lockdown instead of permission checks

**Internationalization:** German (DE) localization integrated; English fallback for class names and status terms; locale-aware via TOC Notes-deDE

---

*Architecture analysis: 2026-04-14*
