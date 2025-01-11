local addonName = ...
local frame = CreateFrame("Frame")
local hasInitialized = false
local lastUpdate = 0
local UPDATE_THRESHOLD = 1

local defaultSettings = {
    showChat = true,
    showPopup = true,
    fontSize = 12,
    fadeTimer = 10,
    frameStrata = "MEDIUM",
    lockPopup = false,
    showEmptyPopup = true,
    blockedHolidays = {},
    knownHolidays = {},
}

local function getTimeRemaining(eventInfo)
    local currentTime = C_DateAndTime.GetCurrentCalendarTime()
    local endTime = eventInfo.endTime

    local currentTimestamp = time({
        year = currentTime.year,
        month = currentTime.month,
        day = currentTime.monthDay,
        hour = currentTime.hour,
        min = currentTime.minute
    })

    local endTimestamp = time({
        year = endTime.year,
        month = endTime.month,
        day = endTime.monthDay,
        hour = endTime.hour,
        min = endTime.minute
    })

    if currentTimestamp > endTimestamp then
        return nil
    end

    local timeRemaining = endTimestamp - currentTimestamp
    local days = math.floor(timeRemaining / 86400)
    local hours = math.floor((timeRemaining % 86400) / 3600)
    local minutes = math.floor((timeRemaining % 3600) / 60)

    return days, hours, minutes
end

local function formatTimeRemaining(days, hours, minutes)
    if days and hours and minutes then
        if days > 0 then
            return string.format("%d days %d hours %d minutes", days, hours, minutes)
        else
            return string.format("0 days %d hours %d minutes", hours, minutes)
        end
    end
    return "Time remaining unknown"
end

local function showPopup(messageText)
    if not popup then
        popup = LibStub("AceGUI-3.0"):Create("Window")
        popup:SetTitle("Holiday Reminder")
        popup:SetLayout("Flow")

        popup.frame:SetResizeBounds(200, 100)

        if not HolidayReminderDB.windowStatus then
            HolidayReminderDB.windowStatus = {
                width = 300,
                height = 200,
                top = nil,
                left = nil
            }
        end

        popup:SetStatusTable(HolidayReminderDB.windowStatus)

        popup.frame:SetScript("OnSizeChanged", function(frame)
            HolidayReminderDB.windowStatus.width = frame:GetWidth()
            HolidayReminderDB.windowStatus.height = frame:GetHeight()
        end)

        popup.frame:SetScript("OnDragStop", function(frame)
            HolidayReminderDB.windowStatus.top = frame:GetTop()
            HolidayReminderDB.windowStatus.left = frame:GetLeft()
        end)

        popup.frame:SetFrameStrata(HolidayReminderDB.frameStrata)

        popup:EnableResize(not HolidayReminderDB.lockPopup)
        if (HolidayReminderDB.lockPopup) then
            popup.title:SetScript("OnMouseDown", function() 
                -- do nothing
            end)
        end

        local scroll = LibStub("AceGUI-3.0"):Create("ScrollFrame")
        scroll:SetLayout("List")
        scroll:SetFullWidth(true)
        scroll:SetFullHeight(true)
        popup:AddChild(scroll)
        
        local label = LibStub("AceGUI-3.0"):Create("Label")
        label:SetText(messageText)
        label:SetFullWidth(true)
        label:SetFont("Fonts\\FRIZQT__.TTF", HolidayReminderDB.fontSize or 12, "")
        scroll:AddChild(label)

        popup:SetCallback("OnClose", function()
            popup = nil
        end)

        popup.fadeTimer = nil
        popup.StartFadeTimer = function()
            if popup.fadeTimer then
                popup.fadeTimer:Cancel()
            end
            if HolidayReminderDB.fadeTimer > 0 then
                popup.fadeTimer = C_Timer.NewTimer(HolidayReminderDB.fadeTimer, function()
                    if popup and popup.frame then
                        popup.frame:SetAlpha(1)
                        local fadeInfo = {
                            mode = "OUT",
                            timeToFade = 1,
                            startAlpha = 1,
                            endAlpha = 0,
                            finishedFunc = function()
                                if popup then
                                    popup:Hide()
                                    popup = nil
                                end
                            end,
                        }
                        UIFrameFade(popup.frame, fadeInfo)
                    end
                end)
            end
        end

        if HolidayReminderDB.fadeTimer > 0 then
            popup.frame:SetScript("OnEnter", function()
                if popup.fadeTimer then
                    popup.fadeTimer:Cancel()
                end
                popup.frame:SetAlpha(1)
            end)

            popup.frame:SetScript("OnLeave", function()
                popup.StartFadeTimer()
            end)
        end
    end

    popup:Show()
    popup.frame:SetAlpha(1)
    popup.StartFadeTimer()
    return popup
end

