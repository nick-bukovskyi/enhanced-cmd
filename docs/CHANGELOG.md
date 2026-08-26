## [0.15.6] - 2026-08-25

&nbsp;

### Fixed

- Tracked Buffs now appear in the saved position immediately after logging in or switching characters
- Opening Edit Mode is no longer required to correct the Tracked Buffs position

&nbsp;

---

&nbsp;

## [0.15.5] - 2026-08-24

&nbsp;

### Fixed

- Fixed errors that could appear in combat when tracked buffs or bars changed

&nbsp;

---

&nbsp;

## [0.15.4] - 2026-08-23

&nbsp;

### Fixed

- Improved cooldown frame positioning when a character's Edit Mode layout loads

&nbsp;

---

&nbsp;

## [0.15.3] - 2026-08-13

&nbsp;

### Fixed

- Fixed errors that could appear during combat, target changes, or Edit Mode
- Improved cooldown grid stability when Blizzard refreshes the layout

&nbsp;

---

&nbsp;

## [0.15.2] - 2026-08-13

&nbsp;

### Fixed

- Cooldown grids are less likely to shift during combat or when opening Cooldown Manager Settings
- Tracked Buffs stay anchored as rows are added or removed
- Moving or resetting a cooldown frame in Edit Mode now updates its saved position correctly

&nbsp;

---

&nbsp;

## [0.15.1] - 2026-08-12

&nbsp;

### Fixed

- Tracked Buffs no longer jump when a new row appears, combat starts, or settings are opened
- Growth Up and Growth Down now keep the starting row in place
- Essential and Utility cooldowns stay in place when their visible rows or columns change
- Cooldown grids stay positioned after display scale, resolution, or snapped anchor changes

&nbsp;

---

&nbsp;

## [0.15.0] - 2026-07-30

&nbsp;

### Added

- Support for WoW 12.0.7 and 12.1.0
- Hotkey labels and click feedback for trinkets, consumables, and item macros

&nbsp;

### Fixed

- Custom bar colors stay correct when a tracked bar is reused
- Hotkey labels update after changing action bar pages or equipped items
- Tracked bars that grow upward stay anchored when their height changes

&nbsp;

### Changed

- Improved performance when many tracked abilities update together

&nbsp;

---

&nbsp;

## [0.14.3] - 2026-05-10

&nbsp;

### Fixed

- Tracked Buffs keep their starting row or column in place as buffs are added or removed

&nbsp;

---

&nbsp;

## [0.14.2] - 2026-05-10

&nbsp;

### Fixed

- Removing or canceling a custom bar color now restores the default appearance correctly
- Enhanced CDM settings open reliably in Edit Mode
- Click feedback now resizes with cooldown icons
- Bar color commands now reject invalid color values

&nbsp;

---

&nbsp;

## [0.14.1] - 2026-03-27

&nbsp;

### Fixed

- Stack and charge text settings work correctly in WoW 12.1

&nbsp;

---

&nbsp;

## [0.14.0] - 2026-03-14

&nbsp;

### Added

- Horizontal and vertical layouts for Buffs, Essential, and Utility cooldowns
- Vertical layouts fill from top to bottom and can wrap into additional columns
- Edit Mode labels now change to match the selected layout direction

&nbsp;

### Fixed

- Bar color options only appear for tracked bars
- Fixed errors when alerts changed or Edit Mode was closed
- Fixed an error that could block Blizzard menus

&nbsp;

### Changed

- Reorganized Edit Mode settings into clearer groups

&nbsp;

---

&nbsp;

## [0.13.0] - 2026-03-14

&nbsp;

### Added

- Optional yellow click feedback for Essential and Utility cooldown icons
- Click feedback works with regular abilities, macros, and replacement spells
- Separate click feedback settings for Essential and Utility cooldowns
- `/ecdm essential feedback on|off` and `/ecdm utility feedback on|off` commands

&nbsp;

---

&nbsp;

## [0.12.0] - 2026-03-06

&nbsp;

### Added

- Left, Center, and Right alignment for Essential and Utility cooldowns
- Alignment controls in Edit Mode and through `/ecdm essential align` and `/ecdm utility align`

&nbsp;

### Changed

- Blizzard's Icon Position setting is hidden where Enhanced CDM controls the layout

&nbsp;

---

&nbsp;

## [0.11.0] - 2026-03-05

&nbsp;

### Changed

