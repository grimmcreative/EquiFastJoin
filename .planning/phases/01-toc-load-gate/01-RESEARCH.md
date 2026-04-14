# Phase 1: TOC & Load Gate - Research

**Researched:** 2026-04-14
**Domain:** WoW Addon Metadata (TOC) and Lua API compatibility
**Confidence:** HIGH

## Summary

Phase 1 consists of two surgical edits: updating `## Interface:` in `EquiFastJoin.toc` to match the current live client version, and replacing the deprecated global `LoadAddOn()` calls in `EquiFastJoin.lua` with the current `C_AddOns.LoadAddOn()` API while preserving a fallback for safety.

The `LoadAddOn` global was deprecated in patch 10.2.0 and the wiki explicitly lists its replacement as `C_AddOns.LoadAddOn`. On WoW Midnight (12.x), calling the removed global would produce a Lua error ("attempt to call a nil value"), which would break the join flow. Using `C_AddOns.LoadAddOn()` is the correct fix; the backwards-compatible fallback pattern `(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn)` handles the case where an older client might still load the addon.

The target Interface version is **120005**, corresponding to patch 12.0.5 ("Lingering Shadows"), which releases April 21, 2026. The CONTEXT.md specifies this value and it follows the standard WoW encoding: `major * 10000 + minor * 100 + patch` → `12 * 10000 + 0 * 100 + 5 = 120005`. Using 120005 ensures the addon will not appear as "outdated" in the addon list once patch 12.0.5 goes live.

**Primary recommendation:** Two file edits — one TOC field update, one two-line Lua replacement — both already localized in CONTEXT.md. No new dependencies, no structural changes.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — pure infrastructure phase.

### Claude's Discretion
All implementation choices are at Claude's discretion. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None for this phase.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-01 | TOC Interface-Version auf 120005 updaten | Interface version encoding confirmed; 120005 = patch 12.0.5; field location confirmed at TOC line 1 |
| COMP-02 | `LoadAddOn()` durch `C_AddOns.LoadAddOn()` ersetzen mit Backwards-Fallback | `LoadAddOn` deprecated since 10.2.0, nil on 11.0+ without fallback CVar; `C_AddOns.LoadAddOn` available since 10.2.0; backwards-compat pattern documented below |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| TOC Interface version declaration | Addon Metadata (TOC) | — | The TOC is Blizzard's loader manifest; the Interface field is read by the WoW client before any Lua runs |
| LoadOnDemand addon loading | API Layer (Lua) | — | `LoadAddOn`/`C_AddOns.LoadAddOn` is a Blizzard API call; belongs in the API helper section of the single-file architecture (lines 49-237) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `C_AddOns.LoadAddOn` | WoW 10.2.0+ (available on 12.x) | Load a LoadOnDemand addon at runtime | Official replacement for deprecated global `LoadAddOn`; part of the `C_AddOns` namespace introduced to namespace all addon-management globals |

No additional libraries required. Phase is pure metadata + one API call replacement.

**No installation step needed** — `C_AddOns` is part of the Blizzard embedded Lua environment.

**Version verification:** `C_AddOns.LoadAddOn` confirmed available since patch 10.2.0. Current live Midnight version is 12.0.x (>10.2.0). [VERIFIED: warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn]

## Architecture Patterns

### System Architecture Diagram

```
Character Login
      |
      v
WoW Client reads TOC
      |
      +-- Interface: 120005 matches client build? --> YES --> Addon listed as enabled
      |                                           --> NO  --> Addon grayed out as "outdated"
      |
      v
Lua VM loads EquiFastJoin.lua
      |
      v
TryJoin() invoked on button click
      |
      v
OpenApplyDialog() checks for LFGListApplicationDialog
      |
      +-- dialog present? --> YES --> show dialog, done
      |
      +-- NO --> pcall(C_AddOns.LoadAddOn, "Blizzard_LFGList")
                      |
                      +--> fallback to C_AddOns.LoadAddOn(Blizzard_LookingForGroupUI)
                      |
                      v
               Re-check LFGListApplicationDialog_Show
                      |
                      +--> found --> show dialog
                      +--> not found --> fall through to direct C_LFGList.ApplyToGroup
```

