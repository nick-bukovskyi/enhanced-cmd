-- Tests for preserving the BuffIconCooldownViewer anchor edge while resizing.
local ns = _G._test_ns

local function hasText(value, text)
    return value and value:find(text, 1, true) ~= nil
end

local function newViewer(point, left, bottom, width, height, scale, name)
    local viewer = {
        _left = left,
        _bottom = bottom,
        _width = width,
        _height = height,
        _scale = scale or 1,
        _originLeft = left,
        _originBottom = bottom,
        _originRight = left + width,
        _originTop = bottom + height,
        _points = {
            { point = point, relativeTo = nil, relativePoint = point, offsetX = 0, offsetY = 0 },
        },
        _usedBaseClear = false,
        _usedBaseSetPoint = false,
        _name = name,
    }

    function viewer:GetName()
        return self._name
    end

    function viewer:GetScale()
        return self._scale
    end

    function viewer:GetEffectiveScale()
        return self._effectiveScale or self._scale
    end

    function viewer:GetRect()
        return self._left, self._bottom, self._width, self._height
    end

    function viewer:GetNumPoints()
        return #self._points
    end

    function viewer:GetPoint(index)
        local p = self._points[index]
        if not p then return nil end
        return p.point, p.relativeTo, p.relativePoint, p.offsetX, p.offsetY
    end

    function viewer:SetSize(widthValue, heightValue)
        local oldLeft, oldBottom = self._left, self._bottom
        local oldRight = oldLeft + self._width
        local oldTop = oldBottom + self._height
        local oldCenterX = oldLeft + (self._width / 2)
        local oldCenterY = oldBottom + (self._height / 2)
        local pointValue = self._points[1] and self._points[1].point

        self._width = widthValue
        self._height = heightValue

        if hasText(pointValue, "RIGHT") then
            self._left = oldRight - widthValue
        elseif hasText(pointValue, "LEFT") then
            self._left = oldLeft
        else
            self._left = oldCenterX - (widthValue / 2)
        end

        if hasText(pointValue, "TOP") then
            self._bottom = oldTop - heightValue
        elseif hasText(pointValue, "BOTTOM") then
            self._bottom = oldBottom
        else
            self._bottom = oldCenterY - (heightValue / 2)
        end
    end

    function viewer:SetFixedSize(widthValue, heightValue)
        self._fixedWidth = widthValue
        self._fixedHeight = heightValue
    end

    function viewer:GetFixedSize()
        return self._fixedWidth, self._fixedHeight
    end

    local function applyPoint(self, pointValue, offsetX, offsetY)
        offsetX = offsetX or 0
        offsetY = offsetY or 0

        if hasText(pointValue, "RIGHT") then
            self._left = self._originRight + (offsetX * self._scale) - self._width
        elseif hasText(pointValue, "LEFT") then
            self._left = self._originLeft + (offsetX * self._scale)
        else
            local originCenterX = self._originLeft + ((self._originRight - self._originLeft) / 2)
            self._left = originCenterX + (offsetX * self._scale) - (self._width / 2)
        end

        if hasText(pointValue, "TOP") then
            self._bottom = self._originTop + (offsetY * self._scale) - self._height
        elseif hasText(pointValue, "BOTTOM") then
            self._bottom = self._originBottom + (offsetY * self._scale)
        else
            local originCenterY = self._originBottom + ((self._originTop - self._originBottom) / 2)
            self._bottom = originCenterY + (offsetY * self._scale) - (self._height / 2)
        end
    end

    function viewer:ClearAllPointsBase()
        self._usedBaseClear = true
        self._points = {}
    end

    function viewer:SetPointBase(pointValue, relativeTo, relativePoint, offsetX, offsetY)
        self._usedBaseSetPoint = true
        self._setPointWasSettingPos = self._arSettingPos
        table.insert(self._points, {
            point = pointValue,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            offsetX = offsetX or 0,
            offsetY = offsetY or 0,
        })
        applyPoint(self, pointValue, offsetX, offsetY)
    end

    return viewer
