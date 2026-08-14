-- Enhanced CDM: Core — layout engine, hooks, init, slash commands, events
local ADDON_NAME, ns = ...

local function IsViewerVertical(v)
    return v and v.IsHorizontal and not v:IsHorizontal()
end
ns.IsViewerVertical = IsViewerVertical

local db
local viewer
local hookedFrames = {}
local mixinHooksInstalled = false
local hookState = { installed = false }
local VERSION

local barViewer
local barHookedFrames = {}
local barHookState = { installed = false }

local essentialViewer
local utilityViewer
local essentialHookedFrames = {}
local utilityHookedFrames = {}
local essentialHookState = { installed = false }
local utilityHookState = { installed = false }
local slotToBinding = {}
local bindingSlots = {}
local initTicker = nil
local feedbackHookedButtons = {}

local function CreateNextFrameScheduler(callback)
    local timer

    local function Schedule()
        if timer then return end
        timer = C_Timer.NewTimer(0, function()
            timer = nil
            callback()
        end)
    end

    local function Cancel()
        if not timer then return end
        timer:Cancel()
        timer = nil
    end

    return Schedule, Cancel
end
ns.CreateNextFrameScheduler = CreateNextFrameScheduler

-- ---------------------------------------------------------------------------
-- Keybinding engine — maps spellID → formatted hotkey text
-- ---------------------------------------------------------------------------

-- Action bar frame-name → binding-command-prefix mapping
local ACTION_BAR_BINDINGS = {
    { frame = "ActionButton",             binding = "ACTIONBUTTON" },
    { frame = "MultiBarBottomLeftButton", binding = "MULTIACTIONBAR1BUTTON" },
    { frame = "MultiBarBottomRightButton",binding = "MULTIACTIONBAR2BUTTON" },
    { frame = "MultiBarRightButton",      binding = "MULTIACTIONBAR3BUTTON" },
    { frame = "MultiBarLeftButton",       binding = "MULTIACTIONBAR4BUTTON" },
    { frame = "MultiBar5Button",          binding = "MULTIACTIONBAR5BUTTON" },
    { frame = "MultiBar6Button",          binding = "MULTIACTIONBAR6BUTTON" },
    { frame = "MultiBar7Button",          binding = "MULTIACTIONBAR7BUTTON" },
}

