-- Tests for CalcGridPosition — grid layout math
local ns = _G._test_ns

describe("CalcGridPosition", function()
  local calc = ns._CalcGridPosition

  -- Common test values: 36px icons, 2px spacing, 6 per row
  local W, H, S = 36, 36, 2

  it("places first icon at origin (LEFT align)", function()
    local fullRowWidth = 6 * (W + S) - S
    local x, y = calc(1, 6, W, H, S, "LEFT", 6, fullRowWidth)
    expect(x).to_equal(0)
    expect(y).to_equal(0)
  end)

  it("places icons left-to-right in a row", function()
    local fullRowWidth = 6 * (W + S) - S
    local x2, y2 = calc(2, 6, W, H, S, "LEFT", 6, fullRowWidth)
    expect(x2).to_equal(W + S) -- 38
    expect(y2).to_equal(0)

    local x3, y3 = calc(3, 6, W, H, S, "LEFT", 6, fullRowWidth)
    expect(x3).to_equal(2 * (W + S)) -- 76
    expect(y3).to_equal(0)
  end)

  it("wraps to next row at maxPerRow", function()
    local fullRowWidth = 3 * (W + S) - S
    -- 4th icon with maxPerRow=3 → row 1, col 0
    local x, y = calc(4, 3, W, H, S, "LEFT", 6, fullRowWidth)
    expect(x).to_equal(0)
    expect(y).to_equal(H + S) -- 38
  end)

  it("calculates correct position for last icon in partial row", function()
    local fullRowWidth = 4 * (W + S) - S
    -- 7th icon with maxPerRow=4 → row 1, col 2
    local x, y = calc(7, 4, W, H, S, "LEFT", 7, fullRowWidth)
    expect(x).to_equal(2 * (W + S))
    expect(y).to_equal(H + S)
  end)

  it("centers incomplete last row with CENTER align", function()
    local maxPerRow = 4
    local totalIcons = 5
    local fullRowWidth = maxPerRow * (W + S) - S -- 150

    -- Row 0: 4 icons → full width, no offset
    local x1, y1 = calc(1, maxPerRow, W, H, S, "CENTER", totalIcons, fullRowWidth)
    expect(x1).to_equal(0)

    -- Row 1: 1 icon → rowWidth = 36, offset = (150 - 36) / 2 = 57
    local x5, y5 = calc(5, maxPerRow, W, H, S, "CENTER", totalIcons, fullRowWidth)
    expect(x5).to_equal((fullRowWidth - W) / 2)
    expect(y5).to_equal(H + S)
  end)

  it("right-aligns incomplete last row with RIGHT align", function()
    local maxPerRow = 4
    local totalIcons = 5
    local fullRowWidth = maxPerRow * (W + S) - S -- 150

    -- Row 1: 1 icon → rowWidth = 36, offset = 150 - 36 = 114
    local x5, y5 = calc(5, maxPerRow, W, H, S, "RIGHT", totalIcons, fullRowWidth)
    expect(x5).to_equal(fullRowWidth - W)
    expect(y5).to_equal(H + S)
  end)

  it("does not offset full rows regardless of alignment", function()
    local maxPerRow = 3
    local totalIcons = 6
    local fullRowWidth = maxPerRow * (W + S) - S

    -- Full row with CENTER → offset should be 0
    local x1c = calc(1, maxPerRow, W, H, S, "CENTER", totalIcons, fullRowWidth)
    expect(x1c).to_equal(0)

    -- Full row with RIGHT → offset should be 0
    local x1r = calc(1, maxPerRow, W, H, S, "RIGHT", totalIcons, fullRowWidth)
    expect(x1r).to_equal(0)
  end)

  it("handles maxPerRow=1 (single column)", function()
    local fullRowWidth = W
    local x1, y1 = calc(1, 1, W, H, S, "LEFT", 3, fullRowWidth)
    expect(x1).to_equal(0)
    expect(y1).to_equal(0)

    local x2, y2 = calc(2, 1, W, H, S, "LEFT", 3, fullRowWidth)
    expect(x2).to_equal(0)
    expect(y2).to_equal(H + S)

    local x3, y3 = calc(3, 1, W, H, S, "LEFT", 3, fullRowWidth)
    expect(x3).to_equal(0)
    expect(y3).to_equal(2 * (H + S))
  end)

  it("handles zero spacing", function()
    local fullRowWidth = 3 * W
    local x2, y2 = calc(2, 3, W, H, 0, "LEFT", 3, fullRowWidth)
    expect(x2).to_equal(W)
    expect(y2).to_equal(0)

    local x4, y4 = calc(4, 3, W, H, 0, "LEFT", 4, fullRowWidth)
    expect(x4).to_equal(0)
    expect(y4).to_equal(H)
  end)

  it("handles single icon with CENTER align", function()
    local maxPerRow = 6
    local fullRowWidth = maxPerRow * (W + S) - S

    local x, y = calc(1, maxPerRow, W, H, S, "CENTER", 1, fullRowWidth)
    expect(x).to_equal((fullRowWidth - W) / 2)
    expect(y).to_equal(0)
  end)

  -- Vertical orientation tests
  it("fills top-to-bottom in vertical mode", function()
    local fullRowWidth = 3 * (W + S) - S
    local x1, y1 = calc(1, 3, W, H, S, "LEFT", 5, fullRowWidth, true)
    expect(x1).to_equal(0)
    expect(y1).to_equal(0)

    local x2, y2 = calc(2, 3, W, H, S, "LEFT", 5, fullRowWidth, true)
    expect(x2).to_equal(0)
    expect(y2).to_equal(H + S)

    local x3, y3 = calc(3, 3, W, H, S, "LEFT", 5, fullRowWidth, true)
    expect(x3).to_equal(0)
    expect(y3).to_equal(2 * (H + S))
  end)

  it("wraps to next column in vertical mode", function()
    local fullRowWidth = 3 * (W + S) - S
    -- 4th icon with maxPerCol=3 → col 1, row 0
    local x, y = calc(4, 3, W, H, S, "LEFT", 5, fullRowWidth, true)
    expect(x).to_equal(W + S)
    expect(y).to_equal(0)
  end)

  it("centers partial last column in vertical mode", function()
    local maxPerCol = 3
    local totalIcons = 5
    local fullRowWidth = maxPerCol * (W + S) - S

    -- Column 0: 3 icons (full) — no offset
    local x1, y1 = calc(1, maxPerCol, W, H, S, "CENTER", totalIcons, fullRowWidth, true)
    expect(y1).to_equal(0)

    -- Column 1: 2 icons — centered vertically
    local fullColHeight = maxPerCol * (H + S) - S
    local lastColHeight = 2 * (H + S) - S
    local x4, y4 = calc(4, maxPerCol, W, H, S, "CENTER", totalIcons, fullRowWidth, true)
    expect(x4).to_equal(W + S)
    expect(y4).to_equal((fullColHeight - lastColHeight) / 2)
  end)

  it("right-aligns partial last column in vertical mode", function()
    local maxPerCol = 3
    local totalIcons = 4
    local fullRowWidth = maxPerCol * (W + S) - S

    -- Column 1: 1 icon — pushed to bottom
    local fullColHeight = maxPerCol * (H + S) - S
    local x4, y4 = calc(4, maxPerCol, W, H, S, "RIGHT", totalIcons, fullRowWidth, true)
    expect(x4).to_equal(W + S)
    expect(y4).to_equal(fullColHeight - H)
  end)
end)
