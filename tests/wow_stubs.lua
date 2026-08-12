-- WoW API stubs — minimal mocks so addon files can load outside WoW
-- Only stubs that the addon actually calls are defined here.

-- WoW global: wipe(table) — clears all keys
function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-- WoW global: hooksecurefunc — we just store the hook, no original to call
_G._hookedMethods = {}
function hooksecurefunc(tblOrName, nameOrFunc, funcOrNil)
    -- Two forms:
    --   hooksecurefunc(obj, "Method", hook)
    --   hooksecurefunc("GlobalFunc", hook)
    if type(tblOrName) == "table" and type(nameOrFunc) == "string" and type(funcOrNil) == "function" then
        tblOrName._secureHooks = tblOrName._secureHooks or {}
        tblOrName._secureHooks[nameOrFunc] = tblOrName._secureHooks[nameOrFunc] or {}
        table.insert(tblOrName._secureHooks[nameOrFunc], funcOrNil)
        table.insert(_G._hookedMethods, { target = tblOrName, method = nameOrFunc, func = funcOrNil })
    elseif type(tblOrName) == "string" and type(nameOrFunc) == "function" then
        _G._secureGlobalHooks = _G._secureGlobalHooks or {}
        _G._secureGlobalHooks[tblOrName] = _G._secureGlobalHooks[tblOrName] or {}
        table.insert(_G._secureGlobalHooks[tblOrName], nameOrFunc)
    end
    -- The original function is not invoked in tests; specs call recorded hooks directly.
end

-- Minimal frame mock
local FrameMixin = {}
FrameMixin.__index = FrameMixin

function FrameMixin:GetParent() return self._parent end
function FrameMixin:GetName() return self._name end
function FrameMixin:GetChildren() return (unpack or table.unpack)(self._children or {}) end
function FrameMixin:GetObjectType() return self._type or "Frame" end
function FrameMixin:GetStatusBarTexture() return self._statusBarTexture end
function FrameMixin:GetFrameLevel() return self._frameLevel or 0 end
function FrameMixin:SetSize(w, h) self._width = w; self._height = h end
function FrameMixin:GetWidth() return self._width or 0 end
function FrameMixin:GetHeight() return self._height or 0 end
function FrameMixin:GetSize() return self._width or 0, self._height or 0 end
function FrameMixin:GetScale() return self._scale or 1 end
function FrameMixin:GetEffectiveScale() return self._effectiveScale or self:GetScale() end
function FrameMixin:SetPoint(...) end
function FrameMixin:ClearAllPoints() end
function FrameMixin:SetAllPoints() end
function FrameMixin:Show() self._shown = true end
function FrameMixin:Hide() self._shown = false end
function FrameMixin:IsShown() return self._shown ~= false end
function FrameMixin:IsVisible() return self:IsShown() end
function FrameMixin:EnableMouse() end
function FrameMixin:SetFrameStrata() end
function FrameMixin:SetFrameLevel(level) self._frameLevel = level end
function FrameMixin:SetParent(parent)
    self._parent = parent
    if parent and parent._children then
        table.insert(parent._children, self)
    end
end
function FrameMixin:SetWidth(w) self._width = w end
function FrameMixin:SetHeight(h) self._height = h end
function FrameMixin:RegisterEvent(event)
    self._events = self._events or {}
    self._events[event] = true
end
function FrameMixin:SetScript(event, handler)
    self._scripts = self._scripts or {}
    self._scripts[event] = handler
end
function FrameMixin:GetScript(event)
    return self._scripts and self._scripts[event]
end
function FrameMixin:HookScript(event, handler)
    self._hookScripts = self._hookScripts or {}
    self._hookScripts[event] = self._hookScripts[event] or {}
    table.insert(self._hookScripts[event], handler)
end
function FrameMixin:Layout() self._layoutCalled = true end
function FrameMixin:OnAnyEditModeSystemAnchorChanged() end
function FrameMixin:SetText(text) self._text = text end
function FrameMixin:GetText() return self._text end
function FrameMixin:SetNormalFontObject() end
function FrameMixin:SetHighlightFontObject() end
function FrameMixin:GetNormalTexture()
    self._normalTexture = self._normalTexture or { SetVertexColor = function() end }
    return self._normalTexture