### Recommended Project Structure

No structural changes in this phase. Existing single-file layout is preserved:

```
EquiFastJoin/
├── EquiFastJoin.toc      # EDIT: line 1, Interface: 110200 -> 120005
├── EquiFastJoin.lua      # EDIT: lines 149-150, LoadAddOn -> C_AddOns.LoadAddOn
└── Media/                # unchanged
```

### Pattern 1: TOC Interface Version Update

**What:** Single field replacement in the TOC manifest file.
**When to use:** After any WoW patch that increments the client build version.

```
## Interface: 120005
```

The encoding formula: `major * 10000 + minor * 100 + patch`. Patch 12.0.5 = 120005.

[VERIFIED: warcraft.wiki.gg/wiki/TOC_format — "If the game version is 10.2.7, the interface version is 100207"]

**Note on future-proofing:** The TOC format also supports comma-delimited interface versions (e.g., `## Interface: 120001, 120005`) for addons that need to signal compatibility with multiple patch levels. For this phase, a single value matching the current live patch is sufficient.

[CITED: us.forums.blizzard.com/en/wow/t/the-client-now-supports-comma-delimited-interface-versions/1896097]

### Pattern 2: C_AddOns.LoadAddOn Backwards-Compatible Replacement

**What:** Replace deprecated global `LoadAddOn` with `C_AddOns.LoadAddOn`, keeping a nil-safe fallback for theoretical older clients.
**When to use:** Any place in the addon that calls `LoadAddOn()`.

Current code (lines 149-150):
```lua
pcall(LoadAddOn, "Blizzard_LFGList")
pcall(LoadAddOn, "Blizzard_LookingForGroupUI")
```

Replacement pattern:
```lua
local _LoadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
pcall(_LoadAddOn, "Blizzard_LFGList")
pcall(_LoadAddOn, "Blizzard_LookingForGroupUI")
```

Alternatively, inline without a local (matching the existing pcall pattern more closely):
```lua
pcall(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn, "Blizzard_LFGList")
pcall(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn, "Blizzard_LookingForGroupUI")
```

Both forms are correct. The local variable form is cleaner and consistent with WoW addon community practice. The `pcall` wrapper is already present — the only change is the function reference.

[CITED: warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn — signature: `loaded, value = C_AddOns.LoadAddOn(name)`]
[CITED: warcraft.wiki.gg/wiki/API_LoadAddOn — "deprecated in patch 10.2.0 and will be removed in patch 11.0.2"]

**Fallback necessity assessment:** On WoW Midnight 12.x, `LoadAddOn` is nil (removed). The `or LoadAddOn` tail of the fallback will never execute on 12.x — it exists only for theoretical backwards compatibility if someone runs the addon on an older retail client (11.x). Since CLAUDE.md states "Must work with WoW Midnight (12.x) live servers" as the primary target, the fallback is a safety belt, not a required feature. Either approach (with or without fallback) satisfies COMP-02; including the fallback costs nothing and is the community-standard pattern.

[ASSUMED] Whether `LoadAddOn` is truly nil on WoW 12.x or still present via `loadDeprecationFallbacks` CVar (which defaults to 1). Regardless, `C_AddOns.LoadAddOn` is the correct current API and should be preferred.

### Anti-Patterns to Avoid

