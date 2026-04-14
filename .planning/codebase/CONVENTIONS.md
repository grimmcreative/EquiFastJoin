# Coding Conventions

**Analysis Date:** 2026-04-14

## Naming Patterns

**Files:**
- Single monolithic file: `EquiFastJoin.lua` - Contains entire addon codebase
- Lowercase with .lua extension for Lua source files
- Configuration file: `EquiFastJoin.toc` - TOC manifest (uppercase addon name, followed by .toc)

**Functions:**
- Local functions use camelCase: `CopyDefaults()`, `BuildSignature()`, `ColorizeByClass()`, `GetActivityInfoForRes()`
- Global/API-accessible functions use PascalCase prefixed with module: `EFJ.UI:Create()`, `EFJ.UI:ShowListFor()`, `EFJ.Options:Create()`
- Forward declarations for functions used across sections: `local FindLeaderClass`, `local BuildCategoryColor`, `local SetMemberIconsFromLFG` (line 98-102)
- Helper functions often follow the pattern: `Get*()` for queries, `Build*()` for construction, `Try*()` for attempted operations with return status

**Variables:**
- Local scope uses camelCase: `leaderName`, `leaderClass`, `textActivity`, `classIcons`
- Global addon reference: `_G.EquiFastJoin = EFJ` (line 7)
- Database reference: `EquiFastJoinDB` (persisted configuration)
- Constants in UPPERCASE: `ADDON_NAME`, `DEFAULTS`, `ROW_HEIGHT`, `ROW_SPACING`, `MAX_ROWS`
- State tables use snake_case for WoW API compatibility: `lastDismissSignature`, `showRaids`, `showDungeons`, etc. (lines 11-30)

**Types:**
- No explicit type annotations (Lua is dynamically typed)
- Table keys for class information: `RAID_CLASS_COLORS[classEN]` (Blizzard API standard)
- Classification results return strings: `"MPLUS"`, `"RAID"`, `"DUNGEON"`, `"PVP"`, `"CUSTOM"`, `"OTHER"`

## Code Style

**Formatting:**
- No formal formatter detected (no .prettierrc or similar)
- Tab/space style: spaces for indentation (2-space indents observed in lines 33-41, 244-276)
- Line length: varies; UI frame setup spans long lines (line 339)
- Braces and conditional style: consistent use of `if/then/else` blocks with `end`

**Linting:**
- No linter configuration files detected (.eslintrc, .luacheckrc, biome.json)
- Manual code style enforcement via git commit messages and code review

## Import Organization

**Order:**
1. Addon initialization and global references (lines 5-10):
   ```lua
   local ADDON_NAME = ...
   local EFJ = {}
   _G.EquiFastJoin = EFJ
   EFJ.State = EFJ.State or { applications = {} }
   EquiFastJoinDB = EquiFastJoinDB or nil
   ```

2. Configuration defaults (lines 11-30):
   ```lua
   local DEFAULTS = {
     debug = false,
     lastDismissSignature = "",
     scale = 1.0,
     ...
   }
   ```

3. Helper/utility functions (lines 32-95):
   - `CopyDefaults()` - Config merging
   - `DBG()` - Debug logging
   - Classification and activity helpers

4. Forward declarations (lines 98-102):
   ```lua
   local FindLeaderClass
   local BuildCategoryColor
   local SetMemberIconsFromLFG
   ```

5. Core processing and UI logic (lines 238+)

6. Event handling (lines 838+)

7. Slash commands (lines 982+)

**Path Aliases:**
- No aliases; WoW APIs used directly: `C_LFGList.*`, `C_SocialQueue.*`, `C_Timer.*`
- Blizzard namespace access: `RAID_CLASS_COLORS`, `CLASS_ICON_TCOORDS` (global WoW constants)

## Error Handling

**Patterns:**

**Protected calls with fallback:**
```lua
local ok, err = pcall(function()
  C_LFGList.ApplyToGroup(id, "", tank, healer, dps)
end)
if not ok and UIErrorsFrame and err then
  UIErrorsFrame:AddMessage("EFJ: Bewerbung fehlgeschlagen", 1, 0.2, 0.2)
  DBG("ApplyToGroup error:", err)
  return false
end
```
(lines 173-180)

**Combat lockdown guards:**
```lua
if InCombatLockdown and InCombatLockdown() then
  if UIErrorsFrame then UIErrorsFrame:AddMessage("EFJ: Beitritt im Kampf gesperrt", 1, 0.2, 0.2) end
  return "combat"
end
```
(lines 142-145)

**Nil checks before operations:**
```lua
if not res then return "OTHER" end
if not (activityID) and type(res.activityIDs) == "table" and #res.activityIDs > 0 then
  activityID = res.activityIDs[1]
end
```
(lines 78, 67-69)

