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

local function handleMessage(msgJson)
    local ok, msg = pcall(hs.json.decode, msgJson)
    if not ok or type(msg) ~= "table" then return end

    if msg.action == "submit" then
        local text = (msg.payload and msg.payload.text) or ""
        local listName = currentLists[currentIndex]
        closeWebview()
        if onSubmit then onSubmit(listName, text) end
    elseif msg.action == "cancel" then
        closeWebview()
        if onCancel then onCancel() end
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

    hs.timer.doAfter(0.2, function()
        if currentWebview then updateListLabel() end
    end)
end

function M.isOpen()
    return currentWebview ~= nil
end

return M