- **Removing pcall without replacement:** The existing `pcall` wrapping around `LoadAddOn` is correct defensive coding. Do not unwrap it. `C_AddOns.LoadAddOn` can return failure silently; pcall guards against unexpected API errors.
- **Setting Interface version higher than current live patch:** If set to 120005 before 12.0.5 releases (April 21, 2026), WoW may show the addon as "incompatible" on clients still running 120001. Set to the highest version you need to support. If targeting both 12.0.1 and 12.0.5, use comma-delimited: `## Interface: 120001, 120005`. [ASSUMED] Exact WoW behavior when TOC version exceeds client build — may warn or silently accept. Conservative approach: match the current live build.
- **Using `IsAddOnLoaded` global:** This was also deprecated in 11.0.2 and replaced with `C_AddOns.IsAddOnLoaded`. Phase 1 does not touch this call, but Phase 2/5 should be aware. Not in scope here.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Load-on-demand addon loading | Custom file loading, `require()`, `dofile()` | `C_AddOns.LoadAddOn` | WoW Lua sandbox forbids `require`/`dofile`; `C_AddOns.LoadAddOn` is the only valid mechanism for loading demand-loaded Blizzard addons |
| Interface version detection at runtime | `/dump select(4, GetBuildInfo())` parsing | Static TOC field | The TOC is read by the loader before any Lua runs; runtime version checks are for conditional code paths, not for registering addon compatibility |

**Key insight:** In the WoW Lua sandbox, there is no package system and no file I/O. `C_AddOns.LoadAddOn` is the only way to programmatically load a LoadOnDemand Blizzard addon (like `Blizzard_LFGList`).

## Runtime State Inventory

Not applicable — this is a greenfield edit phase, not a rename/migration phase. No stored data, live service config, or OS-registered state is affected by changing the TOC version number or the `LoadAddOn` call.

## Common Pitfalls

### Pitfall 1: TOC Version Too High for Current Live Client

**What goes wrong:** If the TOC specifies `120005` but the player's client is still on `120001` (before April 21, 2026 when 12.0.5 releases), WoW may flag the addon as incompatible.
**Why it happens:** WoW compares the TOC interface number against the client build; if TOC > client, behavior is version-dependent.
**How to avoid:** If releasing before April 21, 2026, use `## Interface: 120001` or comma-delimited `120001, 120005`. After April 21, 2026, `120005` alone is correct.
**Warning signs:** Addon appears grayed out or shows "out of date" in addon list on older client.

### Pitfall 2: Calling LoadAddOn Outside pcall

**What goes wrong:** If `LoadAddOn` is nil (removed on 12.x without fallback CVar active), a bare `LoadAddOn(...)` call crashes the addon with "attempt to call a nil value".
**Why it happens:** The global was removed; the fallback CVar (`loadDeprecationFallbacks`) may not always be set to 1 in all environments.
**How to avoid:** Always use `pcall` or the nil-guard pattern `(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn)`. The existing code already uses `pcall` — just change the function reference.
**Warning signs:** Lua error in chat on first join attempt: `[string "EquiFastJoin.lua"]:149: attempt to call a nil value`.

### Pitfall 3: Forgetting the Version Comment in Line 2

**What goes wrong:** The comment at line 2 of `EquiFastJoin.lua` reads `-- EquiFastJoin - Retail 11.2.0`. After this phase, this becomes stale documentation.
**Why it happens:** Comment drift — code change without updating the associated comment.
**How to avoid:** Update the comment to reflect `Retail 12.0.x` (Midnight) when updating the Interface version.
**Warning signs:** Confusion during code review about which WoW version the addon targets.

### Pitfall 4: C_AddOns Availability Assumption

**What goes wrong:** `C_AddOns` is a namespace table; if called on a client where it doesn't exist (pre-10.2.0), `C_AddOns.LoadAddOn` raises an indexing error.
**Why it happens:** Nil table indexing in Lua raises an error, not silently returns nil.
**How to avoid:** Always guard with `(C_AddOns and C_AddOns.LoadAddOn)` before calling. On any WoW 12.x client, `C_AddOns` is guaranteed present, but the guard costs nothing.
**Warning signs:** Lua error: "attempt to index global 'C_AddOns' (a nil value)" — only on very old WoW builds, not a real risk on 12.x.

## Code Examples

### COMP-01: TOC Interface Field Update

File: `EquiFastJoin.toc`, line 1

Before:
```
## Interface: 110200
```

