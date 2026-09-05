-- Enhanced CDM: Edit Mode — settings panel shown when Tracked Buffs is selected
local _, ns = ...
local HookBarContextMenu, HookSettingsBarPreview

local function InitSettingSlider(slider, key, formatter)
  local minimum, maximum = ns.Settings.GetRange(key)
  slider:Init(ns.db[key], minimum, maximum, maximum - minimum, formatter)
end

local editModePanel
local barsEditModePanel
local essentialHotkeysPanel
local utilityHotkeysPanel
local hookedDialogs = setmetatable({}, { __mode = "k" })

-- Layout constants shared by all panels
local LABEL_WIDTH = 110
local DROPDOWN_WIDTH = 225
local SLIDER_WIDTH = 200
local CONTENT_LEFT = 20
local CONTENT_TOP = 15
local CONTENT_BOTTOM = 20
local ROW_HEIGHT = 34
local DIVIDER_GAP = 28

-- Local alias — defined in Core.lua, available after Config→Core load order
local function IsViewerVertical(v)
  if ns.IsViewerVertical then
    return ns.IsViewerVertical(v)
  end
  return v and v.IsHorizontal and not v:IsHorizontal()
end

local POSITION_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER" }

-- Embed-into-dialog constants
local EMBED_COL_WIDTH = 380
local activeEmbeddedPanel = nil
local wrapperFrame = nil
local InstallDialogHooks

