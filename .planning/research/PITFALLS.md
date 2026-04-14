# Domain Pitfalls: WoW Midnight (12.x) Addon Migration

**Domain:** WoW Retail addon — LFG/Quick Join, C_LFGList, C_SocialQueue
**Researched:** 2026-04-14
**Confidence:** MEDIUM — TOC version and activityID→activityIDs changes HIGH confidence (documented). Secret Values impact on LFG/SocialQueue is MEDIUM (pattern documented but EquiFastJoin-specific interactions are not publicly tested). InterfaceOptions/Settings fate is MEDIUM (deprecation pattern clear, exact Midnight removal requires live verification).

---

## Critical Pitfalls

Mistakes that cause the addon to silently fail, crash on load, or produce ADDON_ACTION_BLOCKED errors.

---

### Pitfall 1: TOC Interface Version Mismatch — Addon Does Not Load

**Phase:** TOC/Compat phase (first thing to fix)

**What goes wrong:** The TOC file declares `## Interface: 110200` (11.2.0). WoW Midnight uses interface version `120000`. By default WoW marks addons with a lower interface version as "out of date" and does not load them unless the user enables out-of-date addons in the character selection screen.

**Why it happens:** The addon was written for patch 11.2.0 and the TOC was never updated. This is the confirmed reason the addon is currently broken on Midnight.

**Consequences:** Addon does not load at all. Users on CurseForge report the addon as broken. The entire fix list below is moot until this is resolved first.

**Prevention:**
- Change `## Interface: 110200` to `## Interface: 120000` in `EquiFastJoin.toc`
- For multi-version support, add both `## Interface-Retail: 120000` and keep a fallback (Blizzard supports split TOC in newer format)
- Confirm the current live Midnight version with `GetBuildInfo()` to validate the number

**Detection:** Addon does not appear in the addon list, or appears grayed out with "out of date" warning.

**Sources:** [Patch 12.0.0 released January 28, 2026 — interface 120000](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)

---

### Pitfall 2: activityID → activityIDs Field Rename in GetSearchResultInfo

**Phase:** C_LFGList API audit phase

**What goes wrong:** In Patch 11.0.7 (December 2024), `C_LFGList.GetSearchResultInfo()` changed the return field `activityID` (singular) to `activityIDs` (plural, a table). Any code reading `res.activityID` will get `nil` on Midnight.

**Why it happens:** Blizzard allowed group listings to be associated with multiple activities. The field was silently renamed. Code that reads the old singular field returns nil without error.

**Consequences:** `GetActivityInfoForRes()` (line 63–73 in EquiFastJoin.lua) has a two-path fallback: it tries `res.activityID` first, then falls back to `res.activityIDs[1]`. The fallback covers this change — BUT only if `res.activityIDs` is a non-empty table. If Midnight also changed the table structure, both paths could fail. The fallback in the existing code is partially correct but the primary path (`res.activityID`) will always be nil on Midnight, making the fallback the only live path.

**Current code state:** The fallback at lines 66–68 already handles `activityIDs` as a table. This is a latent correctness issue rather than an immediate crash, but it must be verified: ensure no code assumes `activityID` is non-nil outside this helper.

**Prevention:**
- Audit every reference to `res.activityID` across the codebase and replace with a canonical helper like `GetActivityInfoForRes(res)` that centralizes the fallback
- Remove the `res.activityID` primary path in the helper entirely — just use `res.activityIDs[1]` as the starting point

**Detection:** Activity names show as "Unknown Activity" / "Unbekannte Aktivität" instead of the real name. The `BuildActivityText` function's last fallback fires.

