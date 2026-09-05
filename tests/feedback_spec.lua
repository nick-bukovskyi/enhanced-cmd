-- Tests for action identity and click feedback
local ns = _G._test_ns

describe("Spell action identity", function()
  local getSlotSpellID = ns._GetSlotActionIDs

  it("returns nil for nil slot", function()
    expect(getSlotSpellID(nil)).to_be_nil()
  end)

  it("returns nil for slot 0", function()
    expect(getSlotSpellID(0)).to_be_nil()
  end)

  it("returns spellID for spell-type action", function()
    _G._stubActionInfo[5] = { type = "spell", id = 12345 }
    expect(getSlotSpellID(5)).to_equal(12345)
    _G._stubActionInfo[5] = nil
  end)

  it("returns nil for empty slot", function()
    expect(getSlotSpellID(99)).to_be_nil()
  end)

  it("resolves macro to spellID via GetMacroSpell", function()
    _G._stubActionInfo[10] = { type = "macro", id = 42 }
    _G._stubMacroSpells[42] = 67890
    expect(getSlotSpellID(10)).to_equal(67890)
    _G._stubActionInfo[10] = nil
    _G._stubMacroSpells[42] = nil
  end)

  it("returns nil for macro with no spell", function()
    _G._stubActionInfo[10] = { type = "macro", id = 42 }
    _G._stubMacroSpells[42] = nil
    expect(getSlotSpellID(10)).to_be_nil()
    _G._stubActionInfo[10] = nil
  end)

  it("returns nil for non-spell non-macro action types", function()
    _G._stubActionInfo[7] = { type = "item", id = 999 }
    expect(getSlotSpellID(7)).to_be_nil()
    _G._stubActionInfo[7] = nil
  end)

  it("returns nil for macro with nil id", function()
    _G._stubActionInfo[3] = { type = "macro", id = nil }
    expect(getSlotSpellID(3)).to_be_nil()
    _G._stubActionInfo[3] = nil
  end)
end)

local function withFeedback(callback)
  _WithAddon(nil, function(addon, client)
    local viewer = client.CreateFrame("Frame", "EssentialCooldownViewer")
    local icon = client.CreateFrame("Frame", nil, viewer)
    icon.cooldownID, icon.layoutIndex, icon.rangeCheckSpellID = 1, 1, 123
    local button = client.CreateFrame("Button", "ActionButton1")
    button:SetAttribute("action", 1)
    client._stubActionInfo[1] = { type = "spell", id = 123 }
    client._FireEvent("PLAYER_ENTERING_WORLD")
    button:SetButtonState("PUSHED")
    expect(icon._ecdmPushedTex:IsShown()).to_equal(true)
    callback(addon, client, icon, button, viewer)
  end)
end

describe("Pressed icon ownership", function()
  it("releases the original icon after the button moves to another action or an empty slot", function()
    withFeedback(function(addon, client, icon, button)
      button:SetAttribute("action", 13)
      client._stubActionInfo[13] = { type = "spell", id = 456 }
      button:SetButtonState("NORMAL")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      button:SetAttribute("action", 1)
      button:SetButtonState("PUSHED")
      client._stubActionInfo[1] = nil
      button:SetButtonState("NORMAL")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
    end)
  end)

  it("clears feedback on recycling and reassignment before the button is released", function()
    withFeedback(function(addon, client, icon, button)
      icon.cooldownID, icon.rangeCheckSpellID = nil, nil
      client.CooldownViewerItemDataMixin._secureHooks.ResetCooldownData[1](icon)
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      button:SetButtonState("NORMAL")
      icon.cooldownID, icon.rangeCheckSpellID = 2, 456
      client.CooldownViewerItemDataMixin._secureHooks.SetCooldownID[1](icon)
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
    end)
  end)

  it("clears feedback on a new cooldown assignment and action-page changes", function()
    withFeedback(function(addon, client, icon, button)
      local hooks = client.CooldownViewerItemDataMixin._secureHooks
      icon.cooldownID, icon.rangeCheckSpellID = 2, 456
      hooks.SetCooldownID[1](icon)
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      client._stubActionInfo[1] = { type = "spell", id = 456 }
      button:SetButtonState("PUSHED")
      client._FireEvent("ACTIONBAR_PAGE_CHANGED")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      button:SetButtonState("NORMAL")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
    end)
  end)

  it("keeps feedback pressed until both buttons showing the same action are released", function()
    withFeedback(function(addon, client, icon, first)
      local second = client.CreateFrame("Button", "ActionButton2")
      second:SetAttribute("action", 2)
      client._stubActionInfo[2] = { type = "spell", id = 123 }
      client._FireEvent("PLAYER_ENTERING_WORLD")
      second:SetButtonState("PUSHED")
      first:SetButtonState("NORMAL")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(true)
      second:SetButtonState("NORMAL")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
    end)
  end)

  it("immediately clears feedback disabled through slash commands", function()
    withFeedback(function(addon, client, icon, button)
      client._startCapture()
      client.SlashCmdList.ENHANCEDCDM("essential feedback off")
      client._stopCapture()
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      button:SetButtonState("PUSHED")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
    end)
  end)

  it("persists real checkbox booleans and clears feedback disabled in Edit Mode", function()
    withFeedback(function(addon, client, icon, button, viewer)
      local manager = client.CreateFrame("Frame")
      manager.SelectSystem, manager.ClearSelectedSystem, manager.ExitEditMode = function() end, function() end, function() end
      client.EditModeManagerFrame = manager
      local dialog = client.CreateFrame("Frame", "EditModeSystemSettingsDialog")
      dialog.UpdateSettings = function() end
      dialog.Border = client.CreateFrame("Frame", nil, dialog)
      dialog.Settings = client.CreateFrame("Frame", nil, dialog)
      dialog.attachedToSystem = viewer
      addon.SetupEditMode()
      local before = #client._allFrames
      client._RunHooks(manager, "SelectSystem", viewer)
      local checkbox
      for index = before + 1, #client._allFrames do
        local frame = client._allFrames[index]
        if frame:GetObjectType() == "CheckButton" then
          checkbox = frame
          break
        end
      end
      expect(checkbox).to_be_truthy()
      checkbox:SetChecked(false)
      checkbox:GetScript("OnClick")(checkbox)
      expect(addon.db.essential_feedback_show).to_equal(false)
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      checkbox:SetChecked(true)
      checkbox:GetScript("OnClick")(checkbox)
      expect(addon.db.essential_feedback_show).to_equal(true)
      button:SetButtonState("PUSHED")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(true)
    end)
  end)
end)

