local M = {}

local function escapeAS(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    return s
end
M._escape = escapeAS

-- Run an AppleScript via /usr/bin/osascript subprocess.
-- Returns (ok, output). Writes script to a tmpfile to avoid shell escaping.
local function runOsascript(script)
    local tmpfile = os.tmpname()
    local f, err = io.open(tmpfile, "w")
    if not f then return false, err end
    f:write(script)
    f:close()

    local output, status = hs.execute("/usr/bin/osascript '" .. tmpfile .. "' 2>&1")
    os.remove(tmpfile)
    return status == true, output or ""
end

function M.listLists()
    local ok, output = runOsascript([[
tell application "Reminders"
    return name of every list
end tell
]])
    if not ok then
        print("[quick-reminder] listLists failed:", output)
        return {}
    end

    local result = {}
    for name in output:gmatch("([^,\n]+)") do
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then table.insert(result, name) end
    end
    return result
end

function M.save(args)
    local listName = escapeAS(args.list or "")
    local name = escapeAS(args.name or "")

    local propsParts = { string.format('name:"%s"', name) }

    if args.date then
        local asDate = os.date('date "%A, %B %d, %Y at %I:%M:%S %p"', args.date)
        if args.allday then
            table.insert(propsParts, string.format('allday due date:%s', asDate))
        else
            table.insert(propsParts, string.format('due date:%s', asDate))
        end
    end

    local props = table.concat(propsParts, ", ")

    local script = string.format([[
tell application "Reminders"
    tell list "%s"
        make new reminder with properties {%s}
    end tell
end tell
]], listName, props)

    local ok, output = runOsascript(script)
    if ok then return true end
    return false, output
end

return M
