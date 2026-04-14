# Architecture Patterns: WoW Addon Modularization

**Domain:** WoW Retail addon — modular file organization
**Project:** EquiFastJoin
**Researched:** 2026-04-14
**Confidence:** HIGH (WoW addon patterns are stable, well-documented on warcraft.wiki.gg and wowpedia)

---

## TOC File Loading Mechanics

### How It Works

The `.toc` file is a manifest listing every Lua (and XML) file in load order. WoW reads this list top to bottom and executes each file sequentially before the next begins. **Order is absolute** — a function defined in file B cannot be called during the loading of file A if A appears before B in the TOC.

```
## Interface: 120000
## Title: EquiFastJoin
## SavedVariables: EquiFastJoinDB

Locales\enUS.lua
Locales\deDE.lua
Core\Constants.lua
Core\Utils.lua
Core\State.lua
Data\LFGData.lua
Data\QuickJoinData.lua
Logic\Filters.lua
Logic\JoinLogic.lua
UI\Rows.lua
UI\MainFrame.lua
UI\Options.lua
Events.lua
SlashCommands.lua
```

**Rules:**
- Files listed first are available to all files listed after them
- Locales must be first (everything else uses `L["key"]`)
- Constants and utilities must precede the code that uses them
- The event registration file should be last (it ties all modules together)

### Saved Variables Timing

`SavedVariables` (e.g., `EquiFastJoinDB`) are populated by WoW **after** all Lua files finish loading. They are available starting at `ADDON_LOADED`, not at file load time. Code that reads `EquiFastJoinDB` at module-level (outside a function) will see `nil`.

---

## State Sharing Between Files: The Addon Namespace

WoW passes two arguments to every Lua file in an addon via vararg `(...)`:

- `arg1` — addon name string (`"EquiFastJoin"`)
- `arg2` — a **shared private table**, the same table instance across all files

This is the canonical zero-dependency pattern for sharing state between files without polluting `_G`.

### Pattern (every file starts with this)

```lua
local AddonName, EFJ = ...
```

`EFJ` (the namespace table) is the same object in every file. Assign to it in early files; read from it in later files.

### Initialization File (loads first after locales)

```lua
-- Core/Constants.lua
local AddonName, EFJ = ...

EFJ.VERSION = "2.0.0"
EFJ.State = { applications = {} }
EFJ.UI = {}
EFJ.Options = {}

local DEFAULTS = {
  debug = false,
  scale = 1.0,
  -- ...all defaults
}
EFJ.DEFAULTS = DEFAULTS
```

### Module File (loads later)

```lua
-- UI/MainFrame.lua
local AddonName, EFJ = ...

function EFJ.UI:Create()
  -- EFJ.State is accessible here because Constants.lua loaded first
end
```

### Global Table vs. Namespace Table

The current code assigns `_G.EquiFastJoin = EFJ`. After modularization this becomes unnecessary — every file gets `EFJ` via `...`. Keep the global assignment only if other addons need to call into EquiFastJoin from outside (not the case here). Remove it to reduce global namespace pollution.

---

## Localization File Pattern

### Standard L-Table (no external libraries needed)

For a lightweight addon like EquiFastJoin, AceLocale-3.0 adds LibStub as a dependency with significant boilerplate. The direct metatable pattern is the right choice: no dependencies, fallback to key string on missing translation.

```lua
-- Locales/enUS.lua
local AddonName, EFJ = ...

local L = {}
EFJ.L = L

-- Metatable: if a key is missing, return the key itself as fallback
setmetatable(L, { __index = function(t, k)
  local v = tostring(k)
  rawset(t, k, v)
  return v
end })

L["Join"] = "Join"
L["Leave"] = "Leave"
L["Invited"] = "Invited"
L["Unknown Activity"] = "Unknown Activity"
L["Options Title"] = "EquiFastJoin Options"
L["Show Dungeons"] = "Show Dungeons"
-- ... all strings
```

