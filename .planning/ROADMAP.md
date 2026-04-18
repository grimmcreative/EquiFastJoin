# Roadmap: EquiFastJoin v2.0

## Overview

The addon is currently broken on WoW Midnight (12.x) and exposes only German strings to an international CurseForge audience. This roadmap takes it from broken monolith to a Midnight-compatible, localized, modular addon in five sequential phases. Each phase has a hard gate: Phase 1 makes the addon load, Phase 2 makes it work correctly, Phase 3 enables multi-locale display, Phase 4 splits the monolith into maintainable files, and Phase 5 cleans up everything that accumulated along the way.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: TOC & Load Gate** - Update Interface version and fix load-blocking API calls so the addon loads on Midnight (completed 2026-04-18)
- [x] **Phase 2: API Compatibility** - Fix all broken Midnight APIs so core functionality (join, filter, options) works correctly (completed 2026-04-18)
- [ ] **Phase 3: Localization System** - Create the L-table with enUS primary and deDE override, replace all hardcoded strings
- [ ] **Phase 4: Modularization** - Split monolithic Lua into separate files with correct TOC load order
- [ ] **Phase 5: Code Quality** - Remove dead code, clean naming conventions, resolve forward declarations into modules

## Phase Details

### Phase 1: TOC & Load Gate
**Goal**: The addon loads without errors on WoW Midnight (12.x)
**Depends on**: Nothing (first phase)
**Requirements**: COMP-01, COMP-02
**Success Criteria** (what must be TRUE):
  1. Addon appears in the WoW addon list as enabled (not grayed out as "out of date")
  2. No Lua load error fires on character login
  3. `C_AddOns.LoadAddOn()` is called with a backwards-compatible fallback for the Blizzard LFG dialog
**Plans:** 1 plan
Plans:
- [x] 01-01-PLAN.md — Update TOC Interface version to 120005 and replace LoadAddOn with C_AddOns.LoadAddOn

### Phase 2: API Compatibility
**Goal**: All core addon features (LFG listing, join button, options panel) work correctly on Midnight with no blocked actions or missing UI elements
**Depends on**: Phase 1
**Requirements**: COMP-03, COMP-04, COMP-05, COMP-06, COMP-07
**Success Criteria** (what must be TRUE):
  1. LFG listing displays activity names correctly (not "Unknown Activity") for all content types
  2. Join button opens the Blizzard application dialog from inside and outside instances without ADDON_ACTION_BLOCKED
  3. Options panel opens via `/efj options` with a working scale slider and all controls visible
  4. Filter toggles (Dungeons, Raids, M+, PvP, Custom) correctly include or exclude listings for new Midnight content types
**Plans:** 2 plans
Plans:
- [x] 02-01-PLAN.md — Remove dead API paths (activityID, InterfaceOptions, OptionsSliderTemplate)
- [x] 02-02-PLAN.md — Add Midnight API support (generalPlaystyle, Secret Values hardening)

### Phase 3: Localization System
**Goal**: All UI strings are served from a localization table — English-locale users see English, German-locale users see German, and no hardcoded German strings remain in the main Lua file
**Depends on**: Phase 2
**Requirements**: LOCA-01, LOCA-02, LOCA-03, LOCA-04, LOCA-05
**Success Criteria** (what must be TRUE):
  1. Addon displays English strings on an enUS client (Join, Leave, Invited, filter labels, options labels)
  2. Addon displays German strings on a deDE client with no regression from current behavior
  3. TOC file includes `## Title-deDE:` and `## Notes-deDE:` localized metadata
  4. Any string key missing from a locale falls back to the key string rather than erroring
**Plans:** 2 plans
Plans:
- [x] 03-01-PLAN.md — Create L-table with metatable fallback and deDE override block
- [ ] 03-02-PLAN.md — Replace all hardcoded German strings with L["key"] calls

### Phase 4: Modularization
**Goal**: The monolithic EquiFastJoin.lua is replaced by separate focused files loaded in correct dependency order via the TOC
**Depends on**: Phase 3
**Requirements**: MODR-01, MODR-02, MODR-03
**Success Criteria** (what must be TRUE):
  1. `EquiFastJoin.lua` no longer exists; all code lives in module files (Locales, Core, Data, Logic, UI, Events, SlashCommands)
  2. All modules share state exclusively via the addon namespace (`local _, EFJ = ...`) with no `_G` pollution
  3. TOC lists all files in dependency order (Locales first, Events second-to-last, SlashCommands last)
  4. Addon loads and all Phase 1-3 success criteria still pass after the split
**Plans**: TBD
**UI hint**: yes

### Phase 5: Code Quality
**Goal**: The codebase has no dead code, consistent naming conventions, and no cross-file forward declaration artifacts
**Depends on**: Phase 4
**Requirements**: QUAL-01, QUAL-02, QUAL-03
**Success Criteria** (what must be TRUE):
  1. No legacy fallback stubs remain (InterfaceOptions_AddCategory, activityID primary path, old LoadAddOn calls)
  2. All forward declarations that spanned sections in the monolith are resolved into the module where the function lives
  3. Function and variable names follow a consistent convention throughout all module files
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. TOC & Load Gate | 1/1 | Complete | 2026-04-18 |
| 2. API Compatibility | 2/2 | Complete | 2026-04-18 |
| 3. Localization System | 1/2 | In progress | - |
| 4. Modularization | 0/TBD | Not started | - |
| 5. Code Quality | 0/TBD | Not started | - |