- Enhanced CDM settings now appear beside Blizzard's settings in one combined Edit Mode window

&nbsp;

---

&nbsp;

## [0.10.0] - 2026-03-05

&nbsp;

### Added

- Font size, position, and offset settings for stack and charge text
- Stack text settings for Buffs, Essential, and Utility cooldowns in Edit Mode and through `/ecdm`

&nbsp;

---

&nbsp;

## [0.9.0] - 2026-03-05

&nbsp;

### Added

- Custom start and end colors for individual tracked bars
- Bar color options in the right-click menu
- Commands to add, remove, list, or clear custom bar colors

&nbsp;

---

&nbsp;

## [0.8.0] - 2026-03-03

&nbsp;

### Added

- Horizontal and vertical offset controls for Essential and Utility hotkey text
- `/ecdm essential offsetx`, `/ecdm essential offsety`, and matching Utility commands

&nbsp;

### Changed

- Expanded the available hotkey font sizes and position offsets
- Reordered hotkey settings for easier use

&nbsp;

### Fixed

- Sliders no longer change width when their value text changes

&nbsp;

---

&nbsp;

## [0.7.0] - 2026-03-03

&nbsp;

### Added

- Optional shortened hotkey labels for Essential and Utility cooldowns
- Short labels for common keys such as Page Up, Space, Backspace, Home, Delete, and arrow keys
- Edit Mode and `/ecdm` controls for shortened hotkey text

&nbsp;

### Changed

- Hotkey settings now use Blizzard-style controls and show the current shortening choice in status output

&nbsp;

---

&nbsp;

## [0.6.2] - 2026-03-03

&nbsp;

### Fixed

- Hotkey labels now return after abilities are added, removed, or reordered in Cooldown Manager Settings

&nbsp;

---

&nbsp;

## [0.6.1] - 2026-03-02

&nbsp;

### Fixed

- Fixed a startup error that could occur while reading action bar abilities
- Cooldown frames are found again if Blizzard recreates them during a loading screen

&nbsp;

---

&nbsp;

## [0.6.0] - 2026-03-02

&nbsp;

### Added

- Hotkey labels for Essential and Utility cooldown icons
- Support for action bar abilities, macros, and replacement spells
- Separate show, size, and position settings for Essential and Utility hotkeys
- Edit Mode and `/ecdm` controls for hotkey labels
- Automatic updates after keybind, action bar, or specialization changes

&nbsp;

---

&nbsp;

## [0.5.0] - 2026-03-02

&nbsp;

### Added

- Custom layouts for Tracked Bars
- Vertical and horizontal bar directions
- Static and Dynamic bar layouts with alignment and bars-per-row settings
- Tracked Bar settings in Edit Mode and through `/ecdm bars`

&nbsp;

### Changed

- The `/ecdm` status display now includes Tracked Bar settings

&nbsp;

---

&nbsp;

## [0.4.0] - 2026-03-01

&nbsp;

### Added

- Static layouts, where inactive icons keep their places
- Dynamic layouts, where active icons pack together without gaps
- Layout controls in Edit Mode and through `/ecdm layout`

&nbsp;

---

&nbsp;

## [0.3.0] - 2026-02-28

&nbsp;

### Fixed

- Icon spacing stays correct when using a larger or smaller icon size
- The Edit Mode selection border now matches the full icon grid at every icon size

&nbsp;

---

&nbsp;

## [0.2.2] - 2026-02-28

&nbsp;

### Fixed

- Icon spacing now follows the padding selected in Cooldown Manager Settings
- The layout updates correctly when tracked buffs appear or disappear

&nbsp;

---

&nbsp;

## [0.2.1] - 2026-02-27

&nbsp;

### Added

- Left, Center, and Right alignment for incomplete rows
- Alignment controls in Edit Mode and through `/ecdm align`

&nbsp;

### Changed

- Improved the spacing and sizing of the Edit Mode settings panel

&nbsp;

---

&nbsp;

## [0.2.0] - 2026-02-27

&nbsp;

### Changed

- Enhanced CDM settings now appear only when Tracked Buffs is selected in Edit Mode
- The settings panel now appears below Blizzard's settings
- Growth direction now uses a dropdown menu

&nbsp;

---

&nbsp;

## [0.1.0] - 2026-02-27

&nbsp;

### Added

- Multi-row layouts for Tracked Buffs
- A setting for the number of icons in each row
- Upward and downward growth directions
- Edit Mode and `/ecdm` controls