```lua
-- Locales/deDE.lua
local AddonName, EFJ = ...

-- Only load if client locale is German
if GetLocale() ~= "deDE" then return end

local L = EFJ.L  -- already created by enUS.lua (loaded first)

L["Join"] = "Beitreten"
L["Leave"] = "Abmelden"
L["Invited"] = "Eingeladen"
L["Unknown Activity"] = "Unbekannte Aktivität"
-- ... override only the strings that differ
```

### Usage in Module Files

```lua
-- Any module file
local AddonName, EFJ = ...
local L = EFJ.L

-- Then use strings:
row.join:SetText(L["Join"])
UIErrorsFrame:AddMessage(L["Join blocked in combat"])
```

### TOC Loading Order for Locales

enUS.lua must load before deDE.lua (enUS creates the table, deDE overrides it). Both must load before any file that references `EFJ.L`.

---

## Recommended Module Breakdown for EquiFastJoin

Based on the existing code sections (per `.planning/codebase/STRUCTURE.md`):

```
EquiFastJoin/
├── EquiFastJoin.toc
├── EquiFastJoin.lua             (DELETED — replaced by modules)
├── Locales/
│   ├── enUS.lua                 (creates EFJ.L, all English strings)
│   └── deDE.lua                 (overrides for German locale)
├── Core/
│   ├── Constants.lua            (EFJ namespace init, DEFAULTS, ROW constants)
│   └── Utils.lua                (BuildSignature, ColorizeByClass, DBG, CopyDefaults)
├── Data/
│   ├── LFGData.lua              (GetActivityInfoForRes, ClassifyResult, BuildActivityText,
│   │                             GetFreshResultInfo, GatherResults)
│   └── QuickJoinData.lua        (GatherQuickJoinEntries, HasQuickJoinSuggestions)
├── Logic/
│   ├── Filters.lua              (ResultMatchesFilters, BuildCategoryColor)
│   └── JoinLogic.lua            (TryJoin, TryJoinAndMark, CancelApplicationAndMark)
├── UI/
│   ├── Rows.lua                 (CreateRow, SetRoleIconsFromLFG, SetMemberIconsFromLFG,
│   │                             SetQuickJoinMemberIcons, FindLeaderClass,
│   │                             ComputeRowHeight, Relayout)
│   ├── MainFrame.lua            (EFJ.UI:Create, EFJ.UI:SetRows, EFJ.UI:ShowListFor,
│   │                             EFJ.UI:ShowQuickJoin, EFJ.UI:ShowBanner, EFJ.UI:ShowTest,
│   │                             EFJ.UI:HideIfEmpty, EFJ.UI:UpdateJoinButton,
│   │                             EFJ.UI:MarkAppliedByID, ticker functions, ToastForIDs)
│   └── Options.lua              (EFJ.Options:Create, AddCheck, AddSlider, AddButton,
│                                 EFJ_OpenOptions, Settings API registration)
├── Events.lua                   (CreateFrame event frame, all event registrations,
│                                 OnEvent handler, ProcessResultsAndMaybeShow, timers)
└── SlashCommands.lua            (SLASH_EFJ1, SlashCmdList["EFJ"])
```

### TOC File After Modularization

```
## Interface: 120000
## Title: EquiFastJoin
## Title-deDE: EquiFastJoin
## Notes: Event-driven LFG rendering (no manual search). Minimalist UI.
## Notes-deDE: Zeigt Schnellbeitritt/LFG-Einträge und ermöglicht Direktbeitritt.
## Author: Maximilian Grimm | grimm@grimmcreative.com
## Version: 2.0.0
## SavedVariables: EquiFastJoinDB
## DefaultState: enabled
## IconTexture: Interface/AddOns/EquiFastJoin/Media/LogoAddon

Locales\enUS.lua
Locales\deDE.lua
Core\Constants.lua
Core\Utils.lua
Data\LFGData.lua
Data\QuickJoinData.lua
Logic\Filters.lua
Logic\JoinLogic.lua
UI\Rows.lua
UI\MainFrame.lua
UI\Options.lua
Events.lua
SlashCommands.lua
```

