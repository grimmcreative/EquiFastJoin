# Feature Landscape

**Domain:** WoW LFG / Group Finder addon (Retail)
**Researched:** 2026-04-14
**Confidence:** MEDIUM — LFG ecosystem from CurseForge survey (MEDIUM), localization patterns from Warcraft Wiki + AceLocale docs (HIGH), Midnight API signals from wowhead/warcraft.wiki.gg (MEDIUM)

---

## Current Feature Baseline

EquiFastJoin already has these features as of v1.8.3:

| Feature | Status | Notes |
|---------|--------|-------|
| Quick Join suggestions (friends/guild/community) | Shipped | Event-driven via SOCIAL_QUEUE_UPDATE |
| LFG listing display (leader, activity, role icons) | Shipped | Via C_LFGList |
| One-click join via Blizzard application dialog | Shipped | Safe, non-tainted |
| Filter toggles: Dungeons, Raids, M+, PvP, Custom | Shipped | SavedVariables-persisted |
| Join/Leave button state management | Shipped | Tracks applications in EFJ.State |
| Options panel (sound, scale, lock, position) | Shipped | InterfaceOptions registration |
| Event-driven updates, no manual search | Shipped | Core design principle |
| Combat lockdown guards | Shipped | InCombatLockdown() checks |
| SavedVariables persistence | Shipped | EquiFastJoinDB |
| Slash commands (/efj) | Shipped | test, show, hide, options, debug |
| German UI strings | Shipped | Hardcoded — needs L table |

---

## Table Stakes

Features users on CurseForge expect. Missing = confusion or negative reviews.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **English as primary locale** | English is the CurseForge default audience; German-only blocks 90%+ of users | Low | All hardcoded strings listed in CONCERNS.md must migrate to L table |
| **Localized UI strings via L table** | Standard WoW addon convention; AceLocale or standalone metatables are universal | Low | Use standalone metatable pattern (no library dependency) |
| **TOC localized metadata tags** | CurseForge and Blizzard addon UI shows Title/Notes per client locale | Low | `## Title-deDE:`, `## Notes-enUS:`, `## Notes-deDE:` |
| **Valid Interface version for current WoW** | Addon silently doesn't load if TOC version is wrong | Trivial | Current is 110200 (11.2.0); Midnight needs 120000 or 120001 |
| **Options panel accessible from Escape menu** | Standard discoverability; users find addons via ESC > Interface > AddOns | Low | Already present but uses old InterfaceOptionsFrame API — may need Settings API migration for Midnight |
| **Correct button/action text in English** | Users who read English will see "Abmelden", "Beitreten" — immediately off-putting | Low | Blocked on L table |
| **SavedVariables migration on update** | Existing users must not lose settings when updating | Low | CopyDefaults() pattern already present; version key should be added |
| **Slash command discoverability** | /efj with no args should print usage help | Trivial | Currently /efj without arg does nothing useful |

---

## Differentiators

Features that set EquiFastJoin apart from competing addons. Not required but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Zero-navigation join flow** | No clicks through nested menus — one click from notification to application | Low | Already the core value; must be preserved through API migration |
| **Event-driven, no Search() call** | Avoids taint from C_LFGList.Search(); addons that call Search() are broken on Midnight | Low | Already implemented; document as explicit design decision |
| **Quick Join cross-reference** | Only surfaces groups relevant to the player's social graph — signal over noise | Medium | Already implemented; differentiator vs generic LFG scanners |
| **Compact non-intrusive window** | Minimal screen footprint; scales and locks; out of the way | Low | Already implemented |
| **German locale as secondary** | Rare for non-German addons to ship deDE; expands DE audience | Low | Preserve existing DE strings as the deDE locale file |
| **Activity color coding** | Visual category at a glance without reading text | Low | Already implemented via BuildCategoryColor() |
| **Class-colored leader names** | Immediate recognition of leader class | Low | Already implemented via ColorizeByClass() |