After:
```
## Interface: 120005
```

[VERIFIED: TOC format confirmed at warcraft.wiki.gg/wiki/TOC_format]
[VERIFIED: 12.0.5 = 120005 follows the standard encoding: patch 12.0.5 → 12*10000 + 0*100 + 5 = 120005]

### COMP-02: LoadAddOn Replacement

File: `EquiFastJoin.lua`, lines 149-150

Before:
```lua
pcall(LoadAddOn, "Blizzard_LFGList")
pcall(LoadAddOn, "Blizzard_LookingForGroupUI")
```

After (with backwards-compatible nil-guard):
```lua
local _LoadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
pcall(_LoadAddOn, "Blizzard_LFGList")
pcall(_LoadAddOn, "Blizzard_LookingForGroupUI")
```

The local `_LoadAddOn` should be declared inside the `OpenApplyDialog` closure where the calls live, keeping scope minimal and consistent with the existing architecture's approach to forward declarations and local scoping.

[CITED: warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn]
[CITED: warcraft.wiki.gg/wiki/API_LoadAddOn — deprecation timeline]

### COMP-01 bonus: Version string comment update

File: `EquiFastJoin.lua`, line 2

Before:
```lua
-- EquiFastJoin - Retail 11.2.0
```

After:
```lua
-- EquiFastJoin - Retail 12.0.5 (Midnight)
```

This is a documentation-only change. Not required by COMP-01 but strongly recommended for maintainability.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `LoadAddOn("name")` global | `C_AddOns.LoadAddOn("name")` | Deprecated 10.2.0, targeted removal 11.0.2+ | Global may be nil on 12.x without CVar fallback |
| `## Interface: 110200` | `## Interface: 120005` | WoW Midnight launch (12.0.0, Feb 2026) + 12.0.5 (Apr 21, 2026) | Addon shows as incompatible if TOC version is below client version |
| Monolithic InterfaceOptions API | Settings API (Phase 2 concern) | 10.x | Out of scope for Phase 1 |

**Deprecated/outdated (Phase 1 scope only):**
- `LoadAddOn` global: Deprecated 10.2.0, expected nil on 12.x. Replace with `C_AddOns.LoadAddOn`.
- `## Interface: 110200`: Retail 11.2.0. Replaced by `120005` (12.0.5).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `LoadAddOn` global is nil on WoW 12.x (even with `loadDeprecationFallbacks` CVar) | Common Pitfalls #2 | If still present, current code works without change; but migration is still correct practice |
| A2 | Setting TOC Interface to 120005 before April 21, 2026 may flag addon as incompatible on 120001 clients | Common Pitfalls #1 | If WoW silently accepts TOC > client version, timing doesn't matter |
| A3 | The `OpenApplyDialog` local function closure (lines 147-157) is the correct scope for `_LoadAddOn` local | Code Examples | If scope is wrong, Lua upvalue might not resolve; but local in closure is always correct |

## Open Questions

1. **Exact interface version to ship with before April 21**
   - What we know: 12.0.5 releases April 21, 2026; current live is 12.0.1 (120001); CONTEXT.md specifies 120005
   - What's unclear: Whether to ship 120001 now and 120005 post-release, or ship 120005 immediately
   - Recommendation: Ship 120005 immediately. The planner should note this in the plan; it's safe if the player has already updated to 12.0.5 beta or if WoW silently accepts forward-versioned TOC. If strict, use `## Interface: 120001, 120005` comma syntax.

2. **Whether `Blizzard_LookingForGroupUI` still exists on Midnight**
   - What we know: `Blizzard_LFGList` is still referenced; `Blizzard_LookingForGroupUI` was an older fallback
   - What's unclear: Whether the second `LoadAddOn` call even loads a valid module on 12.x
   - Recommendation: Keep both calls as-is (pcall means failure is silent); investigation of which UI modules changed is Phase 2 scope (COMP-03, COMP-05).

## Environment Availability