-- Creates a red button matching Blizzard's Edit Mode style.
local function CreateRedButton(parent, label, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetHeight(30)
  btn:SetText(label)
  btn:SetNormalFontObject("GameFontNormal")
  btn:SetHighlightFontObject("GameFontHighlight")
  local normalTex = btn:GetNormalTexture()
  if normalTex then
    normalTex:SetVertexColor(0.7, 0.1, 0.1)
  end
  local pushedTex = btn:GetPushedTexture()
  if pushedTex then
    pushedTex:SetVertexColor(0.6, 0.05, 0.05)
  end
  btn:SetScript("OnClick", onClick)
  return btn
end

-- Forward declaration for refresh (defined after panel creation)
local RefreshEditModePanel

-- ---------------------------------------------------------------------------
-- Panel creation — builds the settings panel (slider + 3 dropdowns)
-- ---------------------------------------------------------------------------

local function CreateEditModePanel()
  if editModePanel then
    return
  end

  local db = ns.db

  local f = CreateFrame("Frame", nil, UIParent)
  f:EnableMouse(true)
  f:SetFrameStrata("DIALOG")
  local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
  border:SetAllPoints(f)
  f._border = border
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -CONTENT_TOP)
  title:SetText("Enhanced CDM - Buffs")

  local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

  -- Grid group title
  local gridTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
  gridTitle:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -titleBottom)
  gridTitle:SetText("Grid")

  local gridTitleBottom = titleBottom + gridTitle:GetStringHeight() + 6

  -- Row 1: Layout Mode — [label] [dropdown]
  local row1 = CreateFrame("Frame", nil, f)
  row1:SetHeight(ROW_HEIGHT)
  row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -gridTitleBottom)
  row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -gridTitleBottom)

  local layoutLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  layoutLabel:SetPoint("LEFT", 0, 0)
  layoutLabel:SetWidth(LABEL_WIDTH)
  layoutLabel:SetJustifyH("LEFT")
  layoutLabel:SetText("Layout")

  local layoutDropdown = CreateFrame("DropdownButton", nil, row1, "WowStyle1DropdownTemplate")
  layoutDropdown:SetPoint("LEFT", layoutLabel, "RIGHT", 5, 0)
  layoutDropdown:SetWidth(DROPDOWN_WIDTH)
  layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.layout])
  layoutDropdown:SetupMenu(function(owner, rootDescription)
    for _, l in ipairs({ "STATIC", "DYNAMIC" }) do
      rootDescription:CreateRadio(ns.LAYOUT_DISPLAY[l], function()
        return ns.db.layout == l
      end, function()
        ns.Settings.Set("layout", l)
        if ns.ApplyLayout then
          ns.ApplyLayout()
        end
      end, l)
    end
  end)

  -- Row 2: Icons Per Row / Per Column (label changes with orientation)
  local row2 = CreateFrame("Frame", nil, f)
  row2:SetHeight(ROW_HEIGHT)
  row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, 0)
  row2:SetPoint("TOPRIGHT", row1, "BOTTOMRIGHT", 0, 0)

  local perRowLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  perRowLabel:SetPoint("LEFT", 0, 0)
  perRowLabel:SetWidth(LABEL_WIDTH)
  perRowLabel:SetJustifyH("LEFT")
  perRowLabel:SetText(IsViewerVertical(ns.viewer) and "# Rows" or "# Columns")

  local steppers = CreateFrame("Frame", nil, row2, "MinimalSliderWithSteppersTemplate")
  steppers:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
  steppers:SetWidth(SLIDER_WIDTH)
  steppers:SetHeight(17)
  local fmt = {}
  fmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(steppers, "maxPerRow", fmt)
  steppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set("maxPerRow", value)
    if ns.ApplyLayout then
      ns.ApplyLayout()
    end
  end, steppers)

  -- Row 3: Icons Growth Direction
  local row3 = CreateFrame("Frame", nil, f)
  row3:SetHeight(ROW_HEIGHT)
  row3:SetPoint("TOPLEFT", row2, "BOTTOMLEFT", 0, 0)
  row3:SetPoint("TOPRIGHT", row2, "BOTTOMRIGHT", 0, 0)

  local growLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  growLabel:SetPoint("LEFT", 0, 0)
  growLabel:SetWidth(LABEL_WIDTH)
  growLabel:SetJustifyH("LEFT")
  growLabel:SetText("Growth")

  local dropdown = CreateFrame("DropdownButton", nil, row3, "WowStyle1DropdownTemplate")
  dropdown:SetPoint("LEFT", growLabel, "RIGHT", 5, 0)
  dropdown:SetWidth(DROPDOWN_WIDTH)
  local growMap = IsViewerVertical(ns.viewer) and ns.DIRECTION_V_DISPLAY or ns.DIRECTION_DISPLAY
  dropdown:SetDefaultText(growMap[db.growDirection])
  dropdown:SetupMenu(function(owner, rootDescription)
    local map = IsViewerVertical(ns.viewer) and ns.DIRECTION_V_DISPLAY or ns.DIRECTION_DISPLAY
    for _, dir in ipairs({ "DOWN", "UP" }) do
      rootDescription:CreateRadio(map[dir], function()
        return ns.db.growDirection == dir
      end, function()
        ns.Settings.Set("growDirection", dir)
        if ns.ApplyLayout then
          ns.ApplyLayout()
        end
      end, dir)
    end
  end)

  -- Row 4: Icons Alignment
  local row4 = CreateFrame("Frame", nil, f)
  row4:SetHeight(ROW_HEIGHT)
  row4:SetPoint("TOPLEFT", row3, "BOTTOMLEFT", 0, 0)
  row4:SetPoint("TOPRIGHT", row3, "BOTTOMRIGHT", 0, 0)

  local alignLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  alignLabel:SetPoint("LEFT", 0, 0)
  alignLabel:SetWidth(LABEL_WIDTH)
  alignLabel:SetJustifyH("LEFT")
  alignLabel:SetText("Alignment")

  local alignDropdown = CreateFrame("DropdownButton", nil, row4, "WowStyle1DropdownTemplate")
  alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
  alignDropdown:SetWidth(DROPDOWN_WIDTH)
  local alignMap = IsViewerVertical(ns.viewer) and ns.ALIGN_V_DISPLAY or ns.ALIGN_DISPLAY
  alignDropdown:SetDefaultText(alignMap[db.align])
  alignDropdown:SetupMenu(function(owner, rootDescription)
    local map = IsViewerVertical(ns.viewer) and ns.ALIGN_V_DISPLAY or ns.ALIGN_DISPLAY
    for _, a in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
      rootDescription:CreateRadio(map[a], function()
        return ns.db.align == a
      end, function()
        ns.Settings.Set("align", a)
        if ns.ApplyLayout then
          ns.ApplyLayout()
        end
      end, a)
    end
  end)

  -- -----------------------------------------------------------------------
  -- Stack Text section — divider + 4 rows
  -- -----------------------------------------------------------------------

  local bStacksPrefix = "buffs_stacks_"

  local bDivider = f:CreateTexture(nil, "ARTWORK")
  bDivider:SetHeight(1)
  bDivider:SetColorTexture(1, 1, 1, 0.3)
  bDivider:SetPoint("TOPLEFT", row4, "BOTTOMLEFT", 0, -12)
  bDivider:SetPoint("TOPRIGHT", row4, "BOTTOMRIGHT", 0, -12)

  local bStackTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
  bStackTitle:SetPoint("TOPLEFT", bDivider, "BOTTOMLEFT", 0, -10)
  bStackTitle:SetText("Stacks")

  -- Row S1: Font Size
  local bsRow1 = CreateFrame("Frame", nil, f)
  bsRow1:SetHeight(ROW_HEIGHT)
  bsRow1:SetPoint("TOP", bStackTitle, "BOTTOM", 0, -6)
  bsRow1:SetPoint("LEFT", f, "LEFT", CONTENT_LEFT, 0)
  bsRow1:SetPoint("RIGHT", f, "RIGHT", -CONTENT_LEFT, 0)

  local bsFontLabel = bsRow1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  bsFontLabel:SetPoint("LEFT", 0, 0)
  bsFontLabel:SetWidth(LABEL_WIDTH)
  bsFontLabel:SetJustifyH("LEFT")
  bsFontLabel:SetText("Font Size")

  local bsFontSteppers = CreateFrame("Frame", nil, bsRow1, "MinimalSliderWithSteppersTemplate")
  bsFontSteppers:SetPoint("LEFT", bsFontLabel, "RIGHT", 5, 0)
  bsFontSteppers:SetWidth(SLIDER_WIDTH)
  bsFontSteppers:SetHeight(17)
  local bsfFmt = {}
  bsfFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(bsFontSteppers, bStacksPrefix .. "fontSize", bsfFmt)
  bsFontSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(bStacksPrefix .. "fontSize", value)
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end, bsFontSteppers)

  local bsOffsetXSteppers
  local bsOffsetYSteppers

  -- Row S2: Position
  local bsRow2 = CreateFrame("Frame", nil, f)
  bsRow2:SetHeight(ROW_HEIGHT)
  bsRow2:SetPoint("TOPLEFT", bsRow1, "BOTTOMLEFT", 0, 0)
  bsRow2:SetPoint("TOPRIGHT", bsRow1, "BOTTOMRIGHT", 0, 0)

  local bsPosLabel = bsRow2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  bsPosLabel:SetPoint("LEFT", 0, 0)
  bsPosLabel:SetWidth(LABEL_WIDTH)
  bsPosLabel:SetJustifyH("LEFT")
  bsPosLabel:SetText("Position")

  local bsPosDropdown = CreateFrame("DropdownButton", nil, bsRow2, "WowStyle1DropdownTemplate")
  bsPosDropdown:SetPoint("LEFT", bsPosLabel, "RIGHT", 5, 0)
  bsPosDropdown:SetWidth(DROPDOWN_WIDTH)
  bsPosDropdown:SetDefaultText(ns.HOTKEY_POSITION_DISPLAY[db[bStacksPrefix .. "position"]])

  bsPosDropdown:SetupMenu(function(owner, rootDescription)
    for _, pos in ipairs(POSITION_ORDER) do
      rootDescription:CreateRadio(ns.HOTKEY_POSITION_DISPLAY[pos], function()
        return ns.db[bStacksPrefix .. "position"] == pos
      end, function()
        ns.Settings.Set(bStacksPrefix .. "position", pos)
        if ns.RefreshAllStacks then
          ns.RefreshAllStacks()
        end
        -- Sync slider widgets
        if bsOffsetXSteppers and bsOffsetXSteppers.Slider then
          bsOffsetXSteppers.Slider:SetValue(ns.db[bStacksPrefix .. "offsetX"])
        end
        if bsOffsetYSteppers and bsOffsetYSteppers.Slider then
          bsOffsetYSteppers.Slider:SetValue(ns.db[bStacksPrefix .. "offsetY"])
        end
      end, pos)
    end
  end)

  -- Row S3: Horizontal Offset
  local bsRow3 = CreateFrame("Frame", nil, f)
  bsRow3:SetHeight(ROW_HEIGHT)
  bsRow3:SetPoint("TOPLEFT", bsRow2, "BOTTOMLEFT", 0, 0)
  bsRow3:SetPoint("TOPRIGHT", bsRow2, "BOTTOMRIGHT", 0, 0)

  local bsOffsetXLabel = bsRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  bsOffsetXLabel:SetPoint("LEFT", 0, 0)
  bsOffsetXLabel:SetWidth(LABEL_WIDTH)
  bsOffsetXLabel:SetJustifyH("LEFT")
  bsOffsetXLabel:SetText("Horizontal")

  bsOffsetXSteppers = CreateFrame("Frame", nil, bsRow3, "MinimalSliderWithSteppersTemplate")
  bsOffsetXSteppers:SetPoint("LEFT", bsOffsetXLabel, "RIGHT", 5, 0)
  bsOffsetXSteppers:SetWidth(SLIDER_WIDTH)
  bsOffsetXSteppers:SetHeight(17)
  local bsoxFmt = {}
  bsoxFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(bsOffsetXSteppers, bStacksPrefix .. "offsetX", bsoxFmt)
  bsOffsetXSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(bStacksPrefix .. "offsetX", value)
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end, bsOffsetXSteppers)

  -- Row S4: Vertical Offset
  local bsRow4 = CreateFrame("Frame", nil, f)
  bsRow4:SetHeight(ROW_HEIGHT)
  bsRow4:SetPoint("TOPLEFT", bsRow3, "BOTTOMLEFT", 0, 0)
  bsRow4:SetPoint("TOPRIGHT", bsRow3, "BOTTOMRIGHT", 0, 0)

  local bsOffsetYLabel = bsRow4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  bsOffsetYLabel:SetPoint("LEFT", 0, 0)
  bsOffsetYLabel:SetWidth(LABEL_WIDTH)
  bsOffsetYLabel:SetJustifyH("LEFT")
  bsOffsetYLabel:SetText("Vertical")

  bsOffsetYSteppers = CreateFrame("Frame", nil, bsRow4, "MinimalSliderWithSteppersTemplate")
  bsOffsetYSteppers:SetPoint("LEFT", bsOffsetYLabel, "RIGHT", 5, 0)
  bsOffsetYSteppers:SetWidth(SLIDER_WIDTH)
  bsOffsetYSteppers:SetHeight(17)
  local bsoyFmt = {}
  bsoyFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(bsOffsetYSteppers, bStacksPrefix .. "offsetY", bsoyFmt)
  bsOffsetYSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(bStacksPrefix .. "offsetY", value)
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end, bsOffsetYSteppers)

  -- Reset To Default button
  local BUFFS_KEYS = {
    "maxPerRow",
    "growDirection",
    "align",
    "layout",
    "buffs_stacks_fontSize",
    "buffs_stacks_position",
    "buffs_stacks_offsetX",
    "buffs_stacks_offsetY",
  }
  local resetBtn = CreateRedButton(f, "Reset To Default", function()
    for _, key in ipairs(BUFFS_KEYS) do
      ns.Settings.Reset(key)
    end
    RefreshEditModePanel()
    if ns.ApplyLayout then
      ns.ApplyLayout()
    end
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end)
  local resetDivider = f:CreateTexture(nil, "ARTWORK")
  resetDivider:SetHeight(1)
  resetDivider:SetColorTexture(1, 1, 1, 0.3)
  resetDivider:SetPoint("TOPLEFT", bsRow4, "BOTTOMLEFT", 0, -12)
  resetDivider:SetPoint("TOPRIGHT", bsRow4, "BOTTOMRIGHT", 0, -12)
  resetBtn:SetPoint("TOPLEFT", resetDivider, "BOTTOMLEFT", 0, -10)
  resetBtn:SetPoint("TOPRIGHT", resetDivider, "BOTTOMRIGHT", 0, -10)

  f.growDropdown = dropdown
  f.alignDropdown = alignDropdown
  f.layoutDropdown = layoutDropdown
  f.bsPosDropdown = bsPosDropdown
  f.perRowLabel = perRowLabel
  f.perRowSteppers = steppers
  f.bsFontSteppers = bsFontSteppers
  f.bsOffsetXSteppers = bsOffsetXSteppers
  f.bsOffsetYSteppers = bsOffsetYSteppers
  editModePanel = f

  local stacksExtraHeight = DIVIDER_GAP + bStackTitle:GetStringHeight() + 6 + (ROW_HEIGHT * 4)
  f:SetSize(480, gridTitleBottom + (ROW_HEIGHT * 4) + stacksExtraHeight + CONTENT_BOTTOM + 52)
end

-- ---------------------------------------------------------------------------
-- Panel refresh / show / hide
-- ---------------------------------------------------------------------------

