# Phase 3: Localization System - Research

**Researched:** 2026-04-18
**Domain:** WoW Addon Lua Localization (standalone L-table, GetLocale, string extraction)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**L-Table Architecture (LOCA-01)**
- Standalone L-table with `setmetatable` fallback — no AceLocale dependency
- L-table defined at the top of EquiFastJoin.lua, before all string usages (monolithic until Phase 4 splits files)
- Missing keys fall back to the key string itself via Metatable `__index` — no error, displays the key

**String Extraction (LOCA-02, LOCA-03, LOCA-05)**
- Extract all user-visible UI strings: button labels ("Beitreten", "Abmelden", "Eingeladen"), filter labels, error messages, options panel labels, tooltips
- Debug strings (DBG calls) remain untranslated — they are developer-facing
- Key naming convention: English string as key — `L["Join"]`, `L["Leave"]`, `L["Invited"]` (self-documenting)
- enUS locale is primary (keys = English strings)
- deDE locale overrides with current German strings (no regression)

**TOC Metadata (LOCA-04)**
- `## Title-deDE:` and `## Notes-deDE:` already present in TOC — verify and update if needed
- No additional locales in TOC (LOCA-06 deferred to v2)

**Slash Commands**
- Slash commands (/efj) and their output remain single-language (English) — technical commands, not translated

### Claude's Discretion
- Exact grouping and ordering of L-table entries
- Whether to use a locale detection function or inline `GetLocale()` check

### Deferred Ideas (OUT OF SCOPE)
- LOCA-06: Additional locale support (frFR, esES, etc.) — deferred to v2
- LOCA-07: CurseForge localization integration — deferred to v2
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOCA-01 | Standalone L-Table mit Metatable-Fallback erstellen (kein AceLocale) | L-table pattern verified from warcraft.wiki.gg |
| LOCA-02 | enUS als Primary-Locale mit allen UI-Strings | Key = English string pattern; enUS block documented |
| LOCA-03 | deDE Override-Locale mit aktuellen deutschen Strings | All 35 deDE strings catalogued with line numbers |
| LOCA-04 | TOC Title-deDE und Notes-deDE Tags | TOC already has both tags; content verified |
| LOCA-05 | Alle hardcoded deutschen Strings in EquiFastJoin.lua durch L["key"] ersetzen | Every occurrence mapped to line and deDE equivalent |
</phase_requirements>

---

## Summary

Phase 3 introduces a localization table (`L`) into the existing monolithic `EquiFastJoin.lua`. The pattern is a well-established WoW community standard: a single `local L` table with a metatable `__index` fallback that returns the key verbatim when no translation is found, enUS keys that are the English strings themselves, and a conditional `if GetLocale() == "deDE"` block that overrides each key with the current German string.

The complete inventory below covers **35 distinct user-facing strings** spread across `EquiFastJoin.lua`. All of them are currently in German. The replacements are mechanical — every callsite changes from a quoted German literal to `L["English key"]`. The L-table block is inserted once, near the top of the file after `ADDON_NAME` is declared and before `DEFAULTS`. No other files change in this phase; TOC localization tags are already correct.

The only structural decision left to Claude's discretion is how to group L-table entries (by UI area vs. alphabetical) and whether the `GetLocale()` call is stored in a local variable (`local locale = GetLocale()`) or called inline in the condition. Both are functionally equivalent; a local variable is preferred for clarity.

**Primary recommendation:** Use the single-file inline pattern (no separate locale files), store `local locale = GetLocale()` once, define enUS entries as the table body, then override with `if locale == "deDE" then` block. Insert the entire L-block at line ~10 (after ADDON_NAME, before DEFAULTS).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Locale detection (`GetLocale()`) | Addon init / top-of-file | — | Must run before any string is referenced; WoW client provides locale at load time |
| L-table definition | Addon init / top-of-file | — | Must be defined before all other code that calls `L["key"]` |
| enUS string entries | L-table block | — | Keys are English strings; table body holds English = key, so no-op for enUS |
| deDE override block | L-table block | — | Conditional override; only executes on German clients |
| String substitution (`L["key"]`) | Inline in existing callsites | — | Every hardcoded string replaced in place; no architectural change |
| TOC metadata | EquiFastJoin.toc | — | Already present; only content verification needed |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Lua metatable (`setmetatable`) | Lua 5.1 (built-in) | L-table fallback mechanism | Core Lua; zero dependencies; universally used in WoW addon localization |
| `GetLocale()` | WoW API (all retail versions) | Returns client locale code string | The only sanctioned WoW API for detecting client language |

