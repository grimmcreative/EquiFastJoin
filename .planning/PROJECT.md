# EquiFastJoin

## What This Is

EquiFastJoin is a lightweight World of Warcraft Retail addon that surfaces Quick Join (friends/guild/community) suggestions and LFG listings in a compact, event-driven UI with one-click group joining. Published on CurseForge for the WoW community. Fully compatible with WoW Midnight (12.x), localized for enUS and deDE, and modularized into 7 focused files.

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
- ✓ WoW Midnight (12.x) compatibility — v2.0 (Interface 120005, C_AddOns.LoadAddOn, generalPlaystyle, Secret Values hardening)
- ✓ Modularization — v2.0 (7 files: Locales, Core, Data, Logic, UI, Events, SlashCommands)
- ✓ English localization — v2.0 (L-table with enUS primary, 35 deDE overrides, metatable fallback)
- ✓ Code quality — v2.0 (no dead code, consistent naming, resolved forward declarations)

### Active

(No active requirements — next milestone will define new goals)

### Out of Scope

- Additional locales (frFR, esES, etc.) — deferred to v3
- CurseForge localization integration — deferred to v3
- Minimap button toggle — deferred to v3
- Delisted group detection — deferred to v3
- Mobile companion integration — WoW addon only
- Classic/Wrath/Cata support — Retail only

## Context

- Shipped v2.0 with 1,085 LOC Lua across 7 module files
- Tech stack: Lua 5.1 (WoW addon API), no external dependencies
- Architecture: Modular files with `local _, EFJ = ...` namespace pattern
- Localization: L-table with metatable fallback, enUS keys, deDE overrides
- API: Uses C_LFGList, C_SocialQueue, C_Timer, C_AddOns (all Midnight-compatible)
- Published on CurseForge with GitHub Actions CI for tagged releases
- 8 human UAT items pending live WoW Midnight client verification

## Constraints

- **Tech stack**: Lua (WoW addon API), no external build tools
- **Compatibility**: Must work with WoW Midnight (12.x) live servers
- **Backwards compat**: SavedVariables (EquiFastJoinDB) must migrate cleanly
- **API surface**: Must use only public, non-tainted WoW API calls
- **Localization**: English as primary, German as secondary

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Modularize into 7 separate files | Single 1081-line file was hard to maintain | ✓ Good — clean dependency chain |
| Add L-table localization system | Hardcoded German blocked international adoption | ✓ Good — 35 strings, metatable fallback |
| Research Midnight API changes before coding | Avoid guessing — verify what actually changed | ✓ Good — found activityIDs change, Secret Values |
| Standalone L-table (no AceLocale) | Overkill for 2-locale addon | ✓ Good — zero dependencies |
| Nil-guard pattern for deprecated APIs | Backwards compat without conditional branches | ✓ Good — reused in Phase 2 |
| issecretvalue guards for Secret Values | Midnight taint system can throw on field access | ✓ Good — defensive, nil-guarded |
| UISliderTemplateWithLabels for slider | OptionsSliderTemplate status uncertain on Midnight | ✓ Good — simpler than conditional |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-04-18 after v2.0 milestone*
