# Codebase Concerns

**Analysis Date:** 2026-04-14

## Tech Debt

**WoW API Compatibility Fragility:**
- Issue: Code relies on multiple conditional API checks for backward/forward compatibility (e.g., checking `SetAtlas` existence, fallback texture coords). Each version of WoW may change LFG API signatures.
- Files: `EquiFastJoin.lua` lines 602-607 (role icon rendering), lines 773-781 (player name resolution), lines 586 (member counts)
- Impact: New WoW patches could break icon rendering or player info resolution without warning. No version matrix or API compatibility guide exists.
- Fix approach: Create a compatibility layer module that tests and wraps WoW API calls, centralizing version-specific logic. Document minimum supported WoW version.

**Hardcoded German Text in Core Logic:**
- Issue: All user-facing strings are hardcoded in German. English localization is listed as "can be added later" but is built into core event handlers and UI.
- Files: `EquiFastJoin.lua` lines 105, 128, 143, 177, 210, 223, 272-273, 359, 464, 467, 484, 711, 738, 861-922 (throughout)
- Impact: Non-German players get confusing UI. The toc file mentions "DE notes" but there is no proper localization system (L10n) in place.
- Fix approach: Extract all strings to a localization table at file head. Use getlocale() to select language. Document string keys for translator use. Test with multiple locales.

**State Management Race Conditions:**
- Issue: `EFJ.State.applications` table is updated asynchronously via events (`LFG_LIST_APPLICATION_STATUS_UPDATED`) at line 415, but can be read/written from multiple event handlers and timers simultaneously.
- Files: `EquiFastJoin.lua` lines 219, 393-395, 415, 428
- Impact: Rapid application/cancellation sequences could leave state inconsistent. UI button states may be out of sync with actual server state.
- Fix approach: Implement a simple state queue that processes updates sequentially. Add debug logging to track state transitions. Validate state before any action.

**UI Frame Dangling References:**
- Issue: `EFJ.UI.frame`, `EFJ.UI.content`, `EFJ.UI.rows` can be nil or stale if frame is recreated or destroyed unexpectedly. Code checks existence but doesn't guarantee initialization order.
- Files: `EquiFastJoin.lua` lines 336-389, 702-715 (frame creation), 280-298 (assumed frame exists)
- Impact: If frame creation fails partway, subsequent operations crash silently via nil checks. Resizing while frame hidden could write to stale content frame.
- Fix approach: Use explicit frame lifecycle: `Create()` → `Show()` → `Hide()` with asserts at each step. Store frame state enum (uninitialized, created, shown, hidden). Validate state transitions.

**Scroll Content Height Calculation Edge Case:**
- Issue: `self.content:SetHeight(total)` at line 319 is calculated from visible rows only. If all rows are hidden, height is set to `ROW_HEIGHT` (54px), but scroll frame expects valid child dimensions.
- Files: `EquiFastJoin.lua` lines 301-320 (Relayout function)
- Impact: Empty lists or rapid filter changes could create invisible scroll regions. Scroll bar appears in wrong size or become unresponsive.
- Fix approach: Always ensure content height >= 2 * ROW_HEIGHT even when empty. Add debug assertion. Test with 0, 1, and MAX_ROWS visible.

## Known Bugs

**Button State Out of Sync After Dialog Cancel:**
- Symptoms: User opens Blizzard application dialog (via Join button), closes dialog without applying. Join button still shows "Abmelden" instead of "Beitreten".
- Files: `EquiFastJoin.lua` lines 147-158 (OpenApplyDialog), 197-198 (polling)
- Trigger: Click Join → dialog opens → user closes dialog
- Workaround: Manually refresh with `/efj show` or wait 2 seconds for polling to fix state. Server has not applied, so button state is technically cached.
- Root cause: Dialog close is not detected; code only polls at 0.5s and 2.0s. If user closes dialog between polls, state remains dirty.
- Fix approach: Monitor Blizzard dialog visibility or hook dialog close event. Update button state immediately on dialog close. Increase polling frequency to 0.2s if dialog was opened.

