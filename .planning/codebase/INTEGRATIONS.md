# External Integrations

**Analysis Date:** 2026-04-14

## APIs & External Services

**World of Warcraft LFG System:**
- LFG List API - Core lookup finding and group joining
  - SDK/Client: Native Blizzard API (`C_LFGList.*`)
  - No authentication required (uses WoW session)
  - Methods used:
    - `C_LFGList.GetActivityInfoTable(activityID)` - Activity metadata (line 71)
    - `C_LFGList.GetSearchResults()` - All active LFG listings (line 725)
    - `C_LFGList.GetSearchResultInfo(id)` - Individual listing details (line 132, 624)
    - `C_LFGList.GetSearchResultMemberInfo(id, index)` - Team member class data (line 570)
    - `C_LFGList.GetSearchResultMemberCounts(id)` - Role counts (line 586)
    - `C_LFGList.ApplyToGroup(id, note, tank, healer, dps)` - Submit application (line 174)
    - `C_LFGList.CancelApplication(id)` - Withdraw application (line 213)
    - `C_LFGList.GetApplicationInfo(id)` - Check application status (line 394)
    - `C_LFGList.RefreshResults()` - Force refresh cached results (line 945, 951, 959)

**Social Queue/Quick Join API:**
- Quick Join suggestions - Friends/guild/community group invitations
  - SDK/Client: Native Blizzard API (`C_SocialQueue.*`)
  - No authentication required (uses WoW session)
  - Methods used:
    - `C_SocialQueue.GetAllGroups()` - List of available Quick Join suggestions (line 731, 748)
    - `C_SocialQueue.GetGroupMembers(guid)` - Members in a Quick Join group (line 752)
    - `C_SocialQueue.GetGroupQueues(guid)` - Queue assignments (line 753)
    - `SocialQueueUtil_GetRelationshipInfo(guid, nil, clubId)` - Member name resolution (line 774)

## Data Storage

**Persistent Configuration:**
- Type: Local filesystem (WoW SavedVariables)
- Location: `WTF/Account/*/SavedVariables/EquiFastJoin.lua`
- Client: Native Blizzard SavedVariables system
- Data stored:
  - User preferences (filters, UI scale, position)
  - Debug flag
  - Last dismissed listing signature (for dismiss-on-next-update behavior)

**In-Memory State:**
- `EFJ.State` - Runtime application state table (line 8)
- `EFJ.UI` - UI frame references and visibility tracking
- Cached results from API calls (no persistent caching)

## Authentication & Identity

**Auth Provider:**
- Built-in: World of Warcraft session authentication
- No external OAuth/login required
- Identity sourced from:
  - `GetPlayerInfoByGUID(guid)` - Character class/name lookup (line 782)
  - WoW account session via Battle.net

## Game Events & Messaging

**Event Listeners:**
Registered events (line 839-847) with associated handlers (line 848-979):

- `ADDON_LOADED` - Initialize addon, load SavedVariables, create UI (line 850)
- `PLAYER_ENTERING_WORLD` - Reset on zone change, trigger initial refresh
- `SOCIAL_QUEUE_UPDATE` - New Quick Join suggestions detected (line 841, 968)
- `LFG_LIST_SEARCH_RESULTS_RECEIVED` - LFG search results returned (line 957)
- `LFG_LIST_SEARCH_RESULT_UPDATED` - Individual listing metadata changed
- `LFG_LIST_ACTIVE_ENTRY_UPDATE` - Application status or queue state changed
- `LFG_LIST_APPLICATION_STATUS_UPDATED` - Application accepted/denied/withdrawn (line 961)
- `GROUP_ROSTER_UPDATE` - Player joined/left group (triggers hide if applicable)
- `ZONE_CHANGED_NEW_AREA` - Player moved zones (triggers hide if applicable)

**Periodic Updates:**
- `C_Timer.NewTicker(10, ...)` - Refresh LFG results every 10 seconds (line 950)
- `C_Timer.After(delay, ...)` - Delayed actions for UI synchronization (line 944, 967)

## UI Integration with Blizzard Client

**Frame Templates Used:**
- `UIPanelButtonTemplate` - Join/Cancel buttons (line 272)
- `UIPanelCloseButton` - Close button for main frame (line 361)
- `BackdropTemplate` - Main window backdrop/frame styling
- `UIPanelScrollFrameTemplate` - Scrollable list container (line 368)
- `UICheckButtonTemplate` - Filter checkboxes in options (line 864)
- `OptionsSliderTemplate` - Scale slider in options (line 891)

**Settings Integration:**
- Modern retail: `Settings.RegisterCanvasLayoutCategory()` + `Settings.RegisterAddOnCategory()` (line 932)
- Legacy fallback: `InterfaceOptions_AddCategory()` for older clients (line 936)

**Blizzard Application Dialog:**
- When join is clicked, attempts to open the official LFG application dialog (line 162-170)
- Dialog class: `LFGListApplicationDialog` (referenced by internal Blizzard code)
- Fallback: Direct `ApplyToGroup()` if dialog unavailable

## Webhooks & Callbacks

**Incoming:**
- None (addon is purely client-side, no server communication)

**Outgoing:**
- None (no external HTTP/webhook calls)

**Release Management:**
- GitHub Actions workflow: `.github/workflows/release.yml`
- Triggers: Git tag push or manual workflow dispatch
- Output: Automated GitHub Release creation with version-tagged changelog
- Distribution channels:
  - GitHub Releases (ZIP download)
  - CurseForge (separate manual upload, not automated)

## Protected Actions & Combat Lockdown

**Combat-Blocked Operations:**
- `C_LFGList.RefreshResults()` - Guarded with `InCombatLockdown()` check (line 945, 951, 959)
- `C_LFGList.ApplyToGroup()` - Blocked in combat via UI button disabling (line 542)
- `C_LFGList.CancelApplication()` - Blocked in combat via UI button disabling
- Options panel opening - Blocked in combat with user error message (line 983)

**Taint Mitigation:**
- `C_LFGList.Search()` removed entirely (version 1.8.2+) to avoid protected action taint (CHANGELOG.md, line 9)
- No direct Blizzard dialog opening from timers (prevents taint) (CHANGELOG.md, line 16)
- Event-driven architecture instead of polling (CHANGELOG.md, line 35)

---

*Integration audit: 2026-04-14*
