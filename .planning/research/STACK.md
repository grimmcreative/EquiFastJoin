# Technology Stack

**Project:** EquiFastJoin — WoW Midnight (12.x) Compatibility Update
**Researched:** 2026-04-14
**Milestone:** 11.x → 12.x migration

---

## What Changed: 11.x → 12.x Summary

Midnight launched 2 March 2026. The expansion introduced the largest addon API overhaul since WoW's launch. Three categories of change affect EquiFastJoin:

1. **Hard requirement**: TOC Interface version must be ≥ 120000 — the client will not load the addon at all without this. Unlike previous expansions, there is no "Load Out of Date Addons" override.
2. **API behaviour changes**: Two C_LFGList changes affect existing code directly.
3. **Non-combat addon impact: minimal** — the Midnight combat restrictions (Secret Values, CLEU blackout) target rotation helpers, not LFG/social queue addons. EquiFastJoin's core APIs are not combat-gated.

---

## Interface Version

| Patch | TOC Interface Version | Notes |
|-------|----------------------|-------|
| 11.2.0 (current) | 110200 | What the addon declares today |
| 12.0.0 (Midnight launch) | 120000 | Minimum to load in Midnight |
| 12.0.1 | 120001 | First content patch (10 Feb 2026) |
| 12.0.5 | 120005 | Lingering Shadows (21 Apr 2026) |

**Recommendation:** Update TOC to `120005`. This is the current live patch as of the date of this research. Targeting the latest point-patch version ensures the addon is not shown as "out of date" immediately after release.

The interface number format for 12.x follows the same schema as all prior retail versions: `XXYYZZ` where XX = major (12), YY = minor (00, 01, 05), ZZ = patch revision (usually 00). Version 120500 is the wrong format — the correct number is `120005`.

**Confidence:** HIGH — Multiple sources confirm the 120000 baseline (Warcraft Wiki, CurseForge addon authors, Blizzard forum posts). The 12.0.5 = 120005 mapping follows the documented format convention confirmed by Warcraft Wiki's interface number article.

---

## Lua Version

**No change.** WoW uses an embedded, modified Lua 5.1 runtime. This has not changed in Midnight. No Lua 5.4 migration, no LuaJIT switch. All existing Lua syntax in EquiFastJoin is valid under 12.x.

**Confidence:** HIGH — No credible source indicates a Lua runtime version change. Community resources (Wowpedia, MMO-Champion) explicitly state WoW uses Lua 5.1. The Midnight API change documentation concerns API surface, not the runtime.

---

## Recommended Stack (Unchanged, with Targeted Updates)

### Core Runtime

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| Lua | 5.1 (WoW embedded) | Unchanged | No migration needed |
| WoW Retail client | 12.x (Midnight) | Target | Minimum 120000 to load |
| TOC Interface | 120005 | Update required | Change from 110200 |

### APIs EquiFastJoin Uses — Status in 12.x

| API | Used in Addon | 12.x Status | Action Required |
|-----|--------------|-------------|-----------------|
| `C_LFGList.GetSearchResultInfo(id)` | Lines 132, 624 | Changed (see below) | Verify `activityIDs` field |
| `C_LFGList.GetActivityInfoTable(id)` | Lines 71, 111, 686 | Unchanged | None |
| `C_LFGList.GetSearchResults()` | Line 725 | Unchanged | None |
| `C_LFGList.GetSearchResultMemberInfo(id, idx)` | Lines 570, 627 | Unchanged | None |
| `C_LFGList.GetSearchResultMemberCounts(id)` | Line 586 | Unchanged | None |
| `C_LFGList.ApplyToGroup(id, note, tank, heal, dps)` | Line 174 | Unchanged | None |
| `C_LFGList.CancelApplication(id)` | Line 213 | Unchanged | None |
| `C_LFGList.GetApplicationInfo(id)` | Line 394 | Unchanged | None |
| `C_LFGList.RefreshResults()` | Lines 945, 951, 959 | Unchanged | None |
| `C_SocialQueue.GetAllGroups()` | Lines 731, 748 | Unchanged | None |
| `C_SocialQueue.GetGroupMembers(guid)` | Line 752 | Unchanged | None |
| `C_SocialQueue.GetGroupQueues(guid)` | Line 753 | Unchanged | None |
| `C_Timer.NewTicker` / `C_Timer.After` | Lines 944–967 | Unchanged | None |
| `LFGListApplicationDialog_Show` | Lines 148–157 | Likely unchanged | Verify in-game |
| `LoadAddOn()` | Lines 148–150 | Soft-deprecated | Use `C_AddOns.LoadAddOn()` with fallback |
| `Settings.RegisterCanvasLayoutCategory()` | Line 932 | Unchanged | None |
| `GetSpecialization()` / `GetSpecializationRole()` | Lines 163–169 | Unchanged | None |
| `InCombatLockdown()` | Lines 143, 945, 951, 959 | Unchanged | None |
| `UIParent`, frame templates | Throughout | Unchanged | None |

