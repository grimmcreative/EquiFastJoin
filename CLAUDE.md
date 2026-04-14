<!-- GSD:project-start source:PROJECT.md -->
## Project

**EquiFastJoin**

EquiFastJoin is a lightweight World of Warcraft Retail addon that surfaces Quick Join (friends/guild/community) suggestions and LFG listings in a compact, event-driven UI with one-click group joining. Published on CurseForge for the WoW community.

**Core Value:** One-click group joining — users see relevant groups and join instantly without navigating Blizzard's multi-step LFG UI.

### Constraints

- **Tech stack**: Lua (WoW addon API), no external build tools unless necessary
- **Compatibility**: Must work with WoW Midnight (12.x) live servers
- **Backwards compat**: SavedVariables (EquiFastJoinDB) must migrate cleanly for existing users
- **API surface**: Must use only public, non-tainted WoW API calls
- **Localization**: English as primary, German as secondary (current strings preserved)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Lua 5.1+ - Entire addon codebase (`EquiFastJoin.lua`)
- YAML - CI/CD configuration (`.github/workflows/release.yml`)
## Runtime
- World of Warcraft (Retail) 11.2.0 and later
- Blizzard AddOn Runtime (embedded Lua VM)
- Windows/macOS via Battle.net client
- World of Warcraft Retail (current expansion)
## Frameworks
- Blizzard UI Framework - Widget system, frame creation, event handling
- LFG List API (`C_LFGList.*`) - Group listing and joining
- Social Queue API (`C_SocialQueue.*`) - Quick Join integration
- Chat/UI APIs - Slash commands, tooltips, debug output
## Key Dependencies
- `C_LFGList` - GetActivityInfoTable, GetSearchResults, GetSearchResultInfo, ApplyToGroup, CancelApplication, RefreshResults
- `C_SocialQueue` - GetAllGroups, GetGroupMembers, GetGroupQueues
- `C_Timer` - Timer callbacks (NewTicker, After)
- `UnitInfo`/`GetPlayerInfoByGUID` - Character class detection
- `UIParent` - Frame attachment point
- `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UICheckButtonTemplate` - Stock UI templates
- `BackdropTemplate`, `UIPanelScrollFrameTemplate` - Container templates
- `OptionsSliderTemplate` - Slider UI for settings
- `GameFontNormalLarge`, `GameFontHighlight`, `GameFontNormalSmall` - Font strings
- `PlaySound()` / `SOUNDKIT` - UI sound playback
- `RAID_CLASS_COLORS` - Color mapping for character classes
- `CLASS_ICON_TCOORDS` - Texture coordinates for role icons
## Configuration
- `EquiFastJoinDB` - Global table saved by World of Warcraft
- SavedVariables declaration in TOC: `EquiFastJoinDB`
- Location: `WoW_Installation/WTF/Account/*/SavedVariables/EquiFastJoin.lua`
- `EquiFastJoin.toc` - AddOn metadata and manifest
- Defaults defined at line 11-30 in `EquiFastJoin.lua` (DEFAULTS table)
## Platform Requirements
- Text editor (Lua syntax highlighting recommended)
- World of Warcraft client (retail branch)
- Git for version control
- World of Warcraft Retail 11.2.0 or later
- Interface version 110200+
- Approximately 200KB total addon size (single Lua file + small media assets)
## Build & Packaging
- Folder-based: `Interface/AddOns/EquiFastJoin/`
- Contents:
- `efjicon.tga` - Standard addon icon (64x64, 32-bit RGBA)
- `efjicon256x256.tga` - High-res icon variant
- `efjicon64x64.tga` - Compact icon variant
- `LogoAddon.tga` - Referenced in TOC as IconTexture
- `efjwebicon@4x.png` - Web/marketplace preview
- GitHub Actions via `.github/workflows/release.yml`
- Triggers: Git tags (v*) or manual workflow dispatch
- Workflow: Extract changelog, create GitHub Release with auto-generated notes
## Interface Versioning
- Current: `110200` (WoW Retail 11.2)
- Maintained for each major patch
- Located at line 1 of `EquiFastJoin.toc`
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Single monolithic file: `EquiFastJoin.lua` - Contains entire addon codebase
- Lowercase with .lua extension for Lua source files
- Configuration file: `EquiFastJoin.toc` - TOC manifest (uppercase addon name, followed by .toc)
- Local functions use camelCase: `CopyDefaults()`, `BuildSignature()`, `ColorizeByClass()`, `GetActivityInfoForRes()`
- Global/API-accessible functions use PascalCase prefixed with module: `EFJ.UI:Create()`, `EFJ.UI:ShowListFor()`, `EFJ.Options:Create()`
- Forward declarations for functions used across sections: `local FindLeaderClass`, `local BuildCategoryColor`, `local SetMemberIconsFromLFG` (line 98-102)
- Helper functions often follow the pattern: `Get*()` for queries, `Build*()` for construction, `Try*()` for attempted operations with return status
- Local scope uses camelCase: `leaderName`, `leaderClass`, `textActivity`, `classIcons`
- Global addon reference: `_G.EquiFastJoin = EFJ` (line 7)
- Database reference: `EquiFastJoinDB` (persisted configuration)
- Constants in UPPERCASE: `ADDON_NAME`, `DEFAULTS`, `ROW_HEIGHT`, `ROW_SPACING`, `MAX_ROWS`
- State tables use snake_case for WoW API compatibility: `lastDismissSignature`, `showRaids`, `showDungeons`, etc. (lines 11-30)
- No explicit type annotations (Lua is dynamically typed)
- Table keys for class information: `RAID_CLASS_COLORS[classEN]` (Blizzard API standard)
- Classification results return strings: `"MPLUS"`, `"RAID"`, `"DUNGEON"`, `"PVP"`, `"CUSTOM"`, `"OTHER"`
## Code Style
- No formal formatter detected (no .prettierrc or similar)
- Tab/space style: spaces for indentation (2-space indents observed in lines 33-41, 244-276)
- Line length: varies; UI frame setup spans long lines (line 339)
- Braces and conditional style: consistent use of `if/then/else` blocks with `end`
- No linter configuration files detected (.eslintrc, .luacheckrc, biome.json)
- Manual code style enforcement via git commit messages and code review
## Import Organization
- No aliases; WoW APIs used directly: `C_LFGList.*`, `C_SocialQueue.*`, `C_Timer.*`
- Blizzard namespace access: `RAID_CLASS_COLORS`, `CLASS_ICON_TCOORDS` (global WoW constants)
## Error Handling
- User-facing errors displayed via `UIErrorsFrame:AddMessage()` with red color (1, 0.2, 0.2)
- Debug output via `DBG()` only if `EquiFastJoinDB.debug` is enabled
## Logging
- Debug logs only when `EquiFastJoinDB.debug` is true (opt-in via `/efj debug on`)
- API calls logged: `DBG("ApplyToGroup", id, "roles:", ...)` (line 172)
- Event processing: `DBG("Process", origin or "update", "#ids:", #ids)` (line 809)
- Addon initialization: `DBG("Addon geladen. Initialisiere Aktualisierung.")` (line 942)
## Comments
- Functional separators using comment blocks: `-- Helpers`, `-- LFG helpers`, `-- UI`, `-- Core processing`, `-- Events` (throughout file)
- Forward declarations documented: `-- Forward declare helpers used across sections` (line 97)
- Complex logic documented: `-- Recalculate a row's height based on its text content to avoid overlaps` (line 278)
- Intent clarification: `-- Prefer Blizzard's application dialog on user click (safe, out of combat)` (line 146)
- WoW API specifics: Comments explain category IDs and difficulty codes (lines 87-93)
- Not applicable (Lua without type system; no JSDoc/TSDoc convention)
- Inline comments used for explanation instead
## Function Design
- Range: 10-100 lines per function
- Larger functions: `EFJ.UI:Create()` (55 lines, lines 335-389) - Complex UI setup
- Medium functions: `ProcessResultsAndMaybeShow()` (32 lines, lines 804-835) - Event processing
- Small functions: `ClassifyResult()` (18 lines, lines 76-94) - Classification logic
- Most functions take 1-3 parameters
- Row update functions follow pattern: `function(row, id)` (UpdateJoinButton, MarkAppliedByID)
- Table arguments used for result data: `GetActivityInfoForRes(res)` where `res` is table from WoW API
- No variadic arguments except for `DBG(...)`
- Status string returns: `TryJoin()` returns `"dialog"`, `"applied"`, `"error"`, `"combat"` (line 140-184)
- Nil for missing data: `GetFreshResultInfo()` returns `nil` if not found (line 134)
- Tables for collections: `GatherResults()` returns list or empty table (lines 724-727)
- Boolean for queries: `HasQuickJoinSuggestions()` returns true/false (lines 729-733)
- Classification functions return string constants (lines 76, 735)
## Module Design
- Addon reference: `_G.EquiFastJoin = EFJ` (line 7) - Makes addon globally accessible
- Module structure: `EFJ.UI` for UI operations, `EFJ.Options` for options panel, `EFJ.State` for state management
- Methods attached to tables: `function EFJ.UI:Create()`, `function EFJ.UI:SetRows()` (colon syntax for self-parameter)
- Single file approach: `EquiFastJoin.lua` is monolithic entry point
- No modular file splitting currently
- TOC manifest loads only this single file (line 12 of EquiFastJoin.toc)
- Module tables for namespacing: `EFJ.UI = { rows = {}, visibleIDs = {}, mode = "lfg" }` (line 239)
- Defaults table for config: `DEFAULTS = { debug = false, ... }` (lines 11-30)
- State table for runtime: `EFJ.State = { applications = {} }` (line 8)
- Method table usage: Functions attached as methods for object-oriented style
## German Localization
- German strings hardcoded in Lua (game in German language)
- UI text: `"Beitreten"` (Join), `"Abmelden"` (Leave), `"Eingeladen"` (Invited)
- Error messages in German: `"EFJ: Beitritt im Kampf gesperrt"` (Join blocked in combat)
- Debug strings in German: `"Addon geladen. Initialisiere Aktualisierung."` (Addon loaded. Initializing refresh.)
- TOC file includes German localization: `## Title-deDE: EquiFastJoin`, `## Notes-deDE:` (lines 3, 5 of EquiFastJoin.toc)
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Single-file Lua architecture (World of Warcraft addon pattern)
- Event-based refresh on LFG/Social Queue changes
- Separation of concerns: Data gathering, filtering, and UI rendering
- Two parallel data flows: Quick Join suggestions and generic LFG listings
- Combat-aware state management (operations blocked during combat)
## Layers
- Purpose: Render list frames, buttons, and row content; manage user interactions
- Location: `EquiFastJoin.lua` (lines 238-722)
- Contains: Frame creation, row rendering, event handlers for button clicks
- Depends on: WoW API (CreateFrame, fonts, textures), data from Core Processing
- Used by: Slash commands, event handlers
- Purpose: Gather LFG results, filter by activity type and user preferences, determine what to show
- Location: `EquiFastJoin.lua` (lines 723-835)
- Contains: `ProcessResultsAndMaybeShow()`, `GatherResults()`, `GatherQuickJoinEntries()`, filter logic
- Depends on: WoW LFGList API, Social Queue API, configuration database
- Used by: Event system
- Purpose: Query WoW APIs for LFG listings, Quick Join suggestions, application status
- Location: `EquiFastJoin.lua` (lines 49-237)
- Contains: Helper functions wrapping C_LFGList and C_SocialQueue APIs
- Depends on: World of Warcraft client APIs
- Used by: Core Processing, UI rendering
- Purpose: Persist configuration, track application status, cache UI state
- Location: `EquiFastJoin.lua` (lines 6-41 for globals; lines 850-951 for persistence)
- Contains: `EquiFastJoinDB`, `EFJ.State.applications`, UI visibility state
- Depends on: WoW SavedVariables system
- Used by: All layers
- Purpose: Provide user configuration UI for filters, sound, window settings
- Location: `EquiFastJoin.lua` (lines 853-940)
- Contains: CheckButton controls, sliders, button handlers for options panel
- Depends on: WoW Settings API or InterfaceOptions API
- Used by: Event handler on ADDON_LOADED
## Data Flow
- `EquiFastJoinDB`: Persisted via WoW SavedVariables; stores filters, window position/size, scale, sound/toast prefs
- `EFJ.State.applications`: Runtime cache of join status (applied/invited/declined/etc.)
- `EFJ.UI.visibleIDs`: Current list of displayed result IDs; used for dismissal tracking
- `EFJ.UI.mode`: Tracks current view ("quickjoin", "lfg", "banner", "none")
## Key Abstractions
- Purpose: Normalize WoW's variable activity metadata into canonical types
- Examples: `ClassifyResult()` (line 76), `BuildActivityText()` (line 104)
- Pattern: Checks activityID, categoryID, difficultyID, name patterns to return "MPLUS", "RAID", "DUNGEON", "PVP", "CUSTOM", "OTHER"
- Purpose: Provide visual category distinction in list and toasts
- Examples: `BuildCategoryColor()` (line 735), class colors via `ColorizeByClass()` (line 56)
- Pattern: Maps activity type → hex color; maps WoW class file names → RAID_CLASS_COLORS
- Purpose: Dynamically create and populate individual list entries
- Examples: `CreateRow()` (line 244), `EFJ.UI:SetRows()` (line 633), `EFJ.UI:ShowQuickJoin()` (line 502)
- Pattern: Create frame template once, reuse by showing/hiding and updating text/textures; compute height based on content
- Purpose: Display remaining open slots (Tank/Healer/DPS) or party composition
- Examples: `SetRoleIconsFromLFG()` (line 584), `SetMemberIconsFromLFG()` (line 566)
- Pattern: Query `C_LFGList.GetSearchResultMemberCounts()` or `GetSearchResultMemberInfo()`; render texture atlases sequentially
## Entry Points
- Location: `EquiFastJoin.lua` (line 850)
- Triggers: When WoW loads addon after login
- Responsibilities: Initialize DB defaults, create UI frame, register options panel, set up periodic refresh (10-second ticker), perform initial LFG refresh
- Location: `EquiFastJoin.lua` (line 997)
- Triggers: `/efj test|show|hide|options|debug on|off`
- Responsibilities: Show test banner, display current Quick Join/LFG, open options panel, toggle debug logging
- Location: `EquiFastJoin.lua` (lines 409, 422, 538)
- Triggers: Click "Beitreten"/"Abmelden" button in row
- Responsibilities: `TryJoinAndMark()` applies to group or cancels application; updates button state immediately; falls back to polling if dialog used
- Location: `EquiFastJoin.lua` (line 838)
- Registered: ADDON_LOADED, PLAYER_ENTERING_WORLD, SOCIAL_QUEUE_UPDATE, LFG_LIST_SEARCH_RESULTS_RECEIVED, LFG_LIST_SEARCH_RESULT_UPDATED, LFG_LIST_ACTIVE_ENTRY_UPDATE, LFG_LIST_APPLICATION_STATUS_UPDATED, GROUP_ROSTER_UPDATE, ZONE_CHANGED_NEW_AREA
- Triggers: WoW client fires when game state changes
- Responsibilities: Refresh LFG results, gather Quick Join suggestions, update application UI state, hide frame if user joins/forms group
## Error Handling
- Combat lockdown check: All apply/cancel operations check `InCombatLockdown()` and show error message in UIErrorsFrame
- Protected API fallback: Try Blizzard dialog first; fall back to direct `ApplyToGroup()` if dialog unavailable
- Nil checks: All data access wrapped in existence checks (e.g., `if not res then return nil`)
- pcall wrapping: High-risk API calls wrapped in `pcall()` to prevent addon crashes (lines 149, 173, 945, 959)
- Stale data handling: `GetFreshResultInfo()` checks `isDelisted` flag before using cached result
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
