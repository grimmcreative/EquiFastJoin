---
phase: 1
slug: toc-load-gate
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual (WoW addon — Lua runs only inside game client) |
| **Config file** | none |
| **Quick run command** | `grep "## Interface:" EquiFastJoin.toc` |
| **Full suite command** | Load addon in WoW client, check addon list |
| **Estimated runtime** | ~5 seconds (grep) / ~60 seconds (in-game) |

---

## Sampling Rate

- **After every task commit:** Run `grep "## Interface:" EquiFastJoin.toc`
- **After every plan wave:** Verify Lua syntax with `luac -p EquiFastJoin.lua` if available
- **Before `/gsd-verify-work`:** Full in-game load test
- **Max feedback latency:** 5 seconds (static checks)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | COMP-01 | — | N/A | static | `grep "## Interface: 120" EquiFastJoin.toc` | N/A | pending |
| 1-01-02 | 01 | 1 | COMP-02 | — | N/A | static | `grep "C_AddOns" EquiFastJoin.lua` | N/A | pending |

*Status: pending · green · red · flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework needed — WoW addon Lua has no standalone test runner. Static grep checks verify code changes.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Addon appears in WoW addon list as enabled | COMP-01 | Requires WoW game client | 1. Launch WoW 2. Open AddOns panel 3. Verify EquiFastJoin shows enabled (not grayed) |
| No Lua load error on login | COMP-01, COMP-02 | Requires WoW game client | 1. Login to character 2. Check for Lua error popup 3. Verify no errors in BugSack/Swatter |
| Join dialog opens via C_AddOns.LoadAddOn | COMP-02 | Requires WoW game client and active LFG listing | 1. Open EFJ list 2. Click Join on a listing 3. Verify Blizzard dialog appears |

---

## Validation Sign-Off

- [ ] All tasks have static verify or manual verification documented
- [ ] Sampling continuity: grep checks after every commit
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
