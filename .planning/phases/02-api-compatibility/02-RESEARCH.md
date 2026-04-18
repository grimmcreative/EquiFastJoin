# Phase 2: API Compatibility - Research

**Researched:** 2026-04-18
**Domain:** WoW Midnight (12.x) Lua addon API changes — LFG list, options UI, taint system
**Confidence:** MEDIUM (core API facts HIGH; OptionsSliderTemplate status and Secret Values in-instance behavior LOW without live client confirmation)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **activityID Migration (COMP-03):** Remove the `activityID` primary code path entirely — `activityIDs[1]` is the only live path on Midnight. Consolidate all 3 locations (lines 66-68, 106-108, 687) into a single unified helper function. Return `nil` for empty `activityIDs`.
- **Options Panel & Slider (COMP-04, COMP-05):** Remove legacy `InterfaceOptions_AddCategory` fallback — Midnight only uses `Settings.RegisterCanvasLayoutCategory`. Check if `OptionsSliderTemplate` still exists on Midnight; if removed, build a manual Slider with base `Slider` frame and own textures. Keep scale slider range at 0.75-1.50.
- **Content Classification (COMP-06):** Integrate `generalPlaystyle` as a fallback AFTER `categoryID` check in `ClassifyResult()`. Defensive mapping only — unknown values map to "OTHER".
- **Taint Hardening (COMP-07):** Wrap all `C_LFGList.ApplyToGroup` and dialog calls in `pcall`, catch taint errors, show user message. No additional instance-check — keep current behavior (combat-check blocks; outside combat join is allowed).

### Claude's Discretion
None noted — all implementation areas are locked.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-03 | `activityID` → `activityIDs` Codepfad konsolidieren (toter Primary-Branch entfernen) | `activityID` field removed in patch 11.0.7; `activityIDs` (table) is now the only live field. Three code locations confirmed: lines 64-74, 104-128, 687. |
| COMP-04 | Legacy `InterfaceOptions_AddCategory` Fallback entfernen | `InterfaceOptions_AddCategory` was deprecated in Dragonflight (10.0) and is nil on Midnight. `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` is the current API. Code already has the correct primary branch at line 933-935; only the dead `elseif` at 936-938 needs removal. |
| COMP-05 | `OptionsSliderTemplate` durch Midnight-kompatibles Template ersetzen | `OptionsSliderTemplate` status on Midnight 12.0 is LOW confidence (was confirmed removed in Classic Era 1.15.4; present in Retail 11.0.2). Safe fallback: nil-guard the template reference; if nil, use `UISliderTemplateWithLabels` or manual base `Slider` frame. |
| COMP-06 | `generalPlaystyle` Feld für neue Content-Typen in `ClassifyResult()` nutzen | `generalPlaystyle` field confirmed added in patch 12.0.0 to `C_LFGList.GetSearchResultInfo`. Enum values 0-4 (None, Learning, FunRelaxed, FunSerious, Expert) do NOT map to existing content categories (Dungeon/Raid/etc.); the field describes play intent, not content type. Correct use: pass-through only — do not try to classify by generalPlaystyle alone. See Architecture section. |
| COMP-07 | Secret Values Taint-Hardening für In-Instance-Nutzung | `C_LFGList.ApplyToGroup` is hardware-event protected since patch 7.2.0. On Midnight 12.0, `GetSearchResultInfo` can return Secret Value fields (especially during endgame/instance content). The pcall pattern already present in `TryJoin` is the correct approach. Key risk: field access on Secret Value types causes Lua errors, not just nil returns. |
</phase_requirements>

---

## Summary

Phase 2 addresses five focused API compatibility fixes for WoW Midnight (12.x). Each fix corresponds to a known API change in the Blizzard client.

**COMP-03 (activityID):** The `activityID` singular field was removed from `LfgSearchResultData` in patch 11.0.7 (2024-12-17). The only live path is `activityIDs[1]` (a table). The current codebase has three places that still check `res.activityID` first: `GetActivityInfoForRes` (line 64), `BuildActivityText` (line 106), and an inline access at line 687 in `ToastForIDs`. All three must be consolidated into the single helper.

**COMP-04 (InterfaceOptions):** `InterfaceOptions_AddCategory` was deprecated in Dragonflight (10.0) and is nil on Midnight. The current code at line 933 already has the correct `Settings` API branch as primary; the dead `elseif InterfaceOptions_AddCategory` block at line 936 is dead code that should be removed for clarity.

**COMP-05 (OptionsSliderTemplate):** This template's status on Midnight Retail is MEDIUM/LOW confidence. It was removed in Classic Era 1.15.4 but was present in Retail 11.0.2. The correct approach is to nil-guard the template name and fall back to `UISliderTemplateWithLabels` (documented present) or a manual base `Slider` with explicitly set thumb and track textures.