end
function FrameMixin:GetPushedTexture()
    self._pushedTexture = self._pushedTexture or { SetVertexColor = function() end }
    return self._pushedTexture
end
function FrameMixin:SetDefaultText(text)
    self._defaultText = text
    self.Text = self.Text or { SetText = function(obj, val) obj._text = val end }
    self.Text:SetText(text)
end
function FrameMixin:SetupMenu(generator) self._menuGenerator = generator end
function FrameMixin:Init(value, minValue, maxValue, steps, fmt)
    self._init = { value = value, minValue = minValue, maxValue = maxValue, steps = steps, fmt = fmt }
    if self.Slider and self.Slider.SetValue then self.Slider:SetValue(value) end
end
function FrameMixin:RegisterCallback(event, callback, owner)
    self._callbacks = self._callbacks or {}
    self._callbacks[event] = { callback = callback, owner = owner }
end
function FrameMixin:SetChecked(value) self._checked = value end
function FrameMixin:GetChecked() return self._checked and 1 or nil end
function FrameMixin:EnableMouseWheel() end
function FrameMixin:SetScrollChild(child) self._scrollChild = child end
function FrameMixin:GetVerticalScroll() return self._verticalScroll or 0 end
function FrameMixin:SetVerticalScroll(value) self._verticalScroll = value end
function FrameMixin:SetBackdrop() end
function FrameMixin:SetBackdropColor() end
function FrameMixin:SetBackdropBorderColor() end
function FrameMixin:CreateFontString()
    return setmetatable({
        SetPoint = function() end,
        SetText = function(self, text) self._text = text end,
        SetTextColor = function() end,
        SetFont = function() end,
        SetJustifyH = function() end,
        SetWidth = function() end,
        SetHeight = function() end,
        ClearAllPoints = function() end,
        Show = function(self) self._shown = true end,
        Hide = function(self) self._shown = false end,
        GetStringHeight = function() return 14 end,
    }, {})
end
function FrameMixin:CreateTexture(name, layer)
    return {
        SetTexture = function() end,
        SetAtlas = function() end,
        SetSize = function(self, w, h) self._width = w; self._height = h end,
        SetPoint = function(self, ...) self._point = { ... } end,
        SetAllPoints = function() end,
        SetColorTexture = function() end,
        SetWidth = function() end,
        SetHeight = function() end,
        ClearAllPoints = function() end,
        Show = function() end,
        Hide = function() end,
        GetTexture = function() return nil end,
    }
end
function FrameMixin:GetAttribute(key) return self._attributes and self._attributes[key] end
function FrameMixin:SetAttribute(key, val)
    self._attributes = self._attributes or {}
    self._attributes[key] = val
end

-- Registry of all frames created during the session
_G._allFrames = {}

function CreateFrame(frameType, name, parent, template)
    local f = setmetatable({
        _type = frameType,
        _name = name,
        _parent = parent,
        _children = {},
        _shown = true,
        _width = 0,
        _height = 0,
        _scale = 1,
        Slider = {
            _value = nil,
            SetMinMaxValues = function() end,
            SetValueStep = function() end,
            SetObeyStepOnDrag = function() end,
            SetValue = function(self, value) self._value = value end,
            SetScript = function() end,
        },
    }, FrameMixin)
    if name then _G[name] = f end
    if parent and parent._children then
        table.insert(parent._children, f)
    end
    table.insert(_G._allFrames, f)
    return f
end

