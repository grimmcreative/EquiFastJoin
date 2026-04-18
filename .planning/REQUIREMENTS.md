# Requirements: EquiFastJoin v2.0

**Defined:** 2026-04-14
**Core Value:** One-click group joining — users see relevant groups and join instantly without navigating Blizzard's multi-step LFG UI.

## v1 Requirements

Requirements for Addon v2.0 release. Each maps to roadmap phases.

### Compatibility

- [ ] **COMP-01**: TOC Interface-Version auf 120005 updaten
- [ ] **COMP-02**: `LoadAddOn()` durch `C_AddOns.LoadAddOn()` ersetzen mit Backwards-Fallback
- [x] **COMP-03**: `activityID` → `activityIDs` Codepfad konsolidieren (toter Primary-Branch entfernen)
- [x] **COMP-04**: Legacy `InterfaceOptions_AddCategory` Fallback entfernen
- [x] **COMP-05**: `OptionsSliderTemplate` durch Midnight-kompatibles Template ersetzen
- [x] **COMP-06**: `generalPlaystyle` Feld für neue Content-Typen in ClassifyResult() nutzen
- [x] **COMP-07**: Secret Values Taint-Hardening für In-Instance-Nutzung

### Localization

- [ ] **LOCA-01**: Standalone L-Table mit Metatable-Fallback erstellen (kein AceLocale)
- [ ] **LOCA-02**: enUS als Primary-Locale mit allen UI-Strings
- [ ] **LOCA-03**: deDE Override-Locale mit aktuellen deutschen Strings
- [ ] **LOCA-04**: TOC `## Title-deDE:` und `## Notes-deDE:` Tags hinzufügen
- [ ] **LOCA-05**: Alle hardcoded deutschen Strings in EquiFastJoin.lua durch L["key"] ersetzen

### Modularization

- [ ] **MODR-01**: Monolith in separate Dateien aufteilen (Locales, Core, Data, UI, Events)
- [ ] **MODR-02**: Addon-Namespace Pattern (`local _, EFJ = ...`) für State-Sharing
- [ ] **MODR-03**: TOC Loading Order korrekt nach Abhängigkeiten ordnen

### Code Quality

- [ ] **QUAL-01**: Tote Codepfade und Legacy-Fallbacks entfernen
- [ ] **QUAL-02**: Forward Declarations sauber in richtige Module auflösen
- [ ] **QUAL-03**: Konsistente Namenskonventionen durchsetzen

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Extended Localization

- **LOCA-06**: Additional locale support (frFR, esES, ptBR, zhCN, koKR)
- **LOCA-07**: CurseForge localization integration (community translations)

### Enhanced Features

- **FEAT-01**: Minimap button toggle (optional)
- **FEAT-02**: Delisted group detection and notification

## Out of Scope

| Feature | Reason |
|---------|--------|
| AceLocale / LibStub dependency | Overkill for 2-locale addon, adds unnecessary dependency |
| Full search UI replacement | Would replicate Blizzard UI; EquiFastJoin is complementary, not replacement |
| Classic/Wrath/Cata support | Retail-only addon, different API surface |
| Mobile companion | WoW addon framework only |
| Profile system (per-character settings) | SavedVariables per account sufficient for current scope |
| Automated search (`C_LFGList.Search()`) | Deliberately avoided — taint risk, Midnight restrictions target this |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| COMP-01 | Phase 1 | Pending |
| COMP-02 | Phase 1 | Pending |
| COMP-03 | Phase 2 | Complete |
| COMP-04 | Phase 2 | Complete |
| COMP-05 | Phase 2 | Complete |
| COMP-06 | Phase 2 | Complete |
| COMP-07 | Phase 2 | Complete |
| LOCA-01 | Phase 3 | Pending |
| LOCA-02 | Phase 3 | Pending |
| LOCA-03 | Phase 3 | Pending |
| LOCA-04 | Phase 3 | Pending |
| LOCA-05 | Phase 3 | Pending |
| MODR-01 | Phase 4 | Pending |
| MODR-02 | Phase 4 | Pending |
| MODR-03 | Phase 4 | Pending |
| QUAL-01 | Phase 5 | Pending |
| QUAL-02 | Phase 5 | Pending |
| QUAL-03 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-14*
*Last updated: 2026-04-14 after roadmap creation*
