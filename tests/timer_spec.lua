-- Tests for coalesced next-frame scheduling.
local ns = _G._test_ns

describe("CreateNextFrameScheduler", function()
    it("queues one timer for repeated calls in the same frame", function()
        local callCount = 0
        local schedule = ns.CreateNextFrameScheduler(function()
            callCount = callCount + 1
        end)

        schedule()
        schedule()
        schedule()

        expect(_G._GetPendingTimerCount()).to_equal(1)
        expect(callCount).to_equal(0)

        _G._RunPendingTimers()

        expect(callCount).to_equal(1)
        expect(_G._GetPendingTimerCount()).to_equal(0)
    end)

    it("allows another run after the queued callback completes", function()
        local callCount = 0
        local schedule = ns.CreateNextFrameScheduler(function()
            callCount = callCount + 1
        end)

        schedule()
        _G._RunPendingTimers()
        schedule()
        _G._RunPendingTimers()

        expect(callCount).to_equal(2)
    end)
end)
