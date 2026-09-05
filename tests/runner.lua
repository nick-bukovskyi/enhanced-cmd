-- Minimal test runner for Enhanced CDM
-- Usage: lua tests/runner.lua

local passed = 0
local failed = 0
local errors = {}
local currentSuite = ""
local activeEnvironment

function describe(name, fn)
  currentSuite = name
  print("  " .. name)
  fn()
  currentSuite = ""
end

function it(name, fn)
  local ok, err = pcall(fn)
  local timerOk, timerErr = true, nil
  if activeEnvironment then
    timerOk, timerErr = pcall(function()
      activeEnvironment._RunPendingTimers()
      assert(#activeEnvironment._reportedErrors == 0, activeEnvironment._reportedErrors[1])
    end)
  end
  if ok and not timerOk then
    ok, err = false, timerErr
  end
  if ok then
    passed = passed + 1
    print("    [PASS] " .. name)
  else
    failed = failed + 1
    table.insert(errors, {
      suite = currentSuite,
      test = name,
      err = err,
    })
    print("    [FAIL] " .. name)
    print("           " .. tostring(err))
  end
end

function expect(actual)
  return {
    to_equal = function(expected)
      if actual ~= expected then
        error(string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
      end
    end,
    to_be_nil = function()
      if actual ~= nil then
        error(string.format("expected nil, got %s", tostring(actual)), 2)
      end
    end,
    to_be_truthy = function()
      if not actual then
        error(string.format("expected truthy, got %s", tostring(actual)), 2)
      end
    end,
    to_be_falsy = function()
      if actual then
        error(string.format("expected falsy, got %s", tostring(actual)), 2)
      end
    end,
    to_be_type = function(expected)
      if type(actual) ~= expected then
        error(string.format("expected type %s, got %s", expected, type(actual)), 2)
      end
    end,
  }
end

-- Read executable load order from the shipped TOC
local addonFiles = {}
for line in io.lines("EnhancedCDM.toc") do
  local path = line:match("^%s*(.-)%s*$")
  if path ~= "" and path:sub(1, 1) ~= "#" then
    addonFiles[#addonFiles + 1] = path:gsub("\\", "/")
  end
end
assert(#addonFiles > 0, "TOC contains no addon files")

local function loadInEnvironment(path, environment)
  local chunk, err
  if setfenv then
    chunk, err = loadfile(path)
    if chunk then
      setfenv(chunk, environment)
    end
  else
    chunk, err = loadfile(path, "t", environment)
  end
  assert(chunk, err)
  return chunk
end

local function createAddonEnvironment(saved)
  local environment = {
    assert = assert,
    error = error,
    ipairs = ipairs,
    pairs = pairs,
    next = next,
    pcall = pcall,
    xpcall = xpcall,
    select = select,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    setmetatable = setmetatable,
    math = math,
    string = string,
    table = table,
    unpack = unpack or table.unpack,
    print = print,
    describe = describe,
    it = it,
    expect = expect,
  }
  environment._G = environment
  loadInEnvironment("tests/wow_stubs.lua", environment)()
  environment.EnhancedCDMDB = saved
  local ns = {}
  for _, path in ipairs(addonFiles) do
    loadInEnvironment(path, environment)("EnhancedCDM", ns)
  end
  environment._FireEvent("ADDON_LOADED", "EnhancedCDM")
  environment._test_ns = ns
  environment._WithAddon = function(initialSaved, callback)
    local isolated = createAddonEnvironment(initialSaved)
    callback(isolated._test_ns, isolated)
    isolated._RunPendingTimers()
    assert(#isolated._reportedErrors == 0, isolated._reportedErrors[1])
  end
  return environment
end

-- Discover and run spec files
local function runSpecs()
  print("")
  print("Enhanced CDM Test Suite")
  print(string.rep("-", 50))
  print("")

  -- Collect spec files (Unix-style first, Windows CMD fallback)
  local specFiles = {}
  local p = io.popen("ls tests/*_spec.lua 2>/dev/null")
  if p then
    for line in p:lines() do
      table.insert(specFiles, line)
    end
    p:close()
  end
  if #specFiles == 0 then
    p = io.popen("dir /B tests\\*_spec.lua 2>nul")
    if p then
      for line in p:lines() do
        table.insert(specFiles, "tests/" .. line)
      end
      p:close()
    end
  end

  if #specFiles == 0 then
    error("No spec files found in tests/")
  end

  table.sort(specFiles)
  if arg and arg[1] == "--reverse" then
    local reversed = {}
    for index = #specFiles, 1, -1 do
      reversed[#reversed + 1] = specFiles[index]
    end
    specFiles = reversed
  end

  for _, specFile in ipairs(specFiles) do
    print("[" .. specFile .. "]")
    activeEnvironment = createAddonEnvironment()
    loadInEnvironment(specFile, activeEnvironment)()
    print("")
  end

  -- Summary
  print(string.rep("-", 50))
  local total = passed + failed
  assert(total > 0, "No tests were executed")
  if failed == 0 then
    print(string.format("All %d tests passed.", total))
  else
    print(string.format("%d passed, %d FAILED out of %d tests.", passed, failed, total))
    print("")
    for _, e in ipairs(errors) do
      print(string.format("  FAIL: %s > %s", e.suite, e.test))
      print(string.format("        %s", e.err))
    end
  end

  os.exit(failed > 0 and 1 or 0)
end

runSpecs()
