-- Enhanced CDM: viewer discovery, hook ownership, and recovery
local _, ns = ...
local Lifecycle = {}
ns.ViewerLifecycle = Lifecycle

local definitions
local afterRefresh
local enforceSize, invalidateEdge
local ticker
local refreshing = false
local methods = setmetatable({}, { __mode = "k" })
local initialized = setmetatable({}, { __mode = "k" })

-- Record each successful installation, including work completed before an error
function Lifecycle.HookMethod(target, method, callback)
  if not target or type(target[method]) ~= "function" then
    return false
  end
  local installed = methods[target]
  if not installed then
    installed = {}
    methods[target] = installed
  end
  if not installed[method] then
    hooksecurefunc(target, method, callback)
    installed[method] = true
  end
  return true
end

function Lifecycle.Configure(viewers, onRefresh, onSize, onPosition)
  definitions = viewers
  afterRefresh = onRefresh
  enforceSize, invalidateEdge = onSize, onPosition
end

local function FindViewer(frame)
  for _, definition in ipairs(definitions) do
    if frame and frame == ns[definition.key] then
      return definition
    end
  end
end

local function RefreshChild(frame, cleared)
  local definition = frame and FindViewer(frame:GetParent())
  if definition then
    definition.refreshChild(frame, cleared)
    definition.schedule()
  end
end

local function InstallMixinHooks()
  local acquired = Lifecycle.HookMethod(CooldownViewerMixin, "OnAcquireItemFrame", function(owner, frame)
    local definition = FindViewer(owner)
    if definition then
      definition.hookChild(frame)
      RefreshChild(frame)
    end
  end)
  local function AfterAssignment(frame)
    RefreshChild(frame)
    if ns.ScheduleSettingsBarScan then
      ns.ScheduleSettingsBarScan()
    end
  end
  local function AfterClear(frame)
    RefreshChild(frame, true)
    if ns.ScheduleSettingsBarScan then
      ns.ScheduleSettingsBarScan()
    end
  end
  local assigned = Lifecycle.HookMethod(CooldownViewerItemDataMixin, "SetCooldownID", AfterAssignment)
  -- ResetCooldownData owns recycling in 12.1; older viewers clear directly
  local cleared
  if CooldownViewerItemDataMixin and CooldownViewerItemDataMixin.ResetCooldownData then
    cleared = Lifecycle.HookMethod(CooldownViewerItemDataMixin, "ResetCooldownData", AfterClear)
  else
    cleared = Lifecycle.HookMethod(CooldownViewerItemDataMixin, "ClearCooldownID", AfterClear)
  end
  Lifecycle.HookMethod(CooldownViewerItemDataMixin, "UpdateFromSpellCategory", function(frame)
    local definition = frame and FindViewer(frame:GetParent())
    if definition and definition.refreshIdentity then
      definition.refreshIdentity(frame)
    end
  end)
  return acquired and assigned and cleared
end

local function InstallViewer(definition, frame)
  local function WhileCurrent(callback)
    return function(...)
      if ns[definition.key] == frame then
        callback(...)
      end
    end
  end
  local sized = Lifecycle.HookMethod(frame, "SetSize", WhileCurrent(enforceSize))
  local laidOut = Lifecycle.HookMethod(frame, "Layout", WhileCurrent(definition.onLayout or definition.schedule))
  Lifecycle.HookMethod(frame, "RefreshLayout", WhileCurrent(definition.onRefreshLayout))
  Lifecycle.HookMethod(frame, "OnAnyEditModeSystemAnchorChanged", WhileCurrent(definition.schedule))
  local function PositionChanged()
    invalidateEdge(frame)
    definition.schedule()
  end
  for _, method in ipairs({ "OnSystemPositionChange", "ResetToDefaultPosition", "UpdateSystem" }) do
    Lifecycle.HookMethod(frame, method, WhileCurrent(PositionChanged))
  end
  if not sized or not laidOut then
    return false
  end
  if not initialized[frame] then
    for _, child in ipairs({ frame:GetChildren() }) do
      definition.hookChild(child)
    end
    definition.apply()
    initialized[frame] = true
  end
  return true
end

local function DiscoverViewers()
  if refreshing then
    return false
  end
  refreshing = true
  -- Report the original error through WoW's handler and keep other viewers usable
  local mixinOK, mixinsReady = xpcall(InstallMixinHooks, geterrorhandler())
  local complete = mixinOK and mixinsReady
  for _, definition in ipairs(definitions) do
    local ok, ready = xpcall(function()
      local frame = _G[definition.global]
      local previous = ns[definition.key]
      if previous ~= frame then
        if previous then
          definition.retire(previous)
        end
        ns[definition.key] = frame
        if frame then
          initialized[frame] = nil
        end
      end
      if frame then
        return InstallViewer(definition, frame)
      end
      return false
    end, geterrorhandler())
    complete = complete and ok and ready
  end
  local refreshOK = xpcall(afterRefresh, geterrorhandler())
  refreshing = false
  return complete and refreshOK
end

local function StopTicker()
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
end

function Lifecycle.Refresh()
  if not ns.db then
    return
  end
  if DiscoverViewers() then
    StopTicker()
    return
  end
  if ticker then
    return
  end
  local attempts = 0
  ticker = C_Timer.NewTicker(0.5, function()
    attempts = attempts + 1
    if DiscoverViewers() or attempts >= 20 then
      StopTicker()
    end
  end)
end
