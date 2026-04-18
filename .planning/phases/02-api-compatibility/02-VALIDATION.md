---
phase: 02
slug: api-compatibility
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | WoW Lua runtime (no offline test harness) |
| **Config file** | none — WoW addon Lua has no automated test framework |
| **Quick run command** | `grep -c "pattern" EquiFastJoin.lua` (static checks) |
| **Full suite command** | Manual: copy to WoW AddOns folder, login, verify in-game |
| **Estimated runtime** | ~60 seconds (manual) |

---

## Sampling Rate

- **After every task commit:** Run static `grep` verification checks
- **After every plan wave:** Run full static verification suite
- **Before `/gsd-verify-work`:** Manual in-game test required
- **Max feedback latency:** 5 seconds (static), 60 seconds (manual)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | COMP-03 | — | N/A | static | `grep -c "activityIDs" EquiFastJoin.lua` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | COMP-04 | — | N/A | static | `grep -c "InterfaceOptions_AddCategory" EquiFastJoin.lua` returns 0 | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | COMP-05 | — | N/A | static | `grep -c "OptionsSliderTemplate" EquiFastJoin.lua` returns 0 | ✅ | ⬜ pending |
| 02-02-01 | 02 | 1 | COMP-06 | — | N/A | static | `grep -c "generalPlaystyle" EquiFastJoin.lua` | ✅ | ⬜ pending |
| 02-02-02 | 02 | 1 | COMP-07 | T-02-01 | pcall wraps ApplyToGroup, issecretvalue guards | static | `grep -c "issecretvalue" EquiFastJoin.lua` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework to install (WoW addon Lua).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| LFG listing shows activity names | COMP-03 | Requires live WoW API response | Login, open /efj show, verify listings show correct names |
| Join button opens dialog | COMP-07 | Requires live WoW instance | Click join on a listing, verify Blizzard dialog opens |
| Options panel slider works | COMP-05 | Requires live WoW UI | Run /efj options, drag scale slider, verify frame scales |
| Filter toggles work | COMP-06 | Requires live LFG results | Toggle each filter, verify listings update correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
