local M = {}

local CONFIG = {
    defaultList = "Work",
    toastDuration = 1.2,
}

local TOAST_STYLE = {
    strokeWidth = 1.2,
    strokeColor = { white = 1, alpha = 1 },
    fillColor = { red = 22/255, green = 22/255, blue = 26/255, alpha = 0.9 },
    textColor = { white = 1, alpha = 0.98 },
    textFont = ".AppleSystemUIFont",
    textSize = 12,
    radius = 16,
    atScreenEdge = 0,
    fadeInDuration = 0.12,
    fadeOutDuration = 0.18,
    padding = 10,
}

local TOAST_ERROR_STYLE = {
    strokeWidth = 1.2,
    strokeColor = { red = 1, green = 0.35, blue = 0.35, alpha = 1 },
    fillColor = { red = 22/255, green = 22/255, blue = 26/255, alpha = 0.9 },
    textColor = { white = 1, alpha = 0.98 },
    textFont = ".AppleSystemUIFont",
    textSize = 12,
    radius = 16,
    atScreenEdge = 0,
    fadeInDuration = 0.12,
    fadeOutDuration = 0.18,
    padding = 10,
}

local parser = require("quick-reminder.parser")
local reminders = require("quick-reminder.reminders")
local popup = require("quick-reminder.popup")
local trigger = require("quick-reminder.trigger")

local function onSubmit(listName, text)
    if not text or text == "" then return end

    local parsed = parser.parse(text)
    local ok, err = reminders.save({
        list = listName,
        name = parsed.name,
        date = parsed.date,
        allday = parsed.allday,
    })

    if ok then
        hs.alert.show("✓ " .. listName .. "에 추가됨", TOAST_STYLE, CONFIG.toastDuration)
    else
        hs.alert.show("✗ 저장 실패: " .. tostring(err), TOAST_ERROR_STYLE, 2.0)
    end
end

local function openPopup()
    if popup.isOpen() then return end

    local lists = reminders.listLists()
    if #lists == 0 then
        hs.alert.show("리마인더 리스트가 없습니다", TOAST_ERROR_STYLE, 2.0)
        return
    end

    local initialIndex = 1
    local defaultFound = false
    for i, name in ipairs(lists) do
        if name == CONFIG.defaultList then
            initialIndex = i
            defaultFound = true
            break
        end
    end

    if not defaultFound then
        hs.alert.show("⚠ " .. CONFIG.defaultList .. " 리스트 없음, '" .. lists[1] .. "' 사용",
                      TOAST_STYLE, 1.5)
    end

    popup.open({
        lists = lists,
        initialIndex = initialIndex,
        onSubmit = onSubmit,
    })
end

function M.start()
    trigger.start(openPopup)
    print("[quick-reminder] started — Alt+R to open")
end

function M.stop()
    trigger.stop()
end

M.start()

return M
