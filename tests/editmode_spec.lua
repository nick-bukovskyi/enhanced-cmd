-- Tests for Edit Mode integration hooks and frame scoping
local ns = _G._test_ns

local function makeManager()
  local manager = CreateFrame("Frame")
  manager.SelectSystem = function() end
  manager.ClearSelectedSystem = function() end
  manager.ExitEditMode = function() end
  _G.EditModeManagerFrame = manager
  return manager
end

local function makeDialog()
  local dialog = CreateFrame("Frame", "EditModeSystemSettingsDialog")
  dialog.UpdateSettings = function() end
  dialog.Border = CreateFrame("Frame", nil, dialog)
  dialog.Settings = CreateFrame("Frame", nil, dialog)
  dialog.Settings.Layout = function(self)
    self._layoutCalled = true
  end
  dialog._shown = true
  return dialog
end

local function countHooks(frame, method)
  local hooks = frame and frame._secureHooks and frame._secureHooks[method]
  return hooks and #hooks or 0
end

local function countEnhancedGlobals()
  local count = 0
  for key in pairs(_G) do
    if type(key) == "string" and key:match("^EnhancedCDM") then
      count = count + 1
    end
  end
  return count
end

describe("Edit Mode hook installation", function()
  it("reports partial setup errors and resumes without duplicating manager hooks", function()
    _WithAddon(nil, function(addon, client)
      local manager = client.CreateFrame("Frame")
      manager.SelectSystem = function() end
      manager.ClearSelectedSystem = function() end
      manager.ExitEditMode = function() end
      client.EditModeManagerFrame = manager
      local hook = client.hooksecurefunc
      client.hooksecurefunc = function(target, method, callback)
        if target == manager and method == "ExitEditMode" then
          error("injected Edit Mode hook failure")
        end
        hook(target, method, callback)
      end
      local ok, message = pcall(addon.SetupEditMode)
      expect(ok).to_equal(false)
      expect(message:find("injected Edit Mode hook failure", 1, true)).to_be_truthy()
      client.hooksecurefunc = hook
      addon.SetupEditMode()
      expect(#manager._secureHooks.SelectSystem).to_equal(1)
      expect(#manager._secureHooks.ExitEditMode).to_equal(1)
      local replacement = client.CreateFrame("Frame")
      replacement.SelectSystem = function() end
      replacement.ClearSelectedSystem = function() end
      replacement.ExitEditMode = function() end
      client.EditModeManagerFrame = replacement
      addon.SetupEditMode()
      expect(#replacement._secureHooks.SelectSystem).to_equal(1)
      client._RunHooks(manager, "ExitEditMode")
      expect(client._GetPendingTimerCount()).to_equal(0)
    end)
  end)

  it("installs dialog hooks when the dialog appears after manager setup", function()
    local manager = makeManager()
    _G.EditModeSystemSettingsDialog = nil

    ns.SetupEditMode()
    expect(countHooks(manager, "SelectSystem")).to_equal(1)

    local dialog = makeDialog()
    ns.SetupEditMode()

    expect(countHooks(dialog, "UpdateSettings")).to_equal(1)
  end)

  it("does not duplicate manager hooks on repeated setup", function()
    local manager = _G.EditModeManagerFrame
    local before = countHooks(manager, "SelectSystem")

    ns.SetupEditMode()

    expect(countHooks(manager, "SelectSystem")).to_equal(before)
  end)
end)

describe("Edit Mode frame scoping", function()
  it("does not create EnhancedCDM globals when showing any addon panel", function()
    local manager = _G.EditModeManagerFrame
    local dialog = _G.EditModeSystemSettingsDialog or makeDialog()
    _G.BuffIconCooldownViewer = CreateFrame("Frame")
    _G.BuffBarCooldownViewer = CreateFrame("Frame")
    _G.EssentialCooldownViewer = CreateFrame("Frame")
    _G.UtilityCooldownViewer = CreateFrame("Frame")
    ns.viewer = _G.BuffIconCooldownViewer
    ns.essentialViewer = _G.EssentialCooldownViewer
    ns.utilityViewer = _G.UtilityCooldownViewer
    local before = countEnhancedGlobals()

    local hooks = manager._secureHooks and manager._secureHooks.SelectSystem
    local systems = {
      _G.BuffIconCooldownViewer,
      _G.BuffBarCooldownViewer,
      _G.EssentialCooldownViewer,
      _G.UtilityCooldownViewer,
    }
    for _, system in ipairs(systems) do
      dialog.attachedToSystem = system
      hooks[1](manager, system)
    end

    expect(countEnhancedGlobals()).to_equal(before)
  end)
end)