-- Updates a WowStyle1Dropdown's visible text and default text.
local function SetDropdownText(dropdown, text)
  if not dropdown then
    return
  end
  dropdown:SetDefaultText(text)
  if dropdown.Text then
    dropdown.Text:SetText(text)
  end
end

-- Syncs all panel widgets with current saved variable values
RefreshEditModePanel = function()
  if not editModePanel then
    return
  end
  local db = ns.db
  local isVert = IsViewerVertical(ns.viewer)
  local steppers = editModePanel.perRowSteppers
  if steppers and steppers.Slider then
    steppers.Slider:SetValue(db.maxPerRow)
  end
  if editModePanel.perRowLabel then
    editModePanel.perRowLabel:SetText(isVert and "# Rows" or "# Columns")
  end
  local growMap = isVert and ns.DIRECTION_V_DISPLAY or ns.DIRECTION_DISPLAY
  SetDropdownText(editModePanel.growDropdown, growMap[db.growDirection])
  local alignMap = isVert and ns.ALIGN_V_DISPLAY or ns.ALIGN_DISPLAY
  SetDropdownText(editModePanel.alignDropdown, alignMap[db.align])
  SetDropdownText(editModePanel.layoutDropdown, ns.LAYOUT_DISPLAY[db.layout])
  SetDropdownText(editModePanel.bsPosDropdown, ns.HOTKEY_POSITION_DISPLAY[db.buffs_stacks_position])
  local bsfS = editModePanel.bsFontSteppers
  if bsfS and bsfS.Slider then
    bsfS.Slider:SetValue(db.buffs_stacks_fontSize)
  end
  local bsoxS = editModePanel.bsOffsetXSteppers
  if bsoxS and bsoxS.Slider then
    bsoxS.Slider:SetValue(db.buffs_stacks_offsetX)
  end
  local bsoyS = editModePanel.bsOffsetYSteppers
  if bsoyS and bsoyS.Slider then
    bsoyS.Slider:SetValue(db.buffs_stacks_offsetY)
  end
end
ns.RefreshEditModePanel = function()
  if RefreshEditModePanel then
    RefreshEditModePanel()
  end
end

-- Hides the Blizzard dialog's border/background (dialog.Border frame).
local function HideDialogBorder(dialog)
  if dialog.Border then
    dialog.Border:Hide()
  end
end

-- Restores the Blizzard dialog's border/background.
local function ShowDialogBorder(dialog)
  if dialog.Border then
    dialog.Border:Show()
  end
end

-- Embeds a panel as the LEFT column beside Blizzard's settings dialog.
-- Both panels become borderless; a shared wrapper provides the unified border.
-- Falls back to standalone positioning if the dialog is unavailable.
local function EmbedPanelInDialog(panel)
  if InstallDialogHooks then
    InstallDialogHooks()
  end

  local dialog = _G["EditModeSystemSettingsDialog"]
  if not dialog or not dialog:IsShown() then
    -- Fallback: show standalone
    if panel._border then
      panel._border:Show()
    end
    if panel._ecdmDivider then
      panel._ecdmDivider:Hide()
    end
    panel:SetParent(UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:ClearAllPoints()
    panel:SetPoint("TOP", UIParent, "TOP", 0, -100)
    panel:Show()
    return
  end

  -- Hide panel's own border
  if panel._border then
    panel._border:Hide()
  end

  -- Hide Blizzard dialog's border/background
  HideDialogBorder(dialog)

  -- Create or reuse the wrapper frame that provides the shared border
  if not wrapperFrame then
    wrapperFrame = CreateFrame("Frame", nil, UIParent)
    wrapperFrame:EnableMouse(false)
    wrapperFrame:SetFrameStrata("DIALOG")
    local wrapBorder = CreateFrame("Frame", nil, wrapperFrame, "DialogBorderTranslucentTemplate")
    wrapBorder:SetAllPoints(wrapperFrame)
    wrapperFrame._border = wrapBorder
  end

  -- Position panel to the LEFT of dialog, matching its height
  panel:SetParent(UIParent)
  panel:SetFrameStrata("DIALOG")
  panel:ClearAllPoints()
  panel:SetPoint("TOPRIGHT", dialog, "TOPLEFT", 0, 0)
  panel:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMLEFT", 0, 0)
  panel:SetWidth(EMBED_COL_WIDTH)
  panel:Show()

  -- Ensure panel content renders above the wrapper background
  panel:SetFrameLevel(dialog:GetFrameLevel() + 1)

  -- Position wrapper to span both panel (left) and dialog (right)
  wrapperFrame:SetFrameLevel(dialog:GetFrameLevel() - 1)
  wrapperFrame:ClearAllPoints()
  wrapperFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  wrapperFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", 0, 0)
  wrapperFrame:Show()

  -- Vertical divider between columns (on panel's right edge)
  if not panel._ecdmDivider then
    panel._ecdmDivider = panel:CreateTexture(nil, "OVERLAY")
    panel._ecdmDivider:SetWidth(1)
    panel._ecdmDivider:SetColorTexture(1, 1, 1, 0.15)
  end
  panel._ecdmDivider:ClearAllPoints()
  panel._ecdmDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -10)
  panel._ecdmDivider:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)
  panel._ecdmDivider:Show()

  activeEmbeddedPanel = panel
end

-- Removes the embedded panel and restores the dialog's original border.
local function UnembedPanel()
  if activeEmbeddedPanel then
    activeEmbeddedPanel:Hide()
    activeEmbeddedPanel:SetParent(UIParent)
    activeEmbeddedPanel:SetFrameStrata("DIALOG")
    if activeEmbeddedPanel._border then
      activeEmbeddedPanel._border:Show()
    end
    if activeEmbeddedPanel._ecdmDivider then
      activeEmbeddedPanel._ecdmDivider:Hide()
    end
    activeEmbeddedPanel = nil
  end

  -- Restore Blizzard dialog's border
  local dialog = _G["EditModeSystemSettingsDialog"]
  if dialog then
    ShowDialogBorder(dialog)
  end

  -- Hide wrapper
  if wrapperFrame then
    wrapperFrame:Hide()
  end
end

local function ShowEnhancedCDMPanel()
  CreateEditModePanel()
  RefreshEditModePanel()
  EmbedPanelInDialog(editModePanel)
end

local function HideEnhancedCDMPanel()
  if editModePanel then
    editModePanel:Hide()
  end
end

-- ---------------------------------------------------------------------------
-- Bars panel creation — builds the bars settings panel (dropdowns + slider)
-- ---------------------------------------------------------------------------

