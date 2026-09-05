## [Unreleased]

### Added

- An Enhanced CDM logo in the AddOns list

### Fixed

- Invalid saved settings now recover without resetting valid choices or bar colors
- Viewer enhancements now recover when cooldown viewers load late or are recreated
- Click feedback now clears when actions change, icons are reused, or feedback is disabled
- Bar color options now appear in the original context menu without reopening it

---

## [0.15.6] - 2026-08-25

### Fixed

- Tracked Buffs now appear in the saved position immediately after logging in or switching characters
- Opening Edit Mode is no longer required to correct the Tracked Buffs position

---

## [0.15.5] - 2026-08-24

### Fixed

- Fixed errors that could appear in combat when tracked buffs or bars changed

---

## [0.15.4] - 2026-08-23

### Fixed

- Improved cooldown frame positioning when a character's Edit Mode layout loads

---

## [0.15.3] - 2026-08-13

### Fixed

- Fixed errors that could appear during combat, target changes, or Edit Mode
- Improved cooldown grid stability when Blizzard refreshes the layout

---

## [0.15.2] - 2026-08-13

### Fixed

- Cooldown grids are less likely to shift during combat or when opening Cooldown Manager Settings
- Tracked Buffs stay anchored as rows are added or removed
- Moving or resetting a cooldown frame in Edit Mode now updates its saved position correctly

---

## [0.15.1] - 2026-08-12

### Fixed

- Tracked Buffs no longer jump when a new row appears, combat starts, or settings are opened
- Growth Up and Growth Down now keep the starting row in place
- Essential and Utility cooldowns stay in place when their visible rows or columns change
- Cooldown grids stay positioned after display scale, resolution, or snapped anchor changes

---

## [0.15.0] - 2026-07-30

### Added

- Support for WoW 12.0.7 and 12.1.0
- Hotkey labels and click feedback for trinkets, consumables, and item macros

### Fixed

- Custom bar colors stay correct when a tracked bar is reused
- Hotkey labels update after changing action bar pages or equipped items
- Tracked bars that grow upward stay anchored when their height changes

### Changed

- Improved performance when many tracked abilities update together

---

## [0.14.3] - 2026-05-10

### Fixed

- Tracked Buffs keep their starting row or column in place as buffs are added or removed

---

## [0.14.2] - 2026-05-10

### Fixed

- Removing or canceling a custom bar color now restores the default appearance correctly
- Enhanced CDM settings open reliably in Edit Mode
- Click feedback now resizes with cooldown icons
- Bar color commands now reject invalid color values

---

## [0.14.1] - 2026-03-27

### Fixed

- Stack and charge text settings work correctly in WoW 12.1

---

## [0.14.0] - 2026-03-14

### Added

- Horizontal and vertical layouts for Buffs, Essential, and Utility cooldowns
- Vertical layouts fill from top to bottom and can wrap into additional columns
- Edit Mode labels now change to match the selected layout direction

### Fixed

- Bar color options only appear for tracked bars
- Fixed errors when alerts changed or Edit Mode was closed
- Fixed an error that could block Blizzard menus

### Changed

- Reorganized Edit Mode settings into clearer groups

---

## [0.13.0] - 2026-03-14

### Added

- Optional yellow click feedback for Essential and Utility cooldown icons
- Click feedback works with regular abilities, macros, and replacement spells
- Separate click feedback settings for Essential and Utility cooldowns
- `/ecdm essential feedback on|off` and `/ecdm utility feedback on|off` commands

---

## [0.12.0] - 2026-03-06

### Added

- Left, Center, and Right alignment for Essential and Utility cooldowns
- Alignment controls in Edit Mode and through `/ecdm essential align` and `/ecdm utility align`

### Changed

- Blizzard's Icon Position setting is hidden where Enhanced CDM controls the layout

---

## [0.11.0] - 2026-03-05

### Changed

- Enhanced CDM settings now appear beside Blizzard's settings in one combined Edit Mode window

---

## [0.10.0] - 2026-03-05

### Added

- Font size, position, and offset settings for stack and charge text
- Stack text settings for Buffs, Essential, and Utility cooldowns in Edit Mode and through `/ecdm`

---

## [0.9.0] - 2026-03-05

### Added

- Custom start and end colors for individual tracked bars
- Bar color options in the right-click menu
- Commands to add, remove, list, or clear custom bar colors

---

## [0.8.0] - 2026-03-03

### Added

- Horizontal and vertical offset controls for Essential and Utility hotkey text
- `/ecdm essential offsetx`, `/ecdm essential offsety`, and matching Utility commands

### Changed

- Expanded the available hotkey font sizes and position offsets
- Reordered hotkey settings for easier use

### Fixed

- Sliders no longer change width when their value text changes

---

## [0.7.0] - 2026-03-03

### Added

- Optional shortened hotkey labels for Essential and Utility cooldowns
- Short labels for common keys such as Page Up, Space, Backspace, Home, Delete, and arrow keys
- Edit Mode and `/ecdm` controls for shortened hotkey text

### Changed

- Hotkey settings now use Blizzard-style controls and show the current shortening choice in status output

---

## [0.6.2] - 2026-03-03

### Fixed

- Hotkey labels now return after abilities are added, removed, or reordered in Cooldown Manager Settings

---

## [0.6.1] - 2026-03-02

### Fixed

- Fixed a startup error that could occur while reading action bar abilities
- Cooldown frames are found again if Blizzard recreates them during a loading screen

---

## [0.6.0] - 2026-03-02

### Added

- Hotkey labels for Essential and Utility cooldown icons
- Support for action bar abilities, macros, and replacement spells
- Separate show, size, and position settings for Essential and Utility hotkeys
- Edit Mode and `/ecdm` controls for hotkey labels
- Automatic updates after keybind, action bar, or specialization changes

---

## [0.5.0] - 2026-03-02

### Added

- Custom layouts for Tracked Bars
- Vertical and horizontal bar directions
- Static and Dynamic bar layouts with alignment and bars-per-row settings
- Tracked Bar settings in Edit Mode and through `/ecdm bars`

### Changed

- The `/ecdm` status display now includes Tracked Bar settings

---

## [0.4.0] - 2026-03-01

### Added

- Static layouts, where inactive icons keep their places
- Dynamic layouts, where active icons pack together without gaps
- Layout controls in Edit Mode and through `/ecdm layout`

---

## [0.3.0] - 2026-02-28

### Fixed

- Icon spacing stays correct when using a larger or smaller icon size
- The Edit Mode selection border now matches the full icon grid at every icon size

---

## [0.2.2] - 2026-02-28

### Fixed

- Icon spacing now follows the padding selected in Cooldown Manager Settings
- The layout updates correctly when tracked buffs appear or disappear

---

## [0.2.1] - 2026-02-27

### Added

- Left, Center, and Right alignment for incomplete rows
- Alignment controls in Edit Mode and through `/ecdm align`

### Changed

- Improved the spacing and sizing of the Edit Mode settings panel

---

## [0.2.0] - 2026-02-27

### Changed

- Enhanced CDM settings now appear only when Tracked Buffs is selected in Edit Mode
- The settings panel now appears below Blizzard's settings
- Growth direction now uses a dropdown menu

---

## [0.1.0] - 2026-02-27

### Added

- Multi-row layouts for Tracked Buffs
- A setting for the number of icons in each row
- Upward and downward growth directions
- Edit Mode and `/ecdm` controls