end

describe("SetViewerSizePreservingEdge", function()
    local resize = ns._SetViewerSizePreservingEdge

    it("preserves bottom edge for upward horizontal growth", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 1)

        resize(viewer, 160, 80, "BOTTOM")

        local _, bottom, _, height = viewer:GetRect()
        expect(bottom).to_equal(100)
        expect(bottom + height).to_equal(180)
        expect(select(5, viewer:GetPoint(1))).to_equal(40)
        expect(viewer._usedBaseClear).to_equal(true)
        expect(viewer._usedBaseSetPoint).to_equal(true)
        expect(viewer._setPointWasSettingPos).to_equal(true)
        expect(viewer._arSettingPos).to_equal(false)
    end)

    it("preserves top edge for downward horizontal growth", function()
        local viewer = newViewer("BOTTOMLEFT", 20, 100, 160, 40, 1)

        resize(viewer, 160, 80, "TOP")

        local _, bottom, _, height = viewer:GetRect()
        expect(bottom).to_equal(60)
        expect(bottom + height).to_equal(140)
        expect(select(5, viewer:GetPoint(1))).to_equal(-40)
    end)

    it("converts the edge correction through the viewer's local scale", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 0.8)

        resize(viewer, 160, 80, "BOTTOM")

        local _, bottom = viewer:GetRect()
        expect(bottom).to_equal(100)
        expect(select(5, viewer:GetPoint(1))).to_equal(50)
    end)

    it("preserves right edge for vertical growth left", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 40, 160, 1)

        resize(viewer, 80, 160, "RIGHT")

        local left, _, width = viewer:GetRect()
        expect(left).to_equal(-20)
        expect(left + width).to_equal(60)
        expect(select(4, viewer:GetPoint(1))).to_equal(-40)
    end)

    it("preserves left edge for vertical growth right", function()
        local viewer = newViewer("TOPRIGHT", 20, 100, 40, 160, 1)

        resize(viewer, 80, 160, "LEFT")

        local left, _, width = viewer:GetRect()
        expect(left).to_equal(20)
        expect(left + width).to_equal(100)
        expect(select(4, viewer:GetPoint(1))).to_equal(40)
    end)

    it("uses cached stable edge when Blizzard already resized before our layout", function()
        local viewer = newViewer("TOP", 1313, 419, 204, 40, 1)

        resize(viewer, 204, 40, "BOTTOM")

        -- Simulate Blizzard's grid layout running first on the next update:
        -- the viewer is already two rows tall and top-anchored before ECDM
        -- gets to enforce its Growth Up layout.
        viewer._bottom = 378
        viewer._height = 81
        viewer._originBottom = 378
        viewer._originTop = 459

        resize(viewer, 204, 81, "BOTTOM")

        local _, bottom, _, height = viewer:GetRect()
        expect(bottom).to_equal(419)
        expect(bottom + height).to_equal(500)
    end)

    it("pins Blizzard's resize layout to the custom grid size", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 1)

        resize(viewer, 160, 120, "BOTTOM")

        local fixedWidth, fixedHeight = viewer:GetFixedSize()
        expect(fixedWidth).to_equal(160)
        expect(fixedHeight).to_equal(120)

        -- ResizeLayoutMixin starts every pass at 1x1, then uses fixed size
        -- when supplied. The synchronous native pass must end at the same
        -- dimensions and preserved edge as Enhanced CDM's layout.
        viewer:SetSize(1, 1)
        viewer:SetSize(fixedWidth, fixedHeight)

        local _, bottom, _, height = viewer:GetRect()
        expect(bottom).to_equal(100)
        expect(height).to_equal(120)
    end)

    it("restores the stable edge when Blizzard reapplies the source anchor", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 1)

        resize(viewer, 160, 80, "BOTTOM")

        -- Blizzard reapplies the original Edit Mode point after the frame has
        -- already grown to two rows.
        viewer._points[1].offsetY = 0
        viewer._bottom = 60

        resize(viewer, 160, 80, "BOTTOM")

        local _, bottom = viewer:GetRect()
        expect(bottom).to_equal(100)
        expect(select(5, viewer:GetPoint(1))).to_equal(40)
    end)

    it("adopts a genuinely new anchor as the stable edge", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 1)

        resize(viewer, 160, 80, "BOTTOM")

        -- A different Edit Mode position matches neither the source anchor
        -- nor ECDM's corrected runtime anchor.
        viewer._points[1].offsetY = 20
        viewer._bottom = 80
        ns._InvalidateStableEdge(viewer)

        resize(viewer, 160, 80, "BOTTOM")

        local _, bottom = viewer:GetRect()
        expect(bottom).to_equal(80)
        expect(select(5, viewer:GetPoint(1))).to_equal(20)
    end)

    it("adopts the current edge after effective scale changes", function()
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 1)

        resize(viewer, 160, 80, "BOTTOM")
        viewer._effectiveScale = 0.8
        viewer._bottom = 120

        resize(viewer, 160, 80, "BOTTOM")

        local _, bottom = viewer:GetRect()
        expect(bottom).to_equal(120)
    end)

    it("follows movement of the relative anchor frame", function()
        local relativeFrame = {
            _bottom = 0,
            GetEffectiveScale = function() return 1 end,
            GetRect = function(self) return 0, self._bottom, 300, 300 end,
        }
        local viewer = newViewer("TOPLEFT", 20, 100, 160, 40, 1)
        viewer._points[1].relativeTo = relativeFrame

        resize(viewer, 160, 80, "BOTTOM")
        relativeFrame._bottom = 50
        viewer._bottom = 150

        resize(viewer, 160, 80, "BOTTOM")

        local _, bottom = viewer:GetRect()
        expect(bottom).to_equal(150)
    end)

    it("keeps cached edge across viewer replacement when anchor points match", function()
        local firstViewer = newViewer("TOP", 1334, 378, 204, 40, 1, "BuffIconCooldownViewer")

        resize(firstViewer, 204, 40, "BOTTOM")

        firstViewer._bottom = 339
        firstViewer._height = 81
        firstViewer._originBottom = 339
        firstViewer._originTop = 420
        resize(firstViewer, 204, 81, "BOTTOM")

        local _, _, _, _, stableOffsetY = firstViewer:GetPoint(1)
        local replacementViewer = newViewer("TOP", 1334, 419, 204, 40, 1, "BuffIconCooldownViewer")
        replacementViewer._points[1].offsetY = stableOffsetY
        replacementViewer._originTop = 420

        resize(replacementViewer, 204, 40, "BOTTOM")

        local _, bottom, _, height = replacementViewer:GetRect()
        expect(bottom).to_equal(378)
        expect(bottom + height).to_equal(418)
    end)
end)

describe("Tracked bar stable edge", function()
    it("preserves the top edge for horizontal and downward layouts", function()
        expect(ns._GetBarsPreserveEdge(true, true)).to_equal("TOP")
        expect(ns._GetBarsPreserveEdge(false, true)).to_equal("TOP")
    end)

    it("preserves the bottom edge for upward vertical growth", function()
        expect(ns._GetBarsPreserveEdge(false, false)).to_equal("BOTTOM")
    end)
end)

describe("Cooldown grid stable edge", function()
    it("preserves the leading edge for each growth direction", function()
        expect(ns._GetGridPreserveEdge(false, true)).to_equal("TOP")
        expect(ns._GetGridPreserveEdge(false, false)).to_equal("BOTTOM")
        expect(ns._GetGridPreserveEdge(true, true)).to_equal("LEFT")
        expect(ns._GetGridPreserveEdge(true, false)).to_equal("RIGHT")
    end)
end)