**Overlapping Text in Narrow Windows:**
- Symptoms: Activity and note text overlap row boundaries on resize to < 300px width. Text lines extend beyond row container without visual truncation.
- Files: `EquiFastJoin.lua` lines 278-298 (ComputeRowHeight), 264, 269 (SetWidth)
- Trigger: User resizes frame < 300px, or UI layout forces narrow frame
- Workaround: Resize frame wider; max width is capped at 1200px
- Root cause: Text wrapping width is calculated as `w - 168` (fixed button/icon space), but minimum layout space is never enforced. Very narrow frames result in `textWidth < 50`, but no minimum width check prevents negative values.
- Fix approach: Add `textWidth = math.max(textWidth, 100)` before applying SetWidth. Show ellipsis if text exceeds minimum width. Set minimum frame width to 350px in resize bounds.

**Quick Join List Not Updating on Rapid Group Changes:**
- Symptoms: User joins a Quick Join group, immediately new suggestions appear, but old entry stays shown for 3 seconds (quickTicker interval).
- Files: `EquiFastJoin.lua` lines 439-453 (StartQuickTicker), 441 (3-second ticker)
- Trigger: Multiple friends queue for groups in rapid succession while Quick Join list is open
- Workaround: Manually close and reopen list with `/efj show`
- Root cause: Quick Join list only updates on explicit `ShowQuickJoin()` call or every 3 seconds. SOCIAL_QUEUE_UPDATE event fires more frequently but only calls `ShowQuickJoin()` after 0.05s delay.
- Fix approach: Reduce ticker interval to 1 second or make ticker event-driven. Batch SOCIAL_QUEUE_UPDATE events to avoid flicker. Add `StopQuickTicker()` on immediate manual refresh.

**LFG Result Skipped on RefreshResults Failure:**
- Symptoms: Some LFG listings appear in group finder but not in EquiFastJoin list. List shows empty despite visible groups in native UI.
- Files: `EquiFastJoin.lua` lines 804-835 (ProcessResultsAndMaybeShow)
- Trigger: RefreshResults() fails silently (combat lockdown, addon action blocked), no fresh data available
- Root cause: If `RefreshResults()` fails or returns stale data, `GatherResults()` at line 725 returns old list. Code does not detect staleness or signal user.
- Fix approach: Check timestamp of results before using them. Log when RefreshResults fails. Show toast message if list is older than 10 seconds. Add `/efj force-refresh` command for manual refresh.

## Security Considerations

**Taint Risk from Protected API Calls:**
- Risk: Code calls `C_LFGList.RefreshResults()` and `C_LFGList.ApplyToGroup()` within pcall() blocks, but these are protected actions. Any execution path that calls from combat or from tainted context could trigger "ADDON_ACTION_BLOCKED" and prevent joining.
- Files: `EquiFastJoin.lua` lines 945, 951, 959 (RefreshResults in event handlers), 174 (ApplyToGroup)
- Current mitigation: Code checks `InCombatLockdown()` before calling these. Wraps calls in pcall(). Uses Blizzard dialog when possible to avoid direct apply.
- Recommendations: 
  - Add telemetry: log every blocked action with timestamp and context
  - Create allowlist of safe event types that can call RefreshResults()
  - Never call ApplyToGroup from timers; only from user-initiated events
  - Document which WoW versions have which protected restrictions

**No Input Validation on LFG Result IDs:**
- Risk: Code assumes `C_LFGList.GetSearchResultInfo(id)` and related calls accept any integer. Malformed or negative IDs could crash Lua or trigger unexpected behavior.
- Files: `EquiFastJoin.lua` lines 131-137 (GetFreshResultInfo), 622-631 (FindLeaderClass), 669-683 (ToastForIDs)
- Current mitigation: Code checks `if not info` after API calls, but does not validate ID itself
- Recommendations: Validate ID is positive integer before API calls. Log invalid IDs. Skip entries with invalid IDs instead of crashing. Add assertions in debug mode.

**No Sanitization of Player Names in UI:**
- Risk: Player names from `C_LFGList.GetSearchResultMemberInfo()` and `GetPlayerInfoByGUID()` may contain color codes, special characters, or escape sequences that break UI layout.
- Files: `EquiFastJoin.lua` lines 774-786 (name extraction), 514, 643 (displayed in UI)
- Current mitigation: None. Names are used directly in SetText()
- Recommendations: Strip color codes from names before display. Use `name:gsub("|r", "")` to remove end-color codes. Test with unicode and RTL names. Add unit test with adversarial player names.

## Performance Bottlenecks

