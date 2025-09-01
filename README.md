# EquiFastJoin

A lightweight World of Warcraft (Retail) addon that surfaces Quick Join (friends/guild/community) suggestions and relevant LFG listings in a compact, filterable list with one‑click joining.

Highlights
- Quick Join first: Only shows real Quick Join suggestions (friends/guild/community) by default.
- Clean list UI: Leader name (class colored), activity (Dungeon/Raid/M+ with level), entry title/note.
- Role icons: Shows remaining open roles (Tank/Healer/DPS) for LFG results.
- One‑click join: Opens Blizzard’s application dialog for 100% reliability; falls back to direct apply when needed.
- Button states: Beitreten ↔ Abmelden, auto‑updates on application status changes.
- Filters: Dungeons, Raids/Schlachtzüge, Mythic+, PvP, Benutzerdefiniert/Quest.
- Options: Only Quick Join, Auto‑open on Quick Join, Sound, Toast, Scale, Lock frame.

Installation
- Unzip so the folder structure is: Interface/AddOns/EquiFastJoin/
- Files should include: `EquiFastJoin.toc`, `EquiFastJoin.lua`, `Icons/EFJ-ICON.TGA`.
- Restart or reload UI (`/reload`).

Usage
- Slash: `/efj test|show|hide|options|debug on|off`
- Options: Game Menu → Options → AddOns → EquiFastJoin.
- Default behavior: Shows only Quick Join suggestions. Toggle “Nur Schnellbeitritt anzeigen” to also allow general LFG results.

Filters (what appears in the list)
- Dungeons, Raids/Schlachtzüge, Mythic+, PvP, Benutzerdefiniert/Quest.
- Color coding for activity: M+ (green), Raids (orange), Dungeons (blue), PvP (red), Custom (gray).

Buttons & States
- Beitreten: Opens Blizzard’s LFG application dialog (preferred). If the dialog can’t load, applies directly with your current role selection.
- Abmelden: Cancels your application. Button states update on the fly using `LFG_LIST_APPLICATION_STATUS_UPDATED`.

Quick Join specifics
- Only eligible Quick Join entries that map to an actual LFG listing (with `lfgListID`) are listed, ensuring always‑joinable suggestions.
- The view auto‑refreshes (every few seconds) and hides itself when no suggestions remain.

Troubleshooting
- No icons or entries: Ensure there are Quick Join suggestions or enable general LFG results in options.
- Join button not changing: Some realms/UI lag can delay status events. The addon polls briefly after using the Blizzard dialog.
- Icons: `Icons/EFJ-ICON.TGA` must be uncompressed TGA, preferably 32‑bit with alpha; sizes like 64×64 or 128×128 work well.

Packaging for CurseForge
- Include: `EquiFastJoin.toc`, `EquiFastJoin.lua`, `Icons/EFJ-ICON.TGA`, `README.md`, `CHANGELOG.md`, `LICENSE`.
- Zip the folder `EquiFastJoin/` (do not zip only the files).
- Provide project icon, screenshots and a short/long description on the project page.

Notes
- Retail API target; TOC Interface is kept up to date for 11.2.x.
- Localization: DE notes are included in TOC. More locales can be added later.

Feedback & Issues
- Please report issues with steps to reproduce and screenshots when possible.
