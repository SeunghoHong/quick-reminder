local M = {}

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

    return { name = input, date = nil, allday = false }
end

return M
