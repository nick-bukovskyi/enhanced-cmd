# Enhanced CDM

Enhances World of Warcraft's built-in Cooldown Manager (CDM) with configurable layouts, keybind overlays, and visual customizations. All settings integrate directly into Blizzard's Edit Mode UI, seamlessly extending the native CDM experience. No new frames created — hooks and repositions Blizzard's existing ones.

## Features

### Tracked Buffs (Icons)

- **Multi-row grid** — Configure icons per row (1–40) instead of a single row
- **Growth direction** — Grid grows up or down from the anchor
- **Alignment** — Left, center, or right alignment for incomplete rows
- **Layout modes** — Static (gaps preserved) or Dynamic (tightly packed)
- **Stack text customization** — Adjustable font size, position, and offsets for charge count text

### Tracked Bars

- **Orientation** — Vertical (single column) or Horizontal (multi-row grid)
- **Layout modes** — Static or Dynamic, same behavior as icon layout
- **Alignment** — Down/Up in vertical mode, Left/Center/Right in horizontal mode
- **Bars per row** — Configurable for horizontal mode
- **Per-bar color gradients** — Set custom start/end gradient colors on individual bars via the right-click context menu or slash commands

### Essential & Utility Cooldowns

- **Icon alignment** — Left, center, or right alignment (replaces Blizzard's Icon Position setting)
- **Keybind text overlay** — Displays the configured hotkey from your action bars on each cooldown icon
- **Compact format** — Modifier keys shortened (SHIFT → S, CTRL → C, ALT → A) with optional full-text mode
- **Independent settings** — Separate alignment, show/hide, position, font size, and text shortening for Essential and Utility
- **9-position anchor** — Place keybind text at any corner, edge, or center of the icon
- **Fine-tune offsets** — Horizontal and vertical pixel offsets for precise placement
- **Stack text customization** — Same charge count text options as Tracked Buffs

### Edit Mode Integration

All settings are accessible through Edit Mode panels that appear when selecting the corresponding CDM frame:

- **Tracked Buffs** — Icons per row, growth, alignment, layout mode, stack text
- **Tracked Bars** — Orientation, layout, alignment, bars per row
- **Essential Cooldowns** — Alignment, keybind show/hide, shorten, font size, position, offsets, stack text
- **Utility Cooldowns** — Same options as Essential, configured independently

Panels embed into Blizzard's Edit Mode settings dialog with a shared border.

### General

- **Combat safe** — Reflows the grid mid-fight as buffs appear or expire
- **Viewer recreation handling** — Re-hooks automatically across loading screens
- **Auto-refresh** — Keybind text updates on keybinding changes, action bar changes, and specialization changes

## Slash Commands

Use `/ecdm` or `/enhancedcdm`.

### Tracked Buffs (Icons)

| Command | Description |
|---|---|
| `/ecdm` | Show current settings and command list |
| `/ecdm rows <1-40>` | Set icons per row |
| `/ecdm grow <up\|down>` | Set growth direction |
| `/ecdm align <left\|center\|right>` | Set row alignment |
| `/ecdm layout <static\|dynamic>` | Set layout mode |
| `/ecdm buffs` | Show buffs stack text settings |
| `/ecdm buffs position <pos>` | Set stack text position |
| `/ecdm buffs fontsize <6-32>` | Set stack text font size |
| `/ecdm buffs offsetx <-40..40>` | Stack text horizontal offset |
| `/ecdm buffs offsety <-40..40>` | Stack text vertical offset |

### Tracked Bars

| Command | Description |
|---|---|
| `/ecdm bars` | Show bars settings and commands |
| `/ecdm bars orientation <vertical\|horizontal>` | Set bar orientation |
| `/ecdm bars layout <static\|dynamic>` | Set bar layout mode |
| `/ecdm bars align <up\|down\|left\|center\|right>` | Set bar alignment |
| `/ecdm bars perrow <1-8>` | Set bars per row (horizontal mode) |
| `/ecdm bars gradient` | List configured bar gradients |
| `/ecdm bars gradient <id> <sR> <sG> <sB> <eR> <eG> <eB>` | Set bar gradient by cooldownID |
| `/ecdm bars gradient <id> off` | Remove gradient from a bar |
| `/ecdm bars gradient clear` | Remove all bar gradients |

### Essential & Utility Hotkeys

Replace `essential` with `utility` for Utility cooldown commands.

| Command | Description |
|---|---|
| `/ecdm essential` | Show Essential settings |
| `/ecdm essential align <left\|center\|right>` | Set icon alignment |
| `/ecdm essential show` | Show keybind text |
| `/ecdm essential hide` | Hide keybind text |
| `/ecdm essential position <pos>` | Set keybind text position |
| `/ecdm essential fontsize <6-32>` | Set keybind text font size |
| `/ecdm essential shorten` | Enable compact keybind text |
| `/ecdm essential noshorten` | Show full keybind text |
| `/ecdm essential offsetx <-40..40>` | Keybind horizontal offset |
| `/ecdm essential offsety <-40..40>` | Keybind vertical offset |
| `/ecdm essential stacks` | Show stack text settings |
| `/ecdm essential stacks position <pos>` | Set stack text position |
| `/ecdm essential stacks fontsize <6-32>` | Set stack text font size |
| `/ecdm essential stacks offsetx <-40..40>` | Stack text horizontal offset |
| `/ecdm essential stacks offsety <-40..40>` | Stack text vertical offset |

**Position values:** `topleft`, `top`, `topright`, `right`, `bottomright`, `bottom`, `bottomleft`, `left`, `center`

## License

[MIT](LICENSE)
