# EquiFastJoin

## What This Is

EquiFastJoin is a lightweight World of Warcraft Retail addon that surfaces Quick Join (friends/guild/community) suggestions and LFG listings in a compact, event-driven UI with one-click group joining. Published on CurseForge for the WoW community.

## Core Value

One-click group joining — users see relevant groups and join instantly without navigating Blizzard's multi-step LFG UI.

## Requirements

### Validated

- ✓ Quick Join suggestions display (friends/guild/community) — existing
- ✓ LFG listing display with leader name, activity type, role icons — existing
- ✓ One-click join via Blizzard application dialog — existing
- ✓ Filter toggles for Dungeons, Raids, M+, PvP, Custom — existing
- ✓ Button state management (Join/Leave) — existing
- ✓ Options panel (sound, scale, lock, position) — existing
- ✓ Event-driven updates without manual search — existing
- ✓ Combat lockdown guards — existing
- ✓ SavedVariables persistence — existing

### Active

- [ ] WoW Midnight (12.x) compatibility — update Interface version, fix broken APIs
- [ ] Modularization — split monolithic Lua into separate files (UI, Logic, Events, Localization)
- [ ] English localization — replace hardcoded German strings with localization system
- [ ] Code quality improvements — clean structure, naming, documentation for maintainability

### Out of Scope

- New features beyond current functionality — focus is compatibility and quality first
- Mobile companion integration — WoW addon only
- Classic/Wrath/Cata support — Retail only

## Context

- Addon is currently broken on WoW Midnight (12.x) — does not load due to outdated TOC Interface version (110200)
- Beyond TOC version, Midnight may have changed C_LFGList, C_SocialQueue, or UI template APIs
- All UI strings are hardcoded in German — needs localization system for CurseForge audience
- Single-file architecture (1016 lines in EquiFastJoin.lua) — needs modularization for maintainability
- Existing codebase map available in .planning/codebase/
- Published addon with external users on CurseForge — changes must not break existing user experience
- GitHub Actions CI already configured for tagged releases

## Constraints

- **Tech stack**: Lua (WoW addon API), no external build tools unless necessary
- **Compatibility**: Must work with WoW Midnight (12.x) live servers
- **Backwards compat**: SavedVariables (EquiFastJoinDB) must migrate cleanly for existing users
- **API surface**: Must use only public, non-tainted WoW API calls
- **Localization**: English as primary, German as secondary (current strings preserved)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Modularize into separate files | Single 1016-line file is hard to maintain and navigate | — Pending |
| Add localization system | Hardcoded German blocks international adoption | — Pending |
| Research Midnight API changes before coding | Avoid guessing — verify what actually changed | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-14 after initialization*
