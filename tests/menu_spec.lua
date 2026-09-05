local function openMenu(client, owner, tag)
  return client.MenuUtil.CreateContextMenu(owner, function(_, root)
    root:SetTag(tag or "MENU_COOLDOWN_SETTINGS_ITEM")
    root:CreateButton("Blizzard option", function() end)
  end)
end

local function entry(root, text)
  for _, item in ipairs(root.entries) do
    if item.text == text then
      return item
    end
  end
end

local function createBar(client, id)
  local bar = client.CreateFrame("Frame")
  bar.cooldownID = id
  bar.GetCooldownID = function(self)
    return self.cooldownID
  end
  local statusBar = client.CreateFrame("StatusBar", nil, bar)
  statusBar._statusBarTexture = {
    SetGradient = function(self, orientation, startColor, endColor)
      self.startColor, self.endColor = startColor, endColor
    end,
  }
  return bar, statusBar._statusBarTexture
end

describe("Bar context menu", function()
  it("extends an already generated menu when the addon integration initializes late", function()
    _WithAddon(nil, function(ns, client)
      local bar = createBar(client, 123)
      local menu = openMenu(client, bar)
      ns.SetupEditMode()
      ns.SetupEditMode()
      expect(client.MenuUtil._openCount).to_equal(1)
      expect(#menu.entries).to_equal(5)
      expect(entry(menu, "Set End Color")).to_be_truthy()
    end)
  end)

  it("adds options once to the original tagged menu and ignores unrelated menus and icons", function()
    _WithAddon(nil, function(ns, client)
      ns.SetupEditMode()
      ns.SetupEditMode()
      local bar = createBar(client, 123)
      local generated = 0
      local menu = client.MenuUtil.CreateContextMenu(bar, function(_, root)
        generated = generated + 1
        root:SetTag("MENU_COOLDOWN_SETTINGS_ITEM")
        root:CreateButton("Blizzard option", function() end)
      end)
      expect(generated).to_equal(1)
      expect(client.MenuUtil._openCount).to_equal(1)
      expect(#client.Menu._modifiers.MENU_COOLDOWN_SETTINGS_ITEM).to_equal(1)
      expect(#menu.entries).to_equal(5)
      expect(entry(menu, "Set Start Color")).to_be_truthy()
      expect(entry(openMenu(client, bar, "UNRELATED"), "Set Start Color")).to_be_nil()
      local icon = client.CreateFrame("Frame")
      icon.cooldownID = 123
      expect(entry(openMenu(client, icon), "Set Start Color")).to_be_nil()
    end)
  end)

  it("previews changes, restores previous colors on cancel, and resets the selected bar", function()
    _WithAddon(nil, function(ns, client)
      ns.SetupEditMode()
      local original = { sR = 0.1, sG = 0.2, sB = 0.3, eR = 0.4, eG = 0.5, eB = 0.6 }
      ns.Settings.SetBarColors(123, original)
      local bar, texture = createBar(client, 123)
      entry(openMenu(client, bar), "Set Start Color").callback()
      local picker = client.ColorPickerFrame
      picker._rgb = { 0.7, 0.8, 0.9 }
      picker._info.swatchFunc()
      expect(ns.db.bars_colors[123].sR).to_equal(0.7)
      expect(texture.startColor.r).to_equal(0.7)
      expect(ns.db.bars_colors[123].eB).to_equal(0.6)
      picker._info.cancelFunc(picker._previous)
      expect(ns.db.bars_colors[123].sR).to_equal(0.1)
      expect(texture.startColor.r).to_equal(0.1)
      expect(original.sR).to_equal(0.1)
      entry(openMenu(client, bar), "Reset Gradient").callback()
      expect(ns.db.bars_colors[123]).to_be_nil()
      expect(texture.startColor.r).to_equal(1)
      entry(openMenu(client, bar), "Set End Color").callback()
      picker._rgb = { 0.2, 0.3, 0.4 }
      picker._info.swatchFunc()
      expect(ns.db.bars_colors[123].eB).to_equal(0.4)
      picker._info.cancelFunc(picker._previous)
      expect(ns.db.bars_colors[123]).to_be_nil()
      expect(texture.endColor.b).to_equal(0.25)
    end)
  end)
end)
