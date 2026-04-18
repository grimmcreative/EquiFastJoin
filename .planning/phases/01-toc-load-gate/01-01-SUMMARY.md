---
phase: 01-toc-load-gate
plan: 01
subsystem: core
tags: [wow-api, toc, midnight, compatibility]

requires:
  - phase: none
    provides: first phase
provides:
  - Midnight-compatible TOC Interface version (120005)
  - C_AddOns.LoadAddOn with backwards-compatible fallback
affects: [02-api-compatibility]

tech-stack:
  added: []
  patterns: [nil-guard fallback pattern for deprecated WoW API globals]

key-files:
  created: []
  modified:
    - EquiFastJoin.toc
    - EquiFastJoin.lua

key-decisions:
  - "Used nil-guard pattern (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn for backwards compatibility"
  - "Scoped _LoadAddOn local inside the if block to minimize variable scope"

patterns-established:
  - "Backwards-compat pattern: (C_AddOns and C_AddOns.Method) or LegacyGlobal for deprecated WoW APIs"

requirements-completed: [COMP-01, COMP-02]

duration: 3min
completed: 2026-04-18
---

# Phase 1: TOC & Load Gate Summary

**TOC Interface version bumped to 120005 and LoadAddOn replaced with C_AddOns.LoadAddOn using nil-guard fallback for Midnight 12.x compatibility**

## Performance

- **Duration:** 3 min
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- TOC Interface version updated from 110200 to 120005 (WoW 12.0.5 Midnight)
- Deprecated global `LoadAddOn` replaced with `C_AddOns.LoadAddOn` using backwards-compatible nil-guard
- Version comment updated to reflect Retail 12.0.5 (Midnight)

## Task Commits

Each task was committed atomically:

1. **Task 1: Update TOC Interface version to 120005** - `2258a1f` (fix)
2. **Task 2: Replace LoadAddOn with C_AddOns.LoadAddOn** - `e1af6ce` (fix)

## Files Created/Modified
- `EquiFastJoin.toc` - Interface version bumped from 110200 to 120005
- `EquiFastJoin.lua` - LoadAddOn replaced with C_AddOns.LoadAddOn fallback pattern, version comment updated

## Decisions Made
- Used nil-guard pattern `(C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn` — preserves backwards compatibility while supporting Midnight's namespaced API
- Scoped `_LoadAddOn` local inside the `if` block rather than at function scope — minimal variable scope

## Deviations from Plan
None - plan executed exactly as written

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Addon will load on Midnight 12.x clients without errors
- Phase 2 (API Compatibility) can now fix broken Midnight APIs for core features
- Live client verification needed: addon list shows enabled, no Lua error on login

---
*Phase: 01-toc-load-gate*
*Completed: 2026-04-18*