---

## Component Boundaries and Dependencies

| Module | Responsibility | Reads From | Writes To |
|--------|---------------|------------|-----------|
| `Locales/enUS.lua` | Create L table, define English strings | — | `EFJ.L` |
| `Locales/deDE.lua` | Override German strings | `EFJ.L` | `EFJ.L` |
| `Core/Constants.lua` | Namespace init, DEFAULTS, UI constants | — | `EFJ.*` |
| `Core/Utils.lua` | Shared pure helpers | `EFJ.L`, `EquiFastJoinDB` | nothing (returns values) |
| `Data/LFGData.lua` | C_LFGList API wrappers | WoW API | `EFJ` (helper functions) |
| `Data/QuickJoinData.lua` | C_SocialQueue API wrappers | WoW API, LFGData | `EFJ` (helper functions) |
| `Logic/Filters.lua` | Activity classification, color, filter logic | `EFJ.L`, LFGData, `EquiFastJoinDB` | nothing (returns values) |
| `Logic/JoinLogic.lua` | Apply/cancel group logic, combat guards | WoW API, `EFJ.State`, `EFJ.UI` | `EFJ.State.applications` |
| `UI/Rows.lua` | Row frame creation, icon rendering | WoW API, `EFJ.L` | row frame objects |
| `UI/MainFrame.lua` | Main window, row management, view modes | Rows, Filters, JoinLogic, `EquiFastJoinDB` | `EFJ.UI.*` |
| `UI/Options.lua` | Options panel, Settings API | `EFJ.L`, `EquiFastJoinDB`, MainFrame | `EFJ.Options.*` |
| `Events.lua` | Event frame, all WoW event handling | All modules | — (drives everything) |
| `SlashCommands.lua` | `/efj` command handling | `EFJ.UI`, `EFJ.Options`, Data modules | — |

---

## Forward Declaration Pattern (Critical)

The current monolithic file uses forward declarations to handle mutual references:

```lua
local FindLeaderClass
local BuildCategoryColor
-- ... then defined later
FindLeaderClass = function(...) end
BuildCategoryColor = function(...) end
```

After modularization, forward declarations within a file are still needed if functions in the same file reference each other before definition. However, **cross-file references resolve naturally** because the TOC ensures dependency files load first and assign to `EFJ.*` before dependent files execute.

Example: `Rows.lua` needs `EFJ.L` (defined in locales) and `FindLeaderClass` (defined in the same file or in Rows.lua itself). Since locales load before Rows.lua, `EFJ.L` is ready. `FindLeaderClass` should move from its current position in the monolith to Rows.lua where it is used.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Module-Level SavedVariables Access

**What:** Reading `EquiFastJoinDB.someKey` at module scope (outside any function), at file load time.

**Why bad:** `SavedVariables` are nil when files execute. They only become available after `ADDON_LOADED`. Any module-level read returns nil and silently corrupts defaults.

**Instead:** All `EquiFastJoinDB` reads must happen inside functions called after `ADDON_LOADED`.

### Anti-Pattern 2: Circular Dependencies

**What:** Module A calls a function defined in Module B, and Module B calls a function defined in Module A (at load time, not inside deferred functions).

**Why bad:** WoW's sequential file loading means one must come before the other. The later file's functions don't exist yet when the earlier file executes.

**Instead:** Push shared logic into a third module that both can depend on (the Utils/Data pattern above), or ensure calls only happen inside event handlers (deferred to after all files load).

### Anti-Pattern 3: Global Function Leakage

**What:** Defining top-level functions as globals (`function MyFunction()` without `local`).

**Why bad:** Pollutes `_G`, risks collision with Blizzard or other addon functions, harder to trace.

**Instead:** Assign all functions to the `EFJ` namespace table or use `local function` within a file.