**COMP-06 (generalPlaystyle):** The `generalPlaystyle` field (added 12.0.0) is `Enum.LFGEntryGeneralPlaystyle` with values 0-4. It describes how a group wants to play (learning, relaxed, competitive, etc.), NOT what content type they're doing. It should not be used as a content-type classifier. The correct integration: if `categoryID` is missing or maps to nothing, inspect `generalPlaystyle` only to prevent "Unknown Activity" display by providing a human-readable label.

**COMP-07 (Taint hardening):** `C_LFGList.ApplyToGroup` is hardware-event protected (since 7.2.0) — it works from real button clicks but fires `ADDON_ACTION_BLOCKED` if called from tainted execution paths. On Midnight, `GetSearchResultInfo` fields can be Secret Values during endgame content; reading them in boolean/arithmetic context causes Lua errors. The `pcall` around `C_LFGList.ApplyToGroup` at line 174 already exists. The hardening needed is: (1) confirm pcall catches taint errors correctly, and (2) guard field access on `res` that could contain Secret Values (particularly `autoAccept`, `isDelisted`, and any field used in comparison operators).

**Primary recommendation:** All five fixes are surgical edits within `EquiFastJoin.lua`. No new dependencies, no structural changes, no additional files. The biggest uncertainty is COMP-05 (OptionsSliderTemplate); use a nil-guard + fallback pattern rather than unconditionally removing the reference.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Activity info resolution (activityIDs) | API Layer (lines 49-237) | — | Helper wraps `C_LFGList.GetActivityInfoTable`; single point of truth for all callers |
| Content type classification | Core Processing (lines 723-835) | API Layer | `ClassifyResult` calls `GetActivityInfoForRes`; categorization logic lives in processing layer |
| Options panel registration | Settings/Options Layer (lines 853-940) | — | UI framework integration; Settings API call at addon load time |
| Slider UI element | Settings/Options Layer | — | Frame template lookup + fallback is a UI concern, owned by `EFJ.Options:Create()` |
| Join/Apply taint hardening | API Layer (TryJoin, lines 140-184) | — | All `C_LFGList.ApplyToGroup` calls route through `TryJoin`; taint guard belongs here |
| Secret Value field access | API Layer (GetFreshResultInfo, line 131) | Core Processing | `GetFreshResultInfo` is the gateway for all `res` data; Secret Value guards belong here |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `C_LFGList.GetSearchResultInfo` | WoW 12.x | Returns `LfgSearchResultData` including `activityIDs` (plural) | Only way to get LFG result data; `activityID` singular was removed in 11.0.7 |
| `C_LFGList.GetActivityInfoTable` | WoW 12.x | Resolves activity metadata (fullName, categoryID, etc.) | Standard lookup; no change in Midnight |
| `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` | WoW 10.0+ (Dragonflight+) | Register addon options panel in WoW Settings UI | Replaced `InterfaceOptions_AddCategory`; present on all Midnight clients |
| `CreateFrame("Slider", nil, parent, "UISliderTemplateWithLabels")` | WoW 12.x | Create a slider UI element | Documented as present and functional on current WoW builds; fallback for `OptionsSliderTemplate` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `issecretvalue(val)` | WoW 12.0+ | Test if a Lua value is a Secret Value before using in comparison | Use before any boolean/arithmetic operation on fields from `GetSearchResultInfo` during endgame content |
| `Enum.LFGEntryGeneralPlaystyle` | WoW 12.0+ | Enum for generalPlaystyle field values (0=None, 1=Learning, 2=FunRelaxed, 3=FunSerious, 4=Expert) | Reference only for display strings; do NOT use for content-type routing |

**No installation step needed** — all APIs are part of the Blizzard embedded Lua runtime.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `UISliderTemplateWithLabels` fallback | Manual base `Slider` + custom textures | Manual approach is more work but more portable; `UISliderTemplateWithLabels` is simpler if confirmed present |
| `pcall` around `ApplyToGroup` | SecureActionButton (XML) | SecureActionButton would be truly taint-immune but requires XML and structural change; pcall is in-scope for this phase |

---

## Architecture Patterns

### System Architecture Diagram

