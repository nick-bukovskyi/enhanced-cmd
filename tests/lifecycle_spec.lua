local viewerNames = { "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }

local function createAll(client)
  for _, name in ipairs(viewerNames) do
    client.CreateFrame("Frame", name)
  end
end

describe("Viewer lifecycle recovery", function()
  it("refreshes Utility hotkeys and stacks while Essential is absent, then finishes delayed loading", function()
    _WithAddon({ utility_hotkeys_show = true, utility_stacks_fontSize = 19 }, function(ns, client)
      local viewer = client.CreateFrame("Frame", "UtilityCooldownViewer")
      local icon = client.CreateFrame("Frame", nil, viewer)
      icon.cooldownID, icon.layoutIndex, icon.rangeCheckSpellID = 1, 1, 123
      icon.Applications = { Applications = icon:CreateFontString() }
      local button = client.CreateFrame("Button", "ActionButton1")
      button:SetAttribute("action", 1)
      client._stubActionInfo[1] = { type = "spell", id = 123 }
      client._stubSpellActionButtons[123] = { 1 }
      client._stubBindingKeys.ACTIONBUTTON1 = "Q"
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(icon._ecdmHotkeyText._text).to_equal("Q")
      expect(icon.Applications.Applications._fontSize).to_equal(19)
      button:SetButtonState("PUSHED")
      expect(icon._ecdmPushedTex:IsShown()).to_equal(true)
      button:SetButtonState("NORMAL")
      client._stubBindingKeys.ACTIONBUTTON1 = "E"
      client._FireEvent("UPDATE_BINDINGS")
      client._RunPendingTimers()
      expect(icon._ecdmHotkeyText._text).to_equal("E")
      expect(client._GetTickerCount()).to_equal(1)
      for index = 1, 3 do
        client.CreateFrame("Frame", viewerNames[index])
      end
      client._TickTimers()
      expect(client._GetTickerCount()).to_equal(0)
      expect(#viewer._secureHooks.Layout).to_equal(1)
    end)
  end)

  it("reports a hook error, initializes other viewers, and retries only unfinished hooks", function()
    _WithAddon(nil, function(ns, client)
      createAll(client)
      local viewer = client.BuffIconCooldownViewer
      local hook = client.hooksecurefunc
      client.hooksecurefunc = function(target, method, callback)
        if target == viewer and method == "Layout" then
          error("injected layout hook failure")
        end
        hook(target, method, callback)
      end
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(#client._reportedErrors).to_equal(1)
      expect(client._reportedErrors[1]:find("injected layout hook failure", 1, true)).to_be_truthy()
      expect(#viewer._secureHooks.SetSize).to_equal(1)
      expect(#client.UtilityCooldownViewer._secureHooks.Layout).to_equal(1)
      client.wipe(client._reportedErrors)
      client.hooksecurefunc = hook
      client._TickTimers()
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(#viewer._secureHooks.SetSize).to_equal(1)
      expect(#viewer._secureHooks.Layout).to_equal(1)
      expect(client._GetTickerCount()).to_equal(0)
    end)
  end)

  it("resumes partially installed child hooks without duplicating the successful hook", function()
    _WithAddon(nil, function(ns, client)
      createAll(client)
      local icon = client.CreateFrame("Frame", nil, client.EssentialCooldownViewer)
      icon.cooldownID, icon.layoutIndex = 1, 1
      local hook = client.hooksecurefunc
      client.hooksecurefunc = function(target, method, callback)
        if target == icon and method == "SetShown" then
          error("injected child hook failure")
        end
        hook(target, method, callback)
      end
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(#client._reportedErrors).to_equal(1)
      expect(#icon._secureHooks.SetPoint).to_equal(1)
      client.wipe(client._reportedErrors)
      client.hooksecurefunc = hook
      client._TickTimers()
      expect(#icon._secureHooks.SetPoint).to_equal(1)
      expect(#icon._secureHooks.SetShown).to_equal(1)
      expect(client._GetTickerCount()).to_equal(0)
    end)
  end)

  it("installs a late mixin method without duplicating hooks already available", function()
    _WithAddon(nil, function(ns, client)
      createAll(client)
      local mixin = client.CooldownViewerItemDataMixin
      local assignment = mixin.SetCooldownID
      mixin.SetCooldownID = nil
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(client._GetTickerCount()).to_equal(1)
      mixin.SetCooldownID = assignment
      client._TickTimers()
      expect(#mixin._secureHooks.SetCooldownID).to_equal(1)
      expect(#mixin._secureHooks.ResetCooldownData).to_equal(1)
      expect(client._GetTickerCount()).to_equal(0)
    end)
  end)

  it("retires stale overlays and leaves replaced viewer hooks inert", function()
    _WithAddon({ essential_hotkeys_show = true }, function(ns, client)
      createAll(client)
      local previous = client.EssentialCooldownViewer
      local icon = client.CreateFrame("Frame", nil, previous)
      icon.cooldownID, icon.layoutIndex, icon.rangeCheckSpellID = 1, 1, 123
      local button = client.CreateFrame("Button", "ActionButton1")
      button:SetAttribute("action", 1)
      client._stubActionInfo[1] = { type = "spell", id = 123 }
      client._stubSpellActionButtons[123] = { 1 }
      client._stubBindingKeys.ACTIONBUTTON1 = "Q"
      client._FireEvent("PLAYER_ENTERING_WORLD")
      button:SetButtonState("PUSHED")
      local replacement = client.CreateFrame("Frame", "EssentialCooldownViewer")
      client._FireEvent("PLAYER_ENTERING_WORLD")
      client._RunPendingTimers()
      expect(ns.essentialViewer).to_equal(replacement)
      expect(icon._ecdmPushedTex:IsShown()).to_equal(false)
      expect(icon._ecdmHotkeyText._shown).to_equal(false)
      client._RunHooks(previous, "Layout")
      client._RunHooks(icon, "SetShown")
      expect(client._GetPendingTimerCount()).to_equal(0)
      client.EssentialCooldownViewer = nil
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(ns.essentialViewer).to_be_nil()
      client.EssentialCooldownViewer = previous
      client._TickTimers()
      expect(#previous._secureHooks.Layout).to_equal(1)
      expect(#icon._secureHooks.SetPoint).to_equal(1)
      expect(client._GetTickerCount()).to_equal(0)
    end)
  end)

  it("bounds polling, coalesces repeated events, and restarts on later viewer data", function()
    _WithAddon(nil, function(ns, client)
      client._FireEvent("PLAYER_ENTERING_WORLD")
      client._FireEvent("PLAYER_ENTERING_WORLD")
      expect(client._GetTickerCount()).to_equal(1)
      for _ = 1, 20 do
        client._TickTimers()
      end
      expect(client._GetTickerCount()).to_equal(0)
      createAll(client)
      client._FireEvent("COOLDOWN_VIEWER_DATA_LOADED")
      for _, name in ipairs(viewerNames) do
        expect(#client[name]._secureHooks.Layout).to_equal(1)
      end
      expect(client._GetTickerCount()).to_equal(0)
    end)
  end)
end)
