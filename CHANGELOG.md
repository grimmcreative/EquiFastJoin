# Changelog

## 1.8.2
- Fix taint: remove all calls to `C_LFGList.Search()` to eliminate `[ADDON_ACTION_BLOCKED] ... 'Search()'` errors.
- Join/cancel safety: disallow Join/Cancel while in combat; show a user-facing message instead.
- UI safety: stop programmatically opening Blizzard LFG application dialog; remove FriendsFrame toggle from banner button.
- Refresh policy: only call `C_LFGList.RefreshResults()` out of combat; keep periodic updates event-driven.

## 1.8.1
- Taint mitigation: avoid ApplyToGroup from timers; remove programmatic opening of Blizzard application dialog to prevent taint.
- Combat lockdown: block Join/Cancel while in combat to avoid protected actions.
- Combat guards: block opening Options and Friends toggle in combat with user-facing hint.
- LFG API: remove all calls to `C_LFGList.Search()`; only use safe `RefreshResults()` out of combat.
- Globals hygiene: stop reassigning `SlashCmdList` to reduce taint risk.

## 1.8.0
- Quick Join gating: show only LFG results that also appear as Quick Join suggestions; hide generic LFG when none are available.
- Classification helpers: robust detection of M+, Raid, Dungeon, PvP, and Custom via activity info and key level.
- Filters rework: rely on classification; unknown categories are hidden by default.
- Colors: derive category color from the new classification.
- Deduplication: avoid duplicate Quick Join entries per LFG listing.
- Stability: ignore delisted results; require valid result data for display.
- Options/UI: remove "Nur Schnellbeitritt anzeigen"; reposition "Bei Schnellbeitritt auto-öffnen".
- Refresh flow: always run initial search and periodic refresh; correct INIT/TICK handling.
- Slash: "show" now uses Quick Join list only.

## 1.7.9
- Quick Join focus: show only real Quick Join (friends/guild/community) suggestions by default, with optional LFG results.
- Event-driven updates: auto-open on Quick Join suggestions; periodic cleanup and hide when empty.
- Join flow: prefer Blizzard application dialog; fallback to direct apply; robust status updates.
- Button states: Beitreten ↔ Abmelden; invited → Eingeladen (disabled); reset on decline/timeout/cancel.
- Filters: Dungeons, Raids/Schlachtzüge, Mythic+, PvP, Benutzerdefiniert/Quest.
- UI: activity with color coding and M+ level, title/note under activity.
- Role icons: show remaining roles (Tank/Healer/DPS) for LFG results.
- Options: Only Quick Join, Auto-open on Quick Join, Sound, Toast, Scale, Lock frame.
- Slash: /efj test|show|hide|options|debug on|off.
- AddOn icon via TOC: Icons/EFJ-ICON.TGA.
