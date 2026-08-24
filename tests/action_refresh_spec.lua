-- Tests for batched action-bar binding refreshes.
local ns = _G._test_ns

local function getEventFrame()
    for _, frame in ipairs(_G._allFrames or {}) do
        if frame._scripts and frame._scripts.OnEvent
            and frame._events and frame._events.ACTIONBAR_PAGE_CHANGED then
            return frame
        end
    end
end

describe("Action bar refresh events", function()
    it("registers page and equipment changes", function()
        local eventFrame = getEventFrame()

        expect(eventFrame).to_be_truthy()
        expect(eventFrame._events.ACTIONBAR_PAGE_CHANGED).to_equal(true)
        expect(eventFrame._events.PLAYER_EQUIPMENT_CHANGED).to_equal(true)
    end)

    it("registers display geometry changes", function()
        local eventFrame = getEventFrame()

        expect(eventFrame._events.UI_SCALE_CHANGED).to_equal(true)
        expect(eventFrame._events.DISPLAY_SIZE_CHANGED).to_equal(true)
    end)

    it("registers character Edit Mode layout changes", function()
        local eventFrame = getEventFrame()

        expect(eventFrame._events.EDIT_MODE_LAYOUTS_UPDATED).to_equal(true)
    end)

    it("coalesces display changes into one relayout per cooldown viewer", function()
        local eventFrame = getEventFrame()

        eventFrame._scripts.OnEvent(eventFrame, "UI_SCALE_CHANGED")
        eventFrame._scripts.OnEvent(eventFrame, "DISPLAY_SIZE_CHANGED")

        expect(_G._GetPendingTimerCount()).to_equal(4)
        _G._RunPendingTimers()
    end)

    it("coalesces page changes and rebuilds the slot map next frame", function()
        local eventFrame = getEventFrame()
        local button = CreateFrame("Button", "ActionButton1")
        button:SetAttribute("action", 1)
        _G._stubBindingKeys.ACTIONBUTTON1 = "Q"
        _G._stubSpellActionButtons[12345] = { 13 }
        ns._BuildSlotToBindingMap()
        expect(ns._GetHotkeyText(12345, false)).to_be_nil()

        button:SetAttribute("action", 13)
        eventFrame._scripts.OnEvent(eventFrame, "ACTIONBAR_PAGE_CHANGED")
        eventFrame._scripts.OnEvent(eventFrame, "ACTIONBAR_PAGE_CHANGED")

        expect(_G._GetPendingTimerCount()).to_equal(1)
        _G._RunPendingTimers()
        expect(ns._GetHotkeyText(12345, false)).to_equal("Q")

        _G.ActionButton1 = nil
        wipe(_G._stubBindingKeys)
        wipe(_G._stubSpellActionButtons)
    end)
end)
