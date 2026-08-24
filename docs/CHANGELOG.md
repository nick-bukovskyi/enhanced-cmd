## [0.15.5] - 2026-08-24

&nbsp;

### Fixed

- Fixed Enhanced CDM tainting Blizzard's secure aura processing when tracked buff or bar visibility changed
- Fixed resulting secret-value errors in `TableUtil.tContains` and forbidden-table errors in `CheckAuraAddedAlertTriggers` during combat

&nbsp;

---

&nbsp;

## [0.15.4] - 2026-08-23

&nbsp;

### Fixed

- Tracked Buffs and the other cooldown grids now rebuild their anchor positions after Blizzard loads the active character's Edit Mode layout
- Cooldown grids no longer remain shifted after logging in or switching characters until Edit Mode is opened

&nbsp;

---

&nbsp;

## [0.15.3] - 2026-08-13

&nbsp;

### Fixed

- Fixed Lua taint warnings and secret aura errors introduced in 0.15.2 during combat, target changes, and Edit Mode
- Cooldown grids now resist Blizzard size resets without modifying Blizzard's secure layout state

&nbsp;

---

&nbsp;

## [0.15.2] - 2026-08-13

&nbsp;

### Fixed

- Cooldown grids retain their custom dimensions during Blizzard layout refreshes, preventing occasional position drift in combat or when opening Cooldown Manager Settings
- Tracked Buffs remain anchored at every row count through repeated aura and visibility updates
- Moving, resetting, or switching a cooldown viewer in Edit Mode establishes the correct new growth anchor

&nbsp;

---

&nbsp;

## [0.15.1] - 2026-08-12

&nbsp;

### Fixed

- Tracked Buffs no longer jump when a new row appears, combat starts, or Cooldown Manager Settings opens
- Growth Up keeps the first row in place and adds new rows above it, while Growth Down adds new rows below it
- Essential and Utility cooldown grids stay in place when their visible rows or columns change
- Cooldown grids remain correctly positioned after UI scale, display size, or snapped Edit Mode anchor changes

&nbsp;

---

&nbsp;

## [0.15.0] - 2026-07-30

&nbsp;

### Added

- Support for WoW 12.0.7 and the upcoming WoW 12.1.0 client
- Hotkey labels and the yellow pressed glow now work with Cooldown Manager trinkets, consumables, and item macros

&nbsp;

### Fixed

- Custom bar gradients stay correct when Cooldown Manager reuses an existing bar, including the new WoW 12.1 update behavior
- Hotkey labels update after changing action bar pages or equipped items
- Tracked bars set to grow upward stay anchored instead of shifting when the list changes height

&nbsp;

### Changed

- Improved performance when many tracked abilities update at once
- Reduced unnecessary layout work for fixed tracked buff and bar layouts
- Reduced hotkey lookup work when Cooldown Manager adds or refreshes several icons together

&nbsp;

---

&nbsp;

## [0.14.3] - 2026-05-10

### Fixed

- Tracked Buffs grid growth now preserves the anchor row/column when adding or removing tracked buffs

&nbsp;

---

&nbsp;

## [0.14.2] - 2026-05-10

### Fixed

- Bar gradients now reset stale visuals when a per-bar color is removed, cleared, canceled, or a bar frame is reused
- Edit Mode dialog hooks now install even when Blizzard creates `EditModeSystemSettingsDialog` after Enhanced CDM's initial setup
- Click feedback glow now resizes when CDM icon size changes instead of keeping the first cached overlay size

&nbsp;

### Changed

- Edit Mode addon panels now use local widget references instead of creating `EnhancedCDM*` globals
- Bar gradient slash commands now reject out-of-range RGB values and trailing arguments
- Test runner now loads `EditMode.lua` with expanded WoW stubs for hook and panel regression coverage

&nbsp;

---

&nbsp;

## [0.14.1] - 2026-03-27

### Fixed

- Stack count text not updating size or position after WoW 12.1 update -- Blizzard renamed `ChargeCount` to `Applications` Frame with nested `.Applications` FontString

&nbsp;

---

&nbsp;

## [0.14.0] - 2026-03-14

### Added

- Blizzard Orientation setting (Horizontal/Vertical) now works for Buffs, Essential, and Utility viewers
  - Vertical orientation fills icons top-to-bottom, wrapping to new columns
  - Alignment adjusts partial last column vertically (Top/Center/Bottom)
  - Grid calculator supports both orientations with correct sizing