---

## Anti-Features

Features to deliberately NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **AceLocale or Ace3 dependency** | Heavy library dependency for a lightweight addon; adds ~30KB, requires LibStub; this addon has zero library dependencies by design | Use standalone metatable L table pattern |
| **Full LFG search UI replacement** | Premade Groups Filter and LFG Group Bulletin Board already own that space; high complexity for low differentiation | Stay focused on Quick Join + one-click apply |
| **Minimap button** | Increases surface area; /efj slash command already covers toggle; minimap buttons clutter UI | Keep slash command as primary interface |
| **Item level / gear score filtering** | Premade Groups Filter specializes in this; adds significant complexity and fragile API dependency | Out of scope for this milestone |
| **Social features (whisper leader, inspect)** | Increases scope dramatically; not part of core value | Out of scope |
| **Profile system (multiple configs)** | Adds significant complexity; single-character use is sufficient | Out of scope; single EquiFastJoinDB global is enough |
| **New locales beyond enUS + deDE** | Community can contribute later; shipping empty locale stubs is noise | Ship enUS + deDE; add ## X-Localizations note to README inviting contributions |
| **Combat rotation or performance addons** | Midnight specifically targets restricting combat-advantage addons; stay away from anything that provides combat information | Restrict to UI, LFG display, social queue |

---

## Localization Patterns

### Standard WoW Addon Localization (HIGH confidence — Warcraft Wiki, AceLocale docs)

Two mainstream approaches exist:

**1. Standalone metatable (recommended for EquiFastJoin)**

No library dependency. Self-documenting. Key falls back to itself if no translation exists (prevents nil errors).

```lua
-- Localization/enUS.lua (loaded first — defines defaults)
local ADDON_NAME, ns = ...
local L = setmetatable({}, {
  __index = function(t, k)
    local v = tostring(k)  -- fallback: key becomes its own value
    rawset(t, k, v)
    return v
  end
})
ns.L = L

-- English strings (primary)
L["Join"] = "Join"
L["Leave"] = "Leave"
L["Unknown Activity"] = "Unknown Activity"
-- ... all UI strings

-- Localization/deDE.lua (loaded after — overrides for German)
local ADDON_NAME, ns = ...
local L = ns.L

if GetLocale() ~= "deDE" then return end

L["Join"] = "Beitreten"
L["Leave"] = "Abmelden"
L["Unknown Activity"] = "Unbekannte Aktivität"
-- ... all German overrides
```

Usage in code: `L["Join"]` — returns enUS string if deDE not loaded or key not translated.

**2. AceLocale-3.0 (for Ace3 addons)**

Uses LibStub, NewLocale/GetLocale pattern. Handles nil fallbacks centrally. Over-engineered for a single-file or small addon. Not recommended for EquiFastJoin.

### TOC File Localization Tags (HIGH confidence — Warcraft Wiki TOC format docs)

```
## Title: EquiFastJoin
## Title-deDE: EquiFastJoin
## Notes: Quick one-click group joining for friends and LFG listings.
## Notes-enUS: Quick one-click group joining for friends and LFG listings.
## Notes-deDE: Schnelles Beitreten von Gruppen per Klick – Freunde und LFG-Einträge.
```

Supported locale suffixes: enUS, enGB, deDE, frFR, esES, esMX, ruRU, zhCN, zhTW, koKR.

### GetLocale() Values (HIGH confidence — Warcraft Wiki API docs)

`GetLocale()` returns one of: `"enUS"`, `"enGB"`, `"deDE"`, `"frFR"`, `"esES"`, `"esMX"`, `"ruRU"`, `"zhCN"`, `"zhTW"`, `"koKR"`, `"ptBR"`.

For EquiFastJoin: guard deDE locale file with `if GetLocale() ~= "deDE" then return end`.

### Locale File Loading Order in TOC

Locale files must be listed in TOC before the main Lua file. enUS (default) first, then locale-specific overrides:

