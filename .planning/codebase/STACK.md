# Technology Stack

**Analysis Date:** 2026-04-14

## Languages

**Primary:**
- Lua 5.1+ - Entire addon codebase (`EquiFastJoin.lua`)

**Secondary:**
- YAML - CI/CD configuration (`.github/workflows/release.yml`)

## Runtime

**Environment:**
- World of Warcraft (Retail) 11.2.0 and later
- Blizzard AddOn Runtime (embedded Lua VM)

**Target Platform:**
- Windows/macOS via Battle.net client
- World of Warcraft Retail (current expansion)

## Frameworks

**Core:**
- Blizzard UI Framework - Widget system, frame creation, event handling
  - Built-in Lua API via `CreateFrame()`, font strings, textures, buttons
  - Status: Used throughout for all UI rendering

**API/Integration:**
- LFG List API (`C_LFGList.*`) - Group listing and joining
- Social Queue API (`C_SocialQueue.*`) - Quick Join integration
- Chat/UI APIs - Slash commands, tooltips, debug output

## Key Dependencies

**Critical (Built-in Blizzard APIs):**
- `C_LFGList` - GetActivityInfoTable, GetSearchResults, GetSearchResultInfo, ApplyToGroup, CancelApplication, RefreshResults
- `C_SocialQueue` - GetAllGroups, GetGroupMembers, GetGroupQueues
- `C_Timer` - Timer callbacks (NewTicker, After)
- `UnitInfo`/`GetPlayerInfoByGUID` - Character class detection

**UI Rendering:**
- `UIParent` - Frame attachment point
- `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UICheckButtonTemplate` - Stock UI templates
- `BackdropTemplate`, `UIPanelScrollFrameTemplate` - Container templates
- `OptionsSliderTemplate` - Slider UI for settings
- `GameFontNormalLarge`, `GameFontHighlight`, `GameFontNormalSmall` - Font strings

**Audio:**
- `PlaySound()` / `SOUNDKIT` - UI sound playback

**Localization:**
- `RAID_CLASS_COLORS` - Color mapping for character classes
- `CLASS_ICON_TCOORDS` - Texture coordinates for role icons

## Configuration

**Persistent Storage:**
- `EquiFastJoinDB` - Global table saved by World of Warcraft
- SavedVariables declaration in TOC: `EquiFastJoinDB`
- Location: `WoW_Installation/WTF/Account/*/SavedVariables/EquiFastJoin.lua`

**Settings Schema (`EquiFastJoinDB`):**
```lua
{
  debug = boolean,
  lastDismissSignature = string,
  scale = float (0.75-1.50),
  lockFrame = boolean,
  width = number (pixels),
  height = number (pixels),
  point = string (frame anchor point),
  rel = string (relative frame),
  x = number (x offset),
  y = number (y offset),
  showRaids = boolean,
  showDungeons = boolean,
  showMythicPlus = boolean,
  showPvP = boolean,
  showCustom = boolean,
  openOnQuickJoin = boolean,
  playSound = boolean,
  showToast = boolean
}
```

**Configuration Entry Point:**
- `EquiFastJoin.toc` - AddOn metadata and manifest
- Defaults defined at line 11-30 in `EquiFastJoin.lua` (DEFAULTS table)

## Platform Requirements

**Development:**
- Text editor (Lua syntax highlighting recommended)
- World of Warcraft client (retail branch)
- Git for version control

**Production:**
- World of Warcraft Retail 11.2.0 or later
- Interface version 110200+
- Approximately 200KB total addon size (single Lua file + small media assets)

## Build & Packaging

**Distribution Format:**
- Folder-based: `Interface/AddOns/EquiFastJoin/`
- Contents:
  - `EquiFastJoin.toc` - Addon manifest
  - `EquiFastJoin.lua` - Main addon code (1016 lines)
  - `Media/` - Asset directory with TGA images

**Media Assets:**
- `efjicon.tga` - Standard addon icon (64x64, 32-bit RGBA)
- `efjicon256x256.tga` - High-res icon variant
- `efjicon64x64.tga` - Compact icon variant
- `LogoAddon.tga` - Referenced in TOC as IconTexture
- `efjwebicon@4x.png` - Web/marketplace preview

**CI/CD:**
- GitHub Actions via `.github/workflows/release.yml`
- Triggers: Git tags (v*) or manual workflow dispatch
- Workflow: Extract changelog, create GitHub Release with auto-generated notes

## Interface Versioning

**TOC Interface Header:**
- Current: `110200` (WoW Retail 11.2)
- Maintained for each major patch
- Located at line 1 of `EquiFastJoin.toc`

---

*Stack analysis: 2026-04-14*