- Orientation-aware Edit Mode panel labels
  - Buffs: "# Rows" ↔ "# Columns", Growth "Down/Up" ↔ "Right/Left", Alignment "Left/Center/Right" ↔ "Top/Center/Bottom"
  - Essential/Utility: Alignment labels swap to "Top/Center/Bottom" in vertical mode
  - Labels update dynamically when Blizzard Orientation setting changes

&nbsp;

### Fixed

- Gradient Colors context menu appearing on all cooldown items -- now restricted to bar entries only
- Secret value taint errors (isActive, secureexecuterange) when adding alerts or exiting Edit Mode -- replaced EventRegistry callbacks with per-viewer RefreshLayout hooks to avoid tainting the callback table
- ADDON_ACTION_BLOCKED taint from replacing MenuUtil.CreateContextMenu -- bar gradient context menu now uses hooksecurefunc post-hook with selective reopen instead of global function replacement

&nbsp;

### Changed

- Edit Mode settings panels reorganized into logical groups with left-aligned section headers
  - Buffs panel: "Grid" group (Layout, Per Row, Growth, Alignment) and "Stacks" group
  - Bars panel: "Grid" group (Orientation, Layout, Alignment, Per Row)
  - Essential/Utility panels: ungrouped (Alignment, Click Feedback), "Keybinds" group (Show, Shorten, Font Size, Position, offsets), "Stacks" group

&nbsp;

---

&nbsp;

## [0.13.0] - 2026-03-14

### Added

- Click feedback for Essential and Utility cooldown icons -- when a keybind is pressed, the corresponding CDM icon shows a yellow glow border matching Blizzard's action bar pushed effect (key-down to key-up timing)
  - Detection via SetButtonState hooks on action bar buttons -- event-driven, zero polling, combat-safe
  - Resolves spells through macros and spell overrides
  - Per-viewer toggle: separate enable/disable for Essential and Utility
  - "Click Feedback" checkbox in Edit Mode panels
- /ecdm essential feedback on|off and /ecdm utility feedback on|off slash commands

&nbsp;

---

&nbsp;

## [0.12.0] - 2026-03-06

### Added

- Icon alignment for Essential and Utility Cooldowns -- Left/Center/Right alignment setting matching the Buffs panel
  - Icons are positioned in a single row with alignment offset relative to the full viewer width
  - SetPoint hooks enforce alignment positions and survive Blizzard repositioning
  - Alignment dropdown appears as the first setting in the Essential/Utility Edit Mode panels
- /ecdm essential align <left|center|right> and /ecdm utility align slash commands
- Blizzard's "Icon Position" setting is now hidden for Essential and Utility viewers (previously only hidden for Buffs and Bars)

&nbsp;

---

&nbsp;

## [0.11.0] - 2026-03-05

### Changed

- Edit Mode settings panels now embed into Blizzard's dialog -- panels appear as a left column alongside the native settings dialog with a shared border and vertical divider, instead of floating as separate windows
- Panels automatically unembed and restore the dialog's original border when closed or when the dialog hides

&nbsp;

---

&nbsp;

## [0.10.0] - 2026-03-05

### Added

- Stack/charge count text customization for Essential, Utility, and Buffs viewers
  - Adjustable font size, anchor position, and X/Y offsets for Blizzard's native ChargeCount text
  - Settings integrated into existing Edit Mode panels with visual divider
- /ecdm essential stacks, /ecdm utility stacks, /ecdm buffs slash commands for stack text settings

&nbsp;

---

&nbsp;

## [0.9.0] - 2026-03-05

### Added

- Per-bar gradient colors for Tracked Bars -- each bar can have its own start/end color gradient
  - Colors stored per cooldownID in SavedVariables, persist across sessions
  - Gradient applied via SetGradient("HORIZONTAL", startColor, endColor) on the StatusBar texture
  - Gradients survive combat, ability triggers, CDM settings changes, and loading screens
- Color picker options in bar right-click context menu (Cooldown Settings panel)
  - "Set Start Color" and "Set End Color" open WoW's native ColorPickerFrame with live preview
  - "Remove Gradient" option appears when a gradient is configured
  - Context menu items auto-appear on any bar entry with a cooldownID