**Linear Search for Applied Status on Every Update:**
- Problem: `MarkAppliedByID()` iterates all rows to find matching ID. With MAX_ROWS=30, this is O(30) but done on every `LFG_LIST_APPLICATION_STATUS_UPDATED` event.
- Files: `EquiFastJoin.lua` lines 413-437 (MarkAppliedByID)
- Cause: Row table is indexed by position, not by result ID. No hash map of `id -> row`.
- Improvement path: Create `self.rowsByID = {}` to map result IDs to rows. Update on SetRows(), update on MarkAppliedByID(). Lookup becomes O(1).

**Full Relayout on Every Row Update:**
- Problem: `Relayout()` is called after every single row update (line 550, 555, 667, 678). With wrapping text, each call re-measures all visible rows.
- Files: `EquiFastJoin.lua` lines 301-320 (Relayout), 550, 555, 667, 678 (callers)
- Cause: Text metrics depend on frame width, so any width change requires full remeasure. Called too frequently.
- Improvement path: Batch relayout updates. Use `C_Timer.After(0, Relayout)` to defer to end of event frame. Only call Relayout once per event handler, not per row.

**Redundant API Calls for Role Icons:**
- Problem: `SetRoleIconsFromLFG()` calls `C_LFGList.GetSearchResultMemberCounts(id)` every time a row is rendered. This is called once per row on ShowQuickJoin and SetRows.
- Files: `EquiFastJoin.lua` lines 584-614 (SetRoleIconsFromLFG), calls at 530, 657
- Cause: No caching of member counts. Results are static between SOCIAL_QUEUE_UPDATE events.
- Improvement path: Cache member counts in `EFJ.State` keyed by result ID. Invalidate on `LFG_LIST_SEARCH_RESULT_UPDATED`. Reduces API calls from 30 per update to 1.

**Repeated Texture Lookups for Class Icons:**
- Problem: `CLASS_ICON_TCOORDS[classEN]` is looked up twice per class icon (line 496, 517, 577, 646) without caching.
- Files: `EquiFastJoin.lua` lines 496, 517, 577, 646
- Cause: Blizzard's CLASS_ICON_TCOORDS is a global table; no local caching
- Improvement path: Cache result in local `tcoords` variable at line 495 to avoid second lookup. Or use `local tcoords = CLASS_ICON_TCOORDS[classEN] or {0,1,0,1}` pattern.

## Fragile Areas

**Activity Text Building Function:**
- Files: `EquiFastJoin.lua` lines 104-129 (BuildActivityText)
- Why fragile: Depends on `C_LFGList.GetActivityInfoTable()` returning table with `fullName` field. If API changes structure or name field is missing/nil, fallback chain is deep and error-prone. Returns German hardcoded string "Unbekannte Aktivität" as last resort.
- Safe modification: Add unit tests with real activity IDs from live WoW. Document expected API contract. Use named table access with defaults: `(act or {}).fullName or res.name or "Unknown"`. Test all fallback paths.
- Test coverage: Not tested; no unit tests exist

**Classification and Filtering Logic:**
- Files: `EquiFastJoin.lua` lines 75-93 (ClassifyResult), 227-236 (ResultMatchesFilters)
- Why fragile: Classification relies on multiple heuristics to detect M+, Raid, etc. Changes in activity API or new activity types could bypass classification logic entirely. Filter logic assumes all entries fall into one of 5 categories; unknown types are hidden by default.
- Safe modification: Add extensive comments explaining each heuristic. Add debug logging of classification for every result. Create integration test with real LFG data. Increase "OTHER" category visibility instead of hiding unknown entries.
- Test coverage: Not tested; no unit tests exist

**Role Icon Rendering:**
- Files: `EquiFastJoin.lua` lines 584-614 (SetRoleIconsFromLFG)
- Why fragile: Assumes `GetTexCoordsForRole()` exists and `roleAtlas` table is complete. Fallback to `UI-LFG-ICON-ROLES` texture. If Blizzard changes atlas names or removes function, icons disappear silently.
- Safe modification: Test both atlas and texture paths in a test function at load time. Cache result. Add fallback to simple text (T/H/D) if both fail. Document Blizzard API version for each path.
- Test coverage: Not tested

