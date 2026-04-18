# Milestones

## v2.0 — Midnight Compatibility & Modularization

**Shipped:** 2026-04-18
**Phases:** 5 | **Plans:** 10

### Key Accomplishments
1. TOC Interface version 120005 + C_AddOns.LoadAddOn backwards-compatible fallback
2. Dead API paths removed + Midnight APIs added (generalPlaystyle, Secret Values hardening)
3. L-table localization system with enUS primary and 35 deDE overrides
4. Monolith (1081 lines) split into 7 focused modules with clean namespace pattern
5. Legacy stubs removed, naming conventions enforced across all modules

### Known Deferred Items
- 8 Human UAT scenarios pending live WoW Midnight client testing (see phase UAT files)
- 2 minor dead code items (SetMemberIconsFromLFG export, SetQuickJoinMemberIcons local)
- LOCA-06: Additional locales (frFR, esES, etc.) — deferred to v3
- LOCA-07: CurseForge localization integration — deferred to v3
- FEAT-01: Minimap button toggle — deferred to v3
- FEAT-02: Delisted group detection — deferred to v3

### Archive
- [v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)
- [v2.0-REQUIREMENTS.md](milestones/v2.0-REQUIREMENTS.md)
- [v2.0-MILESTONE-AUDIT.md](milestones/v2.0-MILESTONE-AUDIT.md)
