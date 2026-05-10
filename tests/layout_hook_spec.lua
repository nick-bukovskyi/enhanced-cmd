-- Tests for viewer hook timing behavior.
local ns = _G._test_ns

local function fireEvent(event, arg1)
    for _, frame in ipairs(_G._allFrames or {}) do
        local script = frame._scripts and frame._scripts["OnEvent"]
        if script then
            script(frame, event, arg1)
        end
    end
end

local function createViewer(name)
    local existing = _G[name]
    if existing then return existing end
    return CreateFrame("Frame", name)
end

describe("Layout hook timing", function()
    it("applies tracked buff layout synchronously after Blizzard Layout", function()
        local buffViewer = createViewer("BuffIconCooldownViewer")
        createViewer("BuffBarCooldownViewer")
        createViewer("EssentialCooldownViewer")
        createViewer("UtilityCooldownViewer")

        fireEvent("PLAYER_ENTERING_WORLD")

        local hooks = buffViewer._secureHooks and buffViewer._secureHooks.Layout
        expect(hooks and hooks[#hooks]).to_be_truthy()

        local timerCount = 0
        local oldNewTimer = C_Timer.NewTimer
        C_Timer.NewTimer = function()
            timerCount = timerCount + 1
            return { Cancel = function() end }
        end

        local ok, err = pcall(hooks[#hooks])
        C_Timer.NewTimer = oldNewTimer
        if not ok then error(err, 0) end

        expect(timerCount).to_equal(0)
    end)

    it("cancels pending tracked buff layout timer when Layout applies synchronously", function()
        local buffViewer = createViewer("BuffIconCooldownViewer")
        createViewer("BuffBarCooldownViewer")
        createViewer("EssentialCooldownViewer")
        createViewer("UtilityCooldownViewer")

        fireEvent("PLAYER_ENTERING_WORLD")

        local hooks = buffViewer._secureHooks and buffViewer._secureHooks.Layout
        expect(hooks and hooks[#hooks]).to_be_truthy()

        local cancelCount = 0
        local oldNewTimer = C_Timer.NewTimer
        C_Timer.NewTimer = function()
            return { Cancel = function() cancelCount = cancelCount + 1 end }
        end

        local ok, err = pcall(function()
            ns.ScheduleLayout()
            hooks[#hooks]()
        end)
        C_Timer.NewTimer = oldNewTimer
        if not ok then error(err, 0) end

        expect(cancelCount).to_equal(1)
    end)
end)