**Quick Join Entry Deduplication:**
- Files: `EquiFastJoin.lua` lines 746-802 (GatherQuickJoinEntries)
- Why fragile: Uses `seen[lfgListID]` to deduplicate, but assumes each group has unique `lfgListID`. If API returns same ID for multiple groups, only first is shown. If ID is nil, entry is skipped silently.
- Safe modification: Add validation: skip entries where `lfgListID` is nil with debug log. Track duplicate IDs and warn if same ID appears twice. Store full group guid + lfgListID pair as key.
- Test coverage: Not tested

## Scaling Limits

**Maximum 30 Visible Rows:**
- Current capacity: MAX_ROWS = 30 (line 242). Scroll frame max height is 900px.
- Limit: If > 30 Quick Join groups are available, list cuts off silently. No pagination or "show more" mechanism.
- Scaling path: Either (a) remove MAX_ROWS limit and use dynamic row pool, or (b) add pagination/filtering UI. Document current limit in README.

**Refresh Frequency Bottleneck:**
- Current capacity: Periodic refresh via 10-second ticker (line 950). Event-driven updates via 0.05s debounce (line 967).
- Limit: If SOCIAL_QUEUE_UPDATE events fire > 20 Hz, debounce timer keeps resetting and UI never updates. Conversely, if events are rare, list stales within 10 seconds.
- Scaling path: Use adaptive debounce: start at 0.05s, increase to 0.5s if events fire frequently, reset on user interaction. Log frequency statistics to detect abuse patterns.

## Dependencies at Risk

**Hard Dependency on C_LFGList and C_SocialQueue:**
- Risk: These are part of WoW's social API. If Blizzard removes or radically changes these in a future expansion, addon breaks entirely. No fallback to manual group search.
- Impact: Every major WoW version (Expansion) could potentially break API signatures. Current TOC targets 11.2, which may not be forward-compatible.
- Migration plan: Create adapter functions for each C_* API. Document minimum WoW version. Add error messages if APIs are unavailable instead of silent failure. Consider linking to official API docs in README.

**Blizzard_LFGList Addon Dependency:**
- Risk: Code tries to load "Blizzard_LFGList" addon on demand (line 149). If this addon is removed, disabled, or interferes with other addons, dialog will fail to load.
- Impact: Join button fallback to direct apply, which may not work in some scenarios. No user feedback if addon fails to load.
- Migration plan: Test load outcome. Log success/failure. Show user message if dialog unavailable: "Using direct join (dialog not available)". Provide fallback instructions in options panel.

## Missing Critical Features

**No Offline Notification:**
- Problem: If network lag or crash causes LFG data to stale (no updates for > 30 seconds), user doesn't know list is stale. Might miss groups.
- Blocks: Users cannot trust list accuracy in high-lag scenarios or poor connectivity
- Priority: Medium

**No Search History or Favorites:**
- Problem: Can't save favorite group types or search parameters. Must manually apply to same group type repeatedly.
- Blocks: Inconvenient for players with specific group type preferences
- Priority: Low

**No Rejection/Decline Reason Display:**
- Problem: When application is declined, addon shows "Declined" but no reason. User doesn't know if it was full, requirements not met, or leader declined.
- Blocks: Players can't improve applications or find alternative groups
- Priority: Medium

## Test Coverage Gaps

**No Unit Tests Exist:**
- What's not tested: All core logic (classification, filtering, state management, UI updates)
- Files: Entire `EquiFastJoin.lua`
- Risk: Refactoring or bug fixes could introduce regressions without detection. Logic changes (e.g., M+ detection) are untested.
- Priority: High

**No Integration Tests:**
- What's not tested: Real LFG API interaction, actual Blizzard dialog behavior, state transitions with real events
- Files: Event handlers (lines 848-979), TryJoin flow, button state updates
- Risk: Changes to join flow or event handling could break in production without warning. No way to validate against live WoW without manual testing.
- Priority: High

**No Localization Testing:**
- What's not tested: Non-German locales, RTL languages, long translated strings
- Files: All UI text (lines 105, 128, 143, 177, 210, 223, 272, 359, 464, 467, 484, etc.)
- Risk: If English or other locales added, untranslated strings or layout breakage not caught until user reports
- Priority: Medium

**No Edge Case Testing:**
- What's not tested: Empty result lists, all-filtered results, rapid open/close, extreme frame sizes, very long player names
- Files: UI frame creation and relayout, row rendering, filter application
- Risk: Rare but reproducible scenarios (e.g., zero visible rows) could crash or appear broken
- Priority: Medium

---

*Concerns audit: 2026-04-14*
