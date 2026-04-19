local M = {}

local RELATIVE_DAYS = {
    ["오늘"] = 0, ["today"] = 0,
    ["내일"] = 1, ["tomorrow"] = 1,
    ["모레"] = 2,
}

-- os.date("*t").wday: Sunday=1, Monday=2, ..., Saturday=7
local DOW = {
    ["일"] = 1, ["sun"] = 1,
    ["월"] = 2, ["mon"] = 2,
    ["화"] = 3, ["tue"] = 3,
    ["수"] = 4, ["wed"] = 4,
    ["목"] = 5, ["thu"] = 5,
    ["금"] = 6, ["fri"] = 6,
    ["토"] = 7, ["sat"] = 7,
}

local function dayStart(ts)
    local t = os.date("*t", ts)
    t.hour = 0; t.min = 0; t.sec = 0
    return os.time(t)
end

local function addDays(ts, n)
    return dayStart(ts) + n * 86400
end

local function comingDow(now, targetWday)
    local today = os.date("*t", now).wday
    local delta = (targetWday - today) % 7
    if delta == 0 then delta = 7 end
    return addDays(now, delta)
end

-- Returns the target weekday of the next week (Mon-based week).
local function nextWeekDow(now, targetWday)
    local today = os.date("*t", now).wday  -- 1=Sun ... 7=Sat
    local daysBackToMon = (today == 1) and 6 or (today - 2)
    local mondayThisWeek = addDays(now, -daysBackToMon)
    local mondayNextWeek = addDays(mondayThisWeek, 7)
    local offsetFromMon = (targetWday == 1) and 6 or (targetWday - 2)
    return mondayNextWeek + offsetFromMon * 86400
end

local function parseDateExpr(dateExpr, now)
    local expr = string.lower(dateExpr)

    for token, offset in pairs(RELATIVE_DAYS) do
        if expr == token then
            return { date = addDays(now, offset), allday = true }
        end
    end

    local nextDow = expr:match("^다음주%s+(.+)$") or expr:match("^next%s+(.+)$")
    if nextDow then
        local wday = DOW[nextDow]
        if wday then
            return { date = nextWeekDow(now, wday), allday = true }
        end
    end

    local wday = DOW[expr]
    if wday then
        return { date = comingDow(now, wday), allday = true }
    end

    return nil
end

function M.parse(input, now)
    now = now or os.time()

    local atPos = string.find(input, "@", 1, true)
    if not atPos then
        return { name = input, date = nil, allday = false }
    end

    local namePart = string.sub(input, 1, atPos - 1):gsub("%s+$", "")
    local dateExpr = string.sub(input, atPos + 1):gsub("^%s+", ""):gsub("%s+$", "")

    if dateExpr == "" then
        return { name = input, date = nil, allday = false }
    end

    local parsed = parseDateExpr(dateExpr, now)
    if parsed then
        return { name = namePart, date = parsed.date, allday = parsed.allday }
    end

    return { name = input, date = nil, allday = false }
end

return M
