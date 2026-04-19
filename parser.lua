local M = {}

local RELATIVE_DAYS = {
    ["오늘"] = 0, ["today"] = 0,
    ["내일"] = 1, ["tomorrow"] = 1,
    ["모레"] = 2,
}

local function dayStart(ts)
    local t = os.date("*t", ts)
    t.hour = 0; t.min = 0; t.sec = 0
    return os.time(t)
end

local function addDays(ts, n)
    return dayStart(ts) + n * 86400
end

local function parseDateExpr(dateExpr, now)
    local expr = string.lower(dateExpr)

    for token, offset in pairs(RELATIVE_DAYS) do
        if expr == token then
            return { date = addDays(now, offset), allday = true }
        end
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
