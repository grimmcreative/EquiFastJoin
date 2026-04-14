# Phase 1: TOC & Load Gate - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Mode:** Infrastructure phase — grey area discussion skipped

<domain>
## Phase Boundary

The addon loads without errors on WoW Midnight (12.x). This phase updates the Interface version in the TOC file and fixes the load-blocking `LoadAddOn()` API call with a backwards-compatible `C_AddOns.LoadAddOn()` replacement.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `EquiFastJoin.toc` line 1: `## Interface: 110200` — needs update to 120005
- `EquiFastJoin.lua` line 149-150: `pcall(LoadAddOn, "Blizzard_LFGList")` and `pcall(LoadAddOn, "Blizzard_LookingForGroupUI")` — needs `C_AddOns.LoadAddOn()` with fallback

### Established Patterns
- `pcall()` wrapping for API calls (existing pattern in codebase)
- Single-file architecture: all code in `EquiFastJoin.lua`

### Integration Points
- TOC file controls addon loading and Interface version check
- `LoadAddOn()` calls are in the join flow (line 149-150)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Requirements COMP-01 (TOC version) and COMP-02 (LoadAddOn migration) are well-defined.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
