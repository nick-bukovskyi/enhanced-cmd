-- Tests for player-facing key abbreviations
local ns = _G._test_ns

describe("FormatKeyText", function()
  it("returns nil for nil input", function()
    expect(ns._FormatKeyText(nil)).to_be_nil()
  end)

  local cases = {
    { "simple keys", { "1", "1" }, { "Q", "Q" }, { "F1", "F1" } },
    { "SHIFT", { "SHIFT-1", "S1" }, { "SHIFT-Q", "SQ" } },
    { "CTRL", { "CTRL-1", "C1" }, { "CTRL-F", "CF" } },
    { "ALT", { "ALT-1", "A1" }, { "ALT-Z", "AZ" } },
    { "combined modifiers", { "SHIFT-CTRL-1", "SC1" }, { "CTRL-ALT-F1", "CAF1" }, { "SHIFT-ALT-Q", "SAQ" } },
    { "mouse wheel up", { "MOUSEWHEELUP", "MWU" }, { "SHIFT-MOUSEWHEELUP", "SMWU" } },
    { "mouse wheel down", { "MOUSEWHEELDOWN", "MWD" } },
    { "mouse buttons", { "BUTTON4", "M4" }, { "BUTTON5", "M5" }, { "SHIFT-BUTTON4", "SM4" } },
    { "numpad digits", { "NUMPAD0", "N0" }, { "NUMPAD9", "N9" } },
    { "numpad decimal", { "NUMPADDECIMAL", "N." } },
    { "numpad plus", { "NUMPADPLUS", "N+" } },
    { "numpad minus", { "NUMPADMINUS", "N-" } },
    { "numpad multiply", { "NUMPADMULTIPLY", "N*" } },
    { "numpad divide", { "NUMPADDIVIDE", "N/" } },
    { "page up", { "PAGEUP", "PU" }, { "SHIFT-PAGEUP", "SPU" } },
    { "page down", { "PAGEDOWN", "PD" } },
    { "spacebar", { "SPACEBAR", "SP" }, { "CTRL-SPACEBAR", "CSP" } },
    { "space", { "SPACE", "SP" }, { "SHIFT-SPACE", "SSP" } },
    { "backspace", { "BACKSPACE", "BS" } },
    { "caps lock", { "CAPSLOCK", "CAP" } },
    { "insert", { "INSERT", "INS" } },
    { "delete", { "DELETE", "DEL" } },
    { "home", { "HOME", "HM" } },
    { "arrows", { "DOWNARROW", "DN" }, { "UPARROW", "UP" }, { "LEFTARROW", "LT" }, { "RIGHTARROW", "RT" }, { "SHIFT-DOWNARROW", "SDN" } },
  }
  for _, case in ipairs(cases) do
    it("formats " .. case[1], function()
      for index = 2, #case do
        local example = case[index]
        expect(ns._FormatKeyText(example[1])).to_equal(example[2])
      end
    end)
  end
end)
