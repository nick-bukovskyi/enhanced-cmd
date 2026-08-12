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

    it("relayouts when an Edit Mode anchor dependency moves", function()
        local viewerNames = {
            "BuffIconCooldownViewer",
            "BuffBarCooldownViewer",
            "EssentialCooldownViewer",
            "UtilityCooldownViewer",
        }
        for _, name in ipairs(viewerNames) do
            createViewer(name)
        end
        fireEvent("PLAYER_ENTERING_WORLD")

        for _, name in ipairs(viewerNames) do
            local viewer = _G[name]
            local hooks = viewer._secureHooks
                and viewer._secureHooks.OnAnyEditModeSystemAnchorChanged
            expect(hooks and hooks[#hooks]).to_be_truthy()
            hooks[#hooks]()
        end

        expect(_G._GetPendingTimerCount()).to_equal(4)
        _G._RunPendingTimers()
    end)

    it("only schedules buff visibility changes in dynamic mode", function()
        local buffViewer = createViewer("BuffIconCooldownViewer")
        local child = CreateFrame("Frame", nil, buffViewer)
        child.cooldownID = 1
        local acquireHooks = CooldownViewerMixin._secureHooks.OnAcquireItemFrame
        acquireHooks[#acquireHooks](buffViewer, child)
        _G._RunPendingTimers()

        local visibilityHooks = child._hookScripts.OnShow
        local oldLayout = ns.db.layout
        ns.db.layout = "STATIC"
        visibilityHooks[1](child)
        expect(_G._GetPendingTimerCount()).to_equal(0)

        ns.db.layout = "DYNAMIC"
        visibilityHooks[1](child)
        expect(_G._GetPendingTimerCount()).to_equal(1)
        _G._RunPendingTimers()
        ns.db.layout = oldLayout
    end)

    it("only schedules bar visibility changes in dynamic mode", function()
        local barViewer = createViewer("BuffBarCooldownViewer")
        local child = CreateFrame("Frame", nil, barViewer)
        child.cooldownID = 1
        local acquireHooks = CooldownViewerMixin._secureHooks.OnAcquireItemFrame
        acquireHooks[#acquireHooks](barViewer, child)
        _G._RunPendingTimers()

        local visibilityHooks = child._hookScripts.OnHide
        local oldLayout = ns.db.bars_layout
        ns.db.bars_layout = "STATIC"
        visibilityHooks[1](child)
        expect(_G._GetPendingTimerCount()).to_equal(0)

        ns.db.bars_layout = "DYNAMIC"
        visibilityHooks[1](child)
        expect(_G._GetPendingTimerCount()).to_equal(1)
        _G._RunPendingTimers()
        ns.db.bars_layout = oldLayout
    end)

    it("refreshes a consumable hotkey when 12.1 changes its category item", function()
        local essentialViewer = createViewer("EssentialCooldownViewer")
        local child = CreateFrame("Frame", nil, essentialViewer)
        child.cooldownID = 1
        child.GetSpellCategoryTooltipItemID = function() return 212265 end
        local button = CreateFrame("Button", "ActionButton1")
        button:SetAttribute("action", 1)
        _G._stubActionInfo[1] = { type = "item", id = 212265 }
        _G._stubBindingKeys.ACTIONBUTTON1 = "Q"
        ns._BuildSlotToBindingMap()

        local oldShow = ns.db.essential_hotkeys_show
        ns.db.essential_hotkeys_show = true
        local hooks = CooldownViewerItemDataMixin._secureHooks.UpdateFromSpellCategory
        hooks[#hooks](child)

        expect(child._ecdmHotkeyText._text).to_equal("Q")
        expect(child._ecdmHotkeyText._shown).to_equal(true)

        ns.db.essential_hotkeys_show = oldShow
        _G.ActionButton1 = nil
        _G._stubActionInfo[1] = nil
        _G._stubBindingKeys.ACTIONBUTTON1 = nil
    end)
end)