-- Builds slotNumber → bindingCommandName lookup from actual button frames
local function BuildSlotToBindingMap()
    wipe(slotToBinding)
    wipe(bindingSlots)
    for _, info in ipairs(ACTION_BAR_BINDINGS) do
        for i = 1, 12 do
            local btn = _G[info.frame .. i]
            if btn then
                local slot = btn:GetAttribute("action")
                    or (btn.GetAction and btn:GetAction())
                    or (btn.action)
                -- Main action bar uses a page-based state driver that may not
                -- be ready during initial login; fall back to button index
                -- which equals the correct slot on page 1.
                if (not slot or slot == 0) and info.frame == "ActionButton" then
                    slot = i
                end
                if slot then
                    slot = tonumber(slot)
                    if not slotToBinding[slot] then
                        bindingSlots[#bindingSlots + 1] = slot
                    end
                    slotToBinding[slot] = info.binding .. i
                end
            end
        end
    end
end

-- Abbreviate raw key names for compact display
local function FormatKeyText(key)
    if not key then return nil end
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("MOUSEWHEELUP", "MWU")
    key = key:gsub("MOUSEWHEELDOWN", "MWD")
    key = key:gsub("BUTTON(%d+)", "M%1")
    key = key:gsub("NUMPAD(%d+)", "N%1")
    key = key:gsub("NUMPADDECIMAL", "N.")
    key = key:gsub("NUMPADPLUS", "N+")
    key = key:gsub("NUMPADMINUS", "N-")
    key = key:gsub("NUMPADMULTIPLY", "N*")
    key = key:gsub("NUMPADDIVIDE", "N/")
    key = key:gsub("PAGEUP", "PU")
    key = key:gsub("PAGEDOWN", "PD")
    key = key:gsub("SPACEBAR", "SP")
    key = key:gsub("BACKSPACE", "BS")
    key = key:gsub("SPACE", "SP")
    key = key:gsub("CAPSLOCK", "CAP")
    key = key:gsub("INSERT", "INS")
    key = key:gsub("DELETE", "DEL")
    key = key:gsub("HOME", "HM")
    key = key:gsub("DOWNARROW", "DN")
    key = key:gsub("UPARROW", "UP")
    key = key:gsub("LEFTARROW", "LT")
    key = key:gsub("RIGHTARROW", "RT")
    return key
end

local function GetSlotKeyText(slot, shorten)
    local bindingName = slotToBinding[slot]
    if not bindingName then return nil end
    local key = GetBindingKey(bindingName)
    if not key then return nil end
    return shorten and FormatKeyText(key) or key
end

-- Returns formatted hotkey text for a spellID, or nil if not bound
-- When shorten is false, returns the raw key name without abbreviation
local function GetHotkeyText(spellID, shorten)
    if not spellID then return nil end

    -- Try finding action bar slots for this spell
    local slots = C_ActionBar and C_ActionBar.FindSpellActionButtons
        and C_ActionBar.FindSpellActionButtons(spellID)

    -- If not found, try override spell resolution
    if (not slots or #slots == 0) and C_Spell and C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(spellID)
        if overrideID and overrideID ~= spellID
            and C_ActionBar and C_ActionBar.FindSpellActionButtons then
            slots = C_ActionBar.FindSpellActionButtons(overrideID)
        end
    end

    if not slots or #slots == 0 then return nil end

    -- Check each slot for a binding (prefer the first one found)
    for _, slot in ipairs(slots) do
        local text = GetSlotKeyText(slot, shorten)
        if text then return text end
    end

    return nil
end

local function GetMacroItemID(macroID)
    if not macroID or not GetMacroItem then return nil end

    local itemName, itemLink = GetMacroItem(macroID)
    local itemIdentifier = itemLink or itemName
    if not itemIdentifier then return nil end

    if GetItemInfoInstant then
        return GetItemInfoInstant(itemIdentifier)
    end

    if type(itemIdentifier) == "number" then
        return itemIdentifier
    end

    return tonumber(tostring(itemIdentifier):match("item:(%d+)"))
end

local function GetSlotActionIDs(slot)
    if not slot or slot == 0 then return nil, nil end

    local actionType, id = GetActionInfo(slot)
    if actionType == "spell" then
        return id, nil
    elseif actionType == "item" then
        return nil, id
    elseif actionType == "macro" and id then
        local spellID = GetMacroSpell and GetMacroSpell(id)
        return spellID, GetMacroItemID(id)
    end

    return nil, nil
end

local function GetFrameItemID(frame)
    if not frame then return nil end

    local equipSlot = frame.GetEquipSlot and frame:GetEquipSlot()
    if equipSlot and GetInventoryItemID then
        local itemID = GetInventoryItemID("player", equipSlot)
        if itemID then return itemID end
    end

    local itemLocation = frame.GetItemLocation and frame:GetItemLocation()
    if itemLocation and C_Item and C_Item.GetItemID then
        local itemID = C_Item.GetItemID(itemLocation)
        if itemID then return itemID end
    end

    if frame.GetSpellCategoryTooltipItemID then
        return frame:GetSpellCategoryTooltipItemID()
    end

    return nil
end

local function GetFrameActionIDs(frame)
    if not frame then return nil, nil end

    local spellID = (frame.GetBaseSpellID and frame:GetBaseSpellID())
        or frame.rangeCheckSpellID
    return spellID, GetFrameItemID(frame)
end

local function GetItemHotkeyText(itemID, shorten)
    if not itemID then return nil end

    for _, slot in ipairs(bindingSlots) do
        local _, slotItemID = GetSlotActionIDs(slot)
        if slotItemID == itemID then
            local text = GetSlotKeyText(slot, shorten)
            if text then return text end
        end
    end

    return nil
end

-- Returns the settings prefix ("essential_hotkeys_" or "utility_hotkeys_") for a frame
-- Reads from ns.* (kept in sync by TryInit) so tests can control comparison targets
local function GetHotkeyPrefix(frame)
    local parent = frame and frame:GetParent()
    if not parent then return nil end
    if parent == ns.essentialViewer then
        return "essential_hotkeys_"
    elseif parent == ns.utilityViewer then
        return "utility_hotkeys_"
    end
    return nil
end
ns._GetHotkeyPrefix = GetHotkeyPrefix

local function GetStacksPrefix(frame)
    local parent = frame and frame:GetParent()
    if not parent then return nil end
    if parent == ns.essentialViewer then
        return "essential_stacks_"
    elseif parent == ns.utilityViewer then
        return "utility_stacks_"
    elseif parent == ns.viewer then
        return "buffs_stacks_"
    end
    return nil
end
ns._GetStacksPrefix = GetStacksPrefix

-- Create or update the hotkey FontString on a cooldown viewer icon
local function UpdateFrameHotkey(frame)
    if not frame or not db then
        if frame and frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    local prefix = GetHotkeyPrefix(frame)
    if not prefix or not db[prefix .. "show"] then
        if frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    local spellID, itemID = GetFrameActionIDs(frame)
    if not spellID and not itemID then
        if frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    local shorten = db[prefix .. "shorten"]
    local text = itemID and GetItemHotkeyText(itemID, shorten)
        or GetHotkeyText(spellID, shorten)
    if not text then
        if frame._ecdmHotkeyText then
            frame._ecdmHotkeyText:Hide()
        end
        return
    end

    -- Create an overlay frame above the Cooldown frame so text renders on top of the swipe
    if not frame._ecdmHotkeyText then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        if frame.Cooldown then
            overlay:SetFrameLevel(frame.Cooldown:GetFrameLevel() + 1)
        end
        local fs = overlay:CreateFontString(nil, "OVERLAY")
        fs:SetTextColor(1, 1, 1, 1)
        frame._ecdmHotkeyText = fs
    end

    local fs = frame._ecdmHotkeyText
    local position = db[prefix .. "position"]
    local fontSize = db[prefix .. "fontSize"]
    local anchor = ns.HOTKEY_POSITION_ANCHORS[position]
        or ns.HOTKEY_POSITION_ANCHORS["TOPLEFT"]
    local justify = ns.HOTKEY_POSITION_JUSTIFY[position] or "LEFT"

    local offsetX = db[prefix .. "offsetX"]
    local offsetY = db[prefix .. "offsetY"]

    fs:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
    fs:ClearAllPoints()
    fs:SetPoint(anchor.point, frame, anchor.point, offsetX, offsetY)
    fs:SetJustifyH(justify)
    fs:SetText(text)
    fs:Show()
end

-- Refresh hotkey text on all tracked Essential/Utility children
local function RefreshAllHotkeys()
    BuildSlotToBindingMap()

    local viewers = { essentialViewer, utilityViewer }
    for _, v in ipairs(viewers) do
        if v then
            local children = { v:GetChildren() }
            for _, child in ipairs(children) do
                if child.cooldownID then
                    UpdateFrameHotkey(child)
                end
            end
        end
    end
end

ns.RefreshAllHotkeys = RefreshAllHotkeys

local ScheduleHotkeyRefresh = CreateNextFrameScheduler(RefreshAllHotkeys)

-- ---------------------------------------------------------------------------
-- Click feedback engine — mirrors action bar pushed state on CDM icons
-- ---------------------------------------------------------------------------

local PUSHED_RATIO = 51 / 45

local function GetSlotSpellID(slot)
    return GetSlotActionIDs(slot)
end
ns._GetSlotSpellID = GetSlotSpellID

local function GetButtonSlot(btn)
    return btn:GetAttribute("action")
        or (btn.GetAction and btn:GetAction())
        or btn.action
end

local function FindCDMIconByActionID(actionID, isItem)
    if not actionID then return nil end
    local viewers = { ns.essentialViewer, ns.utilityViewer }
    for _, v in ipairs(viewers) do
        if v then
            local children = { v:GetChildren() }
            for _, child in ipairs(children) do
                if child.cooldownID then
                    if isItem then
                        if GetFrameItemID(child) == actionID then
                            return child
                        end
                    else
                        local childSpell = (child.GetBaseSpellID and child:GetBaseSpellID())
                            or child.rangeCheckSpellID
                        if childSpell == actionID then
                            return child
                        end
                        if C_Spell and C_Spell.GetOverrideSpell then
                            local overrideID = C_Spell.GetOverrideSpell(childSpell or 0)
                            if overrideID and overrideID == actionID then
                                return child
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function FindCDMIcon(spellID, itemID)
    return FindCDMIconByActionID(itemID, true)
        or FindCDMIconByActionID(spellID, false)
end

-- Reads from ns.* (kept in sync by TryInit) so tests can control comparison targets
local function GetFeedbackPrefix(frame)
    local parent = frame and frame:GetParent()
    if not parent then return nil end
    if parent == ns.essentialViewer then
        return "essential_feedback_"
    elseif parent == ns.utilityViewer then
        return "utility_feedback_"
    end
    return nil
end

local function ResizePushedOverlay(frame)
    if not frame or not frame._ecdmPushedTex then return end
    local w, h = frame:GetSize()
    frame._ecdmPushedTex:SetSize(w * PUSHED_RATIO, h * PUSHED_RATIO)
end

local function GetPushedOverlay(frame)
    if not frame._ecdmPushedTex then
        local overlayFrame = CreateFrame("Frame", nil, frame)
        overlayFrame:SetAllPoints(frame)
        local level = frame:GetFrameLevel() + 10
        if frame.Cooldown then
            level = frame.Cooldown:GetFrameLevel() + 5
        end
        overlayFrame:SetFrameLevel(level)
        local tex = overlayFrame:CreateTexture(nil, "OVERLAY")
        tex:SetAtlas("UI-HUD-ActionBar-IconFrame-AddRow-Down")
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        tex:Hide()
        frame._ecdmPushedTex = tex
    end

    ResizePushedOverlay(frame)
    if not frame._ecdmPushedSizeHooked and frame.HookScript then
        frame._ecdmPushedSizeHooked = true
        frame:HookScript("OnSizeChanged", ResizePushedOverlay)
    end

    return frame._ecdmPushedTex
end

local function OnButtonStateChanged(btn, state)
    local slot = GetButtonSlot(btn)
    local spellID, itemID = GetSlotActionIDs(slot)
    if not spellID and not itemID then return end

    local cdmIcon = FindCDMIcon(spellID, itemID)
    if not cdmIcon then return end

    local prefix = GetFeedbackPrefix(cdmIcon)
    if not prefix or not db[prefix .. "show"] then
        if cdmIcon._ecdmPushedTex then
            cdmIcon._ecdmPushedTex:Hide()
        end
        return
    end

    local overlay = GetPushedOverlay(cdmIcon)
    if state == "PUSHED" then
        overlay:Show()
    else
        overlay:Hide()
    end
end

local function InstallFeedbackHooks()
    for _, info in ipairs(ACTION_BAR_BINDINGS) do
        for i = 1, 12 do
            local btn = _G[info.frame .. i]
            if btn and not feedbackHookedButtons[btn] then
                hooksecurefunc(btn, "SetButtonState", OnButtonStateChanged)
                feedbackHookedButtons[btn] = true
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Stack / application count text — repositions the Applications FontString
-- ---------------------------------------------------------------------------

local function UpdateFrameStacks(frame)
    if not frame or not db then return end
    local app = frame.Applications
    if not app then return end
    local fs = app.Applications
    if not fs or not fs.SetFont then return end
    local prefix = GetStacksPrefix(frame)
    if not prefix then return end

    local position = db[prefix .. "position"]
    local fontSize = db[prefix .. "fontSize"]
    local offsetX  = db[prefix .. "offsetX"]
    local offsetY  = db[prefix .. "offsetY"]
    local anchor   = ns.HOTKEY_POSITION_ANCHORS[position]
                     or ns.HOTKEY_POSITION_ANCHORS["BOTTOMRIGHT"]
    local justify  = ns.HOTKEY_POSITION_JUSTIFY[position] or "RIGHT"

    fs:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
    fs:ClearAllPoints()
    fs:SetPoint(anchor.point, frame, anchor.point, offsetX, offsetY)
    fs:SetJustifyH(justify)
end

local function RefreshAllStacks()
    for _, v in ipairs({ essentialViewer, utilityViewer, viewer }) do
        if v then
            for _, child in ipairs({ v:GetChildren() }) do
                if child.cooldownID then
                    UpdateFrameStacks(child)
                end
            end
        end
    end
end
ns.RefreshAllStacks = RefreshAllStacks

local ScheduleStacksRefresh = CreateNextFrameScheduler(RefreshAllStacks)

-- ---------------------------------------------------------------------------
-- Grid math — pure position calculation, no frame dependencies
-- ---------------------------------------------------------------------------

-- Calculates the x,y position for icon at 1-based index in a grid.
-- Returns x, y (unscaled pixel offsets from the grid origin).
local function CalcGridPosition(index, maxPerRow, iconW, iconH, spacing, align, totalIcons, fullRowWidth, isVertical)
    local idx = index - 1

    if isVertical then
        -- Vertical: fill top-to-bottom, wrap to next column
        local maxPerCol = maxPerRow
        local posInCol = idx % maxPerCol
        local colNum = math.floor(idx / maxPerCol)

        local fullColHeight = maxPerCol * (iconH + spacing) - spacing
        local alignOffset = 0
        if align ~= "LEFT" then
            local colStart = colNum * maxPerCol
            local iconsInCol = math.min(maxPerCol, totalIcons - colStart)
            local colHeight = iconsInCol * (iconH + spacing) - spacing
            if align == "CENTER" then
                alignOffset = (fullColHeight - colHeight) / 2
            elseif align == "RIGHT" then
                alignOffset = fullColHeight - colHeight
            end
        end

        local x = colNum * (iconW + spacing)
        local y = alignOffset + posInCol * (iconH + spacing)
        return x, y
    end

    -- Horizontal: fill left-to-right, wrap to next row
    local col = idx % maxPerRow
    local row = math.floor(idx / maxPerRow)

    local alignOffset = 0
    if align ~= "LEFT" then
        local rowStart = row * maxPerRow
        local iconsOnRow = math.min(maxPerRow, totalIcons - rowStart)
        local rowWidth = iconsOnRow * (iconW + spacing) - spacing
        if align == "CENTER" then
            alignOffset = (fullRowWidth - rowWidth) / 2
        elseif align == "RIGHT" then
            alignOffset = fullRowWidth - rowWidth
        end
    end

    local x = alignOffset + col * (iconW + spacing)
    local y = row * (iconH + spacing)
    return x, y
end

local stableEdgeCache = {}
local viewerSizeTargets = setmetatable({}, { __mode = "k" })
local settingViewerSize = setmetatable({}, { __mode = "k" })

local function SetViewerSize(frame, width, height)
    local target = viewerSizeTargets[frame]
    if not target then
        target = {}
        viewerSizeTargets[frame] = target
    end
    target.width = width
    target.height = height

    settingViewerSize[frame] = true
    frame:SetSize(width, height)
    settingViewerSize[frame] = nil
end

local function EnforceViewerSize(frame)
    if settingViewerSize[frame] then return end

    local target = viewerSizeTargets[frame]
    if not target then return end

    local width, height = frame:GetSize()
    if math.abs(width - target.width) < 0.01
        and math.abs(height - target.height) < 0.01 then
        return
    end

    settingViewerSize[frame] = true
    frame:SetSize(target.width, target.height)
    settingViewerSize[frame] = nil
end

local function FormatPointNumber(value)
    if type(value) ~= "number" then return tostring(value) end
    return string.format("%.3f", value)
end

local function GetEdgeValue(left, bottom, right, top, preserveEdge)
    if preserveEdge == "TOP" then
        return top
    elseif preserveEdge == "BOTTOM" then
        return bottom
    elseif preserveEdge == "LEFT" then
        return left
    elseif preserveEdge == "RIGHT" then
        return right
    end

    return nil
end

local function GetViewerRect(frame)
    if not frame or not frame.GetRect then return nil end

    local left, bottom, width, height = frame:GetRect()
    if not left or not bottom or not width or not height then return nil end

    return left, bottom, left + width, bottom + height
end

local function GetPreservedEdgeDelta(targetEdge, afterLeft, afterBottom, afterRight, afterTop, preserveEdge)
    local afterEdge = GetEdgeValue(afterLeft, afterBottom, afterRight, afterTop, preserveEdge)
    if not targetEdge or not afterEdge then return 0, 0 end

    local delta = targetEdge - afterEdge
    if preserveEdge == "TOP" or preserveEdge == "BOTTOM" then
        return 0, delta
    elseif preserveEdge == "LEFT" or preserveEdge == "RIGHT" then
        return delta, 0
    end

    return 0, 0
end

local function GetPointsKey(points)
    local key = {}
    for i, point in ipairs(points) do
        key[i] = tostring(point.point) .. "|"
            .. tostring(point.relativeTo) .. "|"
            .. tostring(point.relativePoint) .. "|"
            .. FormatPointNumber(point.offsetX) .. "|"
            .. FormatPointNumber(point.offsetY)
    end

    return table.concat(key, ";")
end

local function GetRegionGeometryKey(region)
    if not region then return "nil" end

    local effectiveScale = region.GetEffectiveScale and region:GetEffectiveScale()
        or (region.GetScale and region:GetScale())
        or 1
    local left, bottom, width, height
    if region.GetRect then
        left, bottom, width, height = region:GetRect()
    end

    return tostring(region) .. "|"
        .. FormatPointNumber(effectiveScale) .. "|"
        .. FormatPointNumber(left) .. "|"
        .. FormatPointNumber(bottom) .. "|"
        .. FormatPointNumber(width) .. "|"
        .. FormatPointNumber(height)
end

local function GetStableEdgeContextKey(frame, points)
    local key = {
        GetRegionGeometryKey(UIParent),
        FormatPointNumber(frame.GetEffectiveScale and frame:GetEffectiveScale()
            or (frame.GetScale and frame:GetScale())
            or 1),
    }
    local parent = frame.GetParent and frame:GetParent()
    for _, point in ipairs(points) do
        key[#key + 1] = GetRegionGeometryKey(point.relativeTo or parent or UIParent)
    end
    return table.concat(key, ";")
end

local function GetStableEdgeCacheKey(frame)
    if frame and frame.GetName then
        local name = frame:GetName()
        if name then return name end
    end

    return frame
end

local function GetStableEdgeCache(frame)
    local cacheKey = GetStableEdgeCacheKey(frame)
    return stableEdgeCache[cacheKey]
end

local function InvalidateStableEdge(frame)
    stableEdgeCache[GetStableEdgeCacheKey(frame)] = nil
    frame._ecdmStableContextKey = nil
    frame._ecdmStableEdge = nil
    frame._ecdmStableEdgeName = nil
    frame._ecdmStablePointsKey = nil
    frame._ecdmStableSourcePointsKey = nil
end

local function CacheStableEdge(frame, points, sourcePointsKey, preserveEdge, left, bottom, right, top)
    local cache = {
        contextKey = GetStableEdgeContextKey(frame, points),
        edge = GetEdgeValue(left, bottom, right, top, preserveEdge),
        edgeName = preserveEdge,
        pointsKey = GetPointsKey(points),
        sourcePointsKey = sourcePointsKey,
    }
    frame._ecdmStableContextKey = cache.contextKey
    frame._ecdmStableEdge = cache.edge
    frame._ecdmStableEdgeName = cache.edgeName
    frame._ecdmStablePointsKey = cache.pointsKey
    frame._ecdmStableSourcePointsKey = cache.sourcePointsKey
    stableEdgeCache[GetStableEdgeCacheKey(frame)] = cache
end

local function SetViewerSizePreservingEdge(frame, width, height, preserveEdge)
    local points = {}
    local numPoints = frame.GetNumPoints and frame:GetNumPoints() or 0
    for i = 1, numPoints do
        local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(i)
        points[i] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            offsetX = offsetX or 0,
            offsetY = offsetY or 0,
        }
    end
    local pointsKey = GetPointsKey(points)

    local beforeLeft, beforeBottom, beforeRight, beforeTop = GetViewerRect(frame)
    local targetEdge = GetEdgeValue(beforeLeft, beforeBottom, beforeRight, beforeTop, preserveEdge)
    local contextKey = GetStableEdgeContextKey(frame, points)
    local stableCache = GetStableEdgeCache(frame)
    if not stableCache and frame._ecdmStableEdge then
        stableCache = {
            contextKey = frame._ecdmStableContextKey,
            edge = frame._ecdmStableEdge,
            edgeName = frame._ecdmStableEdgeName,
            pointsKey = frame._ecdmStablePointsKey,
            sourcePointsKey = frame._ecdmStableSourcePointsKey,
        }
    end
    -- Blizzard can reapply the saved Edit Mode point after we offset that
    -- point to preserve the growth edge. Both describe the same placement.
    local stablePointsMatch = stableCache
        and (stableCache.pointsKey == pointsKey
            or stableCache.sourcePointsKey == pointsKey)
    local usedStableEdge = stableCache
        and stableCache.contextKey == contextKey
        and stableCache.edgeName == preserveEdge
        and stablePointsMatch
        and stableCache.edge ~= nil
    if usedStableEdge then
        targetEdge = stableCache.edge
    end

    local sourcePointsKey = usedStableEdge
        and (stableCache.sourcePointsKey or pointsKey)
        or pointsKey

    SetViewerSize(frame, width, height)

    if not beforeLeft or #points == 0 then
        return
    end

    local afterLeft, afterBottom, afterRight, afterTop = GetViewerRect(frame)
    if not afterLeft then
        return
    end

    local deltaX, deltaY = GetPreservedEdgeDelta(targetEdge, afterLeft, afterBottom, afterRight, afterTop, preserveEdge)
    if math.abs(deltaX) < 0.01 and math.abs(deltaY) < 0.01 then
        CacheStableEdge(frame, points, sourcePointsKey,
            preserveEdge, afterLeft, afterBottom, afterRight, afterTop)
        return
    end

    local scale = frame.GetScale and frame:GetScale() or 1
    if scale < 0.01 then scale = 1 end

    local clearAllPoints = frame.ClearAllPointsBase or frame.ClearAllPoints
    local setPoint = frame.SetPointBase or frame.SetPoint
    local adjustedPoints = {}

    frame._arSettingPos = true
    clearAllPoints(frame)
    for i, p in ipairs(points) do
        local offsetX = p.offsetX + (deltaX / scale)
        local offsetY = p.offsetY + (deltaY / scale)
        adjustedPoints[i] = {
            point = p.point,
            relativeTo = p.relativeTo,
            relativePoint = p.relativePoint,
            offsetX = offsetX,
            offsetY = offsetY,
        }
        setPoint(frame, p.point, p.relativeTo, p.relativePoint, offsetX, offsetY)
    end
    frame._arSettingPos = false

    local finalLeft, finalBottom, finalRight, finalTop = GetViewerRect(frame)
    CacheStableEdge(frame, adjustedPoints, sourcePointsKey,
        preserveEdge, finalLeft, finalBottom, finalRight, finalTop)
end

-- ---------------------------------------------------------------------------
-- Layout — positions visible icons in a multi-row grid and sizes the viewer
-- ---------------------------------------------------------------------------

local visibleBuf = {}
local HookFrame  -- forward declaration; defined after ScheduleLayout

local barVisibleBuf = {}
local HookBarFrame  -- forward declaration; defined after ScheduleBarsLayout

local function SortByLayoutIndex(a, b)
    return (a.layoutIndex or 0) < (b.layoutIndex or 0)
end

local function GetGridPreserveEdge(isVertical, growForward)
    if isVertical then
        return growForward and "LEFT" or "RIGHT"
    end
    return growForward and "TOP" or "BOTTOM"
end

local function ApplyLayout()
    if not viewer then return end

    -- Collect icon children based on layout mode
    -- Static: all icons (preserves fixed grid positions even when hidden)
    -- Dynamic: only visible icons (packs tightly, no gaps)
    local isDynamic = (db.layout == "DYNAMIC")
    wipe(visibleBuf)
    local children = { viewer:GetChildren() }
    local n = 0
    local withCooldownID = 0
    for i = 1, #children do
        local child = children[i]
        HookFrame(child)  -- idempotent; catches frames created after init
        if child.cooldownID then
            withCooldownID = withCooldownID + 1
            if not isDynamic or child:IsShown() then
                n = n + 1
                visibleBuf[n] = child
            end
        end
    end

    if n == 0 then return end

    -- Sort by Blizzard's layout ordering
    table.sort(visibleBuf, SortByLayoutIndex)

    local maxPerRow = db.maxPerRow
    local growDown = (db.growDirection == "DOWN")
    local align = db.align
    local isVertical = IsViewerVertical(viewer)
    local preserveEdge = GetGridPreserveEdge(isVertical, growDown)

    local scale = visibleBuf[1]:GetScale()
    if scale < 0.01 then scale = 1 end

    -- SetPoint offsets are in the CHILD's coordinate space and get multiplied
    -- by the child's scale automatically.  Use unscaled dimensions for
    -- positioning so coordinates aren't double-scaled.
    local iconW = visibleBuf[1]:GetWidth()
    local iconH = visibleBuf[1]:GetHeight()
    if iconW < 1 then iconW = 36 end
    if iconH < 1 then iconH = 36 end

    -- Blizzard's iconPadding + additional offset gives the native inter-icon gap
    local spacing = 0
    if viewer.iconPadding ~= nil then
        local offset = viewer.GetAdditionalPaddingOffset
            and viewer:GetAdditionalPaddingOffset() or -4
        spacing = viewer.iconPadding + offset
    end

    local totalIcons = n
    -- Compute grid dimensions — swap row/col semantics for vertical
    local refCols, refRows
    if isVertical then
        local numCols = math.ceil(totalIcons / maxPerRow)
        refCols = isDynamic and math.max(numCols, math.ceil(withCooldownID / maxPerRow)) or numCols
        refRows = maxPerRow
    else
        local numRows = math.ceil(totalIcons / maxPerRow)
        refCols = maxPerRow
        refRows = isDynamic and math.max(numRows, math.ceil(withCooldownID / maxPerRow)) or numRows
    end
    local fullRowWidth = refCols * (iconW + spacing) - spacing

    -- Position each icon in the grid
    for i = 1, n do
        local frame = visibleBuf[i]
        local x, y = CalcGridPosition(i, maxPerRow, iconW, iconH, spacing, align, totalIcons, fullRowWidth, isVertical)

        -- Cache target position for the SetPoint hook to enforce
        frame._arTargetX = x
        frame._arTargetY = y
        frame._arSettingPos = true
        frame:ClearAllPoints()
        if isVertical then
            if growDown then -- "Right" in vertical
                frame:SetPoint("TOPLEFT", viewer, "TOPLEFT", x, -y)
            else -- "Left" in vertical
                frame:SetPoint("TOPRIGHT", viewer, "TOPRIGHT", -x, -y)
            end
        elseif growDown then
            frame:SetPoint("TOPLEFT", viewer, "TOPLEFT", x, -y)
        else
            frame:SetPoint("BOTTOMLEFT", viewer, "BOTTOMLEFT", x, y)
        end
        frame._arSettingPos = false
    end

    -- Viewer size is in the viewer's own coordinate space (not child-scaled),
    -- so scale up the unscaled grid dimensions.
    local totalW = (refCols * (iconW + spacing) - spacing) * scale
    local totalH = (refRows * (iconH + spacing) - spacing) * scale
    if totalW > 0 and totalH > 0 then
        SetViewerSizePreservingEdge(viewer, totalW, totalH, preserveEdge)
    end
end

-- ---------------------------------------------------------------------------
-- Debounced scheduling — batches rapid triggers into a single next-frame layout
-- ---------------------------------------------------------------------------

local ScheduleLayout, CancelScheduledLayout = CreateNextFrameScheduler(ApplyLayout)

local function ApplyLayoutFromViewerLayout()
    CancelScheduledLayout()
    ApplyLayout()
end

ns.ApplyLayout = ApplyLayout
ns.ScheduleLayout = ScheduleLayout

-- ---------------------------------------------------------------------------
-- Per-frame hook — overrides Blizzard's SetPoint and relayouts on show/hide
-- ---------------------------------------------------------------------------

-- Shared hook installer for both icon and bar viewer children.
-- Uses getter functions so hooks always read the current viewer/growDown
-- even after viewer recreation in TryInit.
local function HookViewerChild(frame, hookedSet, getViewer, getGrowDown, scheduleFn, shouldScheduleVisibility)
    if hookedSet[frame] then return end
    hookedSet[frame] = true

    -- Intercept Blizzard repositioning and enforce our cached grid position
    -- CDM children are not protected — SetPoint is safe during combat
    hooksecurefunc(frame, "SetPoint", function(self)
        if self._arSettingPos then return end
        if not self._arTargetX then return end
        local v = getViewer()
        if self:GetParent() ~= v then return end

        self._arSettingPos = true
        self:ClearAllPoints()
        if IsViewerVertical(v) then
            if getGrowDown() then -- "Right" in vertical
                self:SetPoint("TOPLEFT", v, "TOPLEFT", self._arTargetX, -self._arTargetY)
            else -- "Left" in vertical
                self:SetPoint("TOPRIGHT", v, "TOPRIGHT", -self._arTargetX, -self._arTargetY)
            end
        elseif getGrowDown() then
            self:SetPoint("TOPLEFT", v, "TOPLEFT", self._arTargetX, -self._arTargetY)
        else
            self:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT", self._arTargetX, self._arTargetY)
        end
        self._arSettingPos = false
    end)

    -- Show/hide changes visible count in dynamic mode — relayout needed
    -- Use HookScript (fires on any visibility change) not hooksecurefunc
    -- (only fires on explicit Lua Show/Hide calls)
    frame:HookScript("OnShow", function(self)
        if self:GetParent() ~= getViewer() then return end
        if shouldScheduleVisibility and not shouldScheduleVisibility() then return end
        scheduleFn()
    end)
    frame:HookScript("OnHide", function(self)
        if self:GetParent() ~= getViewer() then return end
        if shouldScheduleVisibility and not shouldScheduleVisibility() then return end
        scheduleFn()
    end)
end

HookFrame = function(frame)
    HookViewerChild(frame, hookedFrames,
        function() return viewer end,
        function() return db.growDirection == "DOWN" end,
        ScheduleLayout,
        function() return db.layout == "DYNAMIC" end)
end

-- ---------------------------------------------------------------------------
-- Bars layout — positions bar children in a vertical column or horizontal grid
-- ---------------------------------------------------------------------------

local function GetBarsPreserveEdge(isHorizontal, growDown)
    if not isHorizontal and not growDown then
        return "BOTTOM"
    end
    return "TOP"
end

local function ApplyBarsLayout()
    if not barViewer then return end

    local isDynamic = (db.bars_layout == "DYNAMIC")
    local isHorizontal = (db.bars_orientation == "HORIZONTAL")

    wipe(barVisibleBuf)
    local children = { barViewer:GetChildren() }
    local n = 0
    local withCooldownID = 0
    for i = 1, #children do
        local child = children[i]
        HookBarFrame(child)
        if child.cooldownID then
            withCooldownID = withCooldownID + 1
            if not isDynamic or child:IsShown() then
                n = n + 1
                barVisibleBuf[n] = child
            end
        end
    end

    if n == 0 then return end

    table.sort(barVisibleBuf, SortByLayoutIndex)

    local scale = barVisibleBuf[1]:GetScale()
    if scale < 0.01 then scale = 1 end

    local barW = barVisibleBuf[1]:GetWidth()
    local barH = barVisibleBuf[1]:GetHeight()
    if barW < 1 then barW = 220 end
    if barH < 1 then barH = 30 end

    local spacing = 0
    if barViewer.iconPadding ~= nil then
        local offset = barViewer.GetAdditionalPaddingOffset
            and barViewer:GetAdditionalPaddingOffset() or -4
        spacing = barViewer.iconPadding + offset
    end

    local align = db.bars_align

    if isHorizontal then
        -- Multi-row grid (wraps at bars_maxPerRow)
        local maxPerRow = db.bars_maxPerRow
        local totalBars = n
        local numRows = math.ceil(totalBars / maxPerRow)
        local refCols = maxPerRow
        local refRows = isDynamic and math.max(numRows, math.ceil(withCooldownID / maxPerRow)) or numRows
        local fullRowWidth = refCols * (barW + spacing) - spacing

        for i = 1, n do
            local frame = barVisibleBuf[i]
            local gridAlign = isDynamic and align or "LEFT"
            local x, y = CalcGridPosition(i, maxPerRow, barW, barH, spacing, gridAlign, totalBars, fullRowWidth)

            frame._arTargetX = x
            frame._arTargetY = y
            frame._arSettingPos = true
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", barViewer, "TOPLEFT", x, -y)
            frame._arSettingPos = false
        end

        local totalW = (refCols * (barW + spacing) - spacing) * scale
        local totalH = (refRows * (barH + spacing) - spacing) * scale
        if totalW > 0 and totalH > 0 then
            SetViewerSizePreservingEdge(barViewer, totalW, totalH,
                GetBarsPreserveEdge(true, true))
        end
    else
        -- Single column (vertical)
        local refRows = isDynamic and math.max(n, withCooldownID) or n
        local growDown = (align ~= "UP") -- DOWN is default / static behavior

        for i = 1, n do
            local frame = barVisibleBuf[i]
            local row = i - 1
            local y = row * (barH + spacing)

            frame._arTargetX = 0
            frame._arTargetY = y
            frame._arSettingPos = true
            frame:ClearAllPoints()
            if growDown or not isDynamic then
                frame:SetPoint("TOPLEFT", barViewer, "TOPLEFT", 0, -y)
            else
                frame:SetPoint("BOTTOMLEFT", barViewer, "BOTTOMLEFT", 0, y)
            end
            frame._arSettingPos = false
        end

        local totalW = barW * scale
        local totalH = (refRows * (barH + spacing) - spacing) * scale
        if totalW > 0 and totalH > 0 then
            SetViewerSizePreservingEdge(barViewer, totalW, totalH,
                GetBarsPreserveEdge(false, growDown))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Bars debounced scheduling
-- ---------------------------------------------------------------------------

local ScheduleBarsLayout = CreateNextFrameScheduler(ApplyBarsLayout)

ns.ApplyBarsLayout = ApplyBarsLayout
ns.ScheduleBarsLayout = ScheduleBarsLayout

-- ---------------------------------------------------------------------------
-- Per-bar-frame hook — uses shared HookViewerChild with bar-specific config
-- ---------------------------------------------------------------------------

HookBarFrame = function(frame)
    HookViewerChild(frame, barHookedFrames,
        function() return barViewer end,
        function()
            return (db.bars_orientation == "HORIZONTAL")
                or (db.bars_align ~= "UP")
                or (db.bars_layout ~= "DYNAMIC")
        end,
        ScheduleBarsLayout,
        function() return db.bars_layout == "DYNAMIC" end)
end

-- ---------------------------------------------------------------------------
-- Essential / Utility alignment layout — grid with Left/Center/Right
-- ---------------------------------------------------------------------------

local essAlignBuf = {}
local utilAlignBuf = {}

local HookEssentialFrame  -- forward declaration
local HookUtilityFrame    -- forward declaration

local function ApplyAlignLayout(v, alignKey, buf, hookChildFn)
    if not v then return end

    wipe(buf)
    local children = { v:GetChildren() }
    local n = 0
    local totalChildren = 0
    for i = 1, #children do
        local child = children[i]
        hookChildFn(child)
        if child.cooldownID then
            totalChildren = totalChildren + 1
            if child:IsShown() then
                n = n + 1
                buf[n] = child
            end
        end
    end
    if n == 0 then return end

    table.sort(buf, SortByLayoutIndex)

    -- Read column count from Blizzard's stride (iconLimit = #Columns setting)
    local maxPerRow = (v.GetStride and v:GetStride())
        or v.iconLimit
        or totalChildren
    if maxPerRow < 1 then maxPerRow = totalChildren end

    local isVertical = IsViewerVertical(v)

    local scale = buf[1]:GetScale()
    if scale < 0.01 then scale = 1 end

    local iconW = buf[1]:GetWidth()
    local iconH = buf[1]:GetHeight()
    if iconW < 1 then iconW = 36 end
    if iconH < 1 then iconH = 36 end

    local spacing = 0
    if v.iconPadding ~= nil then
        local offset = v.GetAdditionalPaddingOffset
            and v:GetAdditionalPaddingOffset() or -4
        spacing = v.iconPadding + offset
    end

    local align = db[alignKey]
    local refCols, refRows
    if isVertical then
        local numCols = math.ceil(n / maxPerRow)
        refCols = numCols
        refRows = maxPerRow
    else
        local numRows = math.ceil(n / maxPerRow)
        refCols = maxPerRow
        refRows = numRows
    end
    local fullRowWidth = refCols * (iconW + spacing) - spacing

    -- Position each icon using the shared grid calculator
    for i = 1, n do
        local frame = buf[i]
        local x, y = CalcGridPosition(i, maxPerRow, iconW, iconH, spacing, align, n, fullRowWidth, isVertical)

        frame._arTargetX = x
        frame._arTargetY = y
        frame._arSettingPos = true
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", v, "TOPLEFT", x, -y)
        frame._arSettingPos = false
    end

    -- Size viewer to fit the full grid
    local totalW = (refCols * (iconW + spacing) - spacing) * scale
    local totalH = (refRows * (iconH + spacing) - spacing) * scale
    if totalW > 0 and totalH > 0 then
        SetViewerSizePreservingEdge(v, totalW, totalH,
            GetGridPreserveEdge(isVertical, true))
    end
end

local function ApplyEssentialLayout()
    ApplyAlignLayout(essentialViewer, "essential_align", essAlignBuf, function(f)
        if HookEssentialFrame then HookEssentialFrame(f) end
    end)
end

local function ApplyUtilityLayout()
    ApplyAlignLayout(utilityViewer, "utility_align", utilAlignBuf, function(f)
        if HookUtilityFrame then HookUtilityFrame(f) end
    end)
end

local ScheduleEssentialLayout = CreateNextFrameScheduler(ApplyEssentialLayout)
local ScheduleUtilityLayout = CreateNextFrameScheduler(ApplyUtilityLayout)

ns.ApplyEssentialLayout = ApplyEssentialLayout
ns.ApplyUtilityLayout = ApplyUtilityLayout
ns.ScheduleEssentialLayout = ScheduleEssentialLayout
ns.ScheduleUtilityLayout = ScheduleUtilityLayout

HookEssentialFrame = function(frame)
    HookViewerChild(frame, essentialHookedFrames,
        function() return essentialViewer end,
        function() return true end,
        ScheduleEssentialLayout)
end

HookUtilityFrame = function(frame)
    HookViewerChild(frame, utilityHookedFrames,
        function() return utilityViewer end,
        function() return true end,
        ScheduleUtilityLayout)
end

-- ---------------------------------------------------------------------------
-- Bar gradient engine — per-bar start/end color gradients
-- ---------------------------------------------------------------------------

local function GetBarStatusBar(barFrame)
    for _, child in ipairs({ barFrame:GetChildren() }) do
        if child:GetObjectType() == "StatusBar" then return child end
    end
end

local function ApplyBarGradient(barFrame)
    local statusBar = GetBarStatusBar(barFrame)
    if not statusBar then return end
    local tex = statusBar:GetStatusBarTexture()
    if not tex or not tex.SetGradient then return end

    local colors = db.bars_colors and db.bars_colors[barFrame.cooldownID]
    if colors then
        tex:SetGradient("HORIZONTAL",
            CreateColor(colors.sR, colors.sG, colors.sB, 1),
            CreateColor(colors.eR, colors.eG, colors.eB, 1))
    end
end

local function ResetBarGradient(barFrame)
    local statusBar = GetBarStatusBar(barFrame)
    if not statusBar then return end
    local tex = statusBar:GetStatusBarTexture()
    if not tex or not tex.SetGradient then return end
    tex:SetGradient("HORIZONTAL",
        CreateColor(1, 0.5, 0.25, 1),
        CreateColor(1, 0.5, 0.25, 1))
end

local function RefreshBarGradient(barFrame)
    local colors = db.bars_colors and db.bars_colors[barFrame.cooldownID]
    if colors then
        ApplyBarGradient(barFrame)
    else
        ResetBarGradient(barFrame)
    end
end

local function RefreshAllBarGradients()
    if not barViewer then return end
    for _, child in ipairs({ barViewer:GetChildren() }) do
        if child.cooldownID then RefreshBarGradient(child) end
    end
end
ns.RefreshAllBarGradients = RefreshAllBarGradients
ns.RefreshBarGradient = RefreshBarGradient
ns._ApplyBarGradient = ApplyBarGradient
ns._ResetBarGradient = ResetBarGradient

-- ---------------------------------------------------------------------------
-- Mixin hooks — catch new frames, cooldown changes, and CDM settings updates
-- ---------------------------------------------------------------------------

local function InstallMixinHooks()
    if mixinHooksInstalled then return end
    mixinHooksInstalled = true

    -- Hook new frame acquisition (fires when Blizzard creates/recycles frames)
    if CooldownViewerMixin and CooldownViewerMixin.OnAcquireItemFrame then
        hooksecurefunc(CooldownViewerMixin, "OnAcquireItemFrame", function(self, frame)
            if self == viewer then
                HookFrame(frame)
                ScheduleLayout()
                UpdateFrameStacks(frame)
            elseif self == barViewer then
                HookBarFrame(frame)
                RefreshBarGradient(frame)
                ScheduleBarsLayout()
            elseif self == essentialViewer then
                HookEssentialFrame(frame)
                ScheduleEssentialLayout()
                ScheduleHotkeyRefresh()
                UpdateFrameStacks(frame)
            elseif self == utilityViewer then
                HookUtilityFrame(frame)
                ScheduleUtilityLayout()
                ScheduleHotkeyRefresh()
                UpdateFrameStacks(frame)
            end
        end)
    end

    -- Hook cooldown assignment/removal (triggers relayout when buffs change)
    if CooldownViewerItemDataMixin then
        local function DispatchSchedule(frame)
            local parent = frame and frame:GetParent()
            if parent == viewer then
                ScheduleLayout()
                UpdateFrameStacks(frame)
            elseif parent == barViewer then
                RefreshBarGradient(frame)
                ScheduleBarsLayout()
            elseif parent == essentialViewer then
                ScheduleEssentialLayout()
                UpdateFrameHotkey(frame)
                UpdateFrameStacks(frame)
            elseif parent == utilityViewer then
                ScheduleUtilityLayout()
                UpdateFrameHotkey(frame)
                UpdateFrameStacks(frame)
            end
        end

        local function DispatchClear(frame)
            local parent = frame and frame:GetParent()
            if parent == viewer then
                ScheduleLayout()
            elseif parent == barViewer then
                RefreshBarGradient(frame)
                ScheduleBarsLayout()
            elseif parent == essentialViewer then
                ScheduleEssentialLayout()
                if frame._ecdmHotkeyText then
                    frame._ecdmHotkeyText:Hide()
                end
            elseif parent == utilityViewer then
                ScheduleUtilityLayout()
                if frame._ecdmHotkeyText then
                    frame._ecdmHotkeyText:Hide()
                end
            end
        end

        if CooldownViewerItemDataMixin.SetCooldownID then
            hooksecurefunc(CooldownViewerItemDataMixin, "SetCooldownID", function(self)
                DispatchSchedule(self)
                if ns.ScheduleSettingsBarScan then ns.ScheduleSettingsBarScan() end
            end)
        end
        -- 12.1 ClearCooldownID delegates to ResetCooldownData; hook only the
        -- reset method there so a single clear does not dispatch twice.
        if CooldownViewerItemDataMixin.ClearCooldownID
            and not CooldownViewerItemDataMixin.ResetCooldownData then
            hooksecurefunc(CooldownViewerItemDataMixin, "ClearCooldownID", function(self)
                DispatchClear(self)
                if ns.ScheduleSettingsBarScan then ns.ScheduleSettingsBarScan() end
            end)
        end
        if CooldownViewerItemDataMixin.ResetCooldownData then
            hooksecurefunc(CooldownViewerItemDataMixin, "ResetCooldownData", function(self)
                DispatchClear(self)
                if ns.ScheduleSettingsBarScan then ns.ScheduleSettingsBarScan() end
            end)
        end
        if CooldownViewerItemDataMixin.UpdateFromSpellCategory then
            hooksecurefunc(CooldownViewerItemDataMixin, "UpdateFromSpellCategory", function(self)
                local parent = self and self:GetParent()
                if parent == essentialViewer or parent == utilityViewer then
                    UpdateFrameHotkey(self)
                end
            end)
        end
    end

end

-- ---------------------------------------------------------------------------
-- Hook installation — shared installer + per-viewer wrappers
-- ---------------------------------------------------------------------------

local function InstallViewerHooks(state, getViewer, hookChildFn, scheduleFn, applyFn, errorLabel, onRefreshLayout, onLayout)
    if state.installed then return end
    state.installed = true

    local ok = pcall(function()
        InstallMixinHooks()

        local v = getViewer()
        hooksecurefunc(v, "SetSize", EnforceViewerSize)
        hooksecurefunc(v, "Layout", function()
            if onLayout then
                onLayout()
            else
                scheduleFn()
            end
        end)

        -- Hook RefreshLayout to catch CDM settings changes without tainting
        -- the EventRegistry callback table (which would taint all listeners
        -- including Blizzard's own RefreshLayout via secureexecuterange).
        if onRefreshLayout and v.RefreshLayout then
            hooksecurefunc(v, "RefreshLayout", onRefreshLayout)
        end

        -- A snapped anchor can move without changing this viewer's own point.
        if v.OnAnyEditModeSystemAnchorChanged then
            hooksecurefunc(v, "OnAnyEditModeSystemAnchorChanged", scheduleFn)
        end

        local function OnExplicitPositionChange()
            InvalidateStableEdge(v)
            scheduleFn()
        end
        if v.OnSystemPositionChange then
            hooksecurefunc(v, "OnSystemPositionChange", OnExplicitPositionChange)
        end
        if v.ResetToDefaultPosition then
            hooksecurefunc(v, "ResetToDefaultPosition", OnExplicitPositionChange)
        end
        if v.UpdateSystem then
            hooksecurefunc(v, "UpdateSystem", OnExplicitPositionChange)
        end

        local children = { v:GetChildren() }
        for _, child in ipairs(children) do
            hookChildFn(child)
        end

        applyFn()
    end)

    if not ok then
        state.installed = false
        print("|cffff6600Enhanced CDM:|r " .. errorLabel)
    end
end

local function InstallHooks()
    InstallViewerHooks(hookState, function() return viewer end,
        HookFrame, ScheduleLayout, ApplyLayout,
        "Hook installation failed — layout disabled.",
        function()
            ScheduleStacksRefresh()
            if ns.RefreshEditModePanel then ns.RefreshEditModePanel() end
        end,
        ApplyLayoutFromViewerLayout)
end

local function InstallBarsHooks()
    InstallViewerHooks(barHookState, function() return barViewer end,
        HookBarFrame, ScheduleBarsLayout, function()
            ApplyBarsLayout()
            RefreshAllBarGradients()
        end,
        "Bar hook installation failed — bars layout disabled.",
        function()
            RefreshAllBarGradients()
            if ns.ScheduleSettingsBarScan then ns.ScheduleSettingsBarScan() end
        end)
end

local function InstallEssentialHooks()
    InstallViewerHooks(essentialHookState, function() return essentialViewer end,
        HookEssentialFrame, ScheduleEssentialLayout, ApplyEssentialLayout,
        "Essential hook installation failed — alignment disabled.",
        function()
            ScheduleHotkeyRefresh(); ScheduleStacksRefresh()
            if ns.RefreshEssentialPanel then ns.RefreshEssentialPanel() end
        end)
end

local function InstallUtilityHooks()
    InstallViewerHooks(utilityHookState, function() return utilityViewer end,
        HookUtilityFrame, ScheduleUtilityLayout, ApplyUtilityLayout,
        "Utility hook installation failed — alignment disabled.",
        function()
            ScheduleHotkeyRefresh(); ScheduleStacksRefresh()
            if ns.RefreshUtilityPanel then ns.RefreshUtilityPanel() end
        end)
end

-- ---------------------------------------------------------------------------
-- Deferred init — polls for both viewers (may not exist immediately)
-- ---------------------------------------------------------------------------

local function TryInit()
    -- Handle viewer recreation across loading screens
    local newViewer = _G["BuffIconCooldownViewer"]
    local newBarViewer = _G["BuffBarCooldownViewer"]
    local newEssential = _G["EssentialCooldownViewer"]
    local newUtility = _G["UtilityCooldownViewer"]
    local needEditMode = false

    local needStacksRefresh = false

    if newViewer and newViewer ~= viewer then
        viewer = newViewer
        ns.viewer = viewer
        hookState.installed = false
        wipe(hookedFrames)
        InstallHooks()
        needEditMode = true
        needStacksRefresh = true
    end

    if newBarViewer and newBarViewer ~= barViewer then
        barViewer = newBarViewer
        barHookState.installed = false
        wipe(barHookedFrames)
        InstallBarsHooks()
        needEditMode = true
    end

    local needHotkeyRefresh = false

    if newEssential and newEssential ~= essentialViewer then
        essentialViewer = newEssential
        ns.essentialViewer = essentialViewer
        essentialHookState.installed = false
        wipe(essentialHookedFrames)
        InstallEssentialHooks()
        needEditMode = true
        needHotkeyRefresh = true
        needStacksRefresh = true
    end

    if newUtility and newUtility ~= utilityViewer then
        utilityViewer = newUtility
        ns.utilityViewer = utilityViewer
        utilityHookState.installed = false
        wipe(utilityHookedFrames)
        InstallUtilityHooks()
        needEditMode = true
        needHotkeyRefresh = true
        needStacksRefresh = true
    end

    if needHotkeyRefresh then
        RefreshAllHotkeys()
        InstallFeedbackHooks()
    end
    if needStacksRefresh then
        RefreshAllStacks()
    end

    if needEditMode then
        if ns.SetupEditMode then ns.SetupEditMode() end
    end

    -- All already found — nothing to do
    if viewer and barViewer and essentialViewer and utilityViewer then return end

    -- Cancel any existing polling ticker before starting a new one
    if initTicker then initTicker:Cancel() end

    -- Poll every 0.5s for up to 10s until all viewers appear
    local attempts = 0
    initTicker = C_Timer.NewTicker(0.5, function()
        attempts = attempts + 1
        local foundNew = false

        local needStacksRefresh = false

        local foundViewer = _G["BuffIconCooldownViewer"]
        if foundViewer and foundViewer ~= viewer then
            viewer = foundViewer
            ns.viewer = viewer
            hookState.installed = false
            wipe(hookedFrames)
            InstallHooks()
            foundNew = true
            needStacksRefresh = true
        end

        local foundBarViewer = _G["BuffBarCooldownViewer"]
        if foundBarViewer and foundBarViewer ~= barViewer then
            barViewer = foundBarViewer
            barHookState.installed = false
            wipe(barHookedFrames)
            InstallBarsHooks()
            foundNew = true
        end

        local needHotkeyRefresh = false

        local foundEssential = _G["EssentialCooldownViewer"]
        if foundEssential and foundEssential ~= essentialViewer then
            essentialViewer = foundEssential
            ns.essentialViewer = essentialViewer
            essentialHookState.installed = false
            wipe(essentialHookedFrames)
            InstallEssentialHooks()
            foundNew = true
            needHotkeyRefresh = true
            needStacksRefresh = true
        end

        local foundUtility = _G["UtilityCooldownViewer"]
        if foundUtility and foundUtility ~= utilityViewer then
            utilityViewer = foundUtility
            ns.utilityViewer = utilityViewer
            utilityHookState.installed = false
            wipe(utilityHookedFrames)
            InstallUtilityHooks()
            foundNew = true
            needHotkeyRefresh = true
            needStacksRefresh = true
        end

        if needHotkeyRefresh then
            RefreshAllHotkeys()
            InstallFeedbackHooks()
        end
        if needStacksRefresh then
            RefreshAllStacks()
        end

        if foundNew then
            if ns.SetupEditMode then ns.SetupEditMode() end
        end

        if (viewer and barViewer and essentialViewer and utilityViewer) or attempts >= 20 then
            initTicker:Cancel()
            initTicker = nil
            if not viewer and not barViewer then
                print("|cffff6600Enhanced CDM:|r No CDM viewers found. Is the Cooldown Manager enabled?")
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Slash commands — /enhancedcdm or /ecdm
-- ---------------------------------------------------------------------------

local function RegisterSlashCommands()
    local function ParseGradientColors(text)
        local values = { text:match("^%s*([+-]?%d*%.?%d+)%s+([+-]?%d*%.?%d+)%s+([+-]?%d*%.?%d+)%s+([+-]?%d*%.?%d+)%s+([+-]?%d*%.?%d+)%s+([+-]?%d*%.?%d+)%s*$") }
        if #values ~= 6 then return nil end
        for i = 1, 6 do
            values[i] = tonumber(values[i])
            if not values[i] or values[i] < 0 or values[i] > 1 then
                return nil
            end
        end
        return values[1], values[2], values[3], values[4], values[5], values[6]
    end

    SLASH_ENHANCEDCDM1 = "/enhancedcdm"
    SLASH_ENHANCEDCDM2 = "/ecdm"

    SlashCmdList["ENHANCEDCDM"] = function(msg)
        local cmd, arg = msg:match("^(%S+)%s*(.*)")
        cmd = cmd and cmd:lower() or msg:lower()

        if cmd == "rows" or cmd == "perrow" then
            local n = tonumber(arg)
            if n and n >= 1 and n <= 40 then
                db.maxPerRow = math.floor(n)
                print("|cff00ccffEnhanced CDM:|r Icons per row set to " .. db.maxPerRow)
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm rows <1-40>")
            end
        elseif cmd == "grow" or cmd == "direction" then
            local dir = arg:upper()
            if dir == "UP" or dir == "DOWN" then
                db.growDirection = dir
                print("|cff00ccffEnhanced CDM:|r Growth set to " .. ns.DIRECTION_DISPLAY[dir])
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm grow <up|down>")
            end
        elseif cmd == "align" then
            local a = arg:upper()
            if a == "LEFT" or a == "CENTER" or a == "RIGHT" then
                db.align = a
                print("|cff00ccffEnhanced CDM:|r Alignment set to " .. ns.ALIGN_DISPLAY[a])
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm align <left|center|right>")
            end
        elseif cmd == "layout" then
            local l = arg:upper()
            if l == "STATIC" or l == "DYNAMIC" then
                db.layout = l
                print("|cff00ccffEnhanced CDM:|r Layout set to " .. ns.LAYOUT_DISPLAY[l])
                ApplyLayout()
            else
                print("|cff00ccffEnhanced CDM:|r Usage: /ecdm layout <static|dynamic>")
            end
        elseif cmd == "essential" or cmd == "utility" then
            local prefix = cmd == "essential" and "essential_hotkeys_" or "utility_hotkeys_"
            local alignKey = cmd == "essential" and "essential_align" or "utility_align"
            local label = cmd == "essential" and "Essential" or "Utility"
            local applyAlignFn = cmd == "essential" and ApplyEssentialLayout or ApplyUtilityLayout
            local subCmd, subArg = arg:match("^(%S+)%s*(.*)")
            subCmd = subCmd and subCmd:lower() or ""

            if subCmd == "align" then
                local a = subArg:upper()
                if a == "LEFT" or a == "CENTER" or a == "RIGHT" then
                    db[alignKey] = a
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " alignment set to " .. ns.ALIGN_DISPLAY[a])
                    applyAlignFn()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " align <left|center|right>")
                end
            elseif subCmd == "show" then
                db[prefix .. "show"] = true
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkeys enabled")
                RefreshAllHotkeys()
            elseif subCmd == "hide" then
                db[prefix .. "show"] = false
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkeys disabled")
                RefreshAllHotkeys()
            elseif subCmd == "position" or subCmd == "pos" then
                local pos = subArg:upper()
                if ns.HOTKEY_POSITION_DISPLAY[pos] then
                    db[prefix .. "position"] = pos
                    local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
                    if anchor then
                        db[prefix .. "offsetX"] = anchor.x
                        db[prefix .. "offsetY"] = anchor.y
                    end
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey position set to " .. ns.HOTKEY_POSITION_DISPLAY[pos])
                    RefreshAllHotkeys()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " position <topleft|top|topright|right|bottomright|bottom|bottomleft|left|center>")
                end
            elseif subCmd == "fontsize" or subCmd == "size" then
                local n = tonumber(subArg)
                if n and n >= 6 and n <= 32 then
                    db[prefix .. "fontSize"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey font size set to " .. db[prefix .. "fontSize"])
                    RefreshAllHotkeys()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " fontsize <6-32>")
                end
            elseif subCmd == "shorten" then
                db[prefix .. "shorten"] = true
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey text shortening enabled")
                RefreshAllHotkeys()
            elseif subCmd == "noshorten" then
                db[prefix .. "shorten"] = false
                print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey text shortening disabled")
                RefreshAllHotkeys()
            elseif subCmd == "offsetx" then
                local n = tonumber(subArg)
                if n and n >= -40 and n <= 40 then
                    db[prefix .. "offsetX"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey horizontal offset set to " .. db[prefix .. "offsetX"])
                    RefreshAllHotkeys()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " offsetx <-40 to 40>")
                end
            elseif subCmd == "offsety" then
                local n = tonumber(subArg)
                if n and n >= -40 and n <= 40 then
                    db[prefix .. "offsetY"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " hotkey vertical offset set to " .. db[prefix .. "offsetY"])
                    RefreshAllHotkeys()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " offsety <-40 to 40>")
                end
            elseif subCmd == "feedback" then
                local fSubCmd = subArg:lower()
                local feedbackKey = cmd == "essential" and "essential_feedback_show" or "utility_feedback_show"
                if fSubCmd == "on" then
                    db[feedbackKey] = true
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " click feedback enabled")
                elseif fSubCmd == "off" then
                    db[feedbackKey] = false
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " click feedback disabled")
                else
                    local statusText = db[feedbackKey] and "Enabled" or "Disabled"
                    print("|cff00ccffEnhanced CDM:|r " .. label .. " click feedback: " .. statusText)
                    print("|cffcccccc/ecdm " .. cmd .. " feedback on|r - Enable click feedback")
                    print("|cffcccccc/ecdm " .. cmd .. " feedback off|r - Disable click feedback")
                end
            elseif subCmd == "stacks" then
                local sPrefix = cmd == "essential" and "essential_stacks_" or "utility_stacks_"
                local sCmd, sArg = subArg:match("^(%S+)%s*(.*)")
                sCmd = sCmd and sCmd:lower() or ""
                if sCmd == "position" or sCmd == "pos" then
                    local pos = sArg:upper()
                    if ns.HOTKEY_POSITION_DISPLAY[pos] then
                        db[sPrefix .. "position"] = pos
                        local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
                        if anchor then
                            db[sPrefix .. "offsetX"] = anchor.x
                            db[sPrefix .. "offsetY"] = anchor.y
                        end
                        print("|cff00ccffEnhanced CDM:|r " .. label .. " stacks position set to " .. ns.HOTKEY_POSITION_DISPLAY[pos])
                        RefreshAllStacks()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " stacks position <topleft|top|topright|right|bottomright|bottom|bottomleft|left|center>")
                    end
                elseif sCmd == "fontsize" or sCmd == "size" then
                    local n = tonumber(sArg)
                    if n and n >= 6 and n <= 32 then
                        db[sPrefix .. "fontSize"] = math.floor(n)
                        print("|cff00ccffEnhanced CDM:|r " .. label .. " stacks font size set to " .. db[sPrefix .. "fontSize"])
                        RefreshAllStacks()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " stacks fontsize <6-32>")
                    end
                elseif sCmd == "offsetx" then
                    local n = tonumber(sArg)
                    if n and n >= -40 and n <= 40 then
                        db[sPrefix .. "offsetX"] = math.floor(n)
                        print("|cff00ccffEnhanced CDM:|r " .. label .. " stacks horizontal offset set to " .. db[sPrefix .. "offsetX"])
                        RefreshAllStacks()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " stacks offsetx <-40 to 40>")
                    end
                elseif sCmd == "offsety" then
                    local n = tonumber(sArg)
                    if n and n >= -40 and n <= 40 then
                        db[sPrefix .. "offsetY"] = math.floor(n)
                        print("|cff00ccffEnhanced CDM:|r " .. label .. " stacks vertical offset set to " .. db[sPrefix .. "offsetY"])
                        RefreshAllStacks()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm " .. cmd .. " stacks offsety <-40 to 40>")
                    end
                else
                    local posText = ns.HOTKEY_POSITION_DISPLAY[db[sPrefix .. "position"]] or db[sPrefix .. "position"]
                    print("|cff00ccffEnhanced CDM — " .. label .. " Stacks:|r")
                    print("  " .. posText .. ", size " .. db[sPrefix .. "fontSize"] .. ", offset " .. db[sPrefix .. "offsetX"] .. "," .. db[sPrefix .. "offsetY"])
                    print("|cffcccccc/ecdm " .. cmd .. " stacks position|r <pos> - Set position")
                    print("|cffcccccc/ecdm " .. cmd .. " stacks fontsize|r <6-32> - Set font size")
                    print("|cffcccccc/ecdm " .. cmd .. " stacks offsetx|r <-40..40> - Horizontal offset")
                    print("|cffcccccc/ecdm " .. cmd .. " stacks offsety|r <-40..40> - Vertical offset")
                end
            else
                local alignDisplay = ns.ALIGN_DISPLAY[db[alignKey]] or db[alignKey]
                local showText = db[prefix .. "show"] and "Shown" or "Hidden"
                local posText = ns.HOTKEY_POSITION_DISPLAY[db[prefix .. "position"]] or db[prefix .. "position"]
                local shortenText = db[prefix .. "shorten"] and "Shortened" or "Full"
                local feedbackKey = cmd == "essential" and "essential_feedback_show" or "utility_feedback_show"
                local feedbackText = db[feedbackKey] and "On" or "Off"
                print("|cff00ccffEnhanced CDM — " .. label .. ":|r")
                print("  " .. alignDisplay .. ", hotkeys " .. showText .. ", " .. posText)
                print("  size " .. db[prefix .. "fontSize"] .. ", " .. shortenText .. ", offset " .. db[prefix .. "offsetX"] .. "," .. db[prefix .. "offsetY"])
                print("  feedback " .. feedbackText)
                print("|cffcccccc/ecdm " .. cmd .. " align|r <l|c|r> - Icon alignment")
                print("|cffcccccc/ecdm " .. cmd .. " show|r - Show keybinds")
                print("|cffcccccc/ecdm " .. cmd .. " hide|r - Hide keybinds")
                print("|cffcccccc/ecdm " .. cmd .. " position|r <pos> - Set position")
                print("|cffcccccc/ecdm " .. cmd .. " fontsize|r <6-32> - Set font size")
                print("|cffcccccc/ecdm " .. cmd .. " shorten|r - Shorten keybind text")
                print("|cffcccccc/ecdm " .. cmd .. " noshorten|r - Full keybind text")
                print("|cffcccccc/ecdm " .. cmd .. " offsetx|r <-40..40> - Horizontal offset")
                print("|cffcccccc/ecdm " .. cmd .. " offsety|r <-40..40> - Vertical offset")
                print("|cffcccccc/ecdm " .. cmd .. " feedback|r <on|off> - Click feedback")
                print("|cffcccccc/ecdm " .. cmd .. " stacks|r - Stack text settings")
            end
        elseif cmd == "bars" then
            local subCmd, subArg = arg:match("^(%S+)%s*(.*)")
            subCmd = subCmd and subCmd:lower() or ""

            if subCmd == "orientation" then
                local o = subArg:upper()
                if o == "VERTICAL" or o == "HORIZONTAL" then
                    db.bars_orientation = o
                    if o == "VERTICAL" then
                        db.bars_align = "DOWN"
                        db.bars_maxPerRow = ns.DEFAULTS.bars_maxPerRow
                    elseif o == "HORIZONTAL" then
                        db.bars_align = "CENTER"
                    end
                    print("|cff00ccffEnhanced CDM:|r Bars orientation set to " .. ns.ORIENTATION_DISPLAY[o])
                    ApplyBarsLayout()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars orientation <vertical|horizontal>")
                end
            elseif subCmd == "layout" then
                local l = subArg:upper()
                if l == "STATIC" or l == "DYNAMIC" then
                    db.bars_layout = l
                    print("|cff00ccffEnhanced CDM:|r Bars layout set to " .. ns.LAYOUT_DISPLAY[l])
                    ApplyBarsLayout()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars layout <static|dynamic>")
                end
            elseif subCmd == "align" then
                local a = subArg:upper()
                if db.bars_orientation == "VERTICAL" then
                    if a == "DOWN" or a == "UP" then
                        db.bars_align = a
                        print("|cff00ccffEnhanced CDM:|r Bars alignment set to " .. ns.BAR_ALIGN_V_DISPLAY[a])
                        ApplyBarsLayout()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars align <up|down>")
                    end
                else
                    if a == "LEFT" or a == "CENTER" or a == "RIGHT" then
                        db.bars_align = a
                        print("|cff00ccffEnhanced CDM:|r Bars alignment set to " .. ns.BAR_ALIGN_H_DISPLAY[a])
                        ApplyBarsLayout()
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars align <left|center|right>")
                    end
                end
            elseif subCmd == "perrow" then
                local n = tonumber(subArg)
                if n and n >= 1 and n <= 8 then
                    db.bars_maxPerRow = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r Bars per row set to " .. db.bars_maxPerRow)
                    ApplyBarsLayout()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars perrow <1-8>")
                end
            elseif subCmd == "gradient" then
                local gradArg = subArg:match("^(%S+)")
                if not gradArg or gradArg == "" then
                    print("|cff00ccffEnhanced CDM — Bar Gradients:|r")
                    if not db.bars_colors or not next(db.bars_colors) then
                        print("  No gradients set.")
                    else
                        for id, c in pairs(db.bars_colors) do
                            print(string.format("  %d: start(%.2f,%.2f,%.2f) end(%.2f,%.2f,%.2f)",
                                id, c.sR, c.sG, c.sB, c.eR, c.eG, c.eB))
                        end
                    end
                    print("|cffcccccc/ecdm bars gradient|r <id> <sR> <sG> <sB> <eR> <eG> <eB>")
                    print("|cffcccccc/ecdm bars gradient|r <id> off")
                    print("|cffcccccc/ecdm bars gradient clear|r")
                elseif gradArg == "clear" then
                    wipe(db.bars_colors)
                    if barViewer then
                        for _, child in ipairs({ barViewer:GetChildren() }) do
                            if child.cooldownID then ResetBarGradient(child) end
                        end
                    end
                    print("|cff00ccffEnhanced CDM:|r All bar gradients cleared")
                else
                    local id = tonumber(gradArg)
                    if not id then
                        print("|cff00ccffEnhanced CDM:|r Invalid cooldownID")
                        return
                    end
                    local rest = subArg:match("^%S+%s+(.*)")
                    if rest and rest:lower() == "off" then
                        db.bars_colors[id] = nil
                        if barViewer then
                            for _, child in ipairs({ barViewer:GetChildren() }) do
                                if child.cooldownID == id then ResetBarGradient(child) end
                            end
                        end
                        print("|cff00ccffEnhanced CDM:|r Gradient removed for " .. id)
                    elseif rest then
                        local sR, sG, sB, eR, eG, eB = ParseGradientColors(rest)
                        if sR and sG and sB and eR and eG and eB then
                            db.bars_colors[id] = { sR=sR, sG=sG, sB=sB, eR=eR, eG=eG, eB=eB }
                            RefreshAllBarGradients()
                            print(string.format("|cff00ccffEnhanced CDM:|r Gradient set for %d", id))
                        else
                            print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars gradient <id> <sR> <sG> <sB> <eR> <eG> <eB>")
                        end
                    else
                        print("|cff00ccffEnhanced CDM:|r Usage: /ecdm bars gradient <id> <sR> <sG> <sB> <eR> <eG> <eB>")
                    end
                end
            else
                local orientDisplay = ns.ORIENTATION_DISPLAY[db.bars_orientation]
                local layoutDisplay = ns.LAYOUT_DISPLAY[db.bars_layout]
                local alignMap = db.bars_orientation == "VERTICAL" and ns.BAR_ALIGN_V_DISPLAY or ns.BAR_ALIGN_H_DISPLAY
                local alignDisplay = alignMap[db.bars_align] or db.bars_align
                print("|cff00ccffEnhanced CDM — Bars:|r")
                print("  " .. orientDisplay .. ", " .. layoutDisplay .. ", " .. alignDisplay .. ", " .. db.bars_maxPerRow .. "/row")
                print("|cffcccccc/ecdm bars orientation|r <vertical|horizontal>")
                print("|cffcccccc/ecdm bars layout|r <static|dynamic>")
                print("|cffcccccc/ecdm bars align|r <up|down|left|center|right>")
                print("|cffcccccc/ecdm bars perrow|r <1-8>")
                print("|cffcccccc/ecdm bars gradient|r - Bar color gradients")
            end
        elseif cmd == "buffs" then
            local subCmd, subArg = arg:match("^(%S+)%s*(.*)")
            subCmd = subCmd and subCmd:lower() or ""
            local sPrefix = "buffs_stacks_"
            if subCmd == "stacks" then
                local sCmd, sArg = subArg:match("^(%S+)%s*(.*)")
                sCmd = sCmd and sCmd:lower() or ""
                subCmd = sCmd
                subArg = sArg or ""
            end
            if subCmd == "position" or subCmd == "pos" then
                local pos = subArg:upper()
                if ns.HOTKEY_POSITION_DISPLAY[pos] then
                    db[sPrefix .. "position"] = pos
                    local anchor = ns.HOTKEY_POSITION_ANCHORS[pos]
                    if anchor then
                        db[sPrefix .. "offsetX"] = anchor.x
                        db[sPrefix .. "offsetY"] = anchor.y
                    end
                    print("|cff00ccffEnhanced CDM:|r Buffs stacks position set to " .. ns.HOTKEY_POSITION_DISPLAY[pos])
                    RefreshAllStacks()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm buffs position <topleft|top|topright|right|bottomright|bottom|bottomleft|left|center>")
                end
            elseif subCmd == "fontsize" or subCmd == "size" then
                local n = tonumber(subArg)
                if n and n >= 6 and n <= 32 then
                    db[sPrefix .. "fontSize"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r Buffs stacks font size set to " .. db[sPrefix .. "fontSize"])
                    RefreshAllStacks()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm buffs fontsize <6-32>")
                end
            elseif subCmd == "offsetx" then
                local n = tonumber(subArg)
                if n and n >= -40 and n <= 40 then
                    db[sPrefix .. "offsetX"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r Buffs stacks horizontal offset set to " .. db[sPrefix .. "offsetX"])
                    RefreshAllStacks()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm buffs offsetx <-40 to 40>")
                end
            elseif subCmd == "offsety" then
                local n = tonumber(subArg)
                if n and n >= -40 and n <= 40 then
                    db[sPrefix .. "offsetY"] = math.floor(n)
                    print("|cff00ccffEnhanced CDM:|r Buffs stacks vertical offset set to " .. db[sPrefix .. "offsetY"])
                    RefreshAllStacks()
                else
                    print("|cff00ccffEnhanced CDM:|r Usage: /ecdm buffs offsety <-40 to 40>")
                end
            else
                local posText = ns.HOTKEY_POSITION_DISPLAY[db[sPrefix .. "position"]] or db[sPrefix .. "position"]
                print("|cff00ccffEnhanced CDM — Buffs Stacks:|r")
                print("  " .. posText .. ", size " .. db[sPrefix .. "fontSize"] .. ", offset " .. db[sPrefix .. "offsetX"] .. "," .. db[sPrefix .. "offsetY"])
                print("|cffcccccc/ecdm buffs position|r <pos> - Set position")
                print("|cffcccccc/ecdm buffs fontsize|r <6-32> - Set font size")
                print("|cffcccccc/ecdm buffs offsetx|r <-40..40> - Horizontal offset")
                print("|cffcccccc/ecdm buffs offsety|r <-40..40> - Vertical offset")
            end
        else
            print("|cff00ccffEnhanced CDM|r v" .. (VERSION or "?"))
            print(" ")
            local dirDisplay = ns.DIRECTION_DISPLAY[db.growDirection]
            local alignDisplay = ns.ALIGN_DISPLAY[db.align]
            local layoutDisplay = ns.LAYOUT_DISPLAY[db.layout]
            print("|cffccccccIcons:|r " .. db.maxPerRow .. "/row, " .. dirDisplay .. ", " .. alignDisplay .. ", " .. layoutDisplay)
            local bOrient = ns.ORIENTATION_DISPLAY[db.bars_orientation]
            local bLayout = ns.LAYOUT_DISPLAY[db.bars_layout]
            local bAlignMap = db.bars_orientation == "VERTICAL" and ns.BAR_ALIGN_V_DISPLAY or ns.BAR_ALIGN_H_DISPLAY
            local bAlign = bAlignMap[db.bars_align] or db.bars_align
            print("|cffccccccBars:|r " .. bOrient .. ", " .. bLayout .. ", " .. bAlign .. ", " .. db.bars_maxPerRow .. "/row")
            local eAlign = ns.ALIGN_DISPLAY[db.essential_align] or db.essential_align
            local eShow = db.essential_hotkeys_show and "Shown" or "Hidden"
            local ePos = ns.HOTKEY_POSITION_DISPLAY[db.essential_hotkeys_position] or db.essential_hotkeys_position
            local eShorten = db.essential_hotkeys_shorten and "Shortened" or "Full"
            print("|cffccccccEssential:|r " .. eAlign .. ", hotkeys " .. eShow)
            print("  " .. ePos .. ", size " .. db.essential_hotkeys_fontSize .. ", " .. eShorten)
            local uAlign = ns.ALIGN_DISPLAY[db.utility_align] or db.utility_align
            local uShow = db.utility_hotkeys_show and "Shown" or "Hidden"
            local uPos = ns.HOTKEY_POSITION_DISPLAY[db.utility_hotkeys_position] or db.utility_hotkeys_position
            local uShorten = db.utility_hotkeys_shorten and "Shortened" or "Full"
            print("|cffccccccUtility:|r " .. uAlign .. ", hotkeys " .. uShow)
            print("  " .. uPos .. ", size " .. db.utility_hotkeys_fontSize .. ", " .. uShorten)
            print(" ")
            print("|cffcccccc/ecdm rows|r <1-40> - Icons per row")
            print("|cffcccccc/ecdm grow|r <up|down> - Growth direction")
            print("|cffcccccc/ecdm align|r <left|center|right> - Row alignment")
            print("|cffcccccc/ecdm layout|r <static|dynamic> - Layout mode")
            print("|cffcccccc/ecdm bars|r - Bars settings and commands")
            print("|cffcccccc/ecdm essential|r - Essential hotkey settings")
            print("|cffcccccc/ecdm utility|r - Utility hotkey settings")
            print("|cffcccccc/ecdm buffs|r - Buffs stacks text settings")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Events — ADDON_LOADED (init DB), PLAYER_ENTERING_WORLD (find viewer)
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not EnhancedCDMDB then
            EnhancedCDMDB = {}
        end
        for k, v in pairs(ns.DEFAULTS) do
            if EnhancedCDMDB[k] == nil then
                if type(v) == "table" then
                    EnhancedCDMDB[k] = {}
                else
                    EnhancedCDMDB[k] = v
                end
            end
        end
        db = EnhancedCDMDB
        ns.db = db
        VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        RegisterSlashCommands()
    elseif event == "PLAYER_ENTERING_WORLD" then
        TryInit()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        ScheduleLayout()
        ScheduleBarsLayout()
        ScheduleEssentialLayout()
        ScheduleUtilityLayout()
    elseif event == "UPDATE_BINDINGS"
        or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        ScheduleHotkeyRefresh()
    end
end)

-- Test-only exports — used by tests/runner.lua, not by other addon files
ns._FormatKeyText = FormatKeyText
ns._CalcGridPosition = CalcGridPosition
ns._SetViewerSizePreservingEdge = SetViewerSizePreservingEdge
ns._EnforceViewerSize = EnforceViewerSize
ns._InvalidateStableEdge = InvalidateStableEdge
ns._GetGridPreserveEdge = GetGridPreserveEdge
ns._GetBarsPreserveEdge = GetBarsPreserveEdge
ns._GetHotkeyText = GetHotkeyText
ns._GetItemHotkeyText = GetItemHotkeyText
ns._BuildSlotToBindingMap = BuildSlotToBindingMap
ns._GetSlotActionIDs = GetSlotActionIDs
ns._GetFrameActionIDs = GetFrameActionIDs
ns._FindCDMIcon = FindCDMIcon
ns._GetPushedOverlay = GetPushedOverlay
