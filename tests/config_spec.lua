-- Tests for conservative defaults, position consistency, and SavedVariables initialization
local ns = _G._test_ns

describe("Config defaults", function()
  it("starts with conservative layouts and hidden hotkeys", function()
    expect(ns.DEFAULTS.maxPerRow).to_equal(6)
    expect(ns.DEFAULTS.growDirection).to_equal("DOWN")
    expect(ns.DEFAULTS.align).to_equal("CENTER")
    expect(ns.DEFAULTS.layout).to_equal("STATIC")
    expect(ns.DEFAULTS.essential_align).to_equal("CENTER")
    expect(ns.DEFAULTS.utility_align).to_equal("CENTER")
    expect(ns.DEFAULTS.essential_hotkeys_show).to_equal(false)
    expect(ns.DEFAULTS.utility_hotkeys_show).to_equal(false)
    expect(ns.DEFAULTS.bars_colors).to_be_type("table")
    expect(next(ns.DEFAULTS.bars_colors)).to_be_nil()
  end)

  it("keeps hotkey offsets consistent with their default position", function()
    for _, viewer in ipairs({ "essential", "utility" }) do
      local prefix = viewer .. "_hotkeys_"
      expect(ns.DEFAULTS[prefix .. "position"]).to_equal("TOPLEFT")
      local anchor = ns.HOTKEY_POSITION_ANCHORS[ns.DEFAULTS[prefix .. "position"]]
      expect(ns.DEFAULTS[prefix .. "offsetX"]).to_equal(anchor.x)
      expect(ns.DEFAULTS[prefix .. "offsetY"]).to_equal(anchor.y)
    end
  end)

  it("keeps stack text defaults consistent across viewers", function()
    for _, viewer in ipairs({ "essential", "utility", "buffs" }) do
      local prefix = viewer .. "_stacks_"
      expect(ns.DEFAULTS[prefix .. "fontSize"]).to_equal(12)
      expect(ns.DEFAULTS[prefix .. "position"]).to_equal("BOTTOMRIGHT")
      local anchor = ns.HOTKEY_POSITION_ANCHORS[ns.DEFAULTS[prefix .. "position"]]
      expect(ns.DEFAULTS[prefix .. "offsetX"]).to_equal(anchor.x)
      expect(ns.DEFAULTS[prefix .. "offsetY"]).to_equal(anchor.y)
    end
  end)
end)

describe("Hotkey positions", function()
  it("provides labels, anchors, and matching justification for all nine positions", function()
    local positions = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    local justify = { "LEFT", "CENTER", "RIGHT" }
    for index, position in ipairs(positions) do
      expect(ns.HOTKEY_POSITION_DISPLAY[position]).to_be_type("string")
      local anchor = ns.HOTKEY_POSITION_ANCHORS[position]
      expect(anchor.point).to_equal(position)
      expect(anchor.x).to_be_type("number")
      expect(anchor.y).to_be_type("number")
      expect(ns.HOTKEY_POSITION_JUSTIFY[position]).to_equal(justify[(index - 1) % 3 + 1])
    end
  end)
end)

describe("SavedVariables merge", function()
  it("populated ns.db with defaults on ADDON_LOADED", function()
    expect(ns.db).to_equal(EnhancedCDMDB)
    for key, value in pairs(ns.DEFAULTS) do
      if type(value) == "table" then
        expect(ns.db[key]).to_be_type("table")
        expect(ns.db[key] == value).to_be_falsy()
      else
        expect(ns.db[key]).to_equal(value)
      end
    end
  end)
end)