```
Button Click (hardware event)
        |
        v
  TryJoin(id)
        |
        +-- InCombatLockdown? --> YES --> show error, return "combat"
        |
        +-- NO
        |
        v
  OpenApplyDialog()
        |
        +-- Blizzard dialog available? --> YES --> show dialog, return "dialog"
        |
        +-- NO --> pcall(LoadAddOn) --> retry dialog
        |
        +-- still NO
        |
        v
  doApply()
        |
        pcall(C_LFGList.ApplyToGroup)  <-- COMP-07: pcall already present; verify catches taint errors
        |
        +-- ok=true  --> return "applied"
        +-- ok=false --> show UIErrorsFrame error, return "error"

---

  GetFreshResultInfo(id)
        |
        v
  C_LFGList.GetSearchResultInfo(id)
        |
        +-- nil or isDelisted? --> return nil
        |
        +-- Secret Value fields? --> guard with issecretvalue() before comparison  <-- COMP-07
        |
        v
  info.activityText = BuildActivityText(info)
        |
        v
  return info

---

  GetActivityInfoForRes(res)          <-- COMP-03: consolidate to this single helper
        |
        +-- res.activityIDs[1] exists? --> activityID = activityIDs[1]
        +-- empty/missing?             --> return nil
        |
        v
  C_LFGList.GetActivityInfoTable(activityID)
        |
        v
  return activityInfo (or nil)

---

  ClassifyResult(res)                 <-- COMP-06: add generalPlaystyle fallback
        |
        v
  GetActivityInfoForRes(res) --> act
        |
        +-- isMPlus check       --> "MPLUS"
        +-- act.categoryID == 2 --> "RAID"
        +-- act.categoryID == 1 --> "DUNGEON"
        +-- act.categoryID == 3/4 -> "PVP"
        +-- act.categoryID == 6 --> "CUSTOM"
        +-- res.generalPlaystyle  --> "OTHER" (with label hint)  [NEW fallback]
        +-- fallthrough         --> "OTHER"
```

### Recommended Project Structure

No structural changes. All edits within `EquiFastJoin.lua`:

```
EquiFastJoin/
├── EquiFastJoin.toc         # unchanged this phase
├── EquiFastJoin.lua         # 5 targeted edits:
│   ├── lines 64-74          # COMP-03: GetActivityInfoForRes — remove activityID branch
│   ├── lines 104-128        # COMP-03: BuildActivityText — remove activityID branch
│   ├── line 687             # COMP-03: ToastForIDs inline — route through helper
│   ├── lines 76-94          # COMP-06: ClassifyResult — add generalPlaystyle fallback
│   ├── lines 140-184        # COMP-07: TryJoin/doApply — verify/harden pcall
│   ├── lines 888-909        # COMP-05: AddSlider — nil-guard OptionsSliderTemplate
│   └── lines 932-938        # COMP-04: options registration — remove InterfaceOptions fallback
└── Media/                   # unchanged
```

### Pattern 1: activityID Consolidation (COMP-03)

**What:** Remove dead `res.activityID` primary branch; use only `activityIDs[1]`.
**When to use:** Any code accessing activity data from an `LfgSearchResultData` result.

Current (duplicated in 3 places):
```lua
local activityID = res.activityID
if (not activityID) and type(res.activityIDs) == "table" and #res.activityIDs > 0 then
  activityID = res.activityIDs[1]
end
```

After consolidation — `GetActivityInfoForRes` becomes the single path:
```lua
local function GetActivityInfoForRes(res)
  if not res then return nil end
  if type(res.activityIDs) == "table" and #res.activityIDs > 0 then
    return C_LFGList.GetActivityInfoTable(res.activityIDs[1])
  end
  return nil
end
```

Line 687 (ToastForIDs) currently does inline `res.activityID and C_LFGList.GetActivityInfoTable(res.activityID)` — replace with `GetActivityInfoForRes(res)`.

[VERIFIED: warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo — "Patch 11.0.7 (2024-12-17): Changed activityID field to activityIDs"]

### Pattern 2: InterfaceOptions Fallback Removal (COMP-04)

**What:** Remove dead `elseif InterfaceOptions_AddCategory` branch.
**When to use:** Options panel registration code.

Current (lines 932-938):
```lua
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, "EquiFastJoin")
  Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
end
```

After:
```lua
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, "EquiFastJoin")
  Settings.RegisterAddOnCategory(category)
end
```

[CITED: warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes — InterfaceOptions_AddCategory deprecated in 10.0]

### Pattern 3: OptionsSliderTemplate Nil-Guard (COMP-05)

**What:** Guard `OptionsSliderTemplate` reference; fall back to `UISliderTemplateWithLabels`.
**When to use:** Any `CreateFrame("Slider", ...)` call using a named template.

Current (line 892):
```lua
local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
```

After (nil-guard with documented fallback template):
```lua
local sliderTemplate = (C_Util and C_Util.GetFrameTemplate and
  C_Util.GetFrameTemplate("OptionsSliderTemplate")) and "OptionsSliderTemplate"
  or "UISliderTemplateWithLabels"
local slider = CreateFrame("Slider", nil, panel, sliderTemplate)
```

