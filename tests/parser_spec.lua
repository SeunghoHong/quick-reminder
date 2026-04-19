package.path = package.path .. ";./?.lua"
local parser = require("parser")

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ok    " .. name)
    else
        failed = failed + 1
        print("  FAIL  " .. name .. " — " .. tostring(err))
    end
end

local function assertEq(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) ..
              ", got " .. tostring(actual), 2)
    end
end

-- ========== @ 분할 ==========

test("no @ marker → name only", function()
    local r = parser.parse("우유 사기")
    assertEq(r.name, "우유 사기", "name")
    assertEq(r.date, nil, "date")
    assertEq(r.allday, false, "allday")
end)

test("@ at end splits name and empty dateExpr → fallback", function()
    local r = parser.parse("우유 사기 @")
    assertEq(r.name, "우유 사기 @", "name")
    assertEq(r.date, nil, "date")
end)

test("empty input", function()
    local r = parser.parse("")
    assertEq(r.name, "", "name")
    assertEq(r.date, nil, "date")
end)

print()
print(string.format("passed: %d, failed: %d", passed, failed))
if failed > 0 then os.exit(1) end