**Type assertions with fallback:**
```lua
local list = (type(list)=="table") and list or {}
if type(n2)=="string" and n2 or (type(n2)=="table" and n2[1]) or "-"
```
(lines 726, 779)

**UI Error Frame usage:**
- User-facing errors displayed via `UIErrorsFrame:AddMessage()` with red color (1, 0.2, 0.2)
- Debug output via `DBG()` only if `EquiFastJoinDB.debug` is enabled

## Logging

**Framework:** Console/print-based

**Pattern:**
```lua
local function DBG(...)
  if EquiFastJoinDB and EquiFastJoinDB.debug then
    print("|cff33ff99[EFJ]|r", ...)
  end
end
```
(lines 43-47)

**When to Log:**
- Debug logs only when `EquiFastJoinDB.debug` is true (opt-in via `/efj debug on`)
- API calls logged: `DBG("ApplyToGroup", id, "roles:", ...)` (line 172)
- Event processing: `DBG("Process", origin or "update", "#ids:", #ids)` (line 809)
- Addon initialization: `DBG("Addon geladen. Initialisiere Aktualisierung.")` (line 942)

## Comments

**When to Comment:**
- Functional separators using comment blocks: `-- Helpers`, `-- LFG helpers`, `-- UI`, `-- Core processing`, `-- Events` (throughout file)
- Forward declarations documented: `-- Forward declare helpers used across sections` (line 97)
- Complex logic documented: `-- Recalculate a row's height based on its text content to avoid overlaps` (line 278)
- Intent clarification: `-- Prefer Blizzard's application dialog on user click (safe, out of combat)` (line 146)
- WoW API specifics: Comments explain category IDs and difficulty codes (lines 87-93)

**JSDoc/TSDoc:**
- Not applicable (Lua without type system; no JSDoc/TSDoc convention)
- Inline comments used for explanation instead

## Function Design

**Size:** 
- Range: 10-100 lines per function
- Larger functions: `EFJ.UI:Create()` (55 lines, lines 335-389) - Complex UI setup
- Medium functions: `ProcessResultsAndMaybeShow()` (32 lines, lines 804-835) - Event processing
- Small functions: `ClassifyResult()` (18 lines, lines 76-94) - Classification logic

**Parameters:**
- Most functions take 1-3 parameters
- Row update functions follow pattern: `function(row, id)` (UpdateJoinButton, MarkAppliedByID)
- Table arguments used for result data: `GetActivityInfoForRes(res)` where `res` is table from WoW API
- No variadic arguments except for `DBG(...)`

**Return Values:**
- Status string returns: `TryJoin()` returns `"dialog"`, `"applied"`, `"error"`, `"combat"` (line 140-184)
- Nil for missing data: `GetFreshResultInfo()` returns `nil` if not found (line 134)
- Tables for collections: `GatherResults()` returns list or empty table (lines 724-727)
- Boolean for queries: `HasQuickJoinSuggestions()` returns true/false (lines 729-733)
- Classification functions return string constants (lines 76, 735)

## Module Design

**Exports:**
- Addon reference: `_G.EquiFastJoin = EFJ` (line 7) - Makes addon globally accessible
- Module structure: `EFJ.UI` for UI operations, `EFJ.Options` for options panel, `EFJ.State` for state management
- Methods attached to tables: `function EFJ.UI:Create()`, `function EFJ.UI:SetRows()` (colon syntax for self-parameter)

**Barrel Files:**
- Single file approach: `EquiFastJoin.lua` is monolithic entry point
- No modular file splitting currently
- TOC manifest loads only this single file (line 12 of EquiFastJoin.toc)

**Table Patterns:**
- Module tables for namespacing: `EFJ.UI = { rows = {}, visibleIDs = {}, mode = "lfg" }` (line 239)
- Defaults table for config: `DEFAULTS = { debug = false, ... }` (lines 11-30)
- State table for runtime: `EFJ.State = { applications = {} }` (line 8)
- Method table usage: Functions attached as methods for object-oriented style

## German Localization

**Approach:**
- German strings hardcoded in Lua (game in German language)
- UI text: `"Beitreten"` (Join), `"Abmelden"` (Leave), `"Eingeladen"` (Invited)
- Error messages in German: `"EFJ: Beitritt im Kampf gesperrt"` (Join blocked in combat)
- Debug strings in German: `"Addon geladen. Initialisiere Aktualisierung."` (Addon loaded. Initializing refresh.)
- TOC file includes German localization: `## Title-deDE: EquiFastJoin`, `## Notes-deDE:` (lines 3, 5 of EquiFastJoin.toc)

---

*Convention analysis: 2026-04-14*