Simpler practical approach (avoids frame-template introspection API uncertainty):
```lua
-- OptionsSliderTemplate removed in some WoW builds; UISliderTemplateWithLabels is current
local slider = CreateFrame("Slider", nil, panel,
  "UISliderTemplateWithLabels")
```

`UISliderTemplateWithLabels` includes the thumb and track textures, and supports `SetMinMaxValues`, `SetValueStep`, `SetObeyStepOnDrag`, `SetValue`, and `OnValueChanged` — same interface as `OptionsSliderTemplate`.

[CITED: warcraft.wiki.gg/wiki/UIOBJECT_Slider — UISliderTemplateWithLabels usage example shown]
[ASSUMED] `UISliderTemplateWithLabels` is present on Midnight 12.0 retail — confirmed documented on wiki but live client status not independently verified.

### Pattern 4: generalPlaystyle Fallback Classification (COMP-06)

**What:** Add `generalPlaystyle` as a display hint when `categoryID` yields "OTHER".
**When to use:** After all categoryID checks fail in `ClassifyResult`.

The `generalPlaystyle` enum values describe *how* to play (Learning/FunRelaxed/FunSerious/Expert), not *what* to play. They do NOT map to Dungeon/Raid/PvP/Custom content categories. The correct use is: when ClassifyResult would return "OTHER", check if generalPlaystyle is set and non-nil to confirm this is intentional new-content (not a broken result). The classification result is still "OTHER" but future phases can use this field for display.

```lua
local function ClassifyResult(res)
  if not res then return "OTHER" end
  local act = GetActivityInfoForRes(res) or {}
  local name = (act and act.fullName) or res.activityText or res.name or ""
  -- M+ check (unchanged)
  local isMPlus = (res.isMythicPlusActivity == true)
                  or (tonumber(res.keyLevel) and tonumber(res.keyLevel) > 0)
                  or (act and (act.isMythicPlusActivity == true))
                  or (act and act.difficultyID == 8)
                  or (type(name) == "string" and name:find("%+"))
  if isMPlus then return "MPLUS" end
  -- categoryID mapping (unchanged)
  local categoryID = act.categoryID
  if categoryID == 2 then return "RAID" end
  if categoryID == 1 then return "DUNGEON" end
  if categoryID == 3 or categoryID == 4 then return "PVP" end
  if categoryID == 6 then return "CUSTOM" end
  -- generalPlaystyle fallback: new Midnight content types that lack a categoryID
  -- Values: 0=None, 1=Learning, 2=FunRelaxed, 3=FunSerious, 4=Expert
  -- These describe play intent, not content type — classify as "OTHER" regardless
  -- (the field is present on res directly, not via activityInfo)
  if res.generalPlaystyle and not issecretvalue(res.generalPlaystyle) then
    -- known field present; content type is genuinely uncategorized new content
    return "OTHER"
  end
  return "OTHER"
end
```

**Note:** The `issecretvalue()` guard is required here because `generalPlaystyle` may be a Secret Value during endgame instance content (see COMP-07).

[VERIFIED: warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo — generalPlaystyle: Enum.LFGEntryGeneralPlaystyle?, added patch 12.0.0]

### Pattern 5: Taint-Hardened ApplyToGroup (COMP-07)

**What:** Ensure pcall correctly catches both taint errors and hardware-event protection errors.
**When to use:** All `C_LFGList.ApplyToGroup` calls.

The existing `doApply()` at line 172-183 already has `pcall`. The key concern is that on Midnight, if the execution path to `doApply()` was tainted (e.g., by processing a Secret Value field earlier), the pcall may catch a different error than expected. The error string from a taint violation typically contains "Action blocked" or similar.

Current code at line 174 (already correct pattern):
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

This pattern is correct. The additional hardening needed is in `GetFreshResultInfo` — guard Secret Value fields before using them in comparisons:

```lua
local function GetFreshResultInfo(id)
  local info = C_LFGList.GetSearchResultInfo(id)
  if not info then return nil end
  -- isDelisted may be a Secret Value in endgame content; use issecretvalue guard
  if not issecretvalue(info.isDelisted) and info.isDelisted then return nil end
  info.activityText = BuildActivityText(info)
  return info
end
```

[VERIFIED: warcraft.wiki.gg/wiki/Category:API_functions/restricted — C_LFGList.ApplyToGroup listed as restricted (hardware event protected since 7.2.0)]
[CITED: warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes — Secret Values system introduced; issecretvalue() global added]

