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

-- ========== 상대 날짜 ==========

-- 고정 now: 2026-04-20 (월요일) 10:00:00 KST
local FIXED_NOW = os.time({year=2026, month=4, day=20, hour=10, min=0, sec=0})

local function dateFields(ts)
    return os.date("*t", ts)
end

test("@오늘 → today, allday", function()
    local r = parser.parse("약 @오늘", FIXED_NOW)
    assertEq(r.name, "약", "name")
    local d = dateFields(r.date)
    assertEq(d.year, 2026); assertEq(d.month, 4); assertEq(d.day, 20)
    assertEq(r.allday, true, "allday")
end)

test("@today → today, allday (english)", function()
    local r = parser.parse("pill @today", FIXED_NOW)
    assertEq(r.name, "pill", "name")
    assertEq(r.allday, true, "allday")
end)

test("@내일 → tomorrow, allday", function()
    local r = parser.parse("약 @내일", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day")
    assertEq(r.allday, true, "allday")
end)

test("@tomorrow → tomorrow, allday", function()
    local r = parser.parse("pill @tomorrow", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day")
end)

test("@모레 → day after tomorrow, allday", function()
    local r = parser.parse("약 @모레", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 22, "day")
    assertEq(r.allday, true, "allday")
end)

-- ========== 요일 ==========
-- FIXED_NOW = 2026-04-20 월요일

test("@월 → coming Monday (a week later when today is Mon)", function()
    local r = parser.parse("회의 @월", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")
    assertEq(r.allday, true, "allday")
end)

test("@화 → this Tuesday", function()
    local r = parser.parse("회의 @화", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 21, "day")
end)

test("@일 → coming Sunday", function()
    local r = parser.parse("브런치 @일", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 26, "day")
end)

test("@mon → same as @월", function()
    local r = parser.parse("meeting @mon", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")
end)

test("@fri → coming Friday", function()
    local r = parser.parse("drink @fri", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 24, "day")
end)

test("@다음주 월 → next-next Monday", function()
    local r = parser.parse("회의 @다음주 월", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")
end)

test("@다음주 화 → next Tuesday", function()
    local r = parser.parse("회의 @다음주 화", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 28, "day")
end)

test("@next mon → same as 다음주 월", function()
    local r = parser.parse("meeting @next mon", FIXED_NOW)
    local d = dateFields(r.date)
    assertEq(d.day, 27, "day")
end)

print()
print(string.format("passed: %d, failed: %d", passed, failed))
if failed > 0 then os.exit(1) end