### No external dependencies
This phase has no `npm install` or external libraries. Everything is built-in Lua and the WoW API.

---

## Architecture Patterns

### System Architecture Diagram

```
Addon load sequence:
  ADDON_NAME (line 5)
        |
        v
  [L-table block] ── GetLocale() == "enUS" ──> keys = English strings (no-op)
        |               GetLocale() == "deDE" ──> override entries with German
        |
        v
  DEFAULTS table (line ~10 after L-block)
        |
        v
  All functions, UI creation, event handlers
  (every L["key"] call resolves via L-table)
```

### Recommended L-Table Structure

```lua
-- Localization ----------------------------------------------------------------
local locale = GetLocale()
local L = setmetatable({}, {
  __index = function(_, key) return key end
})

-- enUS: keys are the English strings (identity mapping — no entries needed)
-- deDE overrides
if locale == "deDE" then
  -- Button labels
  L["Join"]       = "Beitreten"
  L["Leave"]      = "Abmelden"
  L["Invited"]    = "Eingeladen"
  L["Left"]       = "Abgemeldet"
  L["Not in LFG"] = "Nicht LFG"
  L["OK"]         = "OK"
  -- Activity text
  L["Quick Join"] = "Schnellbeitritt"
  L["Unknown Activity"] = "Unbekannte Aktivität"
  L["New Entry"]  = "Neuer Eintrag"
  -- Banner / test
  L["New Quick Join suggestions available."] = "Es sind neue Schnellbeitritt-Vorschläge verfügbar."
  L["This is a test entry."]                 = "Dies ist ein Testeintrag."
  -- Error messages
  L["EFJ: Join blocked in combat"]           = "EFJ: Beitritt im Kampf gesperrt"
  L["EFJ: Application failed"]               = "EFJ: Bewerbung fehlgeschlagen"
  L["EFJ: Action blocked (Taint)"]           = "EFJ: Aktion blockiert (Taint)"
  L["EFJ: Leave blocked in combat"]          = "EFJ: Abmelden im Kampf gesperrt"
  L["EFJ: Leave failed"]                     = "EFJ: Abmelden fehlgeschlagen"
  L["EFJ: Not available in combat"]          = "EFJ: Nicht im Kampf verfügbar"
  L["EFJ: Options blocked in combat"]        = "EFJ: Optionen im Kampf gesperrt"
  -- Options panel title
  L["EquiFastJoin Options"]                  = "EquiFastJoin Optionen"
  -- Filter checkboxes (label, tooltip)
  L["Show Dungeons"]                         = "Dungeons anzeigen"
  L["Show dungeons"]                         = "Zeigt Dungeon-Gruppen"
  L["Show Raids"]                            = "Raids/Schl\195\188ge anzeigen"
  L["Show raids"]                            = "Zeigt Raid-Gruppen"
  L["Show Mythic+"]                          = "Mythic+ anzeigen"
  L["Show M+ groups"]                        = "Zeigt M+ Gruppen"
  L["Show PvP"]                              = "PvP anzeigen"
  L["Show PvP groups"]                       = "Zeigt PvP-Gruppen"
  L["Show Custom/Quest"]                     = "Benutzerdefiniert/Quest anzeigen"
  L["Show custom/quest groups"]              = "Zeigt benutzerdefinierte/Quest-Gruppen"
  L["Auto-open on Quick Join"]               = "Bei Schnellbeitritt auto-\195\182ffnen"
  L["Opens list on Quick Join suggestions"]  = "\195\150ffnet Liste bei QuickJoin Vorschl\195\164gen"
  L["Play Sound"]                            = "Sound abspielen"
  L["Plays a short sound on open"]           = "Spielt einen kurzen Sound beim \195\150ffnen"
  L["Toast Message"]                         = "Toast Nachricht"
  L["Shows a RaidWarning toast"]             = "Zeigt eine RaidWarning Toast"
  L["Lock Frame"]                            = "Rahmen sperren"
  L["Prevents moving the window"]            = "Verhindert Verschieben des Fensters"
  L["Scale"]                                 = "Skalierung"
  -- Buttons
  L["Test Window"]                           = "Testfenster"
  L["Refresh Now"]                           = "Jetzt aktualisieren"
end
-- /Localization ---------------------------------------------------------------
```

