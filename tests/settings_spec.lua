-- Recover only invalid saved fields and keep commands and UI on one settings contract
describe("Saved setting recovery", function()
  it("loads invalid roots and malformed scalar settings without breaking commands", function()
    for _, saved in ipairs({ 7, false, "invalid", { align = "invalid", bars_colors = "invalid", maxPerRow = "6" } }) do
      _WithAddon(saved, function(ns, client)
        client._startCapture()
        client.SlashCmdList.ENHANCEDCDM("")
        client.SlashCmdList.ENHANCEDCDM("bars gradient")
        client._stopCapture()
        expect(ns.db.align).to_equal("CENTER")
        expect(ns.db.maxPerRow).to_equal(6)
        expect(type(ns.db.bars_colors)).to_equal("table")
      end)
    end
  end)

  it("preserves valid choices and repairs individual gradient channels in place", function()
    local gradient = { sR = 0, sG = "bad", sB = 0.9, eR = 1, eG = 0 / 0, eB = 2 }
    local saved = {
      maxPerRow = 12,
      align = "RIGHT",
      essential_hotkeys_show = false,
      utility_hotkeys_show = true,
      utility_stacks_offsetX = 0,
      bars_orientation = "HORIZONTAL",
      bars_align = "LEFT",
      bars_colors = { [123] = gradient, [456] = "bad", [-1] = {}, [1e100] = {}, invalid = {} },
    }
    _WithAddon(saved, function(ns)
      expect(ns.db).to_equal(saved)
      expect(ns.db.maxPerRow).to_equal(12)
      expect(ns.db.align).to_equal("RIGHT")
      expect(ns.db.essential_hotkeys_show).to_equal(false)
      expect(ns.db.utility_hotkeys_show).to_equal(true)
      expect(ns.db.utility_stacks_offsetX).to_equal(0)
      expect(ns.db.bars_align).to_equal("LEFT")
      expect(ns.db.bars_colors[123]).to_equal(gradient)
      expect(gradient.sR).to_equal(0)
      expect(gradient.sG).to_equal(0.5)
      expect(gradient.sB).to_equal(0.9)
      expect(gradient.eR).to_equal(1)
      expect(gradient.eG).to_equal(0.5)
      expect(gradient.eB).to_equal(0.25)
      expect(ns.db.bars_colors[456]).to_be_nil()
      expect(ns.db.bars_colors[-1]).to_be_nil()
      expect(ns.db.bars_colors[1e100]).to_be_nil()
      expect(ns.db.bars_colors.invalid).to_be_nil()
    end)
  end)

  it("rejects non-finite values and repairs alignment for the saved orientation", function()
    _WithAddon({
      maxPerRow = math.huge,
      bars_maxPerRow = 0,
      utility_stacks_fontSize = 0 / 0,
      essential_hotkeys_offsetX = -math.huge,
      essential_feedback_show = 1,
      bars_orientation = "HORIZONTAL",
      bars_align = "DOWN",
    }, function(ns)
      expect(ns.db.maxPerRow).to_equal(ns.DEFAULTS.maxPerRow)
      expect(ns.db.bars_maxPerRow).to_equal(ns.DEFAULTS.bars_maxPerRow)
      expect(ns.db.utility_stacks_fontSize).to_equal(ns.DEFAULTS.utility_stacks_fontSize)
      expect(ns.db.essential_hotkeys_offsetX).to_equal(ns.DEFAULTS.essential_hotkeys_offsetX)
      expect(ns.db.essential_feedback_show).to_equal(true)
      expect(ns.db.bars_align).to_equal("CENTER")
    end)
  end)

  it("uses the same validation and dependent changes for direct settings and commands", function()
    _WithAddon(nil, function(ns, client)
      client._startCapture()
      client.SlashCmdList.ENHANCEDCDM("bars orientation horizontal")
      expect(ns.db.bars_align).to_equal("CENTER")
      ns.Settings.Set("bars_maxPerRow", 8)
      ns.Settings.Set("bars_orientation", "VERTICAL")
      expect(ns.db.bars_align).to_equal("DOWN")
      expect(ns.db.bars_maxPerRow).to_equal(ns.DEFAULTS.bars_maxPerRow)
      expect(ns.Settings.Set("bars_align", "LEFT")).to_equal(false)
      ns.Settings.Set("utility_hotkeys_position", "CENTER")
      expect(ns.db.utility_hotkeys_offsetX).to_equal(0)
      expect(ns.db.utility_hotkeys_offsetY).to_equal(0)
      client.SlashCmdList.ENHANCEDCDM("utility position bottomleft")
      expect(ns.db.utility_hotkeys_offsetX).to_equal(2)
      expect(ns.db.utility_hotkeys_offsetY).to_equal(2)
      expect(ns.Settings.Set("utility_hotkeys_fontSize", 33)).to_equal(false)
      expect(ns.Settings.Set("utility_hotkeys_show", 1)).to_equal(false)
      for _, id in ipairs({ "-1", "1.5", "inf", "1e100" }) do
        client.SlashCmdList.ENHANCEDCDM("bars gradient " .. id .. " 0 0 0 1 1 1")
      end
      expect(next(ns.db.bars_colors)).to_be_nil()
      client._stopCapture()
    end)
  end)
end)
