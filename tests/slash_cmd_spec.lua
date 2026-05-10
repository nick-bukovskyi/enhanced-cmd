-- Tests for slash command handler
local ns = _G._test_ns

local slash = SlashCmdList["ENHANCEDCDM"]

-- Helper: reset db to defaults
local function resetDb()
    for k, v in pairs(ns.DEFAULTS) do
        if type(v) == "table" then
            ns.db[k] = {}
            for ik, iv in pairs(v) do ns.db[k][ik] = iv end
        else
            ns.db[k] = v
        end
    end
end

describe("Slash command: rows/perrow", function()
    it("sets maxPerRow with valid integer", function()
        resetDb()
        _startCapture(); slash("rows 4"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(4)
    end)

    it("sets at minimum boundary", function()
        resetDb()
        _startCapture(); slash("rows 1"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(1)
    end)

    it("sets at maximum boundary", function()
        resetDb()
        _startCapture(); slash("rows 40"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(40)
    end)

    it("rejects 0", function()
        resetDb()
        _startCapture(); slash("rows 0"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(6)
    end)

    it("rejects 41", function()
        resetDb()
        _startCapture(); slash("rows 41"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(6)
    end)

    it("rejects non-numeric", function()
        resetDb()
        _startCapture(); slash("rows abc"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(6)
    end)

    it("floors decimal values", function()
        resetDb()
        _startCapture(); slash("rows 3.7"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(3)
    end)

    it("works with perrow alias", function()
        resetDb()
        _startCapture(); slash("perrow 5"); _stopCapture()
        expect(ns.db.maxPerRow).to_equal(5)
    end)
end)

describe("Slash command: grow/direction", function()
    it("sets UP", function()
        resetDb()
        _startCapture(); slash("grow up"); _stopCapture()
        expect(ns.db.growDirection).to_equal("UP")
    end)

    it("sets DOWN", function()
        resetDb()
        ns.db.growDirection = "UP"
        _startCapture(); slash("grow down"); _stopCapture()
        expect(ns.db.growDirection).to_equal("DOWN")
    end)

    it("rejects invalid", function()
        resetDb()
        _startCapture(); slash("grow left"); _stopCapture()
        expect(ns.db.growDirection).to_equal("DOWN")
    end)

    it("works with direction alias", function()
        resetDb()
        _startCapture(); slash("direction up"); _stopCapture()
        expect(ns.db.growDirection).to_equal("UP")
    end)
end)

describe("Slash command: align", function()
    it("sets LEFT", function()
        resetDb()
        _startCapture(); slash("align left"); _stopCapture()
        expect(ns.db.align).to_equal("LEFT")
    end)

    it("sets CENTER", function()
        resetDb()
        _startCapture(); slash("align center"); _stopCapture()
        expect(ns.db.align).to_equal("CENTER")
    end)

    it("sets RIGHT", function()
        resetDb()
        _startCapture(); slash("align right"); _stopCapture()
        expect(ns.db.align).to_equal("RIGHT")
    end)

    it("rejects invalid", function()
        resetDb()
        _startCapture(); slash("align middle"); _stopCapture()
        expect(ns.db.align).to_equal("CENTER")
    end)
end)

describe("Slash command: layout", function()
    it("sets DYNAMIC", function()
        resetDb()
        _startCapture(); slash("layout dynamic"); _stopCapture()
        expect(ns.db.layout).to_equal("DYNAMIC")
    end)

    it("sets STATIC", function()
        resetDb()
        ns.db.layout = "DYNAMIC"
        _startCapture(); slash("layout static"); _stopCapture()
        expect(ns.db.layout).to_equal("STATIC")
    end)

    it("rejects invalid", function()
        resetDb()
        _startCapture(); slash("layout flex"); _stopCapture()
        expect(ns.db.layout).to_equal("STATIC")
    end)
end)

describe("Slash command: essential/utility align", function()
    it("sets essential alignment to LEFT", function()
        resetDb()
        _startCapture(); slash("essential align left"); _stopCapture()
        expect(ns.db.essential_align).to_equal("LEFT")
    end)

    it("sets essential alignment to RIGHT", function()
        resetDb()
        _startCapture(); slash("essential align right"); _stopCapture()
        expect(ns.db.essential_align).to_equal("RIGHT")
    end)

    it("sets utility alignment to LEFT", function()
        resetDb()
        _startCapture(); slash("utility align left"); _stopCapture()
        expect(ns.db.utility_align).to_equal("LEFT")
    end)

    it("rejects invalid alignment", function()
        resetDb()
        _startCapture(); slash("essential align middle"); _stopCapture()
        expect(ns.db.essential_align).to_equal("CENTER")
    end)
end)

describe("Slash command: essential/utility", function()
    it("enables essential with show", function()
        resetDb()
        _startCapture(); slash("essential show"); _stopCapture()
        expect(ns.db.essential_hotkeys_show).to_be_truthy()
    end)

    it("disables essential with hide", function()
        resetDb()
        ns.db.essential_hotkeys_show = true
        _startCapture(); slash("essential hide"); _stopCapture()
        expect(ns.db.essential_hotkeys_show).to_be_falsy()
    end)

    it("enables utility with show", function()
        resetDb()
        _startCapture(); slash("utility show"); _stopCapture()
        expect(ns.db.utility_hotkeys_show).to_be_truthy()
    end)

    it("disables utility with hide", function()
        resetDb()
        ns.db.utility_hotkeys_show = true
        _startCapture(); slash("utility hide"); _stopCapture()
        expect(ns.db.utility_hotkeys_show).to_be_falsy()
    end)

    it("sets position and resets offsets", function()
        resetDb()
        _startCapture(); slash("essential position bottomright"); _stopCapture()
        expect(ns.db.essential_hotkeys_position).to_equal("BOTTOMRIGHT")
        expect(ns.db.essential_hotkeys_offsetX).to_equal(-2)
        expect(ns.db.essential_hotkeys_offsetY).to_equal(2)
    end)

    it("rejects invalid position", function()
        resetDb()
        _startCapture(); slash("essential position middle"); _stopCapture()
        expect(ns.db.essential_hotkeys_position).to_equal("TOPLEFT")
    end)

    it("sets font size", function()
        resetDb()
        _startCapture(); slash("essential fontsize 18"); _stopCapture()
        expect(ns.db.essential_hotkeys_fontSize).to_equal(18)
    end)

    it("rejects fontsize out of range", function()
        resetDb()
        _startCapture(); slash("essential fontsize 5"); _stopCapture()
        expect(ns.db.essential_hotkeys_fontSize).to_equal(14)
    end)

    it("toggles shorten off", function()
        resetDb()
        _startCapture(); slash("essential noshorten"); _stopCapture()
        expect(ns.db.essential_hotkeys_shorten).to_be_falsy()
    end)
end)

describe("Slash command: essential/utility feedback", function()
    it("enables essential feedback with on", function()
        resetDb()
        ns.db.essential_feedback_show = false
        _startCapture(); slash("essential feedback on"); _stopCapture()
        expect(ns.db.essential_feedback_show).to_be_truthy()
    end)

    it("disables essential feedback with off", function()
        resetDb()
        _startCapture(); slash("essential feedback off"); _stopCapture()
        expect(ns.db.essential_feedback_show).to_be_falsy()
    end)

    it("enables utility feedback with on", function()
        resetDb()
        ns.db.utility_feedback_show = false
        _startCapture(); slash("utility feedback on"); _stopCapture()
        expect(ns.db.utility_feedback_show).to_be_truthy()
    end)

    it("disables utility feedback with off", function()
        resetDb()
        _startCapture(); slash("utility feedback off"); _stopCapture()
        expect(ns.db.utility_feedback_show).to_be_falsy()
    end)

    it("prints status for feedback without argument", function()
        resetDb()
        _startCapture()
        slash("essential feedback")
        local output = _stopCapture()
        expect(#output > 0).to_be_truthy()
    end)
end)

describe("Slash command: bars gradient", function()
    it("sets gradient when all color channels are within 0..1", function()
        resetDb()
        _startCapture(); slash("bars gradient 42 1 0.25 0 0 0.5 1"); _stopCapture()
        expect(ns.db.bars_colors[42].sR).to_equal(1)
        expect(ns.db.bars_colors[42].sG).to_equal(0.25)
        expect(ns.db.bars_colors[42].sB).to_equal(0)
        expect(ns.db.bars_colors[42].eR).to_equal(0)
        expect(ns.db.bars_colors[42].eG).to_equal(0.5)
        expect(ns.db.bars_colors[42].eB).to_equal(1)
    end)

    it("rejects gradient color channels above 1", function()
        resetDb()
        _startCapture(); slash("bars gradient 42 2 0 0 0 0 0"); _stopCapture()
        expect(ns.db.bars_colors[42]).to_be_nil()
    end)

    it("rejects gradient color channels below 0", function()
        resetDb()
        _startCapture(); slash("bars gradient 42 -0.1 0 0 0 0 0"); _stopCapture()
        expect(ns.db.bars_colors[42]).to_be_nil()
    end)

    it("rejects trailing text after gradient color channels", function()
        resetDb()
        _startCapture(); slash("bars gradient 42 1 0 0 0 1 0 extra"); _stopCapture()
        expect(ns.db.bars_colors[42]).to_be_nil()
    end)
end)

describe("Slash command: default help", function()
    it("prints without error for empty input", function()
        resetDb()
        _startCapture()
        slash("")
        local output = _stopCapture()
        expect(#output > 0).to_be_truthy()
    end)

    it("prints without error for unknown cmd", function()
        resetDb()
        _startCapture()
        slash("unknowncmd")
        local output = _stopCapture()
        expect(#output > 0).to_be_truthy()
    end)
end)