### Pattern: Identity-key enUS

Since the metatable `__index` returns the key string itself, and since the keys ARE the English strings, enUS clients see correct English with zero additional entries in the table. The deDE block only runs on German clients.

**Source:** [warcraft.wiki.gg/wiki/Localizing_an_addon](https://warcraft.wiki.gg/wiki/Localizing_an_addon) [CITED]

### Pattern: `GetLocale()` stored once

```lua
local locale = GetLocale()  -- called once at file load; not repeated
```

`GetLocale()` is synchronous and cheap, but calling it once is cleaner than inline `GetLocale() == "deDE"` comparisons scattered through locale blocks.

**Source:** [warcraft.wiki.gg/wiki/API_GetLocale](https://warcraft.wiki.gg/wiki/API_GetLocale) [CITED]

### Anti-Patterns to Avoid

- **Separate locale files in Phase 3:** CONTEXT.md locks the monolithic approach until Phase 4 splits files. Do not create `Locales/enUS.lua` now.
- **Using numeric index keys (`L[1]`):** Defeats self-documentation. Keys must be English strings.
- **Translating DBG() strings:** DBG calls are developer-facing; they must remain as raw string literals per the locked decision.
- **Translating slash command output (`print("EFJ: Debug an")`):** Per locked decision, slash command output stays English. Lines 1013, 1015, 1019 are excluded.
- **String escape for special chars:** Lua source files must be saved as UTF-8. The WoW Lua VM handles UTF-8 transparently. Use UTF-8 directly in source — the escape sequences shown above are reference only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Locale fallback | Custom `if L[key] == nil then return key end` at each callsite | `setmetatable` `__index` | One declaration, zero per-callsite overhead |
| Locale detection | Custom file-scanning or OS detection | `GetLocale()` WoW API | Only sanctioned method; returns Blizzard's authoritative locale string |
| AceLocale | LibStub + AceLocale dependency | Standalone L-table | CONTEXT.md locks this out; AceLocale is overkill for 2 locales |

---

## Complete Hardcoded String Inventory

This is the exhaustive inventory of every user-visible string that MUST be replaced with `L["key"]`. Strings are grouped by category. DBG strings are listed separately and excluded from replacement.

### Button Labels (UI callsites)

| Line | Current German String | L["key"] (English) | Context |
|------|----------------------|---------------------|---------|
| 279 | `"Beitreten"` | `L["Join"]` | `CreateRow()` — initial button text |
| 198 | `"Abmelden"` | `L["Leave"]` | `TryJoinAndMark()` after apply |
| 229 | `"Abgemeldet"` | `L["Left"]` | `CancelApplicationAndMark()` after cancel |
| 405 | `"Abmelden"` | `L["Leave"]` | `UpdateJoinButton()` — applied state |
| 410 | `"Eingeladen"` | `L["Invited"]` | `UpdateJoinButton()` — invited state |
| 414 | `"Beitreten"` | `L["Join"]` | `UpdateJoinButton()` — default state |
| 427 | `"Abmelden"` | `L["Leave"]` | `MarkAppliedByID()` — applied/applied_with_role |
| 432 | `"Eingeladen"` | `L["Invited"]` | `MarkAppliedByID()` — invited |
| 437 | `"Beitreten"` | `L["Join"]` | `MarkAppliedByID()` — reset states |
| 543 | `"Beitreten"` | `L["Join"]` | `ShowQuickJoin()` — LFG entry |
| 549 | `"Nicht LFG"` | `L["Not in LFG"]` | `ShowQuickJoin()` — no lfgID |
| 666 | `"Beitreten"` | `L["Join"]` | `SetRows()` — default button state |
| 475 | `"OK"` | `L["OK"]` | `ShowBanner()` — dismiss button |

### Activity / Content Strings

| Line | Current German String | L["key"] (English) | Context |
|------|----------------------|---------------------|---------|
| 109 | `"Unbekannte Aktivität"` | `L["Unknown Activity"]` | `BuildActivityText()` — nil res |
| 128 | `"Unbekannte Aktivität"` | `L["Unknown Activity"]` | `BuildActivityText()` — fallback |
| 661 | `"Unbekannte Aktivität"` | `L["Unknown Activity"]` | `SetRows()` — activityText fallback |
| 693 | `"Neuer Eintrag"` | `L["New Entry"]` | `ToastForIDs()` — toast text fallback |
| 800 | `"Schnellbeitritt"` | `L["Quick Join"]` | `GatherQuickJoinEntries()` — activityText fallback |

### Banner / Test Strings

| Line | Current German String | L["key"] (English) | Context |
|------|----------------------|---------------------|---------|
| 470 | `"Schnellbeitritt"` | `L["Quick Join"]` | `ShowBanner()` — headline default |
| 473 | `"Es sind neue Schnellbeitritt-Vorschläge verfügbar."` | `L["New Quick Join suggestions available."]` | `ShowBanner()` — subline default |
| 490 | `"Dies ist ein Testeintrag."` | `L["This is a test entry."]` | `ShowTest()` — subline |

### Error Messages (UIErrorsFrame)

| Line | Current German String | L["key"] (English) | Context |
|------|----------------------|---------------------|---------|
| 144 | `"EFJ: Beitritt im Kampf gesperrt"` | `L["EFJ: Join blocked in combat"]` | `TryJoin()` — combat check |
| 179 | `"EFJ: Bewerbung fehlgeschlagen"` | `L["EFJ: Application failed"]` | `TryJoin()` — apply pcall failure |
| 181 | `"EFJ: Aktion blockiert (Taint)"` | `L["EFJ: Action blocked (Taint)"]` | `TryJoin()` — taint branch |
| 216 | `"EFJ: Abmelden im Kampf gesperrt"` | `L["EFJ: Leave blocked in combat"]` | `CancelApplicationAndMark()` |
| 221 | `"EFJ: Abmelden fehlgeschlagen"` | `L["EFJ: Leave failed"]` | `CancelApplicationAndMark()` — pcall fail |
| 478 | `"EFJ: Nicht im Kampf verfügbar"` | `L["EFJ: Not available in combat"]` | `ShowBanner()` — OK click |
| 989 | `"EFJ: Optionen im Kampf gesperrt"` | `L["EFJ: Options blocked in combat"]` | `EFJ_OpenOptions()` |

### Options Panel (EFJ.Options:Create)

| Line | Current German String | L["key"] (English) | Context |
|------|----------------------|---------------------|---------|
| 867 | `"EquiFastJoin Optionen"` | `L["EquiFastJoin Options"]` | Panel title |
| 918 (label) | `"Dungeons anzeigen"` | `L["Show Dungeons"]` | AddCheck — showDungeons |
| 918 (tip) | `"Zeigt Dungeon-Gruppen"` | `L["Show dungeons"]` | AddCheck tooltip |
| 919 (label) | `"Raids/Schlachtzüge anzeigen"` | `L["Show Raids"]` | AddCheck — showRaids |
| 919 (tip) | `"Zeigt Raid-Gruppen"` | `L["Show raids"]` | AddCheck tooltip |
| 921 (label) | `"Mythic+ anzeigen"` | `L["Show Mythic+"]` | AddCheck — showMythicPlus |
| 921 (tip) | `"Zeigt M+ Gruppen"` | `L["Show M+ groups"]` | AddCheck tooltip |
| 922 (label) | `"PvP anzeigen"` | `L["Show PvP"]` | AddCheck — showPvP |
| 922 (tip) | `"Zeigt PvP-Gruppen"` | `L["Show PvP groups"]` | AddCheck tooltip |
| 924 (label) | `"Benutzerdefiniert/Quest anzeigen"` | `L["Show Custom/Quest"]` | AddCheck — showCustom |
| 924 (tip) | `"Zeigt benutzerdefinierte/Quest-Gruppen"` | `L["Show custom/quest groups"]` | AddCheck tooltip |
| 926 (label) | `"Bei Schnellbeitritt auto-öffnen"` | `L["Auto-open on Quick Join"]` | AddCheck — openOnQuickJoin |
| 926 (tip) | `"Öffnet Liste bei QuickJoin Vorschlägen"` | `L["Opens list on Quick Join suggestions"]` | AddCheck tooltip |
| 928 (label) | `"Sound abspielen"` | `L["Play Sound"]` | AddCheck — playSound |
| 928 (tip) | `"Spielt einen kurzen Sound beim Öffnen"` | `L["Plays a short sound on open"]` | AddCheck tooltip |
| 929 (label) | `"Toast Nachricht"` | `L["Toast Message"]` | AddCheck — showToast |
| 929 (tip) | `"Zeigt eine RaidWarning Toast"` | `L["Shows a RaidWarning toast"]` | AddCheck tooltip |
| 931 (label) | `"Rahmen sperren"` | `L["Lock Frame"]` | AddCheck — lockFrame |
| 931 (tip) | `"Verhindert Verschieben des Fensters"` | `L["Prevents moving the window"]` | AddCheck tooltip |
| 933 | `"Skalierung"` | `L["Scale"]` | AddSlider label |
| 935 | `"Testfenster"` | `L["Test Window"]` | AddButton |
| 936 | `"Jetzt aktualisieren"` | `L["Refresh Now"]` | AddButton |

### Excluded: DBG Strings (remain as-is)

| Line | String | Reason |
|------|--------|--------|
| 947 | `"Addon geladen. Initialisiere Aktualisierung."` | DBG call — developer-facing, locked decision |
| 174 | `"ApplyToGroup"`, `"roles:"` etc. | DBG call — developer-facing |
| 184, 222 | `"ApplyToGroup error:"`, `"CancelApplication error:"` | DBG call — developer-facing |
| 815 | `"Process"`, `"update"`, `"#ids:"` | DBG call — developer-facing |

### Excluded: Slash Command Output (remain English, per locked decision)

| Line | String | Reason |
|------|--------|--------|
| 1013 | `"EFJ: Debug an"` | Slash command output — stays English |
| 1015 | `"EFJ: Debug aus"` | Slash command output — stays English |
| 1019 | `"EFJ: Verwende /efj test | show | hide | options | debug on|off"` | Slash command help — stays English |

**Note on line 1019:** This string is currently in German ("Verwende") but per the locked decision slash command output stays in a single language. The planner must decide: either leave it in German (consistent with current deDE behavior) or migrate it to English as part of this phase. Recommendation: update to English (`"EFJ: Usage: /efj test | show | hide | options | debug on|off"`) since the locked decision says slash commands are English and this is slash command output.

---

## TOC Metadata Verification

**Current TOC state (verified from file):**

```
## Title: EquiFastJoin
## Title-deDE: EquiFastJoin
## Notes: Event-driven LFG rendering (no manual search). Minimalist UI.
## Notes-deDE: Zeigt Schnellbeitritt/LFG-Einträge und ermöglicht Direktbeitritt.
```

[VERIFIED: read EquiFastJoin.toc directly]

**Assessment:** Both `## Title-deDE:` and `## Notes-deDE:` are present. The German Notes string is accurate. LOCA-04 is satisfied with no change required — the plan only needs a verification task, not an edit task.

---

## Common Pitfalls

### Pitfall 1: Missing UTF-8 encoding
**What goes wrong:** Lua file saved as ANSI/Latin-1; German characters (ä, ö, ü, ß) appear corrupted in-game.
**Why it happens:** Most editors default to the system encoding, which may not be UTF-8 on Windows.
**How to avoid:** Confirm file is saved as UTF-8 (no BOM). VS Code shows encoding in status bar. Git will preserve encoding as-is.
**Warning signs:** Characters appear as `?` or `â` sequences in-game.

### Pitfall 2: L-table defined after first usage
**What goes wrong:** Lua executes top-to-bottom; if any function definition captures `L["key"]` before `L` is declared, it gets `nil` at capture time.
**Why it happens:** In Lua, `L["key"]` is evaluated at call time (not definition time) when used inside a function body — BUT the `local L` declaration must be in scope. If `local L` is not yet declared when the function body that references it is defined, Lua will silently use an upvalue of `nil`.
**How to avoid:** Place the entire L-table block immediately after `local ADDON_NAME = ...` on line 5, before the DEFAULTS table and all function definitions.
**Warning signs:** `attempt to index a nil value (global 'L')` error at load time.

### Pitfall 3: Key string mismatch between L-table and callsite
**What goes wrong:** `L["Join"]` in the table but `L["join"]` at the callsite (case mismatch) → fallback returns `"join"` (lowercase key string visible to user).
**Why it happens:** Metatable fallback returns the key itself, so typos silently display the key rather than erroring.
**How to avoid:** Use exact English strings as keys everywhere. Grep verification: after replacement, `grep -n 'L\["' EquiFastJoin.lua` should list every callsite, and every key should match a deDE entry.
**Warning signs:** Users see raw English key strings like `"Join"` or `"Unknown Activity"` in the German client instead of translated text.

### Pitfall 4: Translating "Mythic+" in context
**What goes wrong:** `"Mythic+"` on line 126 is a content name, not a UI label — translating it would change a proper noun.
**Why it happens:** It looks like a German string (it's used as activity text fallback) but "Mythic+" is a brand name identical in all locales.
**How to avoid:** Keep `"Mythic+"` as a raw string literal; do NOT wrap it in `L["Mythic+"]`. The deDE translation would be identical, making the L-table entry useless noise.
**Warning signs:** N/A — this is a prevention note.

### Pitfall 5: Duplicate SetText calls for the same button
**What goes wrong:** `"Beitreten"` appears on 6 lines. If any callsite is missed, that button shows German on enUS clients.
**Why it happens:** Button text is set in multiple code paths (CreateRow, UpdateJoinButton, MarkAppliedByID, ShowQuickJoin, SetRows).
**How to avoid:** Use the inventory table above as a checklist. After replacement, verify with: `grep -n '"Beitreten"\|"Abmelden"\|"Eingeladen"\|"Abgemeldet"' EquiFastJoin.lua` — result should be zero matches.

---

## Code Examples

### L-Table Block (verified pattern)

```lua
-- Source: warcraft.wiki.gg/wiki/Localizing_an_addon
-- Source: phanx.net/addons/tutorials/localize
local locale = GetLocale()
local L = setmetatable({}, {
  __index = function(_, key) return key end
})
if locale == "deDE" then
  L["Join"]    = "Beitreten"
  L["Leave"]   = "Abmelden"
  -- ... (full table in Standard Stack section above)
end
```

### Usage in existing code (after replacement)

```lua
-- Before:
row.join:SetText("Beitreten")

-- After:
row.join:SetText(L["Join"])
```

```lua
-- Before:
UIErrorsFrame:AddMessage("EFJ: Beitritt im Kampf gesperrt", 1, 0.2, 0.2)

-- After:
UIErrorsFrame:AddMessage(L["EFJ: Join blocked in combat"], 1, 0.2, 0.2)
```

```lua
-- Before (line 109):
if not res then return "Unbekannte Aktivität" end

-- After:
if not res then return L["Unknown Activity"] end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate locale `.lua` files per language | Single-file monolithic L-table (for small addons) | Phase 4 will introduce separate files | Phase 3 uses monolithic; Phase 4 modularizes |
| AceLocale / LibStub | Standalone metatable pattern | Community shift for lightweight addons | No library dependency needed for 2 locales |

**Deprecated / out of scope:**
- `GetLocale()` returning `"enGB"`: British English clients return `"enUS"` since early WoW. No `enGB` block needed.

---

## Environment Availability

Step 2.6: SKIPPED (no external tools, services, or CLIs required — this phase is pure Lua source editing)

---

## Validation Architecture

nyquist_validation is enabled. WoW addons run inside the game client Lua VM — no host-side unit test framework (no `pytest`, `jest`, etc.) exists for this stack. Validation is in-game smoke testing only.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — WoW Lua VM only; no automated test runner |
| Config file | N/A |
| Quick run command | Load addon in WoW client, run `/efj test` |
| Full suite command | Manual checklist below |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOCA-01 | L-table with metatable fallback returns key for missing entries | manual smoke | `/efj test` + inspect UI | N/A (no test file possible) |
| LOCA-02 | enUS client sees English strings | manual smoke | Set client to enUS, load addon, check all buttons and options | N/A |
| LOCA-03 | deDE client sees German strings with no regression | manual smoke | Set client to deDE, check all buttons and options match previous German strings | N/A |
| LOCA-04 | TOC tags present | static grep | `grep "Title-deDE\|Notes-deDE" EquiFastJoin.toc` | EquiFastJoin.toc ✅ |
| LOCA-05 | No hardcoded German strings remain | static grep | `grep -n '"[^"]*[äöüÄÖÜß][^"]*"' EquiFastJoin.lua` — must return only DBG/excluded lines | EquiFastJoin.lua ✅ |

### Sampling Rate
- **Per task commit:** Run the static grep verification command above to confirm no remaining German literals
- **Per wave merge:** Full in-game smoke test on both enUS and deDE paths
- **Phase gate:** Both locale paths visually verified before `/gsd-verify-work`

### Wave 0 Gaps
None — no test infrastructure to create. The static grep commands are sufficient for automated verification of LOCA-04 and LOCA-05. LOCA-01/02/03 require live client testing which is manual.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `"Mythic+"` (lines 125–126) is a brand name identical in all locales and should not be translated | Pitfall 4 | Minor — if deDE uses a different term, the activity text shows English "Mythic+" to German users |
| A2 | Line 1019 (`"EFJ: Verwende ..."`) should be updated to English per locked "slash commands are English" decision | String Inventory (Excluded) | Minor — if left in German, German users see German help text for slash commands |
| A3 | `GetLocale()` is available at the top-level Lua execution context (before ADDON_LOADED fires) | Code Examples | If wrong, `locale` would be nil; mitigation: move `local locale = GetLocale()` inside ADDON_LOADED handler |

---

## Open Questions

1. **Line 1019 — German slash command help text**
   - What we know: The string `"EFJ: Verwende /efj test | show | hide | options | debug on|off"` is in German and is slash command output.
   - What's unclear: CONTEXT.md says "slash commands stay English" but this was previously German. Should it be updated to English as part of LOCA-05, or is it explicitly excluded?
   - Recommendation: Update to English (`"EFJ: Usage: /efj test | show | hide | options | debug on|off"`) — it is slash command output and should be language-consistent with the rest of the slash command behavior.

2. **`GetLocale()` call timing**
   - What we know: `GetLocale()` is a standard WoW API call available at file load time (confirmed in community docs).
   - What's unclear: Whether calling it at the top of EquiFastJoin.lua (before ADDON_LOADED) is safe in all WoW builds.
   - Recommendation: It is safe — this is the universal pattern used by all WoW addons and confirmed by warcraft.wiki.gg examples. [ASSUMED based on universal community practice; not verified against Midnight 12.x patch notes specifically]

---

## Project Constraints (from CLAUDE.md)

- **Single Lua file:** Phase 3 must not split into multiple files (Phase 4 does that). L-table goes inside EquiFastJoin.lua.
- **No external dependencies:** AceLocale is explicitly excluded in REQUIREMENTS.md and CLAUDE.md.
- **WoW-only APIs:** `GetLocale()` is a public, non-tainted WoW API call — compliant.
- **Backwards compat (SavedVariables):** No SavedVariables change in this phase.
- **UTF-8 encoding:** File must remain UTF-8 (see Pitfall 1).
- **Code style:** 2-space indentation, camelCase locals, comment separators with `-- Section ---` pattern.
- **Error messages:** Continue using `UIErrorsFrame:AddMessage()` for error strings; just wrap the string literal in `L["key"]`.
- **English primary, German secondary:** Confirmed by REQUIREMENTS.md and CONTEXT.md.

---

## Sources

### Primary (HIGH confidence)
- [warcraft.wiki.gg/wiki/Localizing_an_addon](https://warcraft.wiki.gg/wiki/Localizing_an_addon) — L-table metatable pattern, file structure
- [warcraft.wiki.gg/wiki/API_GetLocale](https://warcraft.wiki.gg/wiki/API_GetLocale) — GetLocale() return values, enGB=enUS note
- EquiFastJoin.lua — direct source read, all string line numbers verified
- EquiFastJoin.toc — direct source read, TOC tag presence verified

### Secondary (MEDIUM confidence)
- [phanx.net/addons/tutorials/localize](https://phanx.net/addons/tutorials/localize) — single-file monolithic pattern, key naming conventions

### Tertiary (LOW confidence)
- None used

---

## Metadata

**Confidence breakdown:**
- String inventory: HIGH — direct grep of source file, every line verified
- L-table pattern: HIGH — verified from warcraft.wiki.gg official addon dev docs
- GetLocale() values: HIGH — verified from warcraft.wiki.gg API reference
- TOC tag status: HIGH — direct file read

**Research date:** 2026-04-18
**Valid until:** 2026-10-18 (stable WoW API; GetLocale pattern unchanged for 15+ years)
