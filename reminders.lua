local M = {}

local function escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    return s
end
M._escape = escape

function M.listLists()
    local script = [[
        tell application "Reminders"
            return name of every list
        end tell
    ]]
    local ok, out, err = hs.osascript.applescript(script)
    if not ok then
        print("[quick-reminder] listLists failed:", tostring(err))
        return {}
    end
    if type(out) == "table" then return out end
    if type(out) == "string" and out ~= "" then return { out } end
    print("[quick-reminder] listLists unexpected return:", type(out), tostring(out))
    return {}
end

-- args: { list, name, date (os.time?), allday (bool) }
-- Returns: true, nil on success. false, errMsg on failure.
function M.save(args)
    local listName = escape(args.list or "")
    local name = escape(args.name or "")

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

    local ok, _, err = hs.osascript.applescript(script)
    if ok then return true end
    return false, tostring(err)
end

return M
