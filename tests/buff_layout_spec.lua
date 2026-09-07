local points = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local function near(actual, expected)
  assert(math.abs(actual - expected) < 0.00001, string.format("expected %.6f, got %.6f", expected, actual))
end

local function rect(frame)
  return { frame:_ScreenRect() }
end

local function sameRect(frame, expected)
  local actual = rect(frame)
  for index = 1, 4 do
    near(actual[index], expected[index])
  end
end

local function setup(ns, client, vertical, point, iconScale)
  client.UIParent = client._GeometryFrame("UIParent")
  client.UIParent:SetSize(1920, 1080)
  local viewer = client._GeometryFrame("BuffIconCooldownViewer", client.UIParent)
  viewer.iconPadding = 5
  viewer.GetAdditionalPaddingOffset = function()
    return -4
  end
  viewer.IsHorizontal = function(self)
    return not self._vertical
  end
  viewer._vertical = vertical
  viewer:SetPoint(point or "TOP", client.UIParent, "CENTER", 30, 60)
  viewer.Selection = client._GeometryFrame(nil, viewer)
  viewer.Selection:SetPoint("TOPLEFT", viewer, "TOPLEFT", 0, 0)
  viewer.Selection:SetPoint("BOTTOMRIGHT", viewer, "BOTTOMRIGHT", 0, 0)
  local icons = {}
  local function configure(count, shown)
    for index = 1, math.max(2, count, #icons) do
      local icon = icons[index]
      if not icon then
        icon = client._GeometryFrame(nil, viewer)
        icons[index] = icon
      end
      icon._scale = iconScale or 1
      icon.cooldownID = index <= count and index or nil
      icon.layoutIndex = index <= math.max(2, count) and index or nil
      icon:SetShown(index <= count and (not shown or shown[index] == true))
    end
  end
  -- Simulate native layout's point writes followed by its temporary and final
  -- sizes, with real post-hook ordering instead of calling the addon alone
  function viewer:Layout()
    for _, icon in ipairs(icons) do
      if icon.layoutIndex then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", self, "TOPLEFT", (icon.layoutIndex - 1) * 41, 0)
      end
    end
    self:SetSize(1, 1)
    self:SetSize(math.max(1, #icons * 41 - 1), 40)
    client._RunHooks(self, "Layout")
  end
  configure(0)
  for _, name in ipairs({ "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
    client.CreateFrame("Frame", name)
  end
  client._FireEvent("PLAYER_ENTERING_WORLD")
  client._RunPendingTimers()
  return viewer, icons, configure
end

local function assertGrid(viewer, icons, count, capacity, vertical, forward, align, scale)
  local left, bottom, width, height = viewer:_ScreenRect()
  local unit = scale * viewer:GetEffectiveScale()
  near(width, (vertical and 40 or capacity * 41 - 1) * unit)
  near(height, (vertical and capacity * 41 - 1 or 40) * unit)
  local sl, sb, sw, sh = viewer.Selection:_ScreenRect()
  local lines = math.max(1, math.ceil(count / capacity))
  near(sw, (vertical and lines * 41 - 1 or capacity * 41 - 1) * unit)
  near(sh, (vertical and capacity * 41 - 1 or lines * 41 - 1) * unit)
  near(sl, vertical and not forward and left + width - sw or left)
  near(sb, not vertical and forward and bottom + height - sh or bottom)
  expect(viewer.Selection:GetNumPoints()).to_equal(2)
  for index = 1, count do
    local il, ib, iw, ih = icons[index]:_ScreenRect()
    near(iw, 40 * unit)
    near(ih, 40 * unit)
    assert(il >= sl - 0.00001 and il + iw <= sl + sw + 0.00001, "icon outside selection horizontally")
    assert(ib >= sb - 0.00001 and ib + ih <= sb + sh + 0.00001, "icon outside selection vertically")
    local line = math.floor((index - 1) / capacity)
    if vertical then
      near(forward and il or il + iw, forward and left + line * 41 * unit or left + width - line * 41 * unit)
    else
      near(forward and ib + ih or ib, forward and bottom + height - line * 41 * unit or bottom + line * 41 * unit)
    end
    local last = math.min(count, (line + 1) * capacity)
    local first = line * capacity + 1
    local fl, fb, fw, fh = icons[first]:_ScreenRect()
    local ll, lb, lw = icons[last]:_ScreenRect()
    if vertical then
      if align == "LEFT" then
        near(fb + fh, bottom + height)
      elseif align == "RIGHT" then
        near(lb, bottom)
      else
        near((fb + fh + lb) / 2, bottom + height / 2)
      end
    else
      if align == "LEFT" then
        near(fl, left)
      elseif align == "RIGHT" then
        near(ll + lw, left + width)
      else
        near((fl + ll + lw) / 2, left + width / 2)
      end
    end
    if index > first then
      local pl, pb = icons[index - 1]:_ScreenRect()
      if vertical then
        near(pb - ib, 41 * unit)
      else
        near(il - pl, 41 * unit)
      end
    end
  end
end

describe("Tracked buff starting footprint", function()
  for _, vertical in ipairs({ false, true }) do
    for _, forward in ipairs({ false, true }) do
      for _, layout in ipairs({ "STATIC", "DYNAMIC" }) do
        for _, align in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
          local name = (vertical and "vertical " or "horizontal ") .. (forward and "forward " or "reverse ") .. layout .. " " .. align
          it("keeps every capacity stable across row boundaries: " .. name, function()
            _WithAddon({ growDirection = forward and "DOWN" or "UP", layout = layout, align = align }, function(ns, client)
              local viewer, icons, configure = setup(ns, client, vertical)
              for capacity = 1, 40 do
                ns.Settings.Set("maxPerRow", capacity)
                configure(capacity)
                viewer:Layout()
                local footprint = rect(viewer)
                for _, count in ipairs({ 1, capacity - 1, capacity, capacity + 1, capacity * 2, capacity * 2 + 1, capacity, 1, 0 }) do
                  configure(count)
                  viewer:Layout()
                  sameRect(viewer, footprint)
                  assertGrid(viewer, icons, count, capacity, vertical, forward, align, 1)
                  client._RunPendingTimers()
                  sameRect(viewer, footprint)
                end
              end
            end)
          end)
        end
      end
    end
  end

  it("keeps all nine saved anchors and nested scales stable without point corrections", function()
    for _, point in ipairs(points) do
      for _, vertical in ipairs({ false, true }) do
        for _, scale in ipairs({ 0.65, 1, 1.75 }) do
          _WithAddon({ growDirection = "UP" }, function(ns, client)
            local viewer, icons, configure = setup(ns, client, vertical, point, scale)
            client.UIParent._scale = 0.8
            viewer._scale = 0.9
            configure(6)
            viewer:Layout()
            local footprint = rect(viewer)
            for _, count in ipairs({ 7, 14, 2, 0, 6 }) do
              configure(count)
              viewer:Layout()
              viewer:SetPoint(point, client.UIParent, "CENTER", 30, 60)
              client._RunHooks(viewer, "UpdateSystem")
              client._FireEvent("EDIT_MODE_LAYOUTS_UPDATED")
              client._RunPendingTimers()
              sameRect(viewer, footprint)
              assertGrid(viewer, icons, count, 6, vertical, false, "CENTER", scale)
              expect(select(4, viewer:GetPoint(1))).to_equal(30)
              expect(select(5, viewer:GetPoint(1))).to_equal(60)
              expect(viewer:GetNumPoints()).to_equal(1)
            end
          end)
        end
      end
    end
  end)

  it("keeps Static slots and packs Dynamic auras without moving the outline", function()
    _WithAddon({ growDirection = "UP", align = "LEFT", maxPerRow = 3 }, function(ns, client)
      local viewer, icons, configure = setup(ns, client)
      configure(7)
      viewer:Layout()
      local outline, seventh = rect(viewer.Selection), rect(icons[7])
      configure(7, { [2] = true, [4] = true, [7] = true })
      viewer:Layout()
      sameRect(icons[7], seventh)
      sameRect(viewer.Selection, outline)
      ns.Settings.Set("layout", "DYNAMIC")
      viewer:Layout()
      local left, bottom = viewer:_ScreenRect()
      near(select(1, icons[2]:_ScreenRect()), left)
      near(select(1, icons[4]:_ScreenRect()), left + 41)
      near(select(1, icons[7]:_ScreenRect()), left + 82)
      near(select(2, icons[7]:_ScreenRect()), bottom)
      configure(7, {})
      viewer:Layout()
      sameRect(viewer.Selection, outline)
      configure(7)
      viewer:Layout()
      sameRect(icons[7], seventh)
      sameRect(viewer.Selection, outline)
    end)
  end)

  it("keeps the first row in place when Growth flips and uses the newest queued settings", function()
    _WithAddon(nil, function(ns, client)
      local viewer, icons, configure = setup(ns, client)
      configure(14)
      viewer:Layout()
      local firstRow = rect(icons[1])
      ns.Settings.Set("growDirection", "UP")
      ns.ApplyLayout()
      sameRect(icons[1], firstRow)
      for capacity = 1, 40 do
        ns.Settings.Set("maxPerRow", capacity)
        ns.ScheduleLayout()
      end
      expect(client._GetPendingTimerCount()).to_equal(1)
      ns.Settings.Set("growDirection", "DOWN")
      ns.Settings.Set("align", "RIGHT")
      viewer._vertical = true
      client._RunPendingTimers()
      assertGrid(viewer, icons, 14, 40, true, true, "RIGHT", 1)
    end)
  end)

  it("follows a snapped frame and preserves the gap when rows grow", function()
    _WithAddon({ growDirection = "UP" }, function(ns, client)
      local viewer, _, configure = setup(ns, client)
      local relative = client._GeometryFrame(nil, client.UIParent)
      relative:SetSize(400, 80)
      relative:SetPoint("CENTER", client.UIParent, "CENTER", 0, -150)
      viewer:ClearAllPoints()
      viewer:SetPoint("BOTTOM", relative, "TOP", 0, 12)
      for _, offset in ipairs({ -150, 25, -30 }) do
        relative:SetPoint("CENTER", client.UIParent, "CENTER", 0, offset)
        for _, count in ipairs({ 6, 14, 1, 0 }) do
          configure(count)
          viewer:Layout()
          client._RunHooks(viewer, "OnAnyEditModeSystemAnchorChanged")
          client._RunPendingTimers()
          local _, rb, _, rh = relative:_ScreenRect()
          near(select(2, viewer:_ScreenRect()) - rb - rh, 12)
        end
      end
    end)
  end)

  it("reconstructs the same starting row from saved points on a fresh reload", function()
    local expected
    for _, count in ipairs({ 6, 14, 1, 0, 14 }) do
      _WithAddon({ growDirection = "UP" }, function(ns, client)
        local viewer, _, configure = setup(ns, client)
        configure(count)
        viewer:Layout()
        if expected then
          sameRect(viewer, expected)
        else
          expected = rect(viewer)
        end
        expect(client._GetPendingTimerCount()).to_equal(0)
      end)
    end
  end)

  it("recovers from delayed frames and dimensions without stale selection bounds", function()
    _WithAddon({ growDirection = "UP" }, function(ns, client)
      local viewer, icons, configure = setup(ns, client)
      configure(14)
      viewer:Layout()
      local footprint = rect(viewer)
      local children = viewer._children
      viewer._children = { viewer.Selection }
      ns.ApplyLayout()
      sameRect(viewer.Selection, footprint)
      viewer._children = children
      icons[1]._width, icons[1]._height = 0, 0
      ns.ApplyLayout()
      sameRect(viewer.Selection, footprint)
      icons[1]._width, icons[1]._height = 40, 40
      ns.ApplyLayout()
      assertGrid(viewer, icons, 14, 6, false, false, "CENTER", 1)
    end)
  end)

  it("keeps the starting row fixed near screen edges even when more rows extend offscreen", function()
    _WithAddon({ growDirection = "UP" }, function(ns, client)
      local viewer, _, configure = setup(ns, client)
      viewer._clamped = true
      viewer:ClearAllPoints()
      viewer:SetPoint("TOP", client.UIParent, "TOP", 0, -10)
      configure(6)
      viewer:Layout()
      local footprint = rect(viewer)
      configure(14)
      viewer:Layout()
      viewer:UpdateClampOffsets()
      sameRect(viewer, footprint)
      local _, bottom, _, height = viewer.Selection:_ScreenRect()
      assert(bottom + height > client.UIParent:GetHeight(), "extra rows should grow beyond the screen, not move the anchor")
      for _, inset in ipairs(viewer._clampInsets) do
        near(inset, 0)
      end
    end)
  end)

  it("uses current ordering and releases obsolete slots when Blizzard recycles icons", function()
    _WithAddon({ growDirection = "UP", align = "LEFT", maxPerRow = 3 }, function(ns, client)
      local viewer, icons, configure = setup(ns, client)
      configure(7)
      viewer:Layout()
      local first = rect(icons[1])
      icons[1].layoutIndex, icons[7].layoutIndex = 7, 1
      for _, callback in ipairs(client.CooldownViewerItemDataMixin._secureHooks.SetCooldownID) do
        callback(icons[1], 1)
      end
      client._RunPendingTimers()
      sameRect(icons[7], first)
      configure(1)
      viewer:Layout()
      expect(icons[7]._arTargetX).to_be_nil()
      expect(icons[7]._arTargetY).to_be_nil()
      configure(7)
      viewer:Layout()
      sameRect(icons[1], first)
      assertGrid(viewer, icons, 7, 3, false, false, "LEFT", 1)
    end)
  end)

  it("applies icon size, spacing, UI scale, and resolution changes before later row changes", function()
    _WithAddon({ growDirection = "UP", align = "LEFT", maxPerRow = 3 }, function(ns, client)
      local viewer, icons, configure = setup(ns, client)
      configure(7)
      for _, padding in ipairs({ 0, 5, 20 }) do
        viewer.iconPadding = padding
        for _, icon in ipairs(icons) do
          icon._width, icon._height, icon._scale = 48, 32, 1.25
        end
        client.UIParent._scale = 0.75
        client.UIParent:SetSize(2560, 1440)
        client._FireEvent("UI_SCALE_CHANGED")
        client._FireEvent("DISPLAY_SIZE_CHANGED")
        client._RunPendingTimers()
        local unit = 1.25 * 0.75
        local x1, y1 = icons[1]:_ScreenRect()
        local x2 = icons[2]:_ScreenRect()
        local _, y4 = icons[4]:_ScreenRect()
        near(x2 - x1, (48 + padding - 4) * unit)
        near(y4 - y1, (32 + padding - 4) * unit)
        local footprint = rect(viewer)
        for index = 4, 7 do
          icons[index].cooldownID = nil
        end
        viewer:Layout()
        sameRect(viewer, footprint)
        for index = 4, 7 do
          icons[index].cooldownID = index
        end
      end
    end)
  end)

  it("accepts movement and reset points without accumulating offsets", function()
    _WithAddon({ growDirection = "UP" }, function(ns, client)
      local viewer, _, configure = setup(ns, client)
      for _, method in ipairs({ "OnSystemPositionChange", "ResetToDefaultPosition", "UpdateSystem" }) do
        viewer:ClearAllPoints()
        viewer:SetPoint("BOTTOMLEFT", client.UIParent, "BOTTOMLEFT", 300, 250)
        client._RunHooks(viewer, method)
        client._RunPendingTimers()
        for _, count in ipairs({ 14, 6, 1, 0 }) do
          configure(count)
          viewer:Layout()
          local left, bottom = viewer:_ScreenRect()
          near(left, 300)
          near(bottom, 250)
        end
      end
    end)
  end)

  it("recovers a late selection and isolates callbacks from a replaced viewer", function()
    _WithAddon({ growDirection = "UP" }, function(ns, client)
      local previous, _, configure = setup(ns, client)
      configure(14)
      local selection = previous.Selection
      previous.Selection = nil
      previous:Layout()
      previous.Selection = selection
      previous:Layout()
      near(select(4, selection:_ScreenRect()), 122)
      ns.ScheduleLayout()
      local viewer, icons, configureReplacement = setup(ns, client)
      configureReplacement(7)
      viewer:Layout()
      local footprint = rect(viewer)
      previous:Layout()
      previous:UpdateClampOffsets()
      client._RunHooks(previous, "UpdateSystem")
      client._RunPendingTimers()
      sameRect(viewer, footprint)
      assertGrid(viewer, icons, 7, 6, false, false, "CENTER", 1)
      expect(#viewer._secureHooks.Layout).to_equal(1)
      expect(#viewer._secureHooks.UpdateClampOffsets).to_equal(1)
    end)
  end)
end)
