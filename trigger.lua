local M = {}

local tap = nil
local shiftHeldSincePrevKey = false

function M.start(cb)
    if tap then tap:stop() end

    local types = hs.eventtap.event.types
    tap = hs.eventtap.new({ types.keyDown, types.flagsChanged }, function(e)
        local etype = e:getType()
        local flags = e:getFlags()

        if etype == types.flagsChanged then
            if not flags.shift then
                shiftHeldSincePrevKey = false
            end
            return false
        end

        local keyCode = e:getKeyCode()
        local isShiftSpace = keyCode == hs.keycodes.map.space
            and flags.shift
            and not flags.cmd and not flags.alt and not flags.ctrl and not flags.fn

        if isShiftSpace then
            if shiftHeldSincePrevKey then
                shiftHeldSincePrevKey = false
                return false
            end
            cb()
            return true
        end

        shiftHeldSincePrevKey = flags.shift == true
        return false
    end)
    tap:start()
end

function M.stop()
    if tap then tap:stop(); tap = nil end
    shiftHeldSincePrevKey = false
end

return M