```
Localization\enUS.lua
Localization\deDE.lua
Core\Events.lua
Core\Logic.lua
UI\Frame.lua
```

### String Key Conventions

Community standard: use English string as the key (not a symbolic key like `"EFJ_BTN_JOIN"`). This means enUS locale file is optional — the key itself is the fallback. deDE file contains only overrides.

Two schools:
- **Symbolic keys** (`L["BTN_JOIN"]`): Requires enUS locale file to map symbols to strings. Safer for refactoring.
- **English-as-key** (`L["Join"]`): Simpler, no enUS file needed, fallback is automatic. Standard for smaller addons.

Recommendation for EquiFastJoin: use English-as-key. The metatable fallback handles untranslated strings gracefully.

---

## Feature Dependencies

```
Valid TOC Interface version
  → Addon loads at all
  → Everything else

L table (localization system)
  → enUS locale file
  → deDE locale file (uses L from ns, overrides if GetLocale() == "deDE")
  → All UI strings use L["..."] instead of hardcoded values

Modular file structure
  → Localization files load before Core/UI files
  → Core and UI files read ns.L
  → TOC file lists files in dependency order

Options panel (Settings API vs InterfaceOptionsFrame)
  → Must use correct API for Midnight 12.x
  → InterfaceOptionsFrame_OpenToCategory() deprecated → Settings.OpenToCategory()
  → Affects discoverability from ESC menu

SavedVariables versioning key
  → Required before any migration logic
  → Version stored in EquiFastJoinDB.version
  → CopyDefaults() already handles new key addition
```

---

## MVP Recommendation for This Milestone

This milestone is compatibility + quality, not new features. Prioritize:

1. **TOC Interface version update to 120000/120001** — unblocks addon loading; everything else is blocked on this
2. **L table localization system** — enUS as primary, deDE as secondary; key blocker for CurseForge audience
3. **English strings in enUS locale file** — translates all hardcoded German to English keys
4. **deDE locale file** — preserves existing German strings for DE users
5. **Modularize TOC file list** — separate Localization, Core, UI, Events files loaded in order
6. **SavedVariables version key** — add `version` field to DEFAULTS; enables future migrations
7. **Options panel API check** — verify Settings API is needed for Midnight; update if required

Defer to later milestones:
- Additional locales (frFR, ruRU, etc.) — community can contribute
- Item level filtering, search history, rejection reasons — new features, out of scope
- Unit tests — valuable but separate concern from compatibility milestone

---

## Sources

- [Localizing an addon - Warcraft Wiki](https://warcraft.wiki.gg/wiki/Localizing_an_addon)
- [AceLocale-3.0 API - WowAce](https://www.wowace.com/projects/ace3/pages/api/ace-locale-3-0)
- [Localizing an addon - Wowpedia](https://wowpedia.fandom.com/wiki/Localizing_an_addon)
- [TOC format - Warcraft Wiki](https://warcraft.wiki.gg/wiki/TOC_format)
- [Patch 12.0.0/API changes - Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [Patch 12.0.1/API changes - Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes)
- [Premade Groups Filter - GitHub](https://github.com/0xbs/premade-groups-filter)
- [Premade Groups Filter - CurseForge](https://www.curseforge.com/wow/addons/premade-groups-filter)
- [LFG Group Bulletin Board - CurseForge](https://www.curseforge.com/wow/addons/lfg-group-finder-bulletin-board)
- [Majority of Addon Changes Finalized for Midnight - Wowhead](https://www.wowhead.com/news/majority-of-addon-changes-finalized-for-midnight-pre-patch-whitelisted-spells-379738)
- [GetLocale - Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_GetLocale)
- [Saving variables between game sessions - Wowpedia](https://wowpedia.fandom.com/wiki/Saving_variables_between_game_sessions)
- [Localization Question - Blizzard Forums](https://us.forums.blizzard.com/en/wow/t/localization-question/1610833)