describe("GetSlotActionIDs", function()
  local getSlotActionIDs = ns._GetSlotActionIDs

  it("returns an itemID for an item action", function()
    _G._stubActionInfo[7] = { type = "item", id = 210816 }

    local spellID, itemID = getSlotActionIDs(7)

    expect(spellID).to_be_nil()
    expect(itemID).to_equal(210816)
    _G._stubActionInfo[7] = nil
  end)

  it("returns both available identities for a macro", function()
    _G._stubActionInfo[10] = { type = "macro", id = 42 }
    _G._stubMacroSpells[42] = 12345
    _G._stubMacroItems[42] = "item:212265:0:0:0"

    local spellID, itemID = getSlotActionIDs(10)

    expect(spellID).to_equal(12345)
    expect(itemID).to_equal(212265)
    _G._stubActionInfo[10] = nil
    _G._stubMacroSpells[42] = nil
    _G._stubMacroItems[42] = nil
  end)

  it("matches an equipped item to its Essential CDM icon", function()
    local oldEssential = ns.essentialViewer
    local essential = CreateFrame("Frame")
    local icon = CreateFrame("Frame", nil, essential)
    icon.cooldownID = 9001
    icon.GetEquipSlot = function()
      return 13
    end
    _G._stubInventoryItems[13] = 219308
    ns.essentialViewer = essential

    expect(ns._FindCDMIcon(nil, 219308)).to_equal(icon)

    ns.essentialViewer = oldEssential
    _G._stubInventoryItems[13] = nil
  end)

  it("prefers an item icon when a macro exposes spell and item IDs", function()
    local oldEssential = ns.essentialViewer
    local essential = CreateFrame("Frame")
    local spellIcon = CreateFrame("Frame", nil, essential)
    spellIcon.cooldownID = 1
    spellIcon.GetBaseSpellID = function()
      return 12345
    end
    local itemIcon = CreateFrame("Frame", nil, essential)
    itemIcon.cooldownID = 2
    itemIcon.GetEquipSlot = function()
      return 13
    end
    _G._stubInventoryItems[13] = 219308
    ns.essentialViewer = essential

    expect(ns._FindCDMIcon(12345, 219308)).to_equal(itemIcon)

    ns.essentialViewer = oldEssential
    _G._stubInventoryItems[13] = nil
  end)
end)

describe("Pushed overlay sizing", function()
  it("refreshes existing overlay size from the current icon size", function()
    local frame = CreateFrame("Frame")
    frame:SetSize(45, 45)

    local overlay = ns._GetPushedOverlay(frame)
    expect(overlay._width).to_equal(51)
    expect(overlay._height).to_equal(51)

    frame:SetSize(90, 30)
    local sameOverlay = ns._GetPushedOverlay(frame)

    expect(sameOverlay).to_equal(overlay)
    expect(sameOverlay._width).to_equal(102)
    expect(sameOverlay._height).to_equal(34)
  end)

  it("updates overlay size from the icon OnSizeChanged hook", function()
    local frame = CreateFrame("Frame")
    frame:SetSize(45, 45)

    local overlay = ns._GetPushedOverlay(frame)
    frame:SetSize(90, 90)
    local hooks = frame._hookScripts and frame._hookScripts.OnSizeChanged
    expect(hooks ~= nil).to_be_truthy()
    hooks[1](frame)

    expect(overlay._width).to_equal(102)
    expect(overlay._height).to_equal(102)
  end)
end)
