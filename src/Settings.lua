-- Enhanced CDM: validated settings and SavedVariables ownership
local _, ns = ...
local Settings = {}
ns.Settings = Settings

local ranges = {
  maxPerRow = { 1, 40 },
  bars_maxPerRow = { 1, 8 },
  fontSize = { 6, 32 },
  offsetX = { -40, 40 },
  offsetY = { -40, 40 },
}
local enums = {
  growDirection = ns.DIRECTION_DISPLAY,
  align = ns.ALIGN_DISPLAY,
  essential_align = ns.ALIGN_DISPLAY,
  utility_align = ns.ALIGN_DISPLAY,
  layout = ns.LAYOUT_DISPLAY,
  bars_layout = ns.LAYOUT_DISPLAY,
  bars_orientation = ns.ORIENTATION_DISPLAY,
}
local colorDefaults = ns.DEFAULT_BAR_COLORS

local function InRange(value, minimum, maximum)
  return type(value) == "number" and value == value and value >= minimum and value <= maximum
end

function Settings.GetRange(key)
  local range = ranges[key] or ranges[key:match("_([^_]+)$")]
  if range then
    return range[1], range[2]
  end
end

function Settings.IsColorComponent(value)
  return InRange(value, 0, 1)
end

function Settings.IsCooldownID(id)
  -- Reject IDs outside Lua's exact integer range
  return InRange(id, 1, 9007199254740991) and id == math.floor(id)
end

local function IsValid(key, value, saved)
  local default = ns.DEFAULTS[key]
  if default == nil or key == "bars_colors" then
    return false
  end
  if type(default) == "boolean" then
    return type(value) == "boolean"
  end
  local minimum, maximum = Settings.GetRange(key)
  if minimum then
    return InRange(value, minimum, maximum)
  end
  local choices = enums[key]
  if key == "bars_align" then
    choices = saved.bars_orientation == "HORIZONTAL" and ns.BAR_ALIGN_H_DISPLAY or ns.BAR_ALIGN_V_DISPLAY
  elseif key:match("_position$") then
    choices = ns.HOTKEY_POSITION_DISPLAY
  end
  return type(value) == "string" and choices and choices[value] ~= nil
end

-- Repair individual fields in place so valid choices and gradients survive
function Settings.Repair(saved)
  if type(saved) ~= "table" then
    saved = {}
  end
  if not IsValid("bars_orientation", saved.bars_orientation, saved) then
    saved.bars_orientation = ns.DEFAULTS.bars_orientation
  end
  for key, default in pairs(ns.DEFAULTS) do
    if key ~= "bars_colors" then
      if not IsValid(key, saved[key], saved) then
        saved[key] = key == "bars_align" and saved.bars_orientation == "HORIZONTAL" and "CENTER" or default
      elseif type(default) == "number" then
        saved[key] = math.floor(saved[key])
      end
    end
  end
  if type(saved.bars_colors) ~= "table" then
    saved.bars_colors = {}
  end
  for id, colors in pairs(saved.bars_colors) do
    if not Settings.IsCooldownID(id) or type(colors) ~= "table" then
      saved.bars_colors[id] = nil
    else
      for channel, default in pairs(colorDefaults) do
        if not Settings.IsColorComponent(colors[channel]) then
          colors[channel] = default
        end
      end
    end
  end
  return saved
end

function Settings.Initialize()
  EnhancedCDMDB = Settings.Repair(EnhancedCDMDB)
  ns.db = EnhancedCDMDB
  return ns.db
end

function Settings.Set(key, value)
  local db = ns.db
  if not db or not IsValid(key, value, db) then
    return false
  end
  if type(value) == "number" then
    value = math.floor(value)
  end
  db[key] = value
  if key == "bars_orientation" then
    db.bars_align = value == "VERTICAL" and "DOWN" or "CENTER"
    if value == "VERTICAL" then
      db.bars_maxPerRow = ns.DEFAULTS.bars_maxPerRow
    end
  elseif key:match("_position$") then
    local prefix = key:sub(1, -9)
    local anchor = ns.HOTKEY_POSITION_ANCHORS[value]
    db[prefix .. "offsetX"] = anchor.x
    db[prefix .. "offsetY"] = anchor.y
  end
  return true
end

function Settings.Reset(key)
  return Settings.Set(key, ns.DEFAULTS[key])
end

function Settings.SetBarColors(id, colors)
  if not ns.db or not Settings.IsCooldownID(id) then
    return false
  end
  if colors == nil then
    ns.db.bars_colors[id] = nil
    return true
  end
  if type(colors) ~= "table" then
    return false
  end
  local copy = {}
  for channel in pairs(colorDefaults) do
    if not Settings.IsColorComponent(colors[channel]) then
      return false
    end
    copy[channel] = colors[channel]
  end
  ns.db.bars_colors[id] = copy
  return true
end

function Settings.SetBarColor(id, endpoint, r, g, b)
  if not ns.db or not Settings.IsCooldownID(id) or (endpoint ~= "s" and endpoint ~= "e") then
    return false
  end
  local current = ns.db.bars_colors[id] or colorDefaults
  local colors = {}
  for channel in pairs(colorDefaults) do
    colors[channel] = current[channel]
  end
  colors[endpoint .. "R"], colors[endpoint .. "G"], colors[endpoint .. "B"] = r, g, b
  return Settings.SetBarColors(id, colors)
end

function Settings.ClearBarColors()
  wipe(ns.db.bars_colors)
end
