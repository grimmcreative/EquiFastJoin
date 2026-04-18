# Phase 4: Modularization - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

The monolithic EquiFastJoin.lua is replaced by separate focused files loaded in correct dependency order via the TOC. After this phase, EquiFastJoin.lua no longer exists and all code lives in module files sharing state via the addon namespace.

</domain>

<decisions>
## Implementation Decisions

### Module Structure
- 7 files: Locales.lua, Core.lua, Data.lua, Logic.lua, UI.lua, Events.lua, SlashCommands.lua
- Each file uses `local _, EFJ = ...` for shared state (standard WoW addon namespace pattern)
- No `_G.EquiFastJoin` pollution — remove the global reference entirely
- L-table goes into Locales.lua (loaded first)

### TOC Load Order
- Locales.lua → Core.lua → Data.lua → Logic.lua → UI.lua → Events.lua → SlashCommands.lua
- Dependency chain: each file can reference anything from files loaded before it

### File Deletion
- EquiFastJoin.lua is deleted after all code is extracted into modules
- This is required by ROADMAP Success Criteria: "EquiFastJoin.lua no longer exists"

### Media Files
- Existing TGA files stay in their current location (no Media/ subfolder)

### Claude's Discretion
- Exact code boundaries between modules (which functions go where)
- Whether to create helper sub-tables on EFJ namespace (e.g., EFJ.Data, EFJ.Logic)

</decisions>

<code_context>
## Existing Code Insights

### Current Structure (EquiFastJoin.lua)
- Lines 1-11: Header, version, addon name
- Lines 12-68: L-table (Locales) — → Locales.lua
- Lines 69-75: DEFAULTS, state init — → Core.lua
- Lines 76-155: Helper functions, API wrappers — → Data.lua
- Lines 156-240: Classification, filtering logic — → Logic.lua
- Lines 241-750: UI frame creation, row rendering — → UI.lua
- Lines 751-850: Event handlers, processing — → Events.lua
- Lines 851-1080: Options panel, slash commands — → SlashCommands.lua (+ options in UI.lua or separate)

### State Tables Used Across Sections
- `EFJ` — main addon table
- `EFJ.UI` — UI state (rows, visibleIDs, mode)
- `EFJ.State` — runtime state (applications)
- `EFJ.Options` — options panel
- `EquiFastJoinDB` — SavedVariables (global, managed by WoW)

### Forward Declarations (line 98-102)
- `local FindLeaderClass`, `local BuildCategoryColor`, `local SetMemberIconsFromLFG`
- These need to be resolved into proper module placement

</code_context>

<specifics>
## Specific Ideas

- Use the existing section comment markers (-- Helpers, -- LFG helpers, -- UI, -- Core processing, -- Events) as natural split boundaries
- DEFAULTS table and CopyDefaults go into Core.lua
- Options panel creation can stay in a separate section of UI.lua or be split to its own file

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