**Sources:** [C_LFGList.GetSearchResultInfo — Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo), [Patch 11.0.7 API changes](https://warcraft.wiki.gg/wiki/Patch_11.0.7/API_changes)

---

### Pitfall 3: C_LFGList.GetPlaystyleString Is a Protected Function — Taint Risk

**Phase:** C_LFGList API audit phase

**What goes wrong:** `C_LFGList.GetPlaystyleString` and related playstyle functions are hardware-protected. Calling them from addon code that was involved in any tainted execution path triggers `ADDON_ACTION_BLOCKED`. In Midnight, Blizzard's new "Secret Values" system extends taint propagation: if any input to a function is a Secret Value, the output becomes secret too. Passing a secret result ID into a protected function contaminates that call chain.

**Why it happens:** Blizzard protects group listing creation/title functions to prevent bots from automating group creation. The protection predates Midnight, but Midnight's Secret Value system makes it harder to avoid accidental taint — tainted code paths can now propagate "secret-ness" through Lua operations, and the Lua concatenation operator was relaxed but arithmetic on secrets still raises errors.

**Consequences:** EquiFastJoin does not currently call `GetPlaystyleString` directly. However, if any result ID returned by `C_LFGList.GetSearchResults()` becomes a Secret Value in certain contexts (e.g., inside an instance), passing that ID into `C_LFGList.GetSearchResultInfo()`, `ApplyToGroup()`, or `LFGListApplicationDialog_Show()` could trigger a blocked action or Lua error. Other addons (e.g., Premade Groups Filter, LFG Teleport Button Midnight) have already hit this. The impact is: join button stops working inside instances.

**Prevention:**
- Never call any `C_LFGList.*` function from a tainted code path
- Wrap every call to `C_LFGList.GetSearchResultInfo`, `GetSearchResultMemberInfo`, `GetSearchResultMemberCounts` in `pcall` — already done for `ApplyToGroup` and `RefreshResults`, but not for the read-only calls
- Do NOT concatenate or do arithmetic with result IDs in potentially-tainted contexts; pass them as raw integers only
- Consider adding `issecretvalue()` checks before passing result IDs into protected calls (if Blizzard exposes this utility in 12.x)
- Keep the existing pattern: open `LFGListApplicationDialog` via user click only, never from timers or automated paths

**Detection:** `ADDON_ACTION_BLOCKED: C_LFGList.GetPlaystyleString()` or similar error in Blizzard Error Frame. Join button stops responding inside instances.

**Sources:** [GetPlaystyleString taint issue — WoWUIBugs #195](https://github.com/Stanzilla/WoWUIBugs/issues/195), [Premade Groups Filter issue #64](https://github.com/0xbs/premade-groups-filter/issues/64), [Midnight Secret Values developer talk — Warcraft Tavern](https://www.warcrafttavern.com/wow/news/wow-midnight-developer-talk-new-secret-values-combat-info-cooldown-manager-combat-addons-nerfed/)

---

### Pitfall 4: InterfaceOptions_AddCategory Removed — Options Panel Does Not Register

**Phase:** Settings/Options migration phase

**What goes wrong:** `InterfaceOptions_AddCategory(panel)` was deprecated in Patch 10.0 and the deprecated legacy functions from 11.x are removed in 12.0.0. The current code has a dual registration path (lines 932–937): it tries the modern `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` first, then falls back to `InterfaceOptions_AddCategory`. On Midnight, the fallback path silently fails or errors because the function no longer exists.

**Why it happens:** Blizzard removed deprecated functions as part of the major API cleanup going into Midnight. API functions deprecated in the 11.x cycle are confirmed removed in Patch 12.0.0.

**Consequences:** If `Settings.RegisterCanvasLayoutCategory` is available in Midnight (HIGH confidence it still is), the primary path works and users never notice. BUT: the existing code also calls `InterfaceOptionsFrame_OpenToCategory` in `EFJ_OpenOptions()` (line 991–993) as a secondary fallback for opening the panel. If that global frame no longer exists, `/efj options` could error. Additionally, `Settings.GetCategory("EquiFastJoin")` at line 988 uses a string name lookup — this API may have changed signature in Midnight.

**Prevention:**
- Remove the `InterfaceOptions_AddCategory` fallback entirely; it is dead code on Midnight
- Remove the `InterfaceOptionsFrame_OpenToCategory` fallback in `EFJ_OpenOptions()` 
- For opening the settings panel, use only `Settings.OpenToCategory(category.ID)` where `category` is the registered category object stored at registration time — do not re-lookup by name on open
- Store the registered category object at registration time: `self.settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "EquiFastJoin")` and use it directly in open

**Detection:** `/efj options` does nothing or throws a Lua error. Settings panel does not appear in the Interface Options UI.

**Sources:** [Patch 12.0.0 API changes — deprecated functions removed](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes), [Patch 10.0.0 deprecation of OptionsSliderTemplate and legacy functions](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes)

---

### Pitfall 5: OptionsSliderTemplate Deprecated — Scale Slider May Break

**Phase:** Settings/Options migration phase

**What goes wrong:** `OptionsSliderTemplate` was deprecated in Patch 10.0 and is likely removed in Midnight. The current code uses it at line 892 for the scale slider in the options panel.

**Why it happens:** Same cleanup as InterfaceOptions — Blizzard removed the legacy XML template pool for option controls.

**Consequences:** The scale slider will fail to create, producing a nil frame. Any code that references `slider:SetValue()` or reads `EquiFastJoinDB.scale` via the slider will produce a Lua error on options panel creation.

**Prevention:**
- Replace `OptionsSliderTemplate` with a manual slider using `CreateFrame("Slider", ...)` and add `Min`/`Max`/`Value` FontString labels manually
- Alternatively, use the modern `Settings.CreateSlider()` API if registering through the new Settings system
- Guard with `if CreateFrame("Slider", nil, parent, "OptionsSliderTemplate") then` before using the template, though a direct replacement is preferred

**Detection:** Options panel creation throws a Lua error; scale slider is missing from the panel.

**Sources:** [OptionsSliderTemplate deprecation thread — WoW Forums](https://us.forums.blizzard.com/en/wow/t/optionsslidertemplate-in-classic-era/1968743), [Patch 10.0.0 API changes](https://warcraft.wiki.gg/wiki/Patch_10.0.0/API_changes)

---

## Moderate Pitfalls

Issues that degrade functionality but do not prevent the addon from loading.

---

### Pitfall 6: LfgSearchResultData Added generalPlaystyle Field — ClassifyResult May Misfire

**Phase:** C_LFGList API audit phase

**What goes wrong:** Patch 12.0.0 added a `generalPlaystyle` field to `LfgSearchResultData` (and corresponding changes to `DoesEntryTitleMatchPrebuiltTitle`, `SetEntryTitle`, `GetPlaystyleString` function signatures). The `ClassifyResult()` function in EquiFastJoin uses `categoryID` heuristics to categorize results. The new `generalPlaystyle` field may supersede `categoryID` as the authoritative classification signal for some content types.

**Consequences:** Groups may be classified as "OTHER" (and therefore hidden) even though they are valid Dungeon/Raid/M+/PvP entries, if Blizzard populates `generalPlaystyle` but leaves `categoryID` empty or changed for new Midnight content types.

**Prevention:**
- After TOC and core API fixes, run the addon against live LFG data and add `/efj debug on` logging for every `ClassifyResult()` call
- Add `generalPlaystyle` as an additional classification signal in `ClassifyResult()` alongside `categoryID`
- Test with each content type filter toggled to verify classification accuracy

**Detection:** Filter toggles produce no results despite groups being visible in native UI. Debug log shows entries falling through to "OTHER" category.

**Sources:** [Patch 12.0.0 API changes — LfgSearchResultData](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)

---

### Pitfall 7: SocialQueueUtil_GetRelationshipInfo May Be Removed or Moved

**Phase:** C_SocialQueue integration phase

**What goes wrong:** `SocialQueueUtil_GetRelationshipInfo` is a global utility function (not a C_* namespace function) called at line 773 to resolve player names from Quick Join group GUIDs. Global utility functions like this are more likely to be renamed, moved to a namespace, or removed than official C_* APIs.

**Consequences:** If the function is gone, `leaderName` falls back to `GetPlayerInfoByGUID()` (line 778–779). That fallback exists and is reasonable. However, if `GetPlayerInfoByGUID` also returns different data (e.g., now returns a struct table instead of positional returns in Midnight), the name extraction at line 782 (`local _, _, _, _, classFile = GetPlayerInfoByGUID(m.guid)`) breaks silently — leader name shows as "-" and class icon is missing.

**Prevention:**
- Verify `SocialQueueUtil_GetRelationshipInfo` existence at addon load time with `if SocialQueueUtil_GetRelationshipInfo then` (already guarded)
- Verify `GetPlayerInfoByGUID` return signature on Midnight; it historically returns `localizedClass, englishClass, race, gender, name, realm, guid` but positional returns can change
- Add debug logging for player info failures: log when leaderName is nil or "-" to detect API signature drift

**Detection:** Quick Join rows show "-" for leader name and have no class icon despite valid group entries existing.

**Sources:** MEDIUM confidence — no public documentation of removal found; guard already present in code.

---

### Pitfall 8: LoadAddOn / pcall LoadAddOn for Blizzard_LFGList No Longer Available

**Phase:** C_LFGList API audit phase

**What goes wrong:** The current code attempts to load `Blizzard_LFGList` and `Blizzard_LookingForGroupUI` via `pcall(LoadAddOn, ...)` at lines 149–150 to get access to `LFGListApplicationDialog_Show`. In Midnight, `LoadAddOn` was deprecated in favor of `C_AddOns.LoadAddOn()`. If `LoadAddOn` is removed, the pcall silently does nothing (returns false), meaning the dialog never loads. Additionally, the Blizzard LFG UI addon may have been renamed or restructured in Midnight.

**Consequences:** `LFGListApplicationDialog_Show` remains nil. The code falls back to direct `C_LFGList.ApplyToGroup()` which bypasses the Blizzard application UI dialog. This works but loses the role/comment selection flow Blizzard provides.

**Prevention:**
- Replace `LoadAddOn(...)` with `C_AddOns.LoadAddOn(...)` (add a compatibility shim: `local LoadAddOn = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn`)
- Verify the correct Midnight name for the Blizzard LFG addon (`Blizzard_LFGList` vs. a new name) by inspecting the live addon list
- Keep the `ApplyToGroup` fallback but ensure it still works in Midnight (role detection via `GetSpecialization` + `GetSpecializationRole` should still be valid)

**Detection:** Join button click opens no dialog; application is submitted silently with auto-detected role instead of showing the Blizzard application UI.

**Sources:** MEDIUM confidence — LoadAddOn/C_AddOns migration is a Midnight API change pattern; Blizzard addon name verification requires live client.

---

### Pitfall 9: C_LFGList.GetApplicationInfo Signature May Have Changed

**Phase:** C_LFGList API audit phase

**What goes wrong:** `C_LFGList.GetApplicationInfo(id)` is called at line 394 to check application status. The current code reads the 2nd and 3rd return values (`appStatus`, `pendingStatus`). If Midnight changed this to return a table or changed positional return order, the status check breaks.

**Consequences:** Join button may always show "Beitreten" even after an application has been submitted (status check returns nil). Or button may be stuck on "Abmelden" after cancellation. This creates a confusing UX but does not crash the addon.

**Prevention:**
- Test the return signature of `GetApplicationInfo` on live Midnight with debug logging
- Add explicit nil checks and log unexpected return shapes: `if type(appStatus) ~= "string" then DBG("GetApplicationInfo unexpected return:", type(appStatus)) end`

**Detection:** Join button state is incorrect after applying to or cancelling from a group.

**Sources:** MEDIUM confidence — no specific Midnight documentation found for this function; the concern is based on the general "table return migration" pattern Blizzard has applied to other C_LFGList functions.

---

## Minor Pitfalls

Small issues that affect specific edge cases.

---

### Pitfall 10: COMBAT_LOG_EVENT_UNFILTERED Removed in Instances

**Phase:** Any (pre-emptive note)

**What goes wrong:** In Midnight, `COMBAT_LOG_EVENT_UNFILTERED` no longer fires for addon code inside instances. EquiFastJoin does not register this event — it is not relevant to the current feature set. However, this is noted because `ProcessResultsAndMaybeShow` already checks `IsInInstance()` and returns early, so the addon is architecturally correct to not rely on combat log data.

**Consequences:** None for EquiFastJoin. Noted only to confirm the existing guard is correct and should be kept.

**Prevention:** No change required. The `if IsInInstance() or IsInGroup() or IsInRaid() then return end` guard at line 805 correctly suppresses all LFG display inside instances.

**Sources:** [WoW 12.0.0 Compatibility — CLEU Removal — Cell addon PR #457](https://github.com/enderneko/Cell/pull/457)

---

### Pitfall 11: Class Icon Atlas Path Changes

**Phase:** UI rendering phase

**What goes wrong:** The current code uses `"Interface\\TargetingFrame\\UI-Classes-Circles"` as the texture path for class icons, with `CLASS_ICON_TCOORDS[classEN]` for texture coordinates. In Midnight, Blizzard may have moved these textures to the Atlas system or renamed the file path. The role icon code already has a dual path (SetAtlas first, texture fallback), but the class icon code only uses the texture path.

**Consequences:** Class icons appear as blank white squares if the texture path is invalid. Not a crash but visually broken.

**Prevention:**
- At addon load, verify the texture loads correctly with a test texture on a hidden frame
- Add an Atlas fallback for class icons using `"classicon-<classname>"` atlas strings if the texture path fails

**Detection:** Class icon textures are blank white in rows.

**Sources:** LOW confidence — no Midnight-specific documentation found for this texture path. The concern is based on general Blizzard art pipeline migration patterns.

---

### Pitfall 12: SavedVariables Schema Migration Risk

**Phase:** Any

**What goes wrong:** Existing users have `EquiFastJoinDB` tables on disk from 11.x. The `CopyDefaults` function correctly adds missing keys with default values but does NOT remove keys that no longer exist. If any key is renamed during the migration (e.g., if a filter key is renamed), old users get the old key with stale data AND the new key with the default, and the old key persists indefinitely.

**Consequences:** Subtle — options a user set persist under the old key name and appear to reset to default, confusing users who had non-default settings.

**Prevention:**
- Do not rename any existing SavedVariables keys; add new keys with new names only
- If a key must be removed, add a one-time migration block in `ADDON_LOADED` that explicitly sets the old key to nil after copying its value to the new key

**Detection:** User reports that settings appear to reset after update; debug print of `EquiFastJoinDB` shows both old and new key names.

**Sources:** Standard WoW addon SavedVariables pattern — HIGH confidence this is correct behavior.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| TOC version update | Addon does not load at all (Pitfall 1) | First commit: bump to 120000 |
| C_LFGList.GetSearchResultInfo usage | activityID is always nil (Pitfall 2) | Canonicalize through helper, remove primary activityID path |
| ApplyToGroup / RefreshResults calls | ADDON_ACTION_BLOCKED if called from tainted path (Pitfall 3) | Keep all protected calls user-initiated or in pcall; never from timers |
| Options panel creation | OptionsSliderTemplate and InterfaceOptions_AddCategory removed (Pitfalls 4, 5) | Replace with modern API; drop legacy fallbacks |
| Classification / filtering | generalPlaystyle field ignored (Pitfall 6) | Add debug logging; verify against live data |
| Quick Join name resolution | SocialQueueUtil_GetRelationshipInfo gone (Pitfall 7) | Guard exists; verify GetPlayerInfoByGUID signature |
| Blizzard dialog loading | LoadAddOn replaced by C_AddOns.LoadAddOn (Pitfall 8) | Add C_AddOns shim |
| Application status tracking | GetApplicationInfo return shape changed (Pitfall 9) | Log return shape on first call; add nil checks |

---

## Summary of Risk Levels

| Area | Risk Level | Confidence | Note |
|------|------------|-----------|------|
| TOC version | CRITICAL (currently broken) | HIGH | Fix first, unblocks everything |
| activityID→activityIDs | HIGH (silent nil) | HIGH | Already partially guarded; audit all references |
| Protected API taint (Secret Values) | HIGH (blocks join) | MEDIUM | Existing pcall guards help; verify inside-instance behavior |
| InterfaceOptions_AddCategory removed | MODERATE (options panel) | MEDIUM | Primary path probably still works; remove dead fallback |
| OptionsSliderTemplate removed | MODERATE (slider widget) | MEDIUM | Needs replacement with manual slider |
| generalPlaystyle classification | MODERATE (hidden results) | MEDIUM | Requires live data verification |
| SocialQueueUtil_GetRelationshipInfo | LOW-MODERATE | LOW | Fallback exists; watch for GetPlayerInfoByGUID changes |
| LoadAddOn→C_AddOns.LoadAddOn | LOW (dialog fallback used) | MEDIUM | Easy shim fix |
| GetApplicationInfo signature | LOW (UX only) | LOW | Defensive coding; no crash risk |
| Class icon texture paths | LOW (visual only) | LOW | Atlas fallback would fix |

---

*Research sources:*
- [Patch 12.0.0/API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [Patch 12.0.0/Planned API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes)
- [Patch 12.0.1/API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.1/API_changes)
- [Patch 11.0.7/API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_11.0.7/API_changes)
- [C_LFGList.GetSearchResultInfo — Warcraft Wiki](https://warcraft.wiki.gg/wiki/API_C_LFGList.GetSearchResultInfo)
- [GetPlaystyleString hardware-protected — WoWUIBugs #195](https://github.com/Stanzilla/WoWUIBugs/issues/195)
- [Premade Groups Filter — GetPlaystyleString taint issue #64](https://github.com/0xbs/premade-groups-filter/issues/64)
- [Midnight Secret Values developer talk — Warcraft Tavern](https://www.warcrafttavern.com/wow/news/wow-midnight-developer-talk-new-secret-values-combat-info-cooldown-manager-combat-addons-nerfed/)
- [CLEU removal in Midnight — Cell addon PR #457](https://github.com/enderneko/Cell/pull/457)
- [Majority of Addon Changes Finalized for Midnight — Wowhead](https://www.wowhead.com/news/majority-of-addon-changes-finalized-for-midnight-pre-patch-whitelisted-spells-379738)
- [Blizzard Relaxing More Addon Limitations in Midnight — Icy Veins](https://www.icy-veins.com/wow/news/blizzard-relaxing-more-addon-limitations-in-midnight/)
