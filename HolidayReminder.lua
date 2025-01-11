local ADDON_NAME, HolidayReminder = ...
local frame = CreateFrame("Frame")
local hasInitialized = false    -- Tracks if addon has completed initialization
local lastUpdate = 0            -- Time of last holiday check
local UPDATE_THRESHOLD = 1      -- Minimum time between holiday checks

-- Initialize or update saved variables with default settings
local function initializeSettings()
    if not HolidayReminderDB then
        HolidayReminderDB = HolidayReminder.Options.defaults
    else
        for key, value in pairs(HolidayReminder.Options.defaults) do
            if HolidayReminderDB[key] == nil then
                HolidayReminderDB[key] = value
            end
        end
    end
end

-- Main function to check and display active holidays
-- Checks calendar for holiday events and displays them according to user settings
local function updateHolidayDisplay()
    -- Verify calendar API is available
    if not C_Calendar then
        print("|cFFFF0000Holiday Reminder:|r Calendar API not available")
        return
    end

    -- Throttle update frequency
    local now = GetTime()
    if now - lastUpdate < UPDATE_THRESHOLD then
        return
    end
    lastUpdate = now

    local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime()
    local success, numEvents = pcall(C_Calendar.GetNumDayEvents, 0, currentCalendarTime.monthDay)
    if not success then
        return
    end

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
            if not HolidayReminderDB.knownHolidays[eventInfo.title] then
                HolidayReminderDB.knownHolidays[eventInfo.title] = true
                HolidayReminderDB.blockedHolidays[eventInfo.title] = HolidayReminderDB.blockByDefault
            end

            if not HolidayReminderDB.blockedHolidays[eventInfo.title] then
                local days, hours, minutes = HolidayReminder.Utils:GetTimeRemaining(eventInfo)
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
            local status = HolidayReminder.Utils:FormatTimeString(holiday.days, holiday.hours, holiday.minutes)

            messageText = messageText .. eventTitle .. "\n    - " .. status .. "\n"
            if i < #holidays then
                messageText = messageText .. "\n"
            end
        end
    end

    if #holidays > 0 or HolidayReminderDB.showEmptyPopup then
        if HolidayReminderDB.showPopup then
            HolidayReminder.Utils:ShowPopup(messageText)
        end
    end
    if HolidayReminderDB.showChat then
        print("|cFF00FF00Active Holidays:|r")
        for line in messageText:gmatch("[^\r\n]+") do
            print(line:match("^%s*(.-)%s*$"))
        end
    end
end

local options

local function ShowConfig()
    HolidayReminder.Options:ShowConfig()
end

local function UpdateHolidayButtons()
    HolidayReminder.Options:UpdateHolidayButtons()
end

-- Event handler for addon initialization and updates
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        -- Initialize addon settings and options panel
        initializeSettings()
        options = HolidayReminder.Options:GetOptionsTable()
        LibStub("AceConfig-3.0"):RegisterOptionsTable("HolidayReminder", options)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HolidayReminder", "Holiday Reminder")
    elseif event == "PLAYER_LOGIN" then
        -- Initial holiday check after player logs in
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
        -- Update display when calendar events change
        updateHolidayDisplay()
    end
end)

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")

-- Slash command handler
SLASH_HOLIDAYREMINDER1 = "/hr"
SlashCmdList["HOLIDAYREMINDER"] = function(msg)
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

-- Dialog for UI reload prompt
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

