-- Minimal test runner for Enhanced CDM
-- Usage: lua tests/runner.lua

local passed = 0
local failed = 0
local errors = {}
local currentSuite = ""

function describe(name, fn)
    currentSuite = name
    print("  " .. name)
    fn()
    currentSuite = ""
end

function it(name, fn)
    local ok, err = pcall(fn)
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
                error(string.format("expected %s, got %s",
                    tostring(expected), tostring(actual)), 2)
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
                error(string.format("expected type %s, got %s",
                    expected, type(actual)), 2)
            end
        end,
    }
end

-- Load WoW stubs
dofile("tests/wow_stubs.lua")

-- Load addon files in TOC order, simulating WoW's ... varargs
local ns = {}
local addonName = "EnhancedCDM"

local function loadAddonFile(path)
    local chunk, err = loadfile(path)
    if not chunk then
        print("ERROR loading " .. path .. ": " .. tostring(err))
        os.exit(1)
    end
    chunk(addonName, ns)
end

-- Discover and run spec files
local function runSpecs()
    print("")
    print("Enhanced CDM Test Suite")
    print(string.rep("-", 50))
    print("")

    -- Load addon
    loadAddonFile("src/Config.lua")
    loadAddonFile("src/Core.lua")
    loadAddonFile("src/EditMode.lua")

    -- Simulate ADDON_LOADED event (fires OnEvent handler from Core.lua)
    -- Scan all created frames for one with an OnEvent script
    for _, frame in ipairs(_G._allFrames or {}) do
        if frame._scripts and frame._scripts["OnEvent"] then
            frame._scripts["OnEvent"](frame, "ADDON_LOADED", addonName)
            break
        end
    end

    -- Collect spec files (Unix-style first, Windows CMD fallback)
    local specFiles = {}
    local p = io.popen('ls tests/*_spec.lua 2>/dev/null')
    if p then
        for line in p:lines() do
            table.insert(specFiles, line)
        end
        p:close()
    end
    if #specFiles == 0 then
        p = io.popen('dir /B tests\\*_spec.lua 2>nul')
        if p then
            for line in p:lines() do
                table.insert(specFiles, "tests/" .. line)
            end
            p:close()
        end
    end

    if #specFiles == 0 then
        print("  No spec files found in tests/")
        return
    end

    for _, specFile in ipairs(specFiles) do
        print("[" .. specFile .. "]")
        -- Each spec file receives ns via a global
        _G._test_ns = ns
        dofile(specFile)
        print("")
    end

    -- Summary
    print(string.rep("-", 50))
    local total = passed + failed
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
