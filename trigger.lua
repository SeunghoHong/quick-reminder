local M = {}

local state = "idle"
local timeoutTimer = nil
local onTrigger = nil
local windowMs = 300

local eventtap = nil

local function resetState()
    state = "idle"
    if timeoutTimer then
        timeoutTimer:stop()
        timeoutTimer = nil
    end
end

local function armTimeout(ms)
    if timeoutTimer then timeoutTimer:stop() end
    timeoutTimer = hs.timer.doAfter(ms / 1000.0, resetState)
end

local function handleFlagsChanged(event)
    local flags = event:getFlags()
    local onlyShift = flags.shift and not flags.cmd and not flags.alt
                      and not flags.ctrl and not flags.fn
    local shiftDown = flags.shift == true
    local otherModifier = flags.cmd or flags.alt or flags.ctrl or flags.fn

    if otherModifier then
        resetState()
        return false
    end

    if state == "idle" then
        if shiftDown and onlyShift then
            state = "first-down"
            armTimeout(500)
        end
    elseif state == "first-down" then
        if not shiftDown then
            state = "first-up"
            armTimeout(windowMs)
        end
    elseif state == "first-up" then
        if shiftDown and onlyShift then
            resetState()
            if onTrigger then onTrigger() end
        end
    end

    return false
end

local function handleKeyDown(event)
    if state ~= "idle" then
        resetState()
    end
    return false
end

function M.start(cb, ms)
    onTrigger = cb
    windowMs = ms or 200
    if eventtap then eventtap:stop() end
    eventtap = hs.eventtap.new(
        {
            hs.eventtap.event.types.flagsChanged,
            hs.eventtap.event.types.keyDown,
        },
        function(event)
            if event:getType() == hs.eventtap.event.types.keyDown then
                return handleKeyDown(event)
            end
            return handleFlagsChanged(event)
        end
    )
    eventtap:start()
end

function M.stop()
    if eventtap then eventtap:stop(); eventtap = nil end
    resetState()
    onTrigger = nil
end

return M