local function CreateBarsEditModePanel()
  if barsEditModePanel then
    return
  end

  local db = ns.db

  local f = CreateFrame("Frame", nil, UIParent)
  f:EnableMouse(true)
  f:SetFrameStrata("DIALOG")
  local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
  border:SetAllPoints(f)
  f._border = border
  f:SetWidth(480)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -CONTENT_TOP)
  title:SetText("Enhanced CDM - Bars")

  local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

  -- Grid group title
  local gridTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
  gridTitle:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -titleBottom)
  gridTitle:SetText("Grid")

  local gridTitleBottom = titleBottom + gridTitle:GetStringHeight() + 6

  -- Row 1: Orientation
  local row1 = CreateFrame("Frame", nil, f)
  row1:SetHeight(ROW_HEIGHT)
  row1:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_LEFT, -gridTitleBottom)
  row1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -CONTENT_LEFT, -gridTitleBottom)

  local orientLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  orientLabel:SetPoint("LEFT", 0, 0)
  orientLabel:SetWidth(LABEL_WIDTH)
  orientLabel:SetJustifyH("LEFT")
  orientLabel:SetText("Orientation")

  local orientDropdown = CreateFrame("DropdownButton", nil, row1, "WowStyle1DropdownTemplate")
  orientDropdown:SetPoint("LEFT", orientLabel, "RIGHT", 5, 0)
  orientDropdown:SetWidth(DROPDOWN_WIDTH)
  orientDropdown:SetDefaultText(ns.ORIENTATION_DISPLAY[db.bars_orientation])

  -- Row 2: Layout
  local row2 = CreateFrame("Frame", nil, f)
  row2:SetHeight(ROW_HEIGHT)
  row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, 0)
  row2:SetPoint("TOPRIGHT", row1, "BOTTOMRIGHT", 0, 0)

  local layoutLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  layoutLabel:SetPoint("LEFT", 0, 0)
  layoutLabel:SetWidth(LABEL_WIDTH)
  layoutLabel:SetJustifyH("LEFT")
  layoutLabel:SetText("Layout")

  local layoutDropdown = CreateFrame("DropdownButton", nil, row2, "WowStyle1DropdownTemplate")
  layoutDropdown:SetPoint("LEFT", layoutLabel, "RIGHT", 5, 0)
  layoutDropdown:SetWidth(DROPDOWN_WIDTH)
  layoutDropdown:SetDefaultText(ns.LAYOUT_DISPLAY[db.bars_layout])

  -- Row 3: Alignment — conditional: visible when layout=DYNAMIC
  local row3 = CreateFrame("Frame", nil, f)
  row3:SetHeight(ROW_HEIGHT)

  local alignLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  alignLabel:SetPoint("LEFT", 0, 0)
  alignLabel:SetWidth(LABEL_WIDTH)
  alignLabel:SetJustifyH("LEFT")
  alignLabel:SetText("Alignment")

  local alignDropdown = CreateFrame("DropdownButton", nil, row3, "WowStyle1DropdownTemplate")
  alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
  alignDropdown:SetWidth(DROPDOWN_WIDTH)

  -- Row 4: Bars Per Row — conditional: visible when orientation=HORIZONTAL
  local row4 = CreateFrame("Frame", nil, f)
  row4:SetHeight(ROW_HEIGHT)

  local perRowLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  perRowLabel:SetPoint("LEFT", 0, 0)
  perRowLabel:SetWidth(LABEL_WIDTH)
  perRowLabel:SetJustifyH("LEFT")
  perRowLabel:SetText("Per Row")

  local steppers = CreateFrame("Frame", nil, row4, "MinimalSliderWithSteppersTemplate")
  steppers:SetPoint("LEFT", perRowLabel, "RIGHT", 5, 0)
  steppers:SetWidth(SLIDER_WIDTH)
  steppers:SetHeight(17)
  local fmt = {}
  fmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(steppers, "bars_maxPerRow", fmt)
  steppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set("bars_maxPerRow", value)
    if ns.ApplyBarsLayout then
      ns.ApplyBarsLayout()
    end
  end, steppers)

  -- Forward-declared update function, reset button, and divider
  local UpdateBarsPanel
  local barsResetBtn
  local barsResetDivider

  -- Setup dropdown menus (use generators so they rebuild on each open)
  orientDropdown:SetupMenu(function(owner, rootDescription)
    for _, o in ipairs({ "VERTICAL", "HORIZONTAL" }) do
      rootDescription:CreateRadio(ns.ORIENTATION_DISPLAY[o], function()
        return ns.db.bars_orientation == o
      end, function()
        ns.Settings.Set("bars_orientation", o)
        if ns.ApplyBarsLayout then
          ns.ApplyBarsLayout()
        end
        UpdateBarsPanel()
      end, o)
    end
  end)

  layoutDropdown:SetupMenu(function(owner, rootDescription)
    for _, l in ipairs({ "STATIC", "DYNAMIC" }) do
      rootDescription:CreateRadio(ns.LAYOUT_DISPLAY[l], function()
        return ns.db.bars_layout == l
      end, function()
        ns.Settings.Set("bars_layout", l)
        if ns.ApplyBarsLayout then
          ns.ApplyBarsLayout()
        end
        UpdateBarsPanel()
      end, l)
    end
  end)

  alignDropdown:SetupMenu(function(owner, rootDescription)
    if ns.db.bars_orientation == "VERTICAL" then
      for _, a in ipairs({ "DOWN", "UP" }) do
        rootDescription:CreateRadio(ns.BAR_ALIGN_V_DISPLAY[a], function()
          return ns.db.bars_align == a
        end, function()
          ns.Settings.Set("bars_align", a)
          if ns.ApplyBarsLayout then
            ns.ApplyBarsLayout()
          end
        end, a)
      end
    else
      for _, a in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
        rootDescription:CreateRadio(ns.BAR_ALIGN_H_DISPLAY[a], function()
          return ns.db.bars_align == a
        end, function()
          ns.Settings.Set("bars_align", a)
          if ns.ApplyBarsLayout then
            ns.ApplyBarsLayout()
          end
        end, a)
      end
    end
  end)

  -- Update panel visibility, anchoring, and sizing based on current settings
  UpdateBarsPanel = function()
    local showAlign = (ns.db.bars_layout == "DYNAMIC")
    local showPerRow = (ns.db.bars_orientation == "HORIZONTAL")

    -- Update dropdown texts
    SetDropdownText(orientDropdown, ns.ORIENTATION_DISPLAY[ns.db.bars_orientation])
    SetDropdownText(layoutDropdown, ns.LAYOUT_DISPLAY[ns.db.bars_layout])
    local alignText
    if ns.db.bars_orientation == "VERTICAL" then
      alignText = ns.BAR_ALIGN_V_DISPLAY[ns.db.bars_align] or "Down"
    else
      alignText = ns.BAR_ALIGN_H_DISPLAY[ns.db.bars_align] or "Center"
    end
    SetDropdownText(alignDropdown, alignText)

    -- Update slider
    local barsSteppers = steppers
    if barsSteppers and barsSteppers.Slider then
      barsSteppers.Slider:SetValue(ns.db.bars_maxPerRow)
    end

    -- Dynamic row anchoring
    local visibleRows = 2 -- orientation + layout always visible
    local lastRow = row2

    if showAlign then
      row3:ClearAllPoints()
      row3:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row3:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row3:Show()
      lastRow = row3
      visibleRows = visibleRows + 1
    else
      row3:Hide()
    end

    if showPerRow then
      row4:ClearAllPoints()
      row4:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row4:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row4:Show()
      lastRow = row4
      visibleRows = visibleRows + 1
    else
      row4:Hide()
    end

    barsResetDivider:ClearAllPoints()
    barsResetDivider:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -12)
    barsResetDivider:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, -12)
    barsResetBtn:ClearAllPoints()
    barsResetBtn:SetPoint("TOPLEFT", barsResetDivider, "BOTTOMLEFT", 0, -10)
    barsResetBtn:SetPoint("TOPRIGHT", barsResetDivider, "BOTTOMRIGHT", 0, -10)

    f:SetHeight(gridTitleBottom + (ROW_HEIGHT * visibleRows) + CONTENT_BOTTOM + 52)
  end

  -- Reset To Default button
  local BARS_KEYS = { "bars_orientation", "bars_layout", "bars_align", "bars_maxPerRow" }
  barsResetDivider = f:CreateTexture(nil, "ARTWORK")
  barsResetDivider:SetHeight(1)
  barsResetDivider:SetColorTexture(1, 1, 1, 0.3)

  barsResetBtn = CreateRedButton(f, "Reset To Default", function()
    for _, key in ipairs(BARS_KEYS) do
      ns.Settings.Reset(key)
    end
    UpdateBarsPanel()
    if ns.ApplyBarsLayout then
      ns.ApplyBarsLayout()
    end
  end)

  f.UpdateBarsPanel = UpdateBarsPanel
  barsEditModePanel = f

  -- Initial layout
  UpdateBarsPanel()
end

-- ---------------------------------------------------------------------------
-- Bars panel refresh / show / hide
-- ---------------------------------------------------------------------------

local function ShowBarsPanel()
  CreateBarsEditModePanel()
  if barsEditModePanel.UpdateBarsPanel then
    barsEditModePanel.UpdateBarsPanel()
  end
  EmbedPanelInDialog(barsEditModePanel)
end

local function HideBarsPanel()
  if barsEditModePanel then
    barsEditModePanel:Hide()
  end
end

-- ---------------------------------------------------------------------------
-- Hotkeys panel factory — creates a checkbox + position + font size panel
-- ---------------------------------------------------------------------------