### Anti-Patterns to Avoid

- **Accessing `res.activityID` (singular):** Removed in patch 11.0.7. Any code reading this field gets `nil` on Midnight. Remove all primary `activityID` branches.
- **Comparing Secret Value fields in boolean context:** `if info.isDelisted then` will throw a Lua error if `isDelisted` is a Secret Value. Always guard with `not issecretvalue(field) and field`.
- **Arithmetic/logic on Secret Values:** Secret Values cannot be used in `==`, `~=`, `and`, `or` without causing Lua errors. The error is not catchable with `pcall` in all contexts.
- **Calling `C_LFGList.ApplyToGroup` from tainted code paths:** If code that modified UI frames (tainting execution) leads to `ApplyToGroup`, it will fire `ADDON_ACTION_BLOCKED`. The button's `OnClick` handler must remain clean.
- **Removing the Settings API nil-guard:** `Settings` may not be present on edge case client builds. Keep the `if Settings and Settings.RegisterCanvasLayoutCategory` guard.
- **Using `InterfaceOptions_AddCategory` without check:** It is nil on Midnight; calling it crashes. The dead `elseif` block is safe only because it is already guarded.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Activity name lookup | Custom activity name table | `C_LFGList.GetActivityInfoTable(activityIDs[1])` | Blizzard maintains the activity data; hand-rolled tables go stale each patch |
| Slider UI | From-scratch slider with custom textures (unless template nil) | `UISliderTemplateWithLabels` | Template provides thumb, track, and all visual states; manual approach requires maintaining texture paths across patches |
| Taint detection | Custom taint tracking | `issecretvalue(val)` global + `pcall` | Blizzard provides `issecretvalue()` precisely for this; attempting to detect taint by context is unreliable |
| Options panel | Custom settings frame/tab system | `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` | Integrates with WoW's built-in Settings UI; users find it in the expected location |

**Key insight:** In the WoW Lua sandbox, Secret Values are a first-class type. Any hand-rolled taint detection based on context (in-instance, in-combat) will be wrong on edge cases. Use `issecretvalue()` directly.

---

## Common Pitfalls

### Pitfall 1: activityID Returns nil Silently
**What goes wrong:** Code checks `res.activityID` — this returns `nil` on Midnight because the field was removed. The fallback to `activityIDs` is then triggered, which is correct, but if the fallback branch has a bug, the activity name displays as "Unknown Activity".
**Why it happens:** Patch 11.0.7 changed the field name without a deprecation period. Old code silently gets nil.
**How to avoid:** Remove the `activityID` primary check entirely. `activityIDs[1]` is the only path.
**Warning signs:** LFG listings show "Unbekannte Aktivität" / "Unknown Activity" for all entries.

### Pitfall 2: Secret Value Comparison Crash
**What goes wrong:** `if info.isDelisted then` or `if info.autoAccept == true then` throws a Lua error: "attempt to perform arithmetic/comparison on a secret value".
**Why it happens:** On Midnight, `GetSearchResultInfo` returns Secret Values for some fields during endgame (instance) content. Any comparison on a Secret Value causes a Lua error, not a boolean false.
**How to avoid:** Guard every field that could be a Secret Value with `not issecretvalue(field)` before using it in boolean context. Critical fields: `isDelisted`, `autoAccept`.
**Warning signs:** Lua error in chat: `[string "EquiFastJoin.lua"]:133: attempt to compare secret value`.

### Pitfall 3: ADDON_ACTION_BLOCKED on ApplyToGroup
**What goes wrong:** `C_LFGList.ApplyToGroup` fires `ADDON_ACTION_BLOCKED`. The pcall catches the error string but the UI shows no feedback beyond the generic error message.
**Why it happens:** The call is hardware-event protected. If execution was tainted before reaching `doApply()` — for example by reading and processing a Secret Value field — the entire call chain becomes tainted and the protected function blocks.
**How to avoid:** Ensure the button `OnClick` handler does NOT process Secret Value fields before calling `TryJoin`. Keep `TryJoin` clean of any field comparisons on `res` data that could be secret.
**Warning signs:** `DBG("ApplyToGroup error:", err)` logs a string containing "Action blocked" or similar.

### Pitfall 4: OptionsSliderTemplate CreateFrame Fails Silently
**What goes wrong:** `CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")` returns a frame with no visual elements (no thumb, no track) if the template no longer exists — or crashes with "attempt to call nil" in some builds.
**Why it happens:** `OptionsSliderTemplate` was removed in Classic Era 1.15.4; its status in Midnight Retail is unconfirmed from static research alone.
**How to avoid:** Use `UISliderTemplateWithLabels` directly (simpler) or nil-guard the template reference and fall back.
**Warning signs:** Options panel opens but scale slider is invisible or throws a Lua error.

