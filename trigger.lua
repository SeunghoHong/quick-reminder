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
    local onlyCtrl = flags.ctrl and not flags.cmd and not flags.alt
                      and not flags.shift and not flags.fn
    local ctrlDown = flags.ctrl == true
    local otherModifier = flags.cmd or flags.alt or flags.shift or flags.fn

    if otherModifier then
        resetState()
        return false
    end

    if state == "idle" then
        if ctrlDown and onlyCtrl then
            state = "first-down"
            armTimeout(500)
        end
    elseif state == "first-down" then
        if not ctrlDown then
            state = "first-up"
            armTimeout(windowMs)
        end
    elseif state == "first-up" then
        if ctrlDown and onlyCtrl then
            resetState()
            if onTrigger then onTrigger() end
        end
    end

    return false
end

function M.start(cb, ms)
    onTrigger = cb
    windowMs = ms or 300
    if eventtap then eventtap:stop() end
    eventtap = hs.eventtap.new(
        { hs.eventtap.event.types.flagsChanged },
        handleFlagsChanged
    )
    eventtap:start()
end

function M.stop()
    if eventtap then eventtap:stop(); eventtap = nil end
    resetState()
    onTrigger = nil
end

return M