-- C_Timer stub
C_Timer = C_Timer or {}
local pendingTimers = {}
function C_Timer.NewTimer(delay, func)
    local timer = {
        delay = delay,
        func = func,
        cancelled = false,
    }
    function timer:Cancel()
        self.cancelled = true
    end
    pendingTimers[#pendingTimers + 1] = timer
    return timer
end
function C_Timer.NewTicker(interval, func)
    return { Cancel = function() end }
end

function _G._RunPendingTimers()
    local passes = 0
    while #pendingTimers > 0 do
        passes = passes + 1
        if passes > 100 then
            error("timer queue did not settle")
        end

        local timers = pendingTimers
        pendingTimers = {}
        for _, timer in ipairs(timers) do
            if not timer.cancelled then
                timer.func()
            end
        end
    end
end

function _G._GetPendingTimerCount()
    local count = 0
    for _, timer in ipairs(pendingTimers) do
        if not timer.cancelled then count = count + 1 end
    end
    return count
end

-- C_AddOns stub
C_AddOns = C_AddOns or {}
function C_AddOns.GetAddOnMetadata(addon, key)
    if key == "Version" then return "0.0.0-test" end
    return nil
end

-- C_ActionBar stub (configurable via _stubSpellActionButtons)
C_ActionBar = C_ActionBar or {}
_G._stubSpellActionButtons = {}
function C_ActionBar.FindSpellActionButtons(spellID)
    return _G._stubSpellActionButtons[spellID] or {}
end

-- C_Spell stub (configurable via _stubOverrideSpells)
C_Spell = C_Spell or {}
_G._stubOverrideSpells = {}
function C_Spell.GetOverrideSpell(spellID)
    return _G._stubOverrideSpells[spellID] or spellID
end

-- Binding stub (configurable via _stubBindingKeys)
_G._stubBindingKeys = {}
function GetBindingKey(binding)
    return _G._stubBindingKeys[binding]
end

-- GetActionInfo stub (configurable via _stubActionInfo)
_G._stubActionInfo = {}
function GetActionInfo(slot)
    local info = _G._stubActionInfo[slot]
    if info then return info.type, info.id end
    return nil, nil
end

-- GetMacroSpell stub (configurable via _stubMacroSpells)
_G._stubMacroSpells = {}
function GetMacroSpell(macroID)
    return _G._stubMacroSpells[macroID]
end

-- GetMacroItem stub (configurable via _stubMacroItems)
_G._stubMacroItems = {}
function GetMacroItem(macroID)
    return _G._stubMacroItems[macroID]
end

function GetItemInfoInstant(item)
    if type(item) == "number" then return item end
    return tonumber(tostring(item):match("item:(%d+)"))
end

-- Equipped-item stubs (configurable via _stubInventoryItems)
_G._stubInventoryItems = {}
function GetInventoryItemID(unit, equipSlot)
    return _G._stubInventoryItems[equipSlot]
end

C_Item = C_Item or {}
function C_Item.GetItemID(itemLocation)
    return itemLocation and itemLocation.itemID
end

-- Event registry stub
EventRegistry = EventRegistry or {}
function EventRegistry:RegisterCallback(...) end

-- Enum stubs
Enum = Enum or {}
Enum.EditModeCooldownViewerSetting = Enum.EditModeCooldownViewerSetting or {}
Enum.EditModeCooldownViewerSetting.IconDirection = 1

MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin or { Label = { Right = "Right" } }
function CreateMinimalSliderFormatter(label)
    return function(value) return tostring(value) end
end

-- Slash command globals
SlashCmdList = SlashCmdList or {}

-- Mixin stubs
CooldownViewerMixin = {
    OnAcquireItemFrame = function() end,
}
CooldownViewerItemDataMixin = {
    SetCooldownID = function() end,
    ClearCooldownID = function() end,
    ResetCooldownData = function() end,
    UpdateFromSpellCategory = function() end,
}
EditModeManagerFrame = nil

-- UIParent stub
UIParent = UIParent or CreateFrame("Frame", "UIParent")

-- CreateColor stub
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
end

-- EnhancedCDMDB starts nil (like first login)
EnhancedCDMDB = nil

-- Print capture helpers for slash command tests
_G._originalPrint = print
_G._printCapture = nil

function _G._startCapture()
    _G._printCapture = {}
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        table.insert(_G._printCapture, table.concat(parts, "\t"))
    end
end

function _G._stopCapture()
    _G.print = _G._originalPrint
    local lines = _G._printCapture
    _G._printCapture = nil
    return lines
end
