---
phase: 03
slug: localization-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | WoW Lua runtime (no offline test harness) |
| **Config file** | none |
| **Quick run command** | `grep -c 'L\["' EquiFastJoin.lua` (static L-table usage count) |
| **Full suite command** | Manual: copy to WoW, test with enUS and deDE client locale |
| **Estimated runtime** | ~5 seconds (static), ~120 seconds (manual) |

---

## Sampling Rate

- **After every task commit:** Run static grep verification
- **After every plan wave:** Verify no hardcoded German strings remain
- **Before `/gsd-verify-work`:** Manual locale switch test
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 03-01-01 | 01 | 1 | LOCA-01 | static | `grep -c "setmetatable" EquiFastJoin.lua` | ⬜ pending |
| 03-01-02 | 01 | 1 | LOCA-02 | static | `grep -c 'L\["' EquiFastJoin.lua` returns >0 | ⬜ pending |
| 03-01-03 | 01 | 1 | LOCA-03 | static | `grep -c "deDE" EquiFastJoin.lua` returns >0 | ⬜ pending |
| 03-02-01 | 02 | 2 | LOCA-05 | static | `grep -cE '"(Beitreten|Abmelden|Eingeladen)"' EquiFastJoin.lua` returns 0 | ⬜ pending |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| enUS strings display | LOCA-02 | Requires enUS WoW client | Login with enUS locale, verify all UI text is English |
| deDE strings display | LOCA-03 | Requires deDE WoW client | Login with deDE locale, verify all UI text is German |
| Missing key fallback | LOCA-01 | Requires removing a key and testing | Remove one L-table entry, verify key string displays instead of error |

---

## Validation Sign-Off

- [ ] All tasks have automated verify
- [ ] Sampling continuity
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