**Confidence:** MEDIUM for the overall "unchanged" conclusions — the Warcraft Wiki API change pages for 12.0.0 and 12.0.1 exist and were referenced in search results without mentioning these functions as removed or changed (absence of citation in change pages is moderate evidence). HIGH for C_LFGList.GetSearchResultInfo change (documented in Patch 11.0.7 change log).

---

## API Changes That Require Code Updates

### 1. `C_LFGList.GetSearchResultInfo` — `activityID` field renamed to `activityIDs`

**When it changed:** Patch 11.0.7 (December 2024), already before Midnight. This means the change is live on 11.2.0 already, but EquiFastJoin's code already handles it.

**What changed:** The return table field `activityID` (single integer) was replaced with `activityIDs` (array of integers).

**Current code already handles this partially** at lines 67–69:
```lua
local activityID = res.activityID
if (not activityID) and type(res.activityIDs) == "table" and #res.activityIDs > 0 then
  activityID = res.activityIDs[1]
end
```

**Action:** The fallback exists. Verify that `res.activityID` still ever returns a value on 12.x — if not, the fallback branch is always taken. The code will work either way, but the primary branch may be dead code. Low priority — code is safe.

**Confidence:** HIGH — explicitly documented in Patch 11.0.7/API changes on Warcraft Wiki.

### 2. `LoadAddOn()` global — soft-deprecated in favour of `C_AddOns.LoadAddOn()`

**What changed:** Blizzard namespaced addon management functions under `C_AddOns`. The global `LoadAddOn()` is not yet removed but is soft-deprecated. The new canonical form is `C_AddOns.LoadAddOn("addonName")`.

**Current code** at lines 148–150 calls `pcall(LoadAddOn, "Blizzard_LFGList")` and `pcall(LoadAddOn, "Blizzard_LookingForGroupUI")`.

**Recommended update** (backwards-compatible pattern):
```lua
local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
```
Then use `LoadAddOn(name)` as before. This resolves to the namespaced version on 12.x and the global on older builds.

**Confidence:** MEDIUM — confirmed that C_AddOns.LoadAddOn exists in current API (Warcraft Wiki page exists). Deprecation of global is reported by community; "removed" status in 12.x is unconfirmed — wrapping with fallback is the safe approach.

---

## Midnight Combat Restriction Impact Assessment

The headline Midnight change is the "Secret Values" system: combat events return opaque identifiers instead of readable data. This breaks rotation helpers, aura trackers, and real-time damage meters.

**EquiFastJoin is not a combat addon.** Its functional scope is:
- Displaying LFG listings (event-driven, not polled during combat)
- Displaying Quick Join suggestions (social queue events)
- One-click group joining (already gated behind `InCombatLockdown()`)
- Options panel (already blocked during combat)

None of these touch `COMBAT_LOG_EVENT_UNFILTERED`, unit health/power, or spell IDs. The combat restriction does not affect this addon's functionality.

