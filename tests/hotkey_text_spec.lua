-- Tests for BuildSlotToBindingMap and GetHotkeyText
local ns = _G._test_ns

-- Helper: create a mock action bar button with a given action slot
local function makeButton(globalName, actionSlot)
  local btn = CreateFrame("Button", globalName)
  if actionSlot then
    btn:SetAttribute("action", actionSlot)
  end
  return btn
end

-- Helper: clean up test state
local function cleanup(...)
  for i = 1, select("#", ...) do
    _G[select(i, ...)] = nil
  end
  wipe(_G._stubBindingKeys)
  wipe(_G._stubSpellActionButtons)
  wipe(_G._stubOverrideSpells)
  wipe(_G._stubActionInfo)
  wipe(_G._stubMacroItems)
  wipe(_G._stubInventoryItems)
end

describe("BuildSlotToBindingMap", function()
  it("maps ActionButton slots to ACTIONBUTTON bindings", function()
    makeButton("ActionButton1", 1)
    ns._BuildSlotToBindingMap()
    _G._stubBindingKeys["ACTIONBUTTON1"] = "1"
    _G._stubSpellActionButtons[100] = { 1 }
    expect(ns._GetHotkeyText(100, false)).to_equal("1")
    cleanup("ActionButton1")
  end)

  it("falls back to button index for ActionButton with nil slot", function()
    makeButton("ActionButton5", nil)
    ns._BuildSlotToBindingMap()
    _G._stubBindingKeys["ACTIONBUTTON5"] = "5"
    _G._stubSpellActionButtons[200] = { 5 }
    expect(ns._GetHotkeyText(200, false)).to_equal("5")
    cleanup("ActionButton5")
  end)

  it("falls back to button index for ActionButton with slot 0", function()
    makeButton("ActionButton3", 0)
    ns._BuildSlotToBindingMap()
    _G._stubBindingKeys["ACTIONBUTTON3"] = "3"
    _G._stubSpellActionButtons[300] = { 3 }
    expect(ns._GetHotkeyText(300, false)).to_equal("3")
    cleanup("ActionButton3")
  end)

  it("maps multi-bar buttons correctly", function()
    makeButton("MultiBarBottomLeftButton1", 61)
    ns._BuildSlotToBindingMap()
    _G._stubBindingKeys["MULTIACTIONBAR1BUTTON1"] = "CTRL-1"
    _G._stubSpellActionButtons[400] = { 61 }
    expect(ns._GetHotkeyText(400, false)).to_equal("CTRL-1")
    cleanup("MultiBarBottomLeftButton1")
  end)
end)

describe("GetHotkeyText", function()
  -- Setup shared buttons for all tests in this block
  local function setup()
    makeButton("ActionButton1", 1)
    makeButton("ActionButton2", 2)
    ns._BuildSlotToBindingMap()
  end

  local function teardown()
    cleanup("ActionButton1", "ActionButton2")
  end

  it("returns nil for nil spellID", function()
    setup()
    expect(ns._GetHotkeyText(nil, true)).to_be_nil()
    teardown()
  end)

  it("returns nil when spell has no action bar slots", function()
    setup()
    expect(ns._GetHotkeyText(9999, true)).to_be_nil()
    teardown()
  end)

  it("returns nil when slot has no binding key", function()
    setup()
    _G._stubSpellActionButtons[500] = { 1 }
    expect(ns._GetHotkeyText(500, true)).to_be_nil()
    teardown()
  end)

  it("returns shortened text when shorten is true", function()
    setup()
    _G._stubSpellActionButtons[12345] = { 1 }
    _G._stubBindingKeys["ACTIONBUTTON1"] = "SHIFT-1"
    expect(ns._GetHotkeyText(12345, true)).to_equal("S1")
    teardown()
  end)

  it("returns raw key when shorten is false", function()
    setup()
    _G._stubSpellActionButtons[12345] = { 1 }
    _G._stubBindingKeys["ACTIONBUTTON1"] = "SHIFT-1"
    expect(ns._GetHotkeyText(12345, false)).to_equal("SHIFT-1")
    teardown()
  end)

  it("uses override spell when primary lookup fails", function()
    setup()
    _G._stubSpellActionButtons[600] = {}
    _G._stubOverrideSpells[600] = 601
    _G._stubSpellActionButtons[601] = { 1 }
    _G._stubBindingKeys["ACTIONBUTTON1"] = "Q"
    expect(ns._GetHotkeyText(600, false)).to_equal("Q")
    teardown()
  end)

  it("does not use override when it equals spellID", function()
    setup()
    _G._stubSpellActionButtons[700] = {}
    _G._stubOverrideSpells[700] = 700
    expect(ns._GetHotkeyText(700, true)).to_be_nil()
    teardown()
  end)

  it("prefers first slot with a bound key", function()
    setup()
    _G._stubSpellActionButtons[800] = { 1, 2 }
    _G._stubBindingKeys["ACTIONBUTTON2"] = "F1"
    -- No key for ACTIONBUTTON1, so should fall through to slot 2
    expect(ns._GetHotkeyText(800, false)).to_equal("F1")
    teardown()
  end)
end)

describe("GetItemHotkeyText", function()
  it("returns the key for a direct item action", function()
    makeButton("ActionButton1", 1)
    ns._BuildSlotToBindingMap()
    _G._stubActionInfo[1] = { type = "item", id = 210816 }
    _G._stubBindingKeys["ACTIONBUTTON1"] = "SHIFT-1"

    expect(ns._GetItemHotkeyText(210816, true)).to_equal("S1")

    cleanup("ActionButton1")
  end)

  it("returns the key for an item macro", function()
    makeButton("ActionButton2", 2)
    ns._BuildSlotToBindingMap()
    _G._stubActionInfo[2] = { type = "macro", id = 42 }
    _G._stubMacroItems[42] = "item:212265:0:0:0"
    _G._stubBindingKeys["ACTIONBUTTON2"] = "Q"

    expect(ns._GetItemHotkeyText(212265, false)).to_equal("Q")

    cleanup("ActionButton2")
  end)
end)

describe("Cooldown item identity", function()
  it("resolves the currently equipped item from a CDM equipment slot", function()
    local frame = {
      GetEquipSlot = function()
        return 13
      end,
      GetBaseSpellID = function()
        return nil
      end,
    }
    _G._stubInventoryItems[13] = 219308

    local spellID, itemID = ns._GetFrameActionIDs(frame)

    expect(spellID).to_be_nil()
    expect(itemID).to_equal(219308)
    wipe(_G._stubInventoryItems)
  end)

  it("resolves a consumable from Blizzard's category item fallback", function()
    local frame = {
      GetBaseSpellID = function()
        return nil
      end,
      GetSpellCategoryTooltipItemID = function()
        return 212265
      end,
    }

    local _, itemID = ns._GetFrameActionIDs(frame)

    expect(itemID).to_equal(212265)
  end)
end)
