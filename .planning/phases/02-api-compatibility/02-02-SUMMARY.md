---
phase: 02-api-compatibility
plan: 02
subsystem: api-layer
tags: [api-compat, generalPlaystyle, secret-values, taint-hardening, issecretvalue]
dependency_graph:
  requires: [02-01]
  provides: [COMP-06, COMP-07]
  affects: [EquiFastJoin.lua]
tech_stack:
  added: [issecretvalue]
  patterns: [nil-guard-issecretvalue, taint-error-distinction]
key_files:
  created: []
  modified: [EquiFastJoin.lua]
decisions:
  - "Both generalPlaystyle branches return OTHER — documents intentional inspection without premature classification"
  - "issecretvalue nil-guarded with (issecretvalue and issecretvalue(val)) pattern for 12.x patch compatibility"
  - "Taint-blocked errors shown as distinct user message vs generic failure"
metrics:
  duration: 58s
  completed: "2026-04-18T06:59:41Z"
  tasks: 2
  files_modified: 1
---

# Phase 02 Plan 02: Midnight API Support (generalPlaystyle + Secret Values) Summary

Added generalPlaystyle classification fallback with issecretvalue guard in ClassifyResult, and hardened GetFreshResultInfo/TryJoin against Secret Value taint crashes on Midnight 12.x.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add generalPlaystyle fallback to ClassifyResult (COMP-06) | 908e450 | EquiFastJoin.lua |
| 2 | Harden GetFreshResultInfo and TryJoin against Secret Values (COMP-07) | f7c2375 | EquiFastJoin.lua |

## Changes Made

### Task 1: generalPlaystyle Fallback (COMP-06)
- **ClassifyResult**: Added generalPlaystyle inspection block after all categoryID checks and before the final `return "OTHER"`.
- Field access uses `res.generalPlaystyle` (on result directly, not activityInfo).
- Guard pattern: `not (issecretvalue and issecretvalue(gps))` prevents crash if field is a Secret Value.
- Both branches return "OTHER" intentionally -- generalPlaystyle describes play intent (Learning/Relaxed/Serious/Expert), not content type.
- The explicit check documents that the field was inspected and the classification is deliberate.

### Task 2: Secret Values Taint Hardening (COMP-07)
- **GetFreshResultInfo**: Replaced bare `if info.isDelisted then` with issecretvalue-guarded comparison: `if not (issecretvalue and issecretvalue(info.isDelisted)) and info.isDelisted then`.
- **TryJoin/doApply**: Enhanced error message to distinguish taint-blocked errors (`err:find("[Bb]locked")`) from generic API failures. Users see "EFJ: Aktion blockiert (Taint)" for taint errors vs "EFJ: Bewerbung fehlgeschlagen" for other failures.
- **autoAccept**: Verified via grep -- not used in boolean context anywhere in the codebase. No additional guard needed.
- All issecretvalue calls use the nil-guard pattern `(issecretvalue and issecretvalue(val))` for compatibility across 12.x patch levels where issecretvalue may not yet exist.

## Verification Results

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| `grep -c "generalPlaystyle"` | >= 2 | 2 | PASS |
| `grep -c "issecretvalue"` | >= 2 | 2 | PASS |
| `grep "isDelisted"` shows guarded pattern | guarded | guarded | PASS |
| No bare `if info.isDelisted then` | 0 unguarded | 0 unguarded | PASS |
| `grep -c "Aktion blockiert"` | 1 | 1 | PASS |
| pcall around ApplyToGroup intact | present | present | PASS |

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None. Both generalPlaystyle branches returning "OTHER" is intentional per plan and research -- future phases can add display-level use of the field value.

## Self-Check: PASSED