### Pitfall 5: InterfaceOptions_AddCategory Dead Code Left In
**What goes wrong:** While the dead `elseif` branch is guarded and won't crash, it adds maintenance confusion and signals to future readers that the old API might still be needed.
**Why it happens:** Code not cleaned up after primary path was added.
**How to avoid:** Remove the `elseif InterfaceOptions_AddCategory` block entirely. On Midnight, `Settings` is always present.
**Warning signs:** Code review flags the dead branch.

---

## Code Examples

### COMP-03: Consolidated GetActivityInfoForRes

```lua
-- Source: warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo
-- activityID (singular) removed in patch 11.0.7; activityIDs (table) is now the only field

local function GetActivityInfoForRes(res)
  if not res then return nil end
  if type(res.activityIDs) == "table" and #res.activityIDs > 0 then
    return C_LFGList.GetActivityInfoTable(res.activityIDs[1])
  end
  return nil
end
```

All callers (`ClassifyResult`, `BuildActivityText`, `ToastForIDs` inline at line 687) must route through this function — no direct `res.activityID` or `res.activityIDs` access outside this helper.

### COMP-04: Clean Settings Registration

```lua
-- Source: warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes
-- InterfaceOptions_AddCategory nil on Midnight; Settings API is the only live path

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, "EquiFastJoin")
  Settings.RegisterAddOnCategory(category)
end
```

### COMP-05: Slider with Fallback Template

```lua
-- UISliderTemplateWithLabels confirmed documented; OptionsSliderTemplate status uncertain
-- Source: warcraft.wiki.gg/wiki/UIOBJECT_Slider

local slider = CreateFrame("Slider", nil, panel, "UISliderTemplateWithLabels")
slider:SetPoint("TOPLEFT", x, y - 18)
slider:SetMinMaxValues(minV, maxV)
slider:SetValueStep(step)
slider:SetObeyStepOnDrag(true)
slider:SetValue(EquiFastJoinDB[key] or 1.0)
slider:SetScript("OnValueChanged", function(self, value)
  EquiFastJoinDB[key] = tonumber(string.format("%.2f", value))
  if EFJ.UI.frame then EFJ.UI.frame:SetScale(EquiFastJoinDB.scale or 1.0) end
end)
```

Note: `UISliderTemplateWithLabels` includes built-in label font strings; the existing Low/High label `CreateFontString` calls below the slider may need adjustment if the template provides its own.

### COMP-06: ClassifyResult with generalPlaystyle guard

```lua
-- Source: warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo
-- generalPlaystyle added patch 12.0.0; values 0-4 describe play intent, not content type

local function ClassifyResult(res)
  if not res then return "OTHER" end
  local act = GetActivityInfoForRes(res) or {}
  local name = (act and act.fullName) or res.activityText or res.name or ""
  local isMPlus = (res.isMythicPlusActivity == true)
                  or (tonumber(res.keyLevel) and tonumber(res.keyLevel) > 0)
                  or (act and (act.isMythicPlusActivity == true))
                  or (act and act.difficultyID == 8)
                  or (type(name) == "string" and name:find("%+"))
  if isMPlus then return "MPLUS" end
  local categoryID = act.categoryID
  if categoryID == 2 then return "RAID" end
  if categoryID == 1 then return "DUNGEON" end
  if categoryID == 3 or categoryID == 4 then return "PVP" end
  if categoryID == 6 then return "CUSTOM" end
  -- generalPlaystyle: new Midnight content with no categoryID mapping
  -- Guard against Secret Value before any field access
  local gps = res.generalPlaystyle
  if gps and not issecretvalue(gps) then
    -- Content type is genuinely new/uncategorized; still "OTHER" but field is valid
    return "OTHER"
  end
  return "OTHER"
end
```

### COMP-07: GetFreshResultInfo with Secret Value guard

```lua
-- Source: warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
-- Secret Values: fields from GetSearchResultInfo can be secret during endgame content

local function GetFreshResultInfo(id)
  local info = C_LFGList.GetSearchResultInfo(id)
  if not info then return nil end
  -- isDelisted may be a Secret Value in instance content; guard before boolean use
  if not issecretvalue(info.isDelisted) and info.isDelisted then return nil end
  info.activityText = BuildActivityText(info)
  return info
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `res.activityID` (singular) | `res.activityIDs[1]` (first element of table) | Patch 11.0.7 (2024-12-17) | Old field is nil on Midnight; displays "Unknown Activity" |
| `InterfaceOptions_AddCategory(panel)` | `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` | Patch 10.0.0 (Dragonflight, 2022) | Old function is nil on Midnight |
| `CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")` | `CreateFrame("Slider", nil, panel, "UISliderTemplateWithLabels")` | Classic Era 1.15.4 (slider template removed); Retail status LOW confidence | Slider may be invisible or error on Midnight if template missing |
| No `generalPlaystyle` field | `res.generalPlaystyle` (Enum.LFGEntryGeneralPlaystyle, values 0-4) | Patch 12.0.0 | New Midnight content types have no categoryID; previously classified as broken "OTHER" |
| Taint = nil or error on protected call | Secret Values = typed Lua value that throws on comparison | Patch 12.0.0 | `issecretvalue()` guard required before any boolean/arithmetic on result fields |

