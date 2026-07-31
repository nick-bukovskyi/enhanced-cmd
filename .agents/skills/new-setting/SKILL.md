---
name: new-setting
description: Scaffold a new EnhancedCDM saved variable setting across all required files
disable-model-invocation: true
---

# New Setting Scaffold

Add a new user-configurable setting to Enhanced CDM. This skill ensures every required touchpoint is updated consistently.

## Arguments

The user must provide:
1. **Setting name** — the `EnhancedCDMDB` key (camelCase, e.g. `iconSpacing`)
2. **Setting type** — `number`, `enum`, or `boolean`
3. **Default value** — the value stored in `ns.DEFAULTS`
4. **For enums:** the list of valid values and their display labels

## Checklist — All 5 Steps Required

You MUST complete every step below. Do not skip any.

### Step 1: `Config.lua` — Default and display map

- Add the default value to `ns.DEFAULTS`.
- If the setting is an enum, add a `ns.<NAME>_DISPLAY` map (e.g. `ns.LAYOUT_DISPLAY`).

### Step 2: `Core.lua` — Slash command handler

Add an `elseif` branch to the slash command handler in `RegisterSlashCommands()`. Follow the existing pattern:

- **Number settings:** validate with `tonumber()`, enforce min/max, use `math.floor()`.
- **Enum settings:** `arg:upper()`, check against valid values.
- **Boolean settings:** accept `on`/`off` or `true`/`false`, toggle if no arg given.

Always call `ApplyLayout()` after changing the value and print confirmation with `|cff00ccffEnhanced CDM:|r` prefix.

Add a help line to the `else` (help) block matching the existing alignment format.

### Step 3: `Core.lua` — `ApplyLayout()`

Read the new setting from `db` and use it in the layout logic where appropriate. The exact integration depends on what the setting controls — ask the user if unclear.

### Step 4: `EditMode.lua` — Panel widget

Add a new row to `CreateEditModePanel()` following the existing pattern:

- **Number settings:** use `MinimalSliderWithSteppersTemplate` (see `maxPerRow` row).
- **Enum settings:** use `WowStyle1DropdownTemplate` with `CreateRadio` (see `growDirection` row).
- **Boolean settings:** use a `WowStyle1DropdownTemplate` with On/Off radio items.

Increment the row count in the `f:SetSize()` call at the bottom of `CreateEditModePanel()`.

Add refresh logic to `RefreshEditModePanel()` for the new widget.

### Step 5: Version bump and changelog

- Bump `## Version` in `EnhancedCDM.toc`.
- Add a `### Added` entry under a new version heading in `docs/CHANGELOG.md` (Keep A Changelog format).

## Conventions

- Use `hooksecurefunc` — never replace Blizzard functions.
- Set `frame._arSettingPos = true` before any `SetPoint` call from our code, reset to `false` after.
- Global frame names: prefix with `EnhancedCDM` (e.g. `EnhancedCDMIconSpacingStepper`).
- Cross-file sharing via `ns` only. Only expose what another file needs.
- All UI labels: PascalCase with spaces (e.g. "Icon Spacing").

## After Completion

Remind the user to test in-game:
- `/reload` and verify the default is applied
- Change the setting via `/ecdm` and via Edit Mode panel
- Verify the setting persists across `/reload`
- Test mid-combat if the setting affects layout