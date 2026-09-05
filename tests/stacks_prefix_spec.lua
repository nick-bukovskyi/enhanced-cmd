local ns = _G._test_ns

describe("GetStacksPrefix", function()
  local getPrefix = ns._GetStacksPrefix

  it("returns essential_stacks_ for essential viewer children", function()
    local viewer = CreateFrame("Frame")
    ns.essentialViewer = viewer
    local child = CreateFrame("Frame", nil, viewer)
    expect(getPrefix(child)).to_equal("essential_stacks_")
    ns.essentialViewer = nil
  end)

  it("returns utility_stacks_ for utility viewer children", function()
    local viewer = CreateFrame("Frame")
    ns.utilityViewer = viewer
    local child = CreateFrame("Frame", nil, viewer)
    expect(getPrefix(child)).to_equal("utility_stacks_")
    ns.utilityViewer = nil
  end)

  it("returns buffs_stacks_ for buff viewer children", function()
    local viewer = CreateFrame("Frame")
    ns.viewer = viewer
    local child = CreateFrame("Frame", nil, viewer)
    expect(getPrefix(child)).to_equal("buffs_stacks_")
    ns.viewer = nil
  end)

  it("returns nil for unknown parent", function()
    local other = CreateFrame("Frame")
    local child = CreateFrame("Frame", nil, other)
    expect(getPrefix(child)).to_be_nil()
  end)

  it("returns nil for nil frame", function()
    expect(getPrefix(nil)).to_be_nil()
  end)
end)

describe("GetHotkeyPrefix", function()
  local getPrefix = ns._GetHotkeyPrefix

  it("returns essential_hotkeys_ for essential viewer children", function()
    local viewer = CreateFrame("Frame")
    ns.essentialViewer = viewer
    local child = CreateFrame("Frame", nil, viewer)
    expect(getPrefix(child)).to_equal("essential_hotkeys_")
    ns.essentialViewer = nil
  end)

  it("returns utility_hotkeys_ for utility viewer children", function()
    local viewer = CreateFrame("Frame")
    ns.utilityViewer = viewer
    local child = CreateFrame("Frame", nil, viewer)
    expect(getPrefix(child)).to_equal("utility_hotkeys_")
    ns.utilityViewer = nil
  end)

  it("returns nil for unknown parent", function()
    local other = CreateFrame("Frame")
    local child = CreateFrame("Frame", nil, other)
    expect(getPrefix(child)).to_be_nil()
  end)

  it("returns nil for nil frame", function()
    expect(getPrefix(nil)).to_be_nil()
  end)
end)
