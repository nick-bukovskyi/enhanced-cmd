-- Opt-in frame geometry for layout regressions, in root UI coordinates
-- This models anchor/scale math and hook order, not WoW security or rendering
local fractions = {
  TOPLEFT = { 0, 1 },
  TOP = { 0.5, 1 },
  TOPRIGHT = { 1, 1 },
  LEFT = { 0, 0.5 },
  CENTER = { 0.5, 0.5 },
  RIGHT = { 1, 0.5 },
  BOTTOMLEFT = { 0, 0 },
  BOTTOM = { 0.5, 0 },
  BOTTOMRIGHT = { 1, 0 },
}

local function resolveAxis(points, axis, size)
  local first = points[1]
  if not first then
    return 0, size
  end
  local fraction = fractions[first.point][axis]
  local position = first[axis]
  for index = 2, #points do
    local other = points[index]
    local otherFraction = fractions[other.point][axis]
    if otherFraction ~= fraction then
      size = (other[axis] - position) / (otherFraction - fraction)
      break
    end
  end
  return position - size * fraction, size
end

function _G._GeometryFrame(name, parent)
  local frame = CreateFrame("Frame", name, parent)
  frame._points = {}
  frame._width, frame._height = 40, 40

  function frame:GetEffectiveScale()
    return self:GetScale() * (self._parent and self._parent:GetEffectiveScale() or 1)
  end

  function frame:_ScreenRect()
    local scale = self:GetEffectiveScale()
    local resolved = {}
    for index, point in ipairs(self._points) do
      local left, bottom, width, height = point.relativeTo:_ScreenRect()
      local relativeFraction = fractions[point.relativePoint]
      resolved[index] = {
        point = point.point,
        left + width * relativeFraction[1] + point.offsetX * scale,
        bottom + height * relativeFraction[2] + point.offsetY * scale,
      }
    end
    local left, width = resolveAxis(resolved, 1, self._width * scale)
    local bottom, height = resolveAxis(resolved, 2, self._height * scale)
    if self._clamped then
      local _, _, screenWidth, screenHeight = UIParent:_ScreenRect()
      local insets = self._clampInsets or { 0, 0, 0, 0 }
      left = math.max(-insets[1] * scale, math.min(left, screenWidth - width - insets[2] * scale))
      bottom = math.max(-insets[4] * scale, math.min(bottom, screenHeight - height - insets[3] * scale))
    end
    return left, bottom, width, height
  end

  function frame:GetRect()
    local left, bottom, width, height = self:_ScreenRect()
    local scale = self:GetEffectiveScale()
    return left / scale, bottom / scale, width / scale, height / scale
  end

  function frame:GetWidth()
    return select(3, self:GetRect())
  end

  function frame:GetHeight()
    return select(4, self:GetRect())
  end

  function frame:GetSize()
    return self:GetWidth(), self:GetHeight()
  end

  function frame:GetNumPoints()
    return #self._points
  end

  function frame:GetPoint(index)
    local point = self._points[index or 1]
    if point then
      return point.point, point.relativeTo, point.relativePoint, point.offsetX, point.offsetY
    end
  end

  function frame:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    assert(fractions[point] and fractions[relativePoint], "invalid anchor point")
    assert(type(relativeTo) == "table" and relativeTo ~= self, "invalid relative frame")
    assert(type(offsetX) == "number" and type(offsetY) == "number", "invalid offsets")
    local slot = #self._points + 1
    for index, previous in ipairs(self._points) do
      if previous.point == point then
        slot = index
        break
      end
    end
    self._points[slot] = {
      point = point,
      relativeTo = relativeTo,
      relativePoint = relativePoint,
      offsetX = offsetX,
      offsetY = offsetY,
    }
    _RunHooks(self, "SetPoint", point, relativeTo, relativePoint, offsetX, offsetY)
  end

  function frame:ClearAllPoints()
    self._points = {}
  end

  frame.SetPointBase = frame.SetPoint
  frame.ClearAllPointsBase = frame.ClearAllPoints

  function frame:SetSize(width, height)
    assert(type(width) == "number" and width > 0, "invalid width")
    assert(type(height) == "number" and height > 0, "invalid height")
    self._width, self._height = width, height
    _RunHooks(self, "SetSize", width, height)
  end

  function frame:SetShown(shown)
    assert(type(shown) == "boolean", "SetShown requires a boolean")
    self._shown = shown
    _RunHooks(self, "SetShown", shown)
  end

  function frame:UpdateClampOffsets()
    local left, bottom, width, height = self:_ScreenRect()
    local sl, sb, sw, sh = self.Selection:_ScreenRect()
    local scale = self:GetEffectiveScale()
    self._clampInsets =
      { (sl - left) / scale, (sl + sw - left - width) / scale, (sb + sh - bottom - height) / scale, (sb - bottom) / scale }
    _RunHooks(self, "UpdateClampOffsets")
  end

  function frame:SetFixedSize()
    error("must not write Blizzard's secure layout fields")
  end

  return frame
end
