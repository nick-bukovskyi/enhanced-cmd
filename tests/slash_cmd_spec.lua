-- Tests for slash command handler
local ns = _G._test_ns

local slash = SlashCmdList["ENHANCEDCDM"]

-- Helper: reset db to defaults
local function resetDb()
  for k, v in pairs(ns.DEFAULTS) do
    if type(v) == "table" then
      ns.db[k] = {}
      for ik, iv in pairs(v) do
        ns.db[k][ik] = iv
      end
    else
      ns.db[k] = v
    end
  end
end

local function runSlash(message)
  _startCapture()
  local ok, err = pcall(slash, message)
  local output = _stopCapture()
  if not ok then
    error(err, 0)
  end
  return output
end

local function settingCase(name, command, key, expected, initial)
  it(name, function()
    resetDb()
    if initial ~= nil then
      ns.db[key] = initial
    end
    runSlash(command)
    expect(ns.db[key]).to_equal(expected)
  end)
end

describe("Slash command: rows/perrow", function()
  settingCase("sets maxPerRow with valid integer", "rows 4", "maxPerRow", 4)

  settingCase("sets at minimum boundary", "rows 1", "maxPerRow", 1)

  settingCase("sets at maximum boundary", "rows 40", "maxPerRow", 40)

  settingCase("rejects 0", "rows 0", "maxPerRow", 6)

  settingCase("rejects 41", "rows 41", "maxPerRow", 6)

  settingCase("rejects non-numeric", "rows abc", "maxPerRow", 6)

  settingCase("floors decimal values", "rows 3.7", "maxPerRow", 3)

  settingCase("works with perrow alias", "perrow 5", "maxPerRow", 5)
end)

describe("Slash command: grow/direction", function()
  settingCase("sets UP", "grow up", "growDirection", "UP")

  settingCase("sets DOWN", "grow down", "growDirection", "DOWN", "UP")

  settingCase("rejects invalid", "grow left", "growDirection", "DOWN")

  settingCase("works with direction alias", "direction up", "growDirection", "UP")
end)

describe("Slash command: align", function()
  settingCase("sets LEFT", "align left", "align", "LEFT")

  settingCase("sets CENTER", "align center", "align", "CENTER", "LEFT")

  settingCase("sets RIGHT", "align right", "align", "RIGHT")

  settingCase("rejects invalid", "align middle", "align", "CENTER")
end)

describe("Slash command: layout", function()
  settingCase("sets DYNAMIC", "layout dynamic", "layout", "DYNAMIC")

  settingCase("sets STATIC", "layout static", "layout", "STATIC", "DYNAMIC")

  settingCase("rejects invalid", "layout flex", "layout", "STATIC")
end)

describe("Slash command: essential/utility align", function()
  settingCase("sets essential alignment to LEFT", "essential align left", "essential_align", "LEFT")

  settingCase("sets essential alignment to RIGHT", "essential align right", "essential_align", "RIGHT")

  settingCase("sets utility alignment to LEFT", "utility align left", "utility_align", "LEFT")

  settingCase("rejects invalid alignment", "essential align middle", "essential_align", "CENTER")
end)

describe("Slash command: essential/utility", function()
  settingCase("enables essential with show", "essential show", "essential_hotkeys_show", true)

  settingCase("disables essential with hide", "essential hide", "essential_hotkeys_show", false, true)

  settingCase("enables utility with show", "utility show", "utility_hotkeys_show", true)

  settingCase("disables utility with hide", "utility hide", "utility_hotkeys_show", false, true)

  it("sets position and resets offsets", function()
    resetDb()
    runSlash("essential position bottomright")
    expect(ns.db.essential_hotkeys_position).to_equal("BOTTOMRIGHT")
    expect(ns.db.essential_hotkeys_offsetX).to_equal(-2)
    expect(ns.db.essential_hotkeys_offsetY).to_equal(2)
  end)

  settingCase("rejects invalid position", "essential position middle", "essential_hotkeys_position", "TOPLEFT")

  settingCase("sets font size", "essential fontsize 18", "essential_hotkeys_fontSize", 18)

  settingCase("rejects fontsize out of range", "essential fontsize 5", "essential_hotkeys_fontSize", 14)

  settingCase("toggles shorten off", "essential noshorten", "essential_hotkeys_shorten", false)
end)

describe("Slash command: essential/utility feedback", function()
  settingCase("enables essential feedback with on", "essential feedback on", "essential_feedback_show", true, false)

  settingCase("disables essential feedback with off", "essential feedback off", "essential_feedback_show", false)

  settingCase("enables utility feedback with on", "utility feedback on", "utility_feedback_show", true, false)

  settingCase("disables utility feedback with off", "utility feedback off", "utility_feedback_show", false)

  it("prints status for feedback without argument", function()
    resetDb()
    local output = runSlash("essential feedback")
    expect(#output > 0).to_be_truthy()
  end)
end)

describe("Slash command: bars gradient", function()
  it("sets gradient when all color channels are within 0..1", function()
    resetDb()
    runSlash("bars gradient 42 1 0.25 0 0 0.5 1")
    expect(ns.db.bars_colors[42].sR).to_equal(1)
    expect(ns.db.bars_colors[42].sG).to_equal(0.25)
    expect(ns.db.bars_colors[42].sB).to_equal(0)
    expect(ns.db.bars_colors[42].eR).to_equal(0)
    expect(ns.db.bars_colors[42].eG).to_equal(0.5)
    expect(ns.db.bars_colors[42].eB).to_equal(1)
  end)

  it("rejects gradient color channels above 1", function()
    resetDb()
    runSlash("bars gradient 42 2 0 0 0 0 0")
    expect(ns.db.bars_colors[42]).to_be_nil()
  end)

  it("rejects gradient color channels below 0", function()
    resetDb()
    runSlash("bars gradient 42 -0.1 0 0 0 0 0")
    expect(ns.db.bars_colors[42]).to_be_nil()
  end)

  it("rejects trailing text after gradient color channels", function()
    resetDb()
    runSlash("bars gradient 42 1 0 0 0 1 0 extra")
    expect(ns.db.bars_colors[42]).to_be_nil()
  end)
end)

describe("Slash command: default help", function()
  it("prints without error for empty input", function()
    resetDb()
    local output = runSlash("")
    expect(#output > 0).to_be_truthy()
  end)

  it("prints without error for unknown cmd", function()
    resetDb()
    local output = runSlash("unknowncmd")
    expect(#output > 0).to_be_truthy()
  end)
end)