local function CreateHotkeysPanelForViewer(titleText, prefix, alignKey, applyAlignFn, getViewer)
  local db = ns.db

  local f = CreateFrame("Frame", nil, UIParent)
  f:EnableMouse(true)
  f:SetFrameStrata("DIALOG")
  local border = CreateFrame("Frame", nil, f, "DialogBorderTranslucentTemplate")
  border:SetAllPoints(f)
  f._border = border
  f:SetWidth(480)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -CONTENT_TOP)
  title:SetText(titleText)

  local titleBottom = CONTENT_TOP + title:GetStringHeight() + 10

  -- Scrollable content area below the title
  local scrollFrame = CreateFrame("ScrollFrame", nil, f)
  scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -titleBottom)
  scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, CONTENT_BOTTOM)
  scrollFrame:EnableMouseWheel(true)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollFrame:SetScrollChild(scrollChild)
  scrollChild:SetWidth(1) -- updated dynamically

  -- Scroll bar track + thumb (auto-show when content overflows)
  local scrollTrack = CreateFrame("Frame", nil, f)
  scrollTrack:SetWidth(8)
  scrollTrack:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -2)
  scrollTrack:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, 2)
  scrollTrack:Hide()

  local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
  scrollThumb:SetWidth(8)
  scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
  scrollThumb:SetHeight(20)
  scrollThumb:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 6,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  scrollThumb:SetBackdropColor(0.6, 0.6, 0.6, 0.5)
  scrollThumb:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.5)

  local function UpdateScrollBar()
    local childH = scrollChild:GetHeight()
    local frameH = scrollFrame:GetHeight()
    if childH <= frameH or frameH < 1 then
      scrollTrack:Hide()
      return
    end
    scrollTrack:Show()
    local trackH = scrollTrack:GetHeight()
    local thumbH = math.max(20, (frameH / childH) * trackH)
    scrollThumb:SetHeight(thumbH)
    local maxScroll = childH - frameH
    local scroll = scrollFrame:GetVerticalScroll()
    local ratio = (maxScroll > 0) and (scroll / maxScroll) or 0
    local thumbOffset = ratio * (trackH - thumbH)
    scrollThumb:ClearAllPoints()
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbOffset)
  end

  scrollFrame:SetScript("OnSizeChanged", function(self, width)
    scrollChild:SetWidth(width)
    UpdateScrollBar()
  end)

  scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, scrollChild:GetHeight() - self:GetHeight())
    local newScroll = math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 30))
    self:SetVerticalScroll(newScroll)
    UpdateScrollBar()
  end)

  scrollFrame:SetScript("OnScrollRangeChanged", function()
    UpdateScrollBar()
  end)

  -- Row 0: Alignment — [label] [dropdown] (always visible)
  local row0 = CreateFrame("Frame", nil, scrollChild)
  row0:SetHeight(ROW_HEIGHT)
  row0:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", CONTENT_LEFT, 0)
  row0:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -CONTENT_LEFT, 0)

  local alignLabel = row0:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  alignLabel:SetPoint("LEFT", 0, 0)
  alignLabel:SetWidth(LABEL_WIDTH)
  alignLabel:SetJustifyH("LEFT")
  alignLabel:SetText("Alignment")

  local alignDropdown = CreateFrame("DropdownButton", nil, row0, "WowStyle1DropdownTemplate")
  alignDropdown:SetPoint("LEFT", alignLabel, "RIGHT", 5, 0)
  alignDropdown:SetWidth(DROPDOWN_WIDTH)
  local initAlignMap = (getViewer and IsViewerVertical(getViewer())) and ns.ALIGN_V_DISPLAY or ns.ALIGN_DISPLAY
  alignDropdown:SetDefaultText(initAlignMap[db[alignKey]])
  alignDropdown:SetupMenu(function(owner, rootDescription)
    local map = (getViewer and IsViewerVertical(getViewer())) and ns.ALIGN_V_DISPLAY or ns.ALIGN_DISPLAY
    for _, a in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
      rootDescription:CreateRadio(map[a], function()
        return ns.db[alignKey] == a
      end, function()
        ns.Settings.Set(alignKey, a)
        if applyAlignFn then
          applyAlignFn()
        end
      end, a)
    end
  end)

  -- Click Feedback checkbox (always visible, ungrouped)
  local feedbackKey = prefix:gsub("hotkeys_$", "feedback_show")
  local feedbackRow = CreateFrame("Frame", nil, scrollChild)
  feedbackRow:SetHeight(ROW_HEIGHT)
  feedbackRow:SetPoint("TOPLEFT", row0, "BOTTOMLEFT", 0, 0)
  feedbackRow:SetPoint("TOPRIGHT", row0, "BOTTOMRIGHT", 0, 0)

  local feedbackCheckbox = CreateFrame("CheckButton", nil, feedbackRow, "UICheckButtonTemplate")
  feedbackCheckbox:SetPoint("LEFT", 0, 0)
  feedbackCheckbox:SetSize(30, 30)

  local feedbackLabel = feedbackRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  feedbackLabel:SetPoint("LEFT", feedbackCheckbox, "RIGHT", 5, 0)
  feedbackLabel:SetJustifyH("LEFT")
  feedbackLabel:SetText("Click Feedback")

  feedbackCheckbox:SetScript("OnClick", function(self)
    ns.Settings.Set(feedbackKey, self:GetChecked())
    ns.ClearDisabledFeedback()
  end)

  -- Keybinds group header
  local keybindsDivider = scrollChild:CreateTexture(nil, "ARTWORK")
  keybindsDivider:SetHeight(1)
  keybindsDivider:SetColorTexture(1, 1, 1, 0.3)
  keybindsDivider:SetPoint("TOPLEFT", feedbackRow, "BOTTOMLEFT", 0, -12)
  keybindsDivider:SetPoint("TOPRIGHT", feedbackRow, "BOTTOMRIGHT", 0, -12)

  local keybindsTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
  keybindsTitle:SetPoint("TOPLEFT", keybindsDivider, "BOTTOMLEFT", 0, -10)
  keybindsTitle:SetText("Keybinds")

  -- Row 1: Show Keybinds checkbox
  local row1 = CreateFrame("Frame", nil, scrollChild)
  row1:SetHeight(ROW_HEIGHT)

  local checkbox = CreateFrame("CheckButton", nil, row1, "UICheckButtonTemplate")
  checkbox:SetPoint("LEFT", 0, 0)
  checkbox:SetSize(30, 30)

  local showLabel = row1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  showLabel:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
  showLabel:SetJustifyH("LEFT")
  showLabel:SetText("Show Keybinds")

  -- Row 2: Shorten Keybinds Text — conditional: visible when show=true
  local row2 = CreateFrame("Frame", nil, scrollChild)
  row2:SetHeight(ROW_HEIGHT)

  local shortenCheckbox = CreateFrame("CheckButton", nil, row2, "UICheckButtonTemplate")
  shortenCheckbox:SetPoint("LEFT", 0, 0)
  shortenCheckbox:SetSize(30, 30)

  local shortenLabel = row2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  shortenLabel:SetPoint("LEFT", shortenCheckbox, "RIGHT", 5, 0)
  shortenLabel:SetJustifyH("LEFT")
  shortenLabel:SetText("Shorten Keybinds Text")

  -- Row 3: Font Size — conditional: visible when show=true
  local row3 = CreateFrame("Frame", nil, scrollChild)
  row3:SetHeight(ROW_HEIGHT)

  local fontLabel = row3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  fontLabel:SetPoint("LEFT", 0, 0)
  fontLabel:SetWidth(LABEL_WIDTH)
  fontLabel:SetJustifyH("LEFT")
  fontLabel:SetText("Font Size")

  local fontSteppers = CreateFrame("Frame", nil, row3, "MinimalSliderWithSteppersTemplate")
  fontSteppers:SetPoint("LEFT", fontLabel, "RIGHT", 5, 0)
  fontSteppers:SetWidth(SLIDER_WIDTH)
  fontSteppers:SetHeight(17)
  local fontFmt = {}
  fontFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(fontSteppers, prefix .. "fontSize", fontFmt)
  fontSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(prefix .. "fontSize", value)
    if ns.RefreshAllHotkeys then
      ns.RefreshAllHotkeys()
    end
  end, fontSteppers)

  -- Row 4: Position — conditional: visible when show=true
  local row4 = CreateFrame("Frame", nil, scrollChild)
  row4:SetHeight(ROW_HEIGHT)

  local posLabel = row4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  posLabel:SetPoint("LEFT", 0, 0)
  posLabel:SetWidth(LABEL_WIDTH)
  posLabel:SetJustifyH("LEFT")
  posLabel:SetText("Position")

  local posDropdown = CreateFrame("DropdownButton", nil, row4, "WowStyle1DropdownTemplate")
  posDropdown:SetPoint("LEFT", posLabel, "RIGHT", 5, 0)
  posDropdown:SetWidth(DROPDOWN_WIDTH)

  local UpdatePanel
  local hotkeyResetBtn
  local hotkeyResetDivider

  posDropdown:SetupMenu(function(owner, rootDescription)
    for _, pos in ipairs(POSITION_ORDER) do
      rootDescription:CreateRadio(ns.HOTKEY_POSITION_DISPLAY[pos], function()
        return ns.db[prefix .. "position"] == pos
      end, function()
        ns.Settings.Set(prefix .. "position", pos)
        if ns.RefreshAllHotkeys then
          ns.RefreshAllHotkeys()
        end
        UpdatePanel()
      end, pos)
    end
  end)

  -- Row 5: Horizontal Offset — conditional: visible when show=true
  local row5 = CreateFrame("Frame", nil, scrollChild)
  row5:SetHeight(ROW_HEIGHT)

  local offsetXLabel = row5:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  offsetXLabel:SetPoint("LEFT", 0, 0)
  offsetXLabel:SetWidth(LABEL_WIDTH)
  offsetXLabel:SetJustifyH("LEFT")
  offsetXLabel:SetText("Horizontal")

  local offsetXSteppers = CreateFrame("Frame", nil, row5, "MinimalSliderWithSteppersTemplate")
  offsetXSteppers:SetPoint("LEFT", offsetXLabel, "RIGHT", 5, 0)
  offsetXSteppers:SetWidth(SLIDER_WIDTH)
  offsetXSteppers:SetHeight(17)
  local oxFmt = {}
  oxFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(offsetXSteppers, prefix .. "offsetX", oxFmt)
  offsetXSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(prefix .. "offsetX", value)
    if ns.RefreshAllHotkeys then
      ns.RefreshAllHotkeys()
    end
  end, offsetXSteppers)

  -- Row 6: Vertical Offset — conditional: visible when show=true
  local row6 = CreateFrame("Frame", nil, scrollChild)
  row6:SetHeight(ROW_HEIGHT)

  local offsetYLabel = row6:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  offsetYLabel:SetPoint("LEFT", 0, 0)
  offsetYLabel:SetWidth(LABEL_WIDTH)
  offsetYLabel:SetJustifyH("LEFT")
  offsetYLabel:SetText("Vertical")

  local offsetYSteppers = CreateFrame("Frame", nil, row6, "MinimalSliderWithSteppersTemplate")
  offsetYSteppers:SetPoint("LEFT", offsetYLabel, "RIGHT", 5, 0)
  offsetYSteppers:SetWidth(SLIDER_WIDTH)
  offsetYSteppers:SetHeight(17)
  local oyFmt = {}
  oyFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(offsetYSteppers, prefix .. "offsetY", oyFmt)
  offsetYSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(prefix .. "offsetY", value)
    if ns.RefreshAllHotkeys then
      ns.RefreshAllHotkeys()
    end
  end, offsetYSteppers)

  -- -----------------------------------------------------------------------
  -- Stack Text section — divider + 4 rows (always visible)
  -- -----------------------------------------------------------------------

  local stacksPrefix = prefix:gsub("hotkeys_$", "stacks_")

  local divider = scrollChild:CreateTexture(nil, "ARTWORK")
  divider:SetHeight(1)
  divider:SetColorTexture(1, 1, 1, 0.3)

  local stackTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
  stackTitle:SetText("Stacks")

  -- Row S1: Font Size
  local sRow1 = CreateFrame("Frame", nil, scrollChild)
  sRow1:SetHeight(ROW_HEIGHT)

  local sFontLabel = sRow1:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  sFontLabel:SetPoint("LEFT", 0, 0)
  sFontLabel:SetWidth(LABEL_WIDTH)
  sFontLabel:SetJustifyH("LEFT")
  sFontLabel:SetText("Font Size")

  local sFontSteppers = CreateFrame("Frame", nil, sRow1, "MinimalSliderWithSteppersTemplate")
  sFontSteppers:SetPoint("LEFT", sFontLabel, "RIGHT", 5, 0)
  sFontSteppers:SetWidth(SLIDER_WIDTH)
  sFontSteppers:SetHeight(17)
  local sfFmt = {}
  sfFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(sFontSteppers, stacksPrefix .. "fontSize", sfFmt)
  sFontSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(stacksPrefix .. "fontSize", value)
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end, sFontSteppers)

  -- Row S2: Position
  local sRow2 = CreateFrame("Frame", nil, scrollChild)
  sRow2:SetHeight(ROW_HEIGHT)

  local sPosLabel = sRow2:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  sPosLabel:SetPoint("LEFT", 0, 0)
  sPosLabel:SetWidth(LABEL_WIDTH)
  sPosLabel:SetJustifyH("LEFT")
  sPosLabel:SetText("Position")

  local sPosDropdown = CreateFrame("DropdownButton", nil, sRow2, "WowStyle1DropdownTemplate")
  sPosDropdown:SetPoint("LEFT", sPosLabel, "RIGHT", 5, 0)
  sPosDropdown:SetWidth(DROPDOWN_WIDTH)

  local UpdateStacksWidgets

  sPosDropdown:SetupMenu(function(owner, rootDescription)
    for _, pos in ipairs(POSITION_ORDER) do
      rootDescription:CreateRadio(ns.HOTKEY_POSITION_DISPLAY[pos], function()
        return ns.db[stacksPrefix .. "position"] == pos
      end, function()
        ns.Settings.Set(stacksPrefix .. "position", pos)
        if ns.RefreshAllStacks then
          ns.RefreshAllStacks()
        end
        if UpdateStacksWidgets then
          UpdateStacksWidgets()
        end
      end, pos)
    end
  end)

  -- Row S3: Horizontal Offset
  local sRow3 = CreateFrame("Frame", nil, scrollChild)
  sRow3:SetHeight(ROW_HEIGHT)

  local sOffsetXLabel = sRow3:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  sOffsetXLabel:SetPoint("LEFT", 0, 0)
  sOffsetXLabel:SetWidth(LABEL_WIDTH)
  sOffsetXLabel:SetJustifyH("LEFT")
  sOffsetXLabel:SetText("Horizontal")

  local sOffsetXSteppers = CreateFrame("Frame", nil, sRow3, "MinimalSliderWithSteppersTemplate")
  sOffsetXSteppers:SetPoint("LEFT", sOffsetXLabel, "RIGHT", 5, 0)
  sOffsetXSteppers:SetWidth(SLIDER_WIDTH)
  sOffsetXSteppers:SetHeight(17)
  local soxFmt = {}
  soxFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(sOffsetXSteppers, stacksPrefix .. "offsetX", soxFmt)
  sOffsetXSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(stacksPrefix .. "offsetX", value)
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end, sOffsetXSteppers)

  -- Row S4: Vertical Offset
  local sRow4 = CreateFrame("Frame", nil, scrollChild)
  sRow4:SetHeight(ROW_HEIGHT)

  local sOffsetYLabel = sRow4:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  sOffsetYLabel:SetPoint("LEFT", 0, 0)
  sOffsetYLabel:SetWidth(LABEL_WIDTH)
  sOffsetYLabel:SetJustifyH("LEFT")
  sOffsetYLabel:SetText("Vertical")

  local sOffsetYSteppers = CreateFrame("Frame", nil, sRow4, "MinimalSliderWithSteppersTemplate")
  sOffsetYSteppers:SetPoint("LEFT", sOffsetYLabel, "RIGHT", 5, 0)
  sOffsetYSteppers:SetWidth(SLIDER_WIDTH)
  sOffsetYSteppers:SetHeight(17)
  local soyFmt = {}
  soyFmt[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  InitSettingSlider(sOffsetYSteppers, stacksPrefix .. "offsetY", soyFmt)
  sOffsetYSteppers:RegisterCallback("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    ns.Settings.Set(stacksPrefix .. "offsetY", value)
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end, sOffsetYSteppers)

  UpdateStacksWidgets = function()
    if sFontSteppers and sFontSteppers.Slider then
      sFontSteppers.Slider:SetValue(ns.db[stacksPrefix .. "fontSize"])
    end

    SetDropdownText(sPosDropdown, ns.HOTKEY_POSITION_DISPLAY[ns.db[stacksPrefix .. "position"]])

    if sOffsetXSteppers and sOffsetXSteppers.Slider then
      sOffsetXSteppers.Slider:SetValue(ns.db[stacksPrefix .. "offsetX"])
    end

    if sOffsetYSteppers and sOffsetYSteppers.Slider then
      sOffsetYSteppers.Slider:SetValue(ns.db[stacksPrefix .. "offsetY"])
    end
  end

  -- -----------------------------------------------------------------------

  checkbox:SetScript("OnClick", function(self)
    ns.Settings.Set(prefix .. "show", self:GetChecked())
    UpdatePanel()
    if ns.RefreshAllHotkeys then
      ns.RefreshAllHotkeys()
    end
  end)

  shortenCheckbox:SetScript("OnClick", function(self)
    ns.Settings.Set(prefix .. "shorten", self:GetChecked())
    if ns.RefreshAllHotkeys then
      ns.RefreshAllHotkeys()
    end
  end)

  UpdatePanel = function()
    local aMap = (getViewer and IsViewerVertical(getViewer())) and ns.ALIGN_V_DISPLAY or ns.ALIGN_DISPLAY
    SetDropdownText(alignDropdown, aMap[ns.db[alignKey]])

    local showHotkeys = ns.db[prefix .. "show"]
    checkbox:SetChecked(showHotkeys)
    feedbackCheckbox:SetChecked(ns.db[feedbackKey])
    shortenCheckbox:SetChecked(ns.db[prefix .. "shorten"])

    if fontSteppers and fontSteppers.Slider then
      fontSteppers.Slider:SetValue(ns.db[prefix .. "fontSize"])
    end

    SetDropdownText(posDropdown, ns.HOTKEY_POSITION_DISPLAY[ns.db[prefix .. "position"]])

    if offsetXSteppers and offsetXSteppers.Slider then
      offsetXSteppers.Slider:SetValue(ns.db[prefix .. "offsetX"])
    end

    if offsetYSteppers and offsetYSteppers.Slider then
      offsetYSteppers.Slider:SetValue(ns.db[prefix .. "offsetY"])
    end

    UpdateStacksWidgets()

    local visibleRows = 3 -- alignment + feedback + show keybinds always visible

    -- Keybinds group: anchor row1 below keybinds title
    row1:ClearAllPoints()
    row1:SetPoint("TOP", keybindsTitle, "BOTTOM", 0, -6)
    row1:SetPoint("LEFT", scrollChild, "LEFT", CONTENT_LEFT, 0)
    row1:SetPoint("RIGHT", scrollChild, "RIGHT", -CONTENT_LEFT, 0)

    local lastRow = row1

    if showHotkeys then
      row2:ClearAllPoints()
      row2:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row2:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row2:Show()
      lastRow = row2
      visibleRows = visibleRows + 1

      row3:ClearAllPoints()
      row3:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row3:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row3:Show()
      lastRow = row3
      visibleRows = visibleRows + 1

      row4:ClearAllPoints()
      row4:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row4:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row4:Show()
      lastRow = row4
      visibleRows = visibleRows + 1

      row5:ClearAllPoints()
      row5:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row5:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row5:Show()
      lastRow = row5
      visibleRows = visibleRows + 1

      row6:ClearAllPoints()
      row6:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, 0)
      row6:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, 0)
      row6:Show()
      lastRow = row6
      visibleRows = visibleRows + 1
    else
      row2:Hide()
      row3:Hide()
      row4:Hide()
      row5:Hide()
      row6:Hide()
    end

    -- Stack Text divider + rows (always visible)
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -12)
    divider:SetPoint("TOPRIGHT", lastRow, "BOTTOMRIGHT", 0, -12)

    stackTitle:ClearAllPoints()
    stackTitle:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)

    sRow1:ClearAllPoints()
    sRow1:SetPoint("TOP", stackTitle, "BOTTOM", 0, -6)
    sRow1:SetPoint("LEFT", scrollChild, "LEFT", CONTENT_LEFT, 0)
    sRow1:SetPoint("RIGHT", scrollChild, "RIGHT", -CONTENT_LEFT, 0)
    sRow1:Show()

    sRow2:ClearAllPoints()
    sRow2:SetPoint("TOPLEFT", sRow1, "BOTTOMLEFT", 0, 0)
    sRow2:SetPoint("TOPRIGHT", sRow1, "BOTTOMRIGHT", 0, 0)
    sRow2:Show()

    sRow3:ClearAllPoints()
    sRow3:SetPoint("TOPLEFT", sRow2, "BOTTOMLEFT", 0, 0)
    sRow3:SetPoint("TOPRIGHT", sRow2, "BOTTOMRIGHT", 0, 0)
    sRow3:Show()

    sRow4:ClearAllPoints()
    sRow4:SetPoint("TOPLEFT", sRow3, "BOTTOMLEFT", 0, 0)
    sRow4:SetPoint("TOPRIGHT", sRow3, "BOTTOMRIGHT", 0, 0)
    sRow4:Show()

    hotkeyResetDivider:ClearAllPoints()
    hotkeyResetDivider:SetPoint("TOPLEFT", sRow4, "BOTTOMLEFT", 0, -12)
    hotkeyResetDivider:SetPoint("TOPRIGHT", sRow4, "BOTTOMRIGHT", 0, -12)
    hotkeyResetBtn:ClearAllPoints()
    hotkeyResetBtn:SetPoint("TOPLEFT", hotkeyResetDivider, "BOTTOMLEFT", 0, -10)
    hotkeyResetBtn:SetPoint("TOPRIGHT", hotkeyResetDivider, "BOTTOMRIGHT", 0, -10)

    local keybindsHeaderHeight = DIVIDER_GAP + keybindsTitle:GetStringHeight() + 6
    local stacksExtraHeight = DIVIDER_GAP + stackTitle:GetStringHeight() + 6 + (ROW_HEIGHT * 4)
    local contentHeight = (ROW_HEIGHT * visibleRows) + keybindsHeaderHeight + stacksExtraHeight + 52
    scrollChild:SetHeight(contentHeight)

    -- Set panel height for standalone mode (embedded mode ignores this)
    f:SetHeight(titleBottom + contentHeight + CONTENT_BOTTOM)

    -- Reset scroll to top when toggling sections
    scrollFrame:SetVerticalScroll(0)
    UpdateScrollBar()
  end

  -- Reset To Default button
  local hotkeyKeys = { alignKey, feedbackKey }
  for key in pairs(ns.DEFAULTS) do
    if key:find("^" .. prefix) or key:find("^" .. stacksPrefix) then
      hotkeyKeys[#hotkeyKeys + 1] = key
    end
  end
  hotkeyResetDivider = scrollChild:CreateTexture(nil, "ARTWORK")
  hotkeyResetDivider:SetHeight(1)
  hotkeyResetDivider:SetColorTexture(1, 1, 1, 0.3)

  hotkeyResetBtn = CreateRedButton(scrollChild, "Reset To Default", function()
    for _, key in ipairs(hotkeyKeys) do
      ns.Settings.Reset(key)
    end
    UpdatePanel()
    if applyAlignFn then
      applyAlignFn()
    end
    if ns.RefreshAllHotkeys then
      ns.RefreshAllHotkeys()
    end
    if ns.RefreshAllStacks then
      ns.RefreshAllStacks()
    end
  end)

  f.UpdatePanel = UpdatePanel
  UpdatePanel()

  return f
end

-- ---------------------------------------------------------------------------
-- Essential / Utility hotkeys panel show / hide
-- ---------------------------------------------------------------------------

local function ShowEssentialHotkeysPanel()
  if not essentialHotkeysPanel then
    essentialHotkeysPanel = CreateHotkeysPanelForViewer(
      "Enhanced CDM - Essential",
      "essential_hotkeys_",
      "essential_align",
      ns.ApplyEssentialLayout,
      function()
        return ns.essentialViewer
      end
    )
  end
  essentialHotkeysPanel.UpdatePanel()
  ns.RefreshEssentialPanel = essentialHotkeysPanel.UpdatePanel
  EmbedPanelInDialog(essentialHotkeysPanel)
end

local function HideEssentialHotkeysPanel()
  if essentialHotkeysPanel then
    essentialHotkeysPanel:Hide()
  end
end

local function ShowUtilityHotkeysPanel()
  if not utilityHotkeysPanel then
    utilityHotkeysPanel = CreateHotkeysPanelForViewer(
      "Enhanced CDM - Utility",
      "utility_hotkeys_",
      "utility_align",
      ns.ApplyUtilityLayout,
      function()
        return ns.utilityViewer
      end
    )
  end
  utilityHotkeysPanel.UpdatePanel()
  ns.RefreshUtilityPanel = utilityHotkeysPanel.UpdatePanel
  EmbedPanelInDialog(utilityHotkeysPanel)
end

local function HideUtilityHotkeysPanel()
  if utilityHotkeysPanel then
    utilityHotkeysPanel:Hide()
  end
end

-- ---------------------------------------------------------------------------
-- Edit Mode hooks — show/hide panel when Tracked Buffs system is selected
-- ---------------------------------------------------------------------------

local function HideAllPanels()
  UnembedPanel()
  HideEnhancedCDMPanel()
  HideBarsPanel()
  HideEssentialHotkeysPanel()
  HideUtilityHotkeysPanel()
end

InstallDialogHooks = function()
  local dialog = _G["EditModeSystemSettingsDialog"]
  if not dialog then
    return
  end

  ns.ViewerLifecycle.HookMethod(dialog, "UpdateSettings", function(self)
    if self ~= _G.EditModeSystemSettingsDialog or not self.attachedToSystem then
      return
    end
    local buffViewer = _G["BuffIconCooldownViewer"]
    local buffBarViewer = _G["BuffBarCooldownViewer"]
    local essViewer = _G["EssentialCooldownViewer"]
    local utilViewer = _G["UtilityCooldownViewer"]
    if
      self.attachedToSystem == buffViewer
      or self.attachedToSystem == buffBarViewer
      or self.attachedToSystem == essViewer
      or self.attachedToSystem == utilViewer
    then
      -- Hide IconDirection - our alignment overrides Blizzard's direction
      local children = { self.Settings:GetChildren() }
      for _, child in ipairs(children) do
        if child.setting == Enum.EditModeCooldownViewerSetting.IconDirection then
          child:Hide()
        end
      end
      self.Settings:Layout()
    end

    -- Refresh our panel labels when Blizzard settings change (e.g. Orientation)
    if self.attachedToSystem == buffViewer then
      RefreshEditModePanel()
    elseif self.attachedToSystem == essViewer then
      if essentialHotkeysPanel and essentialHotkeysPanel.UpdatePanel then
        essentialHotkeysPanel.UpdatePanel()
      end
    elseif self.attachedToSystem == utilViewer then
      if utilityHotkeysPanel and utilityHotkeysPanel.UpdatePanel then
        utilityHotkeysPanel.UpdatePanel()
      end
    end
  end)

  if not hookedDialogs[dialog] then
    dialog:HookScript("OnHide", function(self)
      if self == _G.EditModeSystemSettingsDialog then
        UnembedPanel()
      end
    end)
    hookedDialogs[dialog] = true
  end
end

local function SetupEditMode()
  HookBarContextMenu()
  HookSettingsBarPreview()
  if not EditModeManagerFrame then
    return
  end
  ns.ViewerLifecycle.HookMethod(EditModeManagerFrame, "SelectSystem", function(self, systemFrame)
    if self ~= EditModeManagerFrame or not systemFrame then
      return
    end
    if InstallDialogHooks then
      InstallDialogHooks()
    end

    local buffViewer = _G["BuffIconCooldownViewer"]
    local buffBarViewer = _G["BuffBarCooldownViewer"]
    local essViewer = _G["EssentialCooldownViewer"]
    local utilViewer = _G["UtilityCooldownViewer"]
    HideAllPanels()
    if systemFrame == buffViewer then
      ShowEnhancedCDMPanel()
      if ns.ScheduleLayout then
        ns.ScheduleLayout()
      end
    elseif systemFrame == buffBarViewer then
      ShowBarsPanel()
      if ns.ScheduleBarsLayout then
        ns.ScheduleBarsLayout()
      end
    elseif systemFrame == essViewer then
      ShowEssentialHotkeysPanel()
      if ns.ScheduleEssentialLayout then
        ns.ScheduleEssentialLayout()
      end
    elseif systemFrame == utilViewer then
      ShowUtilityHotkeysPanel()
      if ns.ScheduleUtilityLayout then
        ns.ScheduleUtilityLayout()
      end
    end
  end)

  ns.ViewerLifecycle.HookMethod(EditModeManagerFrame, "ClearSelectedSystem", function(self)
    if self == EditModeManagerFrame then
      HideAllPanels()
    end
  end)

  -- Hide panels on Edit Mode exit and refresh layouts to clear stale positions
  ns.ViewerLifecycle.HookMethod(EditModeManagerFrame, "ExitEditMode", function(self)
    if self ~= EditModeManagerFrame then
      return
    end
    HideAllPanels()
    if ns.ScheduleAllLayouts then
      ns.ScheduleAllLayouts()
    end
  end)

  -- Install dialog hooks if the settings dialog already exists.
  if InstallDialogHooks then
    InstallDialogHooks()
  end
end

ns.SetupEditMode = SetupEditMode

-- ---------------------------------------------------------------------------
-- Bar gradient colors — context menu integration for Tracked Bars entries
-- ---------------------------------------------------------------------------

-- Apply gradient preview to a settings-panel bar entry
local function ApplySettingsBarPreview(entry)
  if not entry or not entry.cooldownID then
    return
  end
  local db = ns.db
  if not db then
    return
  end
  if ns.RefreshBarGradient then
    ns.RefreshBarGradient(entry)
  end
end

local function OpenBarColorPicker(id, endpoint, settingsEntry)
  local previous = ns.db.bars_colors[id]
  local current = previous or ns.DEFAULT_BAR_COLORS
  local function Refresh()
    ns.RefreshAllBarGradients()
    ApplySettingsBarPreview(settingsEntry)
  end
  ColorPickerFrame:SetupColorPickerAndShow({
    r = current[endpoint .. "R"],
    g = current[endpoint .. "G"],
    b = current[endpoint .. "B"],
    hasOpacity = false,
    swatchFunc = function()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      if ns.Settings.SetBarColor(id, endpoint, r, g, b) then
        Refresh()
      end
    end,
    cancelFunc = function()
      ns.Settings.SetBarColors(id, previous)
      Refresh()
    end,
  })
end

-- Scan all descendants for bar entries (frames with cooldownID + StatusBar child)
local function ScanAndApplyBarPreviews(frame, depth)
  if depth > 8 then
    return
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if child.cooldownID then
      -- Leaf entry — check for StatusBar child (bar vs icon)
      for _, sub in ipairs({ child:GetChildren() }) do
        if sub:GetObjectType() == "StatusBar" then
          ApplySettingsBarPreview(child)
          break
        end
      end
    else
      ScanAndApplyBarPreviews(child, depth + 1)
    end
  end
end

-- Apply gradient previews to settings-panel bar entries after tab/view change
local previewHookedFrames = setmetatable({}, { __mode = "k" })
local function GetSettingsFrameForBarScan()
  local settingsFrame = _G["CooldownViewerSettings"]
  if not settingsFrame or not settingsFrame:IsVisible() then
    return nil
  end
  local db = ns.db
  if not db or not db.bars_colors or not next(db.bars_colors) then
    return nil
  end
  return settingsFrame
end

local ScheduleSettingsBarScanOnce = ns.CreateNextFrameScheduler(function()
  local settingsFrame = GetSettingsFrameForBarScan()
  if settingsFrame then
    ScanAndApplyBarPreviews(settingsFrame, 0)
  end
end)

local function ScheduleSettingsBarScan()
  if not GetSettingsFrameForBarScan() then
    return
  end
  -- Delay one frame so scroll pool entries are created.
  ScheduleSettingsBarScanOnce()
end
ns.ScheduleSettingsBarScan = ScheduleSettingsBarScan

HookSettingsBarPreview = function()
  local settingsFrame = _G["CooldownViewerSettings"]
  if not settingsFrame then
    return
  end
  -- Hook both tab button clicks — scan after content populates
  if settingsFrame.TabButtons then
    for _, tab in pairs(settingsFrame.TabButtons) do
      if type(tab) == "table" and tab.HookScript and not previewHookedFrames[tab] then
        tab:HookScript("OnMouseUp", ScheduleSettingsBarScan)
        previewHookedFrames[tab] = true
      end
    end
  end

  -- Also scan on settings panel open (covers case where bars tab is already active)
  if not previewHookedFrames[settingsFrame] then
    settingsFrame:HookScript("OnShow", ScheduleSettingsBarScan)
    previewHookedFrames[settingsFrame] = true
  end
end

-- Extend only Blizzard's tagged cooldown-settings menu
local menuHooked = false
HookBarContextMenu = function()
  if menuHooked or not Menu then
    return
  end
  Menu.ModifyMenu("MENU_COOLDOWN_SETTINGS_ITEM", function(owner, rootDescription)
    if not ns.db or not owner or not ns.Settings.IsCooldownID(owner.cooldownID) then
      return
    end
    local isBar = false
    for _, child in ipairs({ owner:GetChildren() }) do
      if child:GetObjectType() == "StatusBar" then
        isBar = true
        break
      end
    end
    if not isBar then
      return
    end
    local id = owner.cooldownID
    rootDescription:CreateDivider()
    rootDescription:CreateTitle("Gradient Colors")
    rootDescription:CreateButton("Set Start Color", function()
      OpenBarColorPicker(id, "s", owner)
    end)
    rootDescription:CreateButton("Set End Color", function()
      OpenBarColorPicker(id, "e", owner)
    end)
    if ns.db.bars_colors[id] then
      rootDescription:CreateButton("Reset Gradient", function()
        ns.Settings.SetBarColors(id, nil)
        ns.RefreshAllBarGradients()
        ApplySettingsBarPreview(owner)
      end)
    end
  end)
  menuHooked = true
end