### Anti-Pattern 4: XML File Inclusion

**What:** Using an XML file with `<Script file="..."/>` tags instead of direct TOC listing.

**Why bad:** Adds indirection for no benefit in a small addon; harder for contributors to trace load order.

**Instead:** List Lua files directly in TOC. XML is only warranted for addons using XML-defined frame templates.

---

## Loading Order Dependency Graph

```
enUS.lua
    └── deDE.lua (reads EFJ.L)
            └── Constants.lua (reads nothing from EFJ.L, creates EFJ.State/EFJ.UI/EFJ.Options)
                    └── Utils.lua (reads EFJ.L for error messages if any)
                            ├── LFGData.lua (reads nothing, defines EFJ helper functions)
                            └── QuickJoinData.lua (reads LFGData helpers)
                                    └── Filters.lua (reads LFGData helpers, EquiFastJoinDB at runtime)
                                            └── JoinLogic.lua (reads EFJ.L, EFJ.State, EFJ.UI at runtime)
                                                    └── Rows.lua (reads EFJ.L, WoW API)
                                                            └── MainFrame.lua (reads all above at runtime)
                                                                    └── Options.lua (reads EFJ.L, EFJ.UI)
                                                                            └── Events.lua (reads all)
                                                                                    └── SlashCommands.lua
```

---

## Migration Strategy: Monolith to Modules

The safest approach is **extract-and-verify**, not big-bang rewrite:

1. Create the directory structure and empty files
2. Migrate one section at a time, starting with the most self-contained (Locales, Constants, Utils)
3. After each file is extracted, the TOC references it; test that the addon still loads in-game
4. Migrate Data, then Logic, then UI layers last (most coupled)
5. Extract Events.lua second to last (it references everything)
6. Extract SlashCommands.lua last (simplest, safest final step)
7. Delete EquiFastJoin.lua only when all sections have been verified

**Key migration risk:** The existing code uses `local` declarations that span sections. For example, `local FindLeaderClass` is declared at the top, used in the UI section, and defined in the middle. When split into files, the variable must move to the file where it is both defined and used (Rows.lua).

---

## Scalability Considerations

| Concern | Current (1 file) | After Modularization |
|---------|-----------------|---------------------|
| Finding code | Ctrl+F in one file | Predictable by module name |
| Adding a locale | Edit one file | Add new `Locales/frFR.lua` |
| Adding a filter type | Edit middle of monolith | Edit `Logic/Filters.lua` only |
| Adding a new UI view | Edit monolith | Add to `UI/MainFrame.lua` |
| Testing a component | Must load full addon | Each file is independently readable |
| WoW API change | Grep entire file | Change is isolated to Data/ layer |

---

## Sources

- [TOC format — Warcraft Wiki](https://warcraft.wiki.gg/wiki/TOC_format) — canonical TOC syntax and directives (HIGH confidence)
- [AddOn loading process — Warcraft Wiki](https://warcraft.wiki.gg/wiki/AddOn_loading_process) — file execution order, SavedVariables timing (HIGH confidence)
- [Using the AddOn namespace — Wowpedia](https://wowpedia.fandom.com/wiki/Using_the_AddOn_namespace) — `local addonName, ns = ...` pattern (HIGH confidence)
- [AceLocale-3.0 API — WowAce](https://www.wowace.com/projects/ace3/pages/api/ace-locale-3-0) — AceLocale reference (MEDIUM confidence — verified as current standard but not chosen for this addon due to weight)
- [Using variables across multiple files — WoWInterface](https://www.wowinterface.com/forums/showthread.php?t=51502) — community-confirmed namespace sharing pattern (MEDIUM confidence)
- `.planning/codebase/STRUCTURE.md` — existing section analysis of EquiFastJoin.lua (HIGH confidence — direct code analysis)
- `.planning/codebase/ARCHITECTURE.md` — existing layer and data flow analysis (HIGH confidence — direct code analysis)
