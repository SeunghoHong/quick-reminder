local M = {}

local hotkey = nil

function M.start(cb)
    if hotkey then hotkey:delete() end
    hotkey = hs.hotkey.bind({ "alt" }, "r", cb)
end

function M.stop()
    if hotkey then hotkey:delete(); hotkey = nil end
end

return M