local function updateHolidayDisplay()
    local now = GetTime()
    if now - lastUpdate < UPDATE_THRESHOLD then
        return
    end
    lastUpdate = now

    local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime()
    local numEvents = C_Calendar.GetNumDayEvents(0, currentCalendarTime.monthDay)

    local holidays = {}

    if not HolidayReminderDB.knownHolidays then
        HolidayReminderDB.knownHolidays = {}
    end
    if not HolidayReminderDB.blockedHolidays then
        HolidayReminderDB.blockedHolidays = {}
    end

    for i = 1, numEvents do
        local eventInfo = C_Calendar.GetDayEvent(0, currentCalendarTime.monthDay, i)
        if eventInfo and eventInfo.calendarType == "HOLIDAY" then
            HolidayReminderDB.knownHolidays[eventInfo.title] = true

            if not HolidayReminderDB.blockedHolidays[eventInfo.title] then
                local days, hours, minutes = getTimeRemaining(eventInfo)
                if days or hours or minutes then
                    table.insert(holidays, {
                        info = eventInfo,
                        days = days,
                        hours = hours,
                        minutes = minutes,
                        timeRemaining = (days or 0) * 86400 + (hours or 0) * 3600 + (minutes or 0) * 60
                    })
                end
            end
        end
    end

    table.sort(holidays, function(a, b)
        return a.timeRemaining < b.timeRemaining
    end)

    local messageText = ""
    if #holidays == 0 then
        messageText = "No active holidays found for today."
    else
        for i, holiday in ipairs(holidays) do
            local title = holiday.info.title
            if #title > 50 then
                title = title:sub(1, 50) .. "..."
            end

            local eventTitle = string.format("|cFFE6CC80%s|r", title)
            local status = formatTimeRemaining(holiday.days, holiday.hours, holiday.minutes)

            messageText = messageText .. eventTitle .. "\n    - " .. status .. "\n"
            if i < #holidays then
                messageText = messageText .. "\n"
            end
        end
    end

    if #holidays > 0 or HolidayReminderDB.showEmptyPopup then
    if HolidayReminderDB.showPopup then
        showPopup(messageText)
        end
    end
    if HolidayReminderDB.showChat then
        print("|cFF00FF00Active Holidays:|r")
        for line in messageText:gmatch("[^\r\n]+") do
            print(line:match("^%s*(.-)%s*$"))
        end
    end
end

local options = {
    name = "Holiday Reminder",
    handler = {},
    type = 'group',
    args = {
        alerts = {
            type = "group",
            name = "Alerts",
            desc = "Configure alert settings",
            order = 1,
            args = {
                showChat = {
                    type = "toggle",
                    name = "Show in Chat",
                    desc = "Show holiday reminders in chat",
                    get = function() return HolidayReminderDB.showChat end,
                    set = function(_, value) HolidayReminderDB.showChat = value end,
                    order = 1,
                },
                showPopup = {
                    type = "toggle",
                    name = "Show Popup",
                    desc = "Show holiday reminders in a popup window",
                    get = function() return HolidayReminderDB.showPopup end,
                    set = function(_, value) HolidayReminderDB.showPopup = value end,
                    order = 2,
                },
            },
        },
        popup = {
            type = "group",
            name = "Popup Settings",
            desc = "Configure popup appearance",
            order = 2,
            args = {
                fontSize = {
                    type = "range",
                    name = "Font Size",
                    desc = "Adjust the size of text in the popup",
                    min = 8,
                    max = 24,
                    step = 1,
                    get = function() return HolidayReminderDB.fontSize end,
                    set = function(_, value) HolidayReminderDB.fontSize = value end,
                    order = 1,
                },
                fadeTimer = {
                    type = "range",
                    name = "Popup Duration",
                    desc = "How long the popup stays visible before fading (in seconds). Set to 0 to disable auto-fade.",
                    min = 0,
                    max = 60,
                    step = 1,
                    get = function() return HolidayReminderDB.fadeTimer end,
                    set = function(_, value) HolidayReminderDB.fadeTimer = value end,
                    order = 2,
                },
                lockPopup = {
                    type = "toggle",
                    name = "Lock Position and Size",
                    desc = "Prevent the popup from being moved or resized",
                    get = function() return HolidayReminderDB.lockPopup end,
                    set = function(_, value) 
                        HolidayReminderDB.lockPopup = value
                        if popup then 
                        -- Show reload dialog
                            StaticPopup_Show("HOLIDAY_REMINDER_RELOAD_UI")
                        end
                    end,
                    order = 3,
                },
                showEmptyPopup = {
                    type = "toggle",
                    name = "Show When Empty",
                    desc = "Show popup even when there are no active holidays",
                    get = function() return HolidayReminderDB.showEmptyPopup end,
                    set = function(_, value) 
                        HolidayReminderDB.showEmptyPopup = value 
                    end,
                    order = 4,
                },
                frameStrata = {
                    type = "select",
                    name = "Window Layer",
                    desc = "Control which windows can appear above the popup",
                    values = {
                        BACKGROUND = "Background",
                        LOW = "Low",
                        MEDIUM = "Medium",
                        HIGH = "High",
                        DIALOG = "Dialog",
                        FULLSCREEN = "Fullscreen",
                        FULLSCREEN_DIALOG = "Fullscreen Dialog",
                        TOOLTIP = "Tooltip",
                    },
                    sorting = {
                        "BACKGROUND",
                        "LOW",
                        "MEDIUM",
                        "HIGH",
                        "DIALOG",
                        "FULLSCREEN",
                        "FULLSCREEN_DIALOG",
                        "TOOLTIP",
                    },
                    get = function() return HolidayReminderDB.frameStrata end,
                    set = function(_, value) 
                        HolidayReminderDB.frameStrata = value
                        if popup and popup.frame then
                            popup.frame:SetFrameStrata(value)
                        end
                    end,
                    order = 5,
                },
            },
        },
        holidayFilters = {
            type = "group",
            name = "Holiday Filters",
            desc = "Choose which holidays to show or hide",
            order = 3,
            args = {},
        },
    },
}

