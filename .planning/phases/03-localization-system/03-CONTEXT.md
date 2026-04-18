# Phase 3: Localization System - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

All UI strings are served from a localization table — English-locale users see English, German-locale users see German, and no hardcoded German strings remain in the main Lua file. This phase creates the L-table, populates enUS and deDE locales, and replaces all hardcoded strings.

</domain>

<decisions>
## Implementation Decisions

### L-Table Architecture (LOCA-01)
- Standalone L-table with `setmetatable` fallback — no AceLocale dependency
- L-table defined at the top of EquiFastJoin.lua, before all string usages (monolithic until Phase 4 splits files)
- Missing keys fall back to the key string itself via Metatable `__index` — no error, displays the key

### String Extraction (LOCA-02, LOCA-03, LOCA-05)
- Extract all user-visible UI strings: button labels ("Beitreten", "Abmelden", "Eingeladen"), filter labels, error messages, options panel labels, tooltips
- Debug strings (DBG calls) remain untranslated — they are developer-facing
- Key naming convention: English string as key — `L["Join"]`, `L["Leave"]`, `L["Invited"]` (self-documenting)
- enUS locale is primary (keys = English strings)
- deDE locale overrides with current German strings (no regression)

### TOC Metadata (LOCA-04)
- `## Title-deDE:` and `## Notes-deDE:` already present in TOC — verify and update if needed
- No additional locales in TOC (LOCA-06 deferred to v2)

### Slash Commands
- Slash commands (/efj) and their output remain single-language (English) — technical commands, not translated

### Claude's Discretion
- Exact grouping and ordering of L-table entries
- Whether to use a locale detection function or inline `GetLocale()` check

</decisions>

<code_context>
## Existing Code Insights

### Hardcoded German Strings Found
- Button labels: "Beitreten" (Join), "Abmelden" (Leave), "Eingeladen" (Invited), "Abgemeldet" (Left)
- Filter labels: "Dungeons anzeigen", "Raids/Schlachtzüge anzeigen", "Mythic+ anzeigen", "PvP anzeigen", "Benutzerdefiniert/Quest anzeigen"
- Options labels: "Bei Schnellbeitritt auto-öffnen", "Sound abspielen", "Toast Nachricht", "Rahmen sperren", "Skalierung"
- UI text: "Schnellbeitritt" (Quick Join), "Testfenster", "Jetzt aktualisieren"
- Error messages: "EFJ: Beitritt im Kampf gesperrt", "EFJ: Bewerbung fehlgeschlagen", "EFJ: Aktion blockiert (Taint)"
- Tooltip/description strings in AddCheck calls

### Established Patterns
- All strings are inline in the Lua code
- No existing localization infrastructure
- WoW provides `GetLocale()` which returns "enUS", "deDE", etc.

### Integration Points
- String replacements span the entire EquiFastJoin.lua file
- TOC file already has deDE metadata fields

</code_context>

<specifics>
## Specific Ideas

- Use `GetLocale()` to detect client locale at addon load time
- Define enUS table first, then conditionally override with deDE
- Pattern: `local L = setmetatable({}, {__index = function(_, key) return key end})`

</specifics>

<deferred>
## Deferred Ideas

- LOCA-06: Additional locale support (frFR, esES, etc.) — deferred to v2
- LOCA-07: CurseForge localization integration — deferred to v2

</deferred>
