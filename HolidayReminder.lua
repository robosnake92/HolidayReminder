local addonName = ...
local frame = CreateFrame("Frame")
local hasInitialized = false
local lastUpdate = 0
local UPDATE_THRESHOLD = 1

local defaultSettings = {
    showChat = true,
    showPopup = true,
    fontSize = 12,
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
    end

    popup:Show()
    return popup
end

local function updateHolidayDisplay(printToChat)
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

    if HolidayReminderDB.showPopup then
        showPopup(messageText)
    end

    if printToChat and HolidayReminderDB.showChat then
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
        desc = {
            type = "description",
            name = "Keeping track of holidays since whenever you installed this addon!",
            order = 1,
        },
        showChat = {
            type = "toggle",
            name = "Show in Chat",
            desc = "Show holiday reminders in chat on login",
            get = function() return HolidayReminderDB.showChat end,
            set = function(_, value) HolidayReminderDB.showChat = value end,
            order = 2,
        },
        showPopup = {
            type = "toggle",
            name = "Show Popup",
            desc = "Show holiday reminders in a popup on login",
            get = function() return HolidayReminderDB.showPopup end,
            set = function(_, value) HolidayReminderDB.showPopup = value end,
            order = 3,
        },
        fontSize = {
            type = "range",
            name = "Font Size",
            desc = "Adjust the size of text in the popup",
            min = 8,
            max = 24,
            step = 1,
            get = function() return HolidayReminderDB.fontSize end,
            set = function(_, value) HolidayReminderDB.fontSize = value end,
            order = 4,
        },
        holidayFilters = {
            type = "group",
            name = "Holiday Filters",
            desc = "Choose which holidays to show or hide",
            order = 5,
            args = {
                allowedHeader = {
                    type = "description",
                    name = "=== Allowed Holidays ===",
                    fontSize = "large",
                    order = 1,
                },
            },
        },
    },
}

local function UpdateHolidayButtons()
    for k in pairs(options.args.holidayFilters.args) do
        if k:match("^holiday") then
            options.args.holidayFilters.args[k] = nil
        end
    end

    local allowedHolidays = {}
    for holiday in pairs(HolidayReminderDB.knownHolidays or {}) do
        if not (HolidayReminderDB.blockedHolidays and HolidayReminderDB.blockedHolidays[holiday]) then
            table.insert(allowedHolidays, holiday)
        end
    end
    table.sort(allowedHolidays)

    options.args.holidayFilters.args.holidayTree = {
        type = "multiselect",
        name = "Active Holidays",
        values = function()
            local list = {}
            for _, holiday in ipairs(allowedHolidays) do
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

            updateHolidayDisplay(false)
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
                updateHolidayDisplay(HolidayReminderDB.showChat)
                UpdateHolidayButtons()
            end
        end)
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" and hasInitialized then
        local now = GetTime()
        if now - lastUpdate >= UPDATE_THRESHOLD then
            updateHolidayDisplay(false)
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

        local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime()
        local numEvents = C_Calendar.GetNumDayEvents(0, currentCalendarTime.monthDay)

        for i = 1, numEvents do
            local eventInfo = C_Calendar.GetDayEvent(0, currentCalendarTime.monthDay, i)
            if eventInfo and eventInfo.calendarType == "HOLIDAY" then
                HolidayReminderDB.knownHolidays[eventInfo.title] = true
            end
        end

        print("Holiday Reminder: Known and Blocked Holidays Cleared!")

        UpdateHolidayButtons()
        LibStub("AceConfigRegistry-3.0"):NotifyChange("HolidayReminder")
        updateHolidayDisplay(true)
    elseif msg == "options" then
        ShowConfig()
    elseif msg == "show" then
        updateHolidayDisplay(true)
    else
        print("Holiday Reminder commands:")
        print("  /hr show - Show active holidays")
        print("  /hr options - Open settings window")
        print("  /hr reset - Clear all holiday lists and start fresh")
        print("  /hr - Show this help message")
    end
end

SlashCmdList["HOLIDAYREMINDER"] = HandleSlashCommand