- /ecdm bars gradient slash command namespace
  - /ecdm bars gradient -- list all configured gradients
  - /ecdm bars gradient <id> <sR> <sG> <sB> <eR> <eG> <eB> -- set gradient by cooldownID
  - /ecdm bars gradient <id> off -- remove gradient (revert to default orange)
  - /ecdm bars gradient clear -- remove all gradients

&nbsp;

---

&nbsp;

## [0.8.0] - 2026-03-03

### Added

- Horizontal/Vertical offset sliders for Essential and Utility hotkey text positioning
  - Fine-tune keybind text placement with -40 to +40 pixel offsets per axis
  - Offsets reset to position defaults when Position is changed
  - Sliders conditional on "Show Keybinds" being enabled
- /ecdm essential offsetx and /ecdm essential offsety slash commands (same for utility)

&nbsp;

### Changed

- Edit Mode hotkey panels reordered: Show > Shorten > Font Size > Position > Horizontal > Vertical
- Font size range expanded to 6-32 (was 8-20)
- Offset range expanded to -40..40 (was -20..20)

&nbsp;

### Fixed

- Slider width jitter when value text changes -- value labels now use fixed width

&nbsp;

---

&nbsp;

## [0.7.0] - 2026-03-03

### Added

- Shorten Keybinds Text toggle for Essential and Utility hotkey overlays (independently configurable)
  - When enabled (default), abbreviates key names compactly (e.g. SHIFT-PAGEUP > SPU)
  - When disabled, displays full unabbreviated key names
- Additional key abbreviations: PAGEUP/PAGEDOWN, SPACEBAR, BACKSPACE, CAPSLOCK, INSERT, DELETE, HOME, and arrow keys
- "Shorten Keybinds Text" checkbox in Edit Mode panels for Essential and Utility hotkeys
- /ecdm essential shorten|noshorten and /ecdm utility shorten|noshorten slash commands
- Tests for all new key abbreviations

&nbsp;

### Changed

- Edit Mode hotkey panels use [checkbox] [label] layout for Show Keybinds row (Blizzard style)
- Status output now includes text shortening state

&nbsp;

---

&nbsp;

## [0.6.2] - 2026-03-03

### Fixed

- Keybinding overlays not appearing on Essential/Utility icons after adding, removing, or reordering cooldowns in Blizzard's CDM settings

&nbsp;

---

&nbsp;

## [0.6.1] - 2026-03-02

### Fixed

- Crash in GetHotkeyText() when C_ActionBar API is unavailable during override spell resolution
- Viewer recreation during polling window now correctly detected and re-hooked

&nbsp;

### Changed

- Removed unnecessary RefreshAllHotkeys() from CDM settings change callback
- Deduplicated RefreshAllHotkeys() calls when multiple hotkey viewers discovered simultaneously
- Extracted shared HookViewerChild(), InstallViewerHooks(), SortByLayoutIndex() helpers in Core
- Extracted shared AnchorPanelToDialog(), HideAllPanels() helpers and hoisted layout constants in EditMode
- SetupEditMode now follows local function + ns assignment convention
- Removed unused err captures from pcall() calls

&nbsp;

---

&nbsp;

## [0.6.0] - 2026-03-02

### Added

- Keybinding text overlay for Essential and Utility cooldown icons
  - Displays the configured hotkey from action bars on each cooldown icon
  - Only shows for abilities placed on action bars with a keybinding assigned
  - Resolves talent overrides and spell replacements via C_Spell.GetOverrideSpell
  - Compact format: SHIFT > S, CTRL > C, ALT > A (e.g. "S3", "CF1")
  - Styled like Blizzard's stack count text (Arial Narrow, outline)
- Separate hotkey settings for Essential and Utility cooldowns (independently configurable)
  - Show/hide toggle, 9-position anchor, configurable font size (8-20) per viewer
- Separate Edit Mode panels for Essential and Utility cooldowns with checkbox + conditional settings
- /ecdm essential and /ecdm utility slash command namespaces with show, hide, position, and fontsize subcommands
- Auto-refresh on keybinding changes, action bar changes, and specialization changes

&nbsp;

---

&nbsp;

## [0.5.0] - 2026-03-02

### Added

