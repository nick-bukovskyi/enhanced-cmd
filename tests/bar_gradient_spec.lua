-- Tests for ApplyBarGradient and ResetBarGradient
local ns = _G._test_ns
local initializedBarViewer

-- Helper: create a mock bar frame with a StatusBar child and trackable texture
local function makeMockBarFrame(cooldownID)
    local barFrame = CreateFrame("Frame")
    local statusBar = CreateFrame("StatusBar", nil, barFrame)
    local tex = { _gradientCalls = {} }
    tex.SetGradient = function(self, orient, startColor, endColor)
        table.insert(self._gradientCalls, {
            orient = orient, startColor = startColor, endColor = endColor
        })
    end
    statusBar._statusBarTexture = tex
    barFrame.cooldownID = cooldownID
    return barFrame, statusBar, tex
end

describe("ApplyBarGradient", function()
    it("applies gradient from db.bars_colors", function()
        local barFrame, _, tex = makeMockBarFrame(42)
        ns.db.bars_colors = {[42] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}
        ns._ApplyBarGradient(barFrame)
        expect(#tex._gradientCalls).to_equal(1)
        local call = tex._gradientCalls[1]
        expect(call.startColor.r).to_equal(1)
        expect(call.startColor.g).to_equal(0)
        expect(call.startColor.b).to_equal(0)
        expect(call.endColor.r).to_equal(0)
        expect(call.endColor.g).to_equal(1)
        expect(call.endColor.b).to_equal(0)
        ns.db.bars_colors = {}
    end)

    it("does nothing when cooldownID has no color", function()
        local barFrame, _, tex = makeMockBarFrame(99)
        ns.db.bars_colors = {}
        ns._ApplyBarGradient(barFrame)
        expect(#tex._gradientCalls).to_equal(0)
    end)

    it("does nothing when no StatusBar child", function()
        local barFrame = CreateFrame("Frame")
        barFrame.cooldownID = 50
        ns.db.bars_colors = {[50] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}
        -- Should not error
        ns._ApplyBarGradient(barFrame)
        ns.db.bars_colors = {}
    end)

    it("does nothing when texture is nil", function()
        local barFrame = CreateFrame("Frame")
        local statusBar = CreateFrame("StatusBar", nil, barFrame)
        statusBar._statusBarTexture = nil
        barFrame.cooldownID = 55
        ns.db.bars_colors = {[55] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}
        -- Should not error
        ns._ApplyBarGradient(barFrame)
        ns.db.bars_colors = {}
    end)
end)

describe("ResetBarGradient", function()
    it("resets to default orange", function()
        local barFrame, _, tex = makeMockBarFrame(42)
        ns._ResetBarGradient(barFrame)
        expect(#tex._gradientCalls).to_equal(1)
        local call = tex._gradientCalls[1]
        expect(call.startColor.r).to_equal(1)
        expect(call.startColor.g).to_equal(0.5)
        expect(call.startColor.b).to_equal(0.25)
        expect(call.endColor.r).to_equal(1)
        expect(call.endColor.g).to_equal(0.5)
        expect(call.endColor.b).to_equal(0.25)
    end)

    it("does nothing when no StatusBar child", function()
        local barFrame = CreateFrame("Frame")
        -- Should not error
        ns._ResetBarGradient(barFrame)
    end)
end)

describe("RefreshBarGradient", function()
    it("resets to default orange when cooldownID has no configured color", function()
        local barFrame, _, tex = makeMockBarFrame(99)
        ns.db.bars_colors = {}

        ns.RefreshBarGradient(barFrame)

        expect(#tex._gradientCalls).to_equal(1)
        local call = tex._gradientCalls[1]
        expect(call.startColor.r).to_equal(1)
        expect(call.startColor.g).to_equal(0.5)
        expect(call.startColor.b).to_equal(0.25)
        expect(call.endColor.r).to_equal(1)
        expect(call.endColor.g).to_equal(0.5)
        expect(call.endColor.b).to_equal(0.25)
    end)

    it("uses configured gradient when present", function()
        local barFrame, _, tex = makeMockBarFrame(42)
        ns.db.bars_colors = {[42] = {sR=0.1, sG=0.2, sB=0.3, eR=0.4, eG=0.5, eB=0.6}}

        ns.RefreshBarGradient(barFrame)

        expect(#tex._gradientCalls).to_equal(1)
        local call = tex._gradientCalls[1]
        expect(call.startColor.r).to_equal(0.1)
        expect(call.startColor.g).to_equal(0.2)
        expect(call.startColor.b).to_equal(0.3)
        expect(call.endColor.r).to_equal(0.4)
        expect(call.endColor.g).to_equal(0.5)
        expect(call.endColor.b).to_equal(0.6)
        ns.db.bars_colors = {}
    end)

    it("refreshes all tracked bars and resets stale bars", function()
        local viewer = CreateFrame("Frame")
        local barA, _, texA = makeMockBarFrame(1)
        local barB, _, texB = makeMockBarFrame(2)
        barA._parent = viewer
        barB._parent = viewer
        viewer._children = { barA, barB }
        _G["BuffBarCooldownViewer"] = viewer
        initializedBarViewer = viewer
        ns.db.bars_colors = {[1] = {sR=1, sG=0, sB=0, eR=0, eG=1, eB=0}}

        for _, frame in ipairs(_G._allFrames or {}) do
            if frame._scripts and frame._scripts["OnEvent"] then
                frame._scripts["OnEvent"](frame, "PLAYER_ENTERING_WORLD")
                break
            end
        end

        ns.RefreshAllBarGradients()

        expect(texA._gradientCalls[#texA._gradientCalls].startColor.g).to_equal(0)
        expect(texB._gradientCalls[#texB._gradientCalls].startColor.g).to_equal(0.5)

        _G["BuffBarCooldownViewer"] = nil
        ns.db.bars_colors = {}
    end)
end)

describe("12.1 bar frame reassignment", function()
    it("reapplies the gradient after SetCooldownID changes a pooled frame", function()
        local barFrame, _, tex = makeMockBarFrame(1)
        barFrame._parent = initializedBarViewer
        ns.db.bars_colors = {
            [1] = {sR=1, sG=0, sB=0, eR=1, eG=0, eB=0},
            [2] = {sR=0, sG=0, sB=1, eR=0, eG=0, eB=1},
        }
        ns.RefreshBarGradient(barFrame)

        barFrame.cooldownID = 2
        local hooks = CooldownViewerItemDataMixin._secureHooks.SetCooldownID
        hooks[#hooks](barFrame)

        local call = tex._gradientCalls[#tex._gradientCalls]
        expect(call.startColor.r).to_equal(0)
        expect(call.startColor.b).to_equal(1)
        ns.db.bars_colors = {}
    end)

    it("resets the gradient after PTR ResetCooldownData releases a frame", function()
        local barFrame, _, tex = makeMockBarFrame(1)
        barFrame._parent = initializedBarViewer
        ns.db.bars_colors = {
            [1] = {sR=1, sG=0, sB=0, eR=1, eG=0, eB=0},
        }
        ns.RefreshBarGradient(barFrame)

        barFrame.cooldownID = nil
        local hooks = CooldownViewerItemDataMixin._secureHooks.ResetCooldownData
        hooks[#hooks](barFrame)

        local call = tex._gradientCalls[#tex._gradientCalls]
        expect(call.startColor.r).to_equal(1)
        expect(call.startColor.g).to_equal(0.5)
        expect(call.startColor.b).to_equal(0.25)
        ns.db.bars_colors = {}
    end)
end)
