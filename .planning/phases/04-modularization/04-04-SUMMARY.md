---
phase: 04-modularization
plan: 04
subsystem: events-slash-toc
tags: [lua, wow-addon, modularization, events, slash-commands, toc]

# Dependency graph
requires:
  - phase: 04-03
    provides: UI.lua (EFJ.UI table with frame creation and display methods)
provides:
  - "Events.lua -- event frame, ADDON_LOADED handler, DB init, options panel, timers"
  - "SlashCommands.lua -- /efj slash command handler, EFJ_OpenOptions"
  - "EquiFastJoin.toc -- 7-file manifest in dependency order"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["7-file modular architecture", "TOC dependency-ordered loading"]

key-files:
  created: [Events.lua, SlashCommands.lua]
  modified: [EquiFastJoin.toc]
  deleted: [EquiFastJoin.lua]

key-decisions:
  - "Options panel stays in Events.lua (triggered by ADDON_LOADED, tightly coupled to init)"
  - "Monolith deleted via git rm for tracked deletion"

patterns-established:
  - "Complete modular addon: Locales -> Core -> Data -> Logic -> UI -> Events -> SlashCommands"
  - "No _G.EquiFastJoin global pollution -- all modules share state via WoW vararg namespace"

requirements-completed: [MODR-01, MODR-02, MODR-03]

# Metrics
duration: 1.6min
completed: 2026-04-18
---

# Phase 04 Plan 04: Events, SlashCommands & Monolith Deletion Summary

**Events.lua with event frame, ADDON_LOADED init (DB defaults, options panel, timers), all event routing; SlashCommands.lua with /efj handler; TOC rewritten for 7-module load order; EquiFastJoin.lua deleted**

## Performance

- **Duration:** 96s (~1.6 min)
- **Started:** 2026-04-18T09:08:41Z
- **Completed:** 2026-04-18T09:10:17Z
- **Tasks:** 2
- **Files created:** 2
- **Files modified:** 1
- **Files deleted:** 1

## Accomplishments
- Created Events.lua (142 lines) with event frame, 9 WoW event registrations, ADDON_LOADED handler containing DB init, options panel creation, initial refresh timer, and 10-second periodic ticker
- Created SlashCommands.lua (42 lines) with /efj slash command handler (test, show, hide, options, debug on/off) and EFJ_OpenOptions function
- Rewrote EquiFastJoin.toc to list all 7 module files in correct dependency order
- Deleted EquiFastJoin.lua monolith (1081 lines removed)
- All cross-module references use EFJ namespace pattern
- No _G.EquiFastJoin global reference in any file
- All 7 files use `local _, EFJ = ...` pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Events.lua** - `853eae7` (feat)
2. **Task 2: Create SlashCommands.lua, rewrite TOC, delete monolith** - `31240a8` (feat)

## Files Created/Modified
- `Events.lua` - Event frame, ADDON_LOADED handler with DB init/options/timers, all event routing
- `SlashCommands.lua` - /efj slash command handler, EFJ_OpenOptions
- `EquiFastJoin.toc` - Rewritten with 7-file manifest in dependency order
- `EquiFastJoin.lua` - Deleted (monolith replaced by modular files)

## Decisions Made
- Options panel creation stays in Events.lua (triggered by ADDON_LOADED, tightly coupled to initialization)
- Monolith deleted via git rm for proper tracked deletion in git history

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None

## Phase 04 Completion

Phase 04 (modularization) is now complete. The addon has been split from a single 1081-line monolith into 7 focused module files:

| File | Lines | Purpose |
|------|-------|---------|
| Locales.lua | ~67 | L-table with enUS/deDE strings |
| Core.lua | ~47 | DEFAULTS, CopyDefaults, DBG, EFJ.State |
| Data.lua | ~155 | Helpers, API wrappers, join/cancel logic, icons |
| Logic.lua | ~120 | Gathering, processing, filtering, Quick Join |
| UI.lua | ~412 | Frame creation, row rendering, display methods |
| Events.lua | ~142 | Event frame, ADDON_LOADED, options, timers |
| SlashCommands.lua | ~42 | /efj command handler |

---
*Phase: 04-modularization*
*Completed: 2026-04-18*
