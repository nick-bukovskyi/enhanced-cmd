-- Tests for click feedback engine (GetSlotSpellID)
local ns = _G._test_ns

describe("GetSlotSpellID", function()
    local getSlotSpellID = ns._GetSlotSpellID

    it("returns nil for nil slot", function()
        expect(getSlotSpellID(nil)).to_be_nil()
    end)

    it("returns nil for slot 0", function()
        expect(getSlotSpellID(0)).to_be_nil()
    end)

    it("returns spellID for spell-type action", function()
        _G._stubActionInfo[5] = { type = "spell", id = 12345 }
        expect(getSlotSpellID(5)).to_equal(12345)
        _G._stubActionInfo[5] = nil
    end)

    it("returns nil for empty slot", function()
        expect(getSlotSpellID(99)).to_be_nil()
    end)

    it("resolves macro to spellID via GetMacroSpell", function()
        _G._stubActionInfo[10] = { type = "macro", id = 42 }
        _G._stubMacroSpells[42] = 67890
        expect(getSlotSpellID(10)).to_equal(67890)
        _G._stubActionInfo[10] = nil
        _G._stubMacroSpells[42] = nil
    end)

    it("returns nil for macro with no spell", function()
        _G._stubActionInfo[10] = { type = "macro", id = 42 }
        _G._stubMacroSpells[42] = nil
        expect(getSlotSpellID(10)).to_be_nil()
        _G._stubActionInfo[10] = nil
    end)

    it("returns nil for non-spell non-macro action types", function()
        _G._stubActionInfo[7] = { type = "item", id = 999 }
        expect(getSlotSpellID(7)).to_be_nil()
        _G._stubActionInfo[7] = nil
    end)

    it("returns nil for macro with nil id", function()
        _G._stubActionInfo[3] = { type = "macro", id = nil }
        expect(getSlotSpellID(3)).to_be_nil()
        _G._stubActionInfo[3] = nil
    end)
end)

describe("Pushed overlay sizing", function()
    it("refreshes existing overlay size from the current icon size", function()
        local frame = CreateFrame("Frame")
        frame:SetSize(45, 45)

        local overlay = ns._GetPushedOverlay(frame)
        expect(overlay._width).to_equal(51)
        expect(overlay._height).to_equal(51)

        frame:SetSize(90, 30)
        local sameOverlay = ns._GetPushedOverlay(frame)

        expect(sameOverlay).to_equal(overlay)
        expect(sameOverlay._width).to_equal(102)
        expect(sameOverlay._height).to_equal(34)
    end)

    it("updates overlay size from the icon OnSizeChanged hook", function()
        local frame = CreateFrame("Frame")
        frame:SetSize(45, 45)

        local overlay = ns._GetPushedOverlay(frame)
        frame:SetSize(90, 90)
        local hooks = frame._hookScripts and frame._hookScripts.OnSizeChanged
        expect(hooks ~= nil).to_be_truthy()
        hooks[1](frame)

        expect(overlay._width).to_equal(102)
        expect(overlay._height).to_equal(102)
    end)
end)