local function UpdateHolidayButtons()
    for k in pairs(options.args.holidayFilters.args) do
        if k:match("^holiday") then
            options.args.holidayFilters.args[k] = nil
        end
    end

    local knownHolidays = {}
    for holiday in pairs(HolidayReminderDB.knownHolidays or {}) do
        table.insert(knownHolidays, holiday)
    end
    table.sort(knownHolidays)

    options.args.holidayFilters.args.holidayTree = {
        type = "multiselect",
        name = "Active Holidays",
        values = function()
            local list = {}
            for _, holiday in ipairs(knownHolidays) do
                list[holiday] = holiday
            end
            return list
        end,
        get = function(_, key)
            return not (HolidayReminderDB.blockedHolidays and HolidayReminderDB.blockedHolidays[key])
        end,
        set = function(_, key, value)
            if not HolidayReminderDB.blockedHolidays then
                HolidayReminderDB.blockedHolidays = {}
            end

            if not value then
                HolidayReminderDB.blockedHolidays[key] = true
            else
                HolidayReminderDB.blockedHolidays[key] = nil
            end
        end,
        width = "full",
        order = 1
    }

    LibStub("AceConfigRegistry-3.0"):NotifyChange("HolidayReminder")
end

local function ShowConfig()
    UpdateHolidayButtons()
end

local function initializeSettings()
    if not HolidayReminderDB then
        HolidayReminderDB = defaultSettings
    else
        for key, value in pairs(defaultSettings) do
            if HolidayReminderDB[key] == nil then
                HolidayReminderDB[key] = value
            end
        end
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        initializeSettings()
        LibStub("AceConfig-3.0"):RegisterOptionsTable("HolidayReminder", options)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HolidayReminder", "Holiday Reminder")
    elseif event == "PLAYER_LOGIN" then
        initializeSettings()
        C_Calendar.OpenCalendar()
        C_Timer.After(2, function()
            if not hasInitialized then
                hasInitialized = true
                updateHolidayDisplay()
                UpdateHolidayButtons()
            end
        end)
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" and hasInitialized then
        local now = GetTime()
        if now - lastUpdate >= UPDATE_THRESHOLD then
            updateHolidayDisplay()
        end
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")

SLASH_HOLIDAYREMINDER1 = "/hr"

local function HandleSlashCommand(msg)
    msg = msg:lower():trim()

    if msg == "reset" then
        HolidayReminderDB.blockedHolidays = {}
        HolidayReminderDB.knownHolidays = {}

        print("Holiday Reminder: Known and Blocked Holidays Cleared!")

        updateHolidayDisplay()
        UpdateHolidayButtons()
        LibStub("AceConfigRegistry-3.0"):NotifyChange("HolidayReminder")
    elseif msg == "options" then
        ShowConfig()
    elseif msg == "show" then
        updateHolidayDisplay()
    else
        print("Holiday Reminder commands:")
        print("  /hr show - Show active holidays")
        print("  /hr options - Open settings window")
        print("  /hr reset - Clear all holiday lists and start fresh")
        print("  /hr - Show this help message")
    end
end

SlashCmdList["HOLIDAYREMINDER"] = HandleSlashCommand

-- Register the static popup
StaticPopupDialogs["HOLIDAY_REMINDER_RELOAD_UI"] = {
    text = "Holiday Reminder: The lock setting has changed. Would you like to reload your UI now?",
    button1 = "Reload",
    button2 = "Later",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