Step 2.6 SKIPPED — Phase 1 is code/config file edits only. No external tools, runtimes, databases, or CLI utilities are required beyond a text editor and git. The WoW client is required for live verification but not for making the edits.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (WoW Lua addons have no automated unit test runner in-game) |
| Config file | none |
| Quick run command | Manual: load addon in WoW client, check addon list, attempt `/efj show` |
| Full suite command | Manual: login to character, verify no Lua errors, test join button |

**Note:** WoW addon testing is inherently manual. There is no automated Lua test runner for retail WoW addons that runs outside the game client. The nyquist_validation setting is enabled in config.json but the WoW addon ecosystem has no equivalent to jest or pytest. Validation is via in-game observation.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-01 | Addon appears enabled (not grayed out) in WoW addon list | manual-smoke | None — requires live WoW client | N/A |
| COMP-02 | No Lua error when join button triggers LoadAddOn | manual-smoke | None — requires live WoW client | N/A |

**Manual-only justification:** WoW addons execute inside the game's embedded Lua VM. There is no offline test harness that can run WoW addon Lua. Both requirements can only be verified by loading the addon in the WoW client and observing behavior. [ASSUMED] No offline WoW addon Lua test runner exists for retail WoW — if one has emerged in the community (e.g., `wow-mock`), the planner may investigate, but it is not standard practice.

### Sampling Rate

- **Per task commit:** Static code review only (grep for `LoadAddOn` to confirm replacement)
- **Per wave merge:** Live WoW client smoke test
- **Phase gate:** Both COMP-01 and COMP-02 verified in live client before `/gsd-verify-work`

### Wave 0 Gaps

None — existing "test infrastructure" is manual-only by nature of the platform. No test files to create.

## Security Domain

No security surface changes in this phase. COMP-01 (TOC version) and COMP-02 (LoadAddOn replacement) are purely compatibility fixes with no authentication, session, access control, input, or cryptography implications.

ASVS categories are not applicable to a TOC version field update or a `pcall` function reference swap.

## Sources

### Primary (HIGH confidence)
- [warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn](https://warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn) — function signature, availability since 10.2.0
- [warcraft.wiki.gg/wiki/API_LoadAddOn](https://warcraft.wiki.gg/wiki/API_LoadAddOn) — deprecation in 10.2.0, targeted removal in 11.0.2
- [warcraft.wiki.gg/wiki/TOC_format](https://warcraft.wiki.gg/wiki/TOC_format) — Interface version encoding rules, comma-delimited syntax
- [warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes](https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes) — TOC 120001 confirmed for 12.0.1

### Secondary (MEDIUM confidence)
- [wowhead.com — Midnight Patch 12.0.5 releases April 21st](https://www.wowhead.com/news/midnight-patch-12-0-5-releases-april-21st-381173) — confirms 12.0.5 release date
- [warcraft.wiki.gg/wiki/Patch_11.0.2/API_changes](https://warcraft.wiki.gg/wiki/Patch_11.0.2/API_changes) — LoadAddOn → C_AddOns.LoadAddOn migration documented
- [us.forums.blizzard.com — comma-delimited Interface versions](https://us.forums.blizzard.com/en/wow/t/the-client-now-supports-comma-delimited-interface-versions/1896097) — multiple interface version support in TOC

### Tertiary (LOW confidence)
- Search result assertion that `loadDeprecationFallbacks` CVar defaults to 1 (not verified against official docs) — flagged as ASSUMED in Assumptions Log

## Metadata

**Confidence breakdown:**
- COMP-01 (TOC version): HIGH — format verified, 12.0.5 = 120005 encoding confirmed
- COMP-02 (LoadAddOn migration): HIGH — deprecation and replacement API both verified against official wiki
- Backwards-compat fallback pattern: HIGH — standard community pattern, consistent with existing pcall usage in codebase
- 12.0.5 release timing risk: MEDIUM — release date sourced from Wowhead/Blizzard news, not from client build

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (stable API; TOC version only changes with new patches)