The one area to verify: Blizzard tightened restrictions on which UI interactions can happen during combat. The existing `InCombatLockdown()` guards in EquiFastJoin should be sufficient, but `LFGListApplicationDialog_Show` (a Blizzard frame interaction) should be verified works out of combat on 12.x.

**Confidence:** HIGH that combat restrictions don't affect EquiFastJoin's core. MEDIUM that LFGListApplicationDialog interaction is unchanged — it's a Blizzard-owned secure frame so it is expected to remain functional when called from non-tainted code out of combat.

---

## TOC File Changes

The TOC format itself has no new required fields for Midnight. The only mandatory change is the `## Interface:` value.

**Current TOC (must change):**
```
## Interface: 110200
```

**Updated TOC:**
```
## Interface: 120005
```

No new TOC metadata fields are required. The existing fields (`Title`, `Notes`, `Author`, `Version`, `SavedVariables`, `DefaultState`, `IconTexture`) are all still valid.

**Confidence:** HIGH — TOC format page on Warcraft Wiki confirms no structural changes for 12.x.

---

## What Stays Completely Unchanged

- Lua 5.1 syntax and standard library (`table`, `string`, `math`, `pairs`, `ipairs`, `pcall`, etc.)
- All `CreateFrame()` calls and frame hierarchy
- `BackdropTemplate` (introduced 9.0.1, still valid)
- `UIPanelScrollFrameTemplate` (still present)
- `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `OptionsSliderTemplate`
- `Settings.RegisterCanvasLayoutCategory()` / `Settings.RegisterAddOnCategory()` (modern Settings API, introduced in 10.x, still current)
- `SavedVariables` system — same WTF path, same load/save behaviour
- All game events: `ADDON_LOADED`, `SOCIAL_QUEUE_UPDATE`, `LFG_LIST_SEARCH_RESULTS_RECEIVED`, `LFG_LIST_ACTIVE_ENTRY_UPDATE`, `LFG_LIST_APPLICATION_STATUS_UPDATED`, `GROUP_ROSTER_UPDATE`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`
- `RAID_CLASS_COLORS`, `CLASS_ICON_TCOORDS` global tables
- `GetPlayerInfoByGUID()`, `GetSpecialization()`, `GetSpecializationRole()`
- `SocialQueueUtil_GetRelationshipInfo()` — not in documented removal lists

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| [Patch 12.0.0/API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) | Official wiki | HIGH |
| [Patch 12.0.1/API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes) | Official wiki | HIGH |
| [Patch 11.0.7/API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_11.0.7/API_changes) | Official wiki (activityIDs change) | HIGH |
| [TOC format — Warcraft Wiki](https://warcraft.wiki.gg/wiki/TOC_format) | Official wiki | HIGH |
| [Getting the current interface number — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number) | Official wiki | HIGH |
| [C_AddOns.LoadAddOn — Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_AddOns.LoadAddOn) | Official wiki | HIGH |
| [Midnight: Get up to Speed with UI Updates — Blizzard Forums](https://us.forums.blizzard.com/en/wow/t/midnight-get-up-to-speed-with-user-interface-updates/2163232) | Blizzard official post | HIGH |
| [No more Load Out of Date Addons — Blizzard Forums](https://us.forums.blizzard.com/en/wow/t/no-more-load-out-of-date-addons/2195566) | Blizzard official post | HIGH |
| [Patch 12.0.0/Planned API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes) | Official wiki | MEDIUM |
| [ToCVersions GitHub (NumyAddon)](https://github.com/NumyAddon/ToCVersions) | Community tool | MEDIUM |
| [WoW Midnight API changes — Wowhead](https://www.wowhead.com/news/addon-changes-for-midnight-launch-ending-soon-with-release-candidate-coming-380133) | Community news | MEDIUM |
| [Combat addon restrictions eased — Icy Veins](https://www.icy-veins.com/wow/news/combat-addon-restrictions-eased-in-midnight/) | Community news | MEDIUM |

---

*Research date: 2026-04-14 | Researcher: GSD Phase 6 (Stack dimension)*
