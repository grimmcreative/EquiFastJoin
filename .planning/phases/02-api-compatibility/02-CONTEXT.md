# Phase 2: API Compatibility - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

All core addon features (LFG listing, join button, options panel) work correctly on Midnight with no blocked actions or missing UI elements. This phase fixes 5 broken or deprecated APIs: activityID consolidation, InterfaceOptions removal, OptionsSliderTemplate replacement, generalPlaystyle classification, and Secret Values taint hardening.

</domain>

<decisions>
## Implementation Decisions

### activityID Migration (COMP-03)
- Remove the `activityID` primary code path entirely — `activityIDs[1]` is the only live path on Midnight
- Consolidate all 3 locations (lines 66-68, 106-108, 687) into a single unified helper function
- Return `nil` for empty `activityIDs` (consistent with existing fallback behavior)

### Options Panel & Slider (COMP-04, COMP-05)
- Remove legacy `InterfaceOptions_AddCategory` fallback — Midnight only uses `Settings.RegisterCanvasLayoutCategory`
- Check if `OptionsSliderTemplate` still exists on Midnight; if removed, build a manual Slider with base `Slider` frame and own textures
- Keep scale slider range at 0.75-1.50 (proven values)

### Content Classification (COMP-06)
- Integrate `generalPlaystyle` as a fallback AFTER `categoryID` check in `ClassifyResult()` — used for new Midnight content types that don't map to existing categoryIDs
- Defensive mapping only: map known `generalPlaystyle` values, unknown values → "OTHER"

### Taint Hardening (COMP-07)
- Defensive strategy: wrap all `C_LFGList.ApplyToGroup` and dialog calls in `pcall`, catch taint errors, show user message
- No additional instance-check — keep current behavior (combat-check blocks, outside combat join is allowed)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GetActivityInfoForRes(res)` at line 63 — existing helper that resolves activityID, needs consolidation
- `ClassifyResult(res)` at line 76 — existing classifier, needs generalPlaystyle addition
- `TryJoin(id)` at line 140 — existing join function with combat check, needs taint hardening
- `OpenApplyDialog()` at line 147 — already uses pcall pattern (Phase 1 updated)
- `EFJ.Options:Create()` at line 853 — options panel with slider and checkboxes

### Established Patterns
- `pcall()` wrapping for all WoW API calls (existing pattern throughout codebase)
- Nil-guard fallback: `(C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn` (established in Phase 1)
- Category mapping via if-chain in ClassifyResult (lines 87-92)
- Settings API registration with fallback (lines 933-937)

### Integration Points
- `GetActivityInfoForRes()` called from ClassifyResult, BuildActivityText, and inline at line 687
- Options panel registered via Settings API at lines 933-937
- `C_LFGList.ApplyToGroup` called at line 173 inside TryJoin
- Direct `res.activityID` access at line 687 bypasses the helper

</code_context>

<specifics>
## Specific Ideas

- STATE.md notes COMP-06 and COMP-07 require live Midnight client verification (MEDIUM confidence)
- COMP-05 OptionsSliderTemplate removal is MEDIUM confidence — verify on live client before replacing
- Phase 1 established the nil-guard pattern for deprecated globals — reuse this pattern where applicable

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
