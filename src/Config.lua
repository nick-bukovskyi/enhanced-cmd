-- Enhanced CDM: Configuration — constants, defaults, display maps
local _, ns = ...

ns.DEFAULT_BAR_COLORS = { sR = 1, sG = 0.5, sB = 0.25, eR = 1, eG = 0.5, eB = 0.25 }

-- Default saved variable values
ns.DEFAULTS = {
  -- Buffs (icons)
  maxPerRow = 6,
  growDirection = "DOWN",
  align = "CENTER",
  layout = "STATIC",
  buffs_stacks_fontSize = 12,
  buffs_stacks_position = "BOTTOMRIGHT",
  buffs_stacks_offsetX = -2,
  buffs_stacks_offsetY = 2,
  -- Bars
  bars_orientation = "VERTICAL",
  bars_layout = "STATIC",
  bars_align = "DOWN",
  bars_maxPerRow = 2,
  bars_colors = {},
  -- Essential
  essential_align = "CENTER",
  essential_hotkeys_show = false,
  essential_hotkeys_position = "TOPLEFT",
  essential_hotkeys_fontSize = 14,
  essential_hotkeys_shorten = true,
  essential_hotkeys_offsetX = 2,
  essential_hotkeys_offsetY = -2,
  essential_stacks_fontSize = 12,
  essential_stacks_position = "BOTTOMRIGHT",
  essential_stacks_offsetX = -2,
  essential_stacks_offsetY = 2,
  essential_feedback_show = true,
  -- Utility
  utility_align = "CENTER",
  utility_hotkeys_show = false,
  utility_hotkeys_position = "TOPLEFT",
  utility_hotkeys_fontSize = 12,
  utility_hotkeys_shorten = true,
  utility_hotkeys_offsetX = 2,
  utility_hotkeys_offsetY = -2,
  utility_stacks_fontSize = 12,
  utility_stacks_position = "BOTTOMRIGHT",
  utility_stacks_offsetX = -2,
  utility_stacks_offsetY = 2,
  utility_feedback_show = true,
}

-- Display text for UI labels
ns.DIRECTION_DISPLAY = { DOWN = "Down", UP = "Up" }
ns.ALIGN_DISPLAY = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
ns.LAYOUT_DISPLAY = { STATIC = "Static", DYNAMIC = "Dynamic" }
ns.ORIENTATION_DISPLAY = { VERTICAL = "Vertical", HORIZONTAL = "Horizontal" }
ns.BAR_ALIGN_V_DISPLAY = { DOWN = "Down", UP = "Up" }
ns.BAR_ALIGN_H_DISPLAY = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }

-- Vertical-orientation display maps for buffs / CDs
ns.DIRECTION_V_DISPLAY = { DOWN = "Right", UP = "Left" }
ns.ALIGN_V_DISPLAY = { LEFT = "Top", CENTER = "Center", RIGHT = "Bottom" }

ns.HOTKEY_POSITION_DISPLAY = {
  TOPLEFT = "Top Left",
  TOP = "Top",
  TOPRIGHT = "Top Right",
  RIGHT = "Right",
  BOTTOMRIGHT = "Bottom Right",
  BOTTOM = "Bottom",
  BOTTOMLEFT = "Bottom Left",
  LEFT = "Left",
  CENTER = "Center",
}

-- Anchor point + offsets for each hotkey position
ns.HOTKEY_POSITION_ANCHORS = {
  TOPLEFT = { point = "TOPLEFT", x = 2, y = -2 },
  TOP = { point = "TOP", x = 0, y = -2 },
  TOPRIGHT = { point = "TOPRIGHT", x = -2, y = -2 },
  RIGHT = { point = "RIGHT", x = -2, y = 0 },
  BOTTOMRIGHT = { point = "BOTTOMRIGHT", x = -2, y = 2 },
  BOTTOM = { point = "BOTTOM", x = 0, y = 2 },
  BOTTOMLEFT = { point = "BOTTOMLEFT", x = 2, y = 2 },
  LEFT = { point = "LEFT", x = 2, y = 0 },
  CENTER = { point = "CENTER", x = 0, y = 0 },
}

-- Horizontal text alignment per position
ns.HOTKEY_POSITION_JUSTIFY = {
  TOPLEFT = "LEFT",
  TOP = "CENTER",
  TOPRIGHT = "RIGHT",
  LEFT = "LEFT",
  CENTER = "CENTER",
  RIGHT = "RIGHT",
  BOTTOMLEFT = "LEFT",
  BOTTOM = "CENTER",
  BOTTOMRIGHT = "RIGHT",
}