**Deprecated/outdated:**
- `res.activityID`: Removed 11.0.7. Replace with `res.activityIDs[1]`.
- `InterfaceOptions_AddCategory`: Deprecated 10.0, nil on Midnight. Replace with Settings API.
- `OptionsSliderTemplate`: Removed in Classic Era; Retail status uncertain. Use `UISliderTemplateWithLabels` as safe alternative.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `UISliderTemplateWithLabels` is present on Midnight 12.0 Retail | Standard Stack, Pattern 3 | If missing, slider is invisible; fallback needed to manual base Slider + textures |
| A2 | `issecretvalue()` global is available at runtime in all addon execution contexts on Midnight | Pattern 4, Pattern 5 | If nil, the guard itself crashes; need to wrap in `(issecretvalue and issecretvalue(val))` |
| A3 | `GetSearchResultInfo` returns Secret Values for `isDelisted` and `autoAccept` fields specifically during endgame/instance content | Pitfall 2, COMP-07 | If wrong fields are guarded (false negative), crash persists; if unnecessary fields guarded (false positive), no harm |
| A4 | `OptionsSliderTemplate` is nil (not just missing textures) on Midnight Retail — i.e., `CreateFrame` with that template name causes an error | Common Pitfalls 4 | If template still present but with missing textures, behavior is visual-only bug not a crash |
| A5 | `generalPlaystyle` field on `res` (from `GetSearchResultInfo`) is directly on the `res` table, not inside `act` (activityInfo) | Pattern 4 (COMP-06) | If it's on `act` instead, current code reads nil and the guard never triggers |

---

## Open Questions

1. **Is `OptionsSliderTemplate` nil on Midnight Retail 12.0?**
   - What we know: Removed in Classic Era 1.15.4; present in Retail 11.0.2; no direct confirmation for 12.0
   - What's unclear: Whether Blizzard cleaned it from Retail in the Midnight restructure
   - Recommendation: Use `UISliderTemplateWithLabels` unconditionally (safer) rather than conditional nil-guard. If `UISliderTemplateWithLabels` also fails, fall back to manual Slider. This is MEDIUM risk, requires live client verification.

2. **Does `issecretvalue` need to be nil-guarded itself?**
   - What we know: `issecretvalue()` was added in patch 12.0.0 per API changes
   - What's unclear: Whether it is available on all 12.x patch levels (12.0.1, 12.0.5)
   - Recommendation: Wrap as `(issecretvalue and issecretvalue(val))` — costs nothing, is safe.

3. **Are there additional Secret Value fields beyond `isDelisted` and `autoAccept` in GetSearchResultInfo?**
   - What we know: Fields become secret "while in an instance" for endgame content restriction
   - What's unclear: Complete list of which fields are secret-ified
   - Recommendation: Guard any field used in boolean/arithmetic comparison that originates from `GetSearchResultInfo`. Safe fields: string operations (display only) generally don't require guards. Risky fields: booleans used in if-conditions.

---

## Environment Availability

Step 2.6 SKIPPED — Phase 2 is code-only edits to `EquiFastJoin.lua`. No external tools, runtimes, databases, or CLI utilities required beyond a text editor and git. Live WoW client is required for final validation (noted in Validation Architecture section).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (WoW Lua addons have no automated unit test runner in-game) |
| Config file | none |
| Quick run command | Manual: load addon in WoW client, `/efj show`, check for Lua errors in chat |
| Full suite command | Manual: login, `/efj show`, click Join button from inside and outside instance, open `/efj options`, check slider and all checkboxes |

WoW addon testing is inherently manual. There is no offline Lua test runner that can execute WoW API calls. All COMP-0x requirements require live WoW client verification.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-03 | LFG listings show correct activity names (not "Unbekannte Aktivität") | manual-smoke | None — requires live WoW client | N/A |
| COMP-04 | Options panel opens via `/efj options` with no Lua errors | manual-smoke | None — requires live WoW client | N/A |
| COMP-05 | Scale slider visible and functional in options panel | manual-smoke | None — requires live WoW client | N/A |
| COMP-06 | New Midnight content types appear in listing (not filtered out incorrectly) | manual-smoke | None — requires live WoW client | N/A |
| COMP-07 | Join button works from inside a Mythic+ or raid instance without ADDON_ACTION_BLOCKED | manual-smoke | None — requires live WoW client | N/A |

**Manual-only justification:** WoW addons execute inside the game's embedded Lua VM with Blizzard API globals unavailable offline. Secret Values behavior can only be observed during live endgame content (instances). [ASSUMED: no offline WoW addon Lua test runner exists for retail Midnight]

**Partial static verification** (before live test):
- `grep -n "res\.activityID[^s]" EquiFastJoin.lua` should return 0 results after COMP-03
- `grep -n "InterfaceOptions_AddCategory" EquiFastJoin.lua` should return 0 results after COMP-04

### Sampling Rate

- **Per task commit:** Static grep verification (confirm removed code is absent)
- **Per wave merge:** Live WoW client smoke test in open world (no instance)
- **Phase gate:** COMP-07 specifically requires in-instance test; full suite must include joining a Mythic+ dungeon group from inside an instance

### Wave 0 Gaps

None — existing "test infrastructure" is manual-only by nature of the platform.

---

## Security Domain

No security surface changes in this phase. Changes are API compatibility fixes (field name migration, template replacement, dead code removal). The taint hardening (COMP-07) reduces crash surface but does not add new user-facing security.

ASVS categories: not applicable. WoW addons run in a sandboxed Lua VM with no network access, no file I/O, and no user credential handling. The relevant "security" concern is Blizzard's addon sandbox rules (taint, hardware event protection), which are addressed by the pcall pattern and `issecretvalue()` guard documented above.

---

## Sources

### Primary (HIGH confidence)
- [warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo](https://warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo) — activityIDs field (plural, patch 11.0.7), generalPlaystyle field (patch 12.0.0), full return table documented
- [warcraft.wiki.gg/wiki/Category:API_functions/restricted](https://warcraft.wiki.gg/wiki/Category:API_functions/restricted) — C_LFGList.ApplyToGroup listed as restricted (hardware event protected)
- [warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) — Secret Values system, issecretvalue() global added, 437 added / 138 removed APIs
- [warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes) — InterfaceOptions_AddCategory deprecated; Settings API introduced

### Secondary (MEDIUM confidence)
- [warcraft.wiki.gg/wiki/UIOBJECT_Slider](https://warcraft.wiki.gg/wiki/UIOBJECT_Slider) — UISliderTemplateWithLabels documented with usage example
- [us.forums.blizzard.com/en/wow/t/optionsslidertemplate-in-classic-era/1968743](https://us.forums.blizzard.com/en/wow/t/optionsslidertemplate-in-classic-era/1968743) — OptionsSliderTemplate removed in Classic Era 1.15.4; present in Retail 11.0.2 (status on 12.0 unconfirmed)
- [wowhead.com/news/new-playstyle-options-category-required-for-posting-in-group-finder-in-midnight-379263](https://www.wowhead.com/news/new-playstyle-options-category-required-for-posting-in-group-finder-in-midnight-379263) — generalPlaystyle is mandatory for posting in Group Finder on Midnight; describes Learning/Relaxed/Competitive/Carry intent
- [github.com/0xbs/premade-groups-filter/issues/64](https://github.com/0xbs/premade-groups-filter/issues/64) — ADDON_ACTION_BLOCKED pattern for tainted LFG list interaction; workaround via local reimplementation documented

### Tertiary (LOW confidence)
- WebSearch synthesis: OptionsSliderTemplate status on Midnight 12.0 Retail (flagged A4 in Assumptions Log — requires live client verification)
- WebSearch synthesis: Exact list of Secret Value fields in GetSearchResultInfo during endgame content (flagged A3 — only `isDelisted` confirmed via community reports)

---

## Metadata

**Confidence breakdown:**
- COMP-03 (activityID consolidation): HIGH — field change documented with patch number in official wiki
- COMP-04 (InterfaceOptions removal): HIGH — deprecation documented in 10.0 API changes; Settings API confirmed
- COMP-05 (OptionsSliderTemplate): LOW-MEDIUM — removed in Classic builds; Retail 12.0 status requires live verification
- COMP-06 (generalPlaystyle): HIGH for field existence; MEDIUM for correct integration pattern
- COMP-07 (Secret Values taint): MEDIUM — system confirmed in 12.0 API changes; exact fields affected require live verification

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (stable API surface; only changes with new WoW patches)
