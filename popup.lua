local M = {}

local CONFIG = {
    width = 560,
    height = 90,
}

local currentWebview = nil
local currentLists = {}
local currentIndex = 1
local onSubmit = nil
local onCancel = nil
local hotkeys = {}
local outsideClickTap = nil

local function centerFrame()
    local screen = hs.screen.mainScreen():frame()
    return {
        x = screen.x + (screen.w - CONFIG.width) / 2,
        y = screen.y + (screen.h - CONFIG.height) / 2,
        w = CONFIG.width,
        h = CONFIG.height,
    }
end

local function closeWebview()
    for _, hk in ipairs(hotkeys) do hk:delete() end
    hotkeys = {}
    if outsideClickTap then
        outsideClickTap:stop()
        outsideClickTap = nil
    end
    if currentWebview then
        currentWebview:delete()
        currentWebview = nil
    end
end

local function updateListLabel()
    if not currentWebview then return end
    local name = currentLists[currentIndex] or ""
    name = name:gsub("\\", "\\\\"):gsub("'", "\\'")
    currentWebview:evaluateJavaScript(string.format("window.setListName('%s')", name))
end

local function cancel()
    closeWebview()
    if onCancel then onCancel() end
end

local function submit()
    if not currentWebview then return end
    currentWebview:evaluateJavaScript(
        "document.getElementById('input').value",
        function(result)
            local text = result or ""
            local listName = currentLists[currentIndex]
            closeWebview()
            if onSubmit then onSubmit(listName, text) end
        end
    )
end

local function cycleList(delta)
    if #currentLists == 0 then return end
    currentIndex = ((currentIndex - 1 + delta) % #currentLists) + 1
    if not currentWebview then return end
    local name = currentLists[currentIndex] or ""
    name = name:gsub("\\", "\\\\"):gsub("'", "\\'")
    currentWebview:evaluateJavaScript(string.format("window.setListName('%s')", name))
end

local function handleMessage(msgJson)
    local ok, msg = pcall(hs.json.decode, msgJson)
    if not ok or type(msg) ~= "table" then return end

    if msg.action == "submit" then
        local text = (msg.payload and msg.payload.text) or ""
        local listName = currentLists[currentIndex]
        closeWebview()
        if onSubmit then onSubmit(listName, text) end
    elseif msg.action == "cancel" then
        cancel()
    elseif msg.action == "next-list" then
        if #currentLists > 0 then
            currentIndex = (currentIndex % #currentLists) + 1
            updateListLabel()
        end
    elseif msg.action == "prev-list" then
        if #currentLists > 0 then
            currentIndex = ((currentIndex - 2) % #currentLists) + 1
            updateListLabel()
        end
    end
end

function M.open(opts)
    if currentWebview then return end
    currentLists = opts.lists or {}
    currentIndex = opts.initialIndex or 1
    onSubmit = opts.onSubmit
    onCancel = opts.onCancel

    local htmlPath = hs.configdir .. "/quick-reminder/popup.html"
    local url = "file://" .. htmlPath

    local frame = centerFrame()

    currentWebview = hs.webview.new(frame, { developerExtrasEnabled = false })
        :windowStyle({ "closable", "nonactivating" })
        :level(hs.drawing.windowLevels.floating)
        :allowTextEntry(true)
        :transparent(true)
        :bringToFront(true)

    currentWebview:policyCallback(function(action, webview, navDetails)
        if action == "navigationAction" then
            local target = navDetails.request.URL
            if type(target) == "string" and target:sub(1, 8) == "hsmsg://" then
                local encoded = target:sub(9)
                local decoded = hs.http.urlDecode(encoded)
                handleMessage(decoded)
                return false
            end
        end
        return true
    end)

    currentWebview:url(url):show()
    currentWebview:hswindow():focus()

    table.insert(hotkeys, hs.hotkey.bind({}, "escape", cancel))
    table.insert(hotkeys, hs.hotkey.bind({}, "return", submit))
    table.insert(hotkeys, hs.hotkey.bind({}, "tab", function() cycleList(1) end))
    table.insert(hotkeys, hs.hotkey.bind({ "shift" }, "tab", function() cycleList(-1) end))

    outsideClickTap = hs.eventtap.new(
        { hs.eventtap.event.types.leftMouseDown,
          hs.eventtap.event.types.rightMouseDown },
        function(event)
            if not currentWebview then return false end
            local webFrame = currentWebview:frame()
            local p = event:location()
            local outside = p.x < webFrame.x or p.x > webFrame.x + webFrame.w
                          or p.y < webFrame.y or p.y > webFrame.y + webFrame.h
            if outside then cancel() end
            return false
        end
    )
    outsideClickTap:start()

    hs.timer.doAfter(0.2, function()
        if currentWebview then updateListLabel() end
    end)
end

function M.isOpen()
    return currentWebview ~= nil
end

return M
