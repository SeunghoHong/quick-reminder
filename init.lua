local M = {}

local CONFIG = {
    defaultList = "Work",
    doubleTapWindowMs = 300,
    toastDuration = 1.2,
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
        hs.alert.show("✓ " .. listName .. "에 추가됨", CONFIG.toastDuration)
    else
        hs.alert.show("✗ 저장 실패: " .. tostring(err), {
            strokeColor = { red = 1, green = 0.3, blue = 0.3 },
            fillColor = { red = 0.2, green = 0, blue = 0, alpha = 0.85 },
        }, 2.0)
    end
end

local function openPopup()
    if popup.isOpen() then return end

    local lists = reminders.listLists()
    if #lists == 0 then
        hs.alert.show("리마인더 리스트가 없습니다", 2.0)
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
        hs.alert.show("⚠ " .. CONFIG.defaultList .. " 리스트 없음, '" .. lists[1] .. "' 사용", 1.5)
    end

    popup.open({
        lists = lists,
        initialIndex = initialIndex,
        onSubmit = onSubmit,
    })
end

function M.start()
    trigger.start(openPopup, CONFIG.doubleTapWindowMs)
    print("[quick-reminder] started — Ctrl×2 to open")
end

function M.stop()
    trigger.stop()
end

M.start()

return M