- Tracked Bars support -- configurable layout for the BuffBarCooldownViewer (Tracked Bars)
  - Orientation: Vertical (single column, default) or Horizontal (multi-row grid)
  - Layout mode: Static or Dynamic, same behavior as icon layout
  - Conditional alignment: Down/Up in vertical mode, Left/Center/Right in horizontal mode (dynamic only)
  - Bars per row: Configurable 1-40, applies in horizontal mode only
- Separate Edit Mode panel for Tracked Bars with conditional row visibility
- /ecdm bars slash command namespace with orientation, layout, align, and perrow subcommands
- Dual-viewer init polling -- finds both icon and bar viewers independently
- CooldownViewerSettings.OnDataChanged now triggers relayout for both viewers
- Blizzard's "Icon Direction" setting hidden for both Tracked Buffs and Tracked Bars

&nbsp;

### Changed

- Mixin hooks (OnAcquireItemFrame, SetCooldownID, ClearCooldownID) now dispatch to the correct viewer
- /ecdm status output now shows both icon and bar settings
- TryInit() handles recreation of both viewers across loading screens

&nbsp;

---

&nbsp;

## [0.4.0] - 2026-03-01

### Added

- Layout mode setting -- Static or Dynamic layout via dropdown, slash command, and Edit Mode panel
  - Static (default): Icons keep their pre-configured grid positions; inactive icons leave gaps
  - Dynamic: Active icons pack tightly with no gaps, re-aligned per alignment setting
- /ecdm layout <static|dynamic> slash command
- Layout dropdown in Edit Mode panel

&nbsp;

---

&nbsp;

## [0.3.0] - 2026-02-28

### Fixed

- Icon spacing at non-100% Icon Size -- SetPoint offsets were double-scaled by child frame scale
- Edit Mode selection border now correctly matches icon grid at all Icon Size values

&nbsp;

### Removed

- Dead duplicate ShouldShowSetting patch in EditMode (Core.lua patch already covers it)
- Unused _arOrigLayout reference (stored but never read)
- Redundant ScheduleLayout orphan cleanup loop (already handled by TryInit wipe)
- Redundant CooldownViewerSettings.NotifyListeners hook (EventRegistry callback covers it)

&nbsp;

---

&nbsp;

## [0.2.2] - 2026-02-28

### Fixed

- Icon spacing now uses Blizzard's native iconPadding instead of hardcoded value -- respects CDM padding slider
- Added Show/Hide hooks on icon frames for full Blizzard trigger coverage (catches SetIsActive > SetShown visibility changes from UNIT_AURA, SPELL_UPDATE_COOLDOWN, PLAYER_TOTEM_UPDATE events)
- Replaced SetSize hook with Layout() override to neutralize Blizzard's GridLayoutFrame engine

&nbsp;

---

&nbsp;

## [0.2.1] - 2026-02-27

### Added

- Align setting -- Left, Center, or Right alignment for incomplete last rows
- /ecdm align <left|center|right> slash command
- Align dropdown in Edit Mode panel

&nbsp;

### Changed

- Slider value text now uses GameFontHighlightSmall (smaller, yellow/gold -- matches Tracked Buffs style)
- Growth and Align dropdowns dynamically match slider width
- "Growth Direction" label shortened to "Growth"
- Panel height increased for proper bottom padding

&nbsp;

---

&nbsp;

## [0.2.0] - 2026-02-27

### Changed

- Edit Mode panel now only appears when "Tracked Buffs" frame is selected (was: appeared on any Edit Mode entry)
- Edit Mode panel anchors below Blizzard's settings dialog instead of floating independently
- Growth direction setting changed from toggle button to dropdown select

&nbsp;

---

&nbsp;

## [0.1.0] - 2026-02-27

### Added

- Multi-row grid layout for BuffIconCooldownViewer (Tracked Buffs)
- Configurable icons per row (1-40) via /ecdm rows <n>
- Growth direction (UP/DOWN) via /ecdm grow <direction>
- Edit Mode floating settings panel with slider and toggle
- Combat safety -- defers layout during InCombatLockdown, flushes on PLAYER_REGEN_ENABLED
- Debounced layout via C_Timer.NewTimer(0, ...) to run after Blizzard's layout pass
- Per-frame SetPoint hook to prevent Blizzard from overriding grid positions
- Viewer recreation detection across loading screens
- Scoped CooldownViewerItemDataMixin hooks (only trigger for BuffIconCooldownViewer children)
