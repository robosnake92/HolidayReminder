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

    local holidays = {}
    local upcomingHolidays = {}
    local activeHolidayTitles = {}
    local processedEventTitles = {}
    local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime()
    local processedDays = {}
    
    -- Function to process events for a given day
    local function processEvents(monthOffset, day, isUpcoming)
        -- Create a unique key for this day
        local dayKey = monthOffset .. "-" .. day
        if processedDays[dayKey] then
            return
        end
        processedDays[dayKey] = true

        local dayEvents = C_Calendar.GetNumDayEvents(monthOffset, day)
        for i = 1, dayEvents do
            local eventInfo = C_Calendar.GetDayEvent(monthOffset, day, i)
            if eventInfo and eventInfo.calendarType == "HOLIDAY" then
                -- Only process if we haven't seen this event title yet
                if not processedEventTitles[eventInfo.title] then
                    processedEventTitles[eventInfo.title] = true

                    -- Track known holidays
                    if not HolidayReminderDB.knownHolidays[eventInfo.title] then
                        HolidayReminderDB.knownHolidays[eventInfo.title] = true
                        HolidayReminderDB.blockedHolidays[eventInfo.title] = HolidayReminderDB.blockByDefault
                    end

                    if not HolidayReminderDB.blockedHolidays[eventInfo.title] then
                        if isUpcoming then
                            local days, hours, minutes = HolidayReminder.Utils:GetTimeUntilStart(eventInfo)
                            if days or hours or minutes then
                                local holidayInfo = {
                                    info = eventInfo,
                                    days = days,
                                    hours = hours,
                                    minutes = minutes,
                                    timeRemaining = (days or 0) * 86400 + (hours or 0) * 3600 + (minutes or 0) * 60,
                                    isUpcoming = isUpcoming
                                }
                                
                                if not activeHolidayTitles[eventInfo.title] then
                                    table.insert(upcomingHolidays, holidayInfo)
                                end
                            end
                        else
                            local days, hours, minutes = HolidayReminder.Utils:GetTimeRemaining(eventInfo)
                            if days or hours or minutes then
                                local holidayInfo = {
                                    info = eventInfo,
                                    days = days,
                                    hours = hours,
                                    minutes = minutes,
                                    timeRemaining = (days or 0) * 86400 + (hours or 0) * 3600 + (minutes or 0) * 60,
                                    isUpcoming = isUpcoming
                                }
                                table.insert(holidays, holidayInfo)
                                activeHolidayTitles[eventInfo.title] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- Check current day
    processEvents(0, currentCalendarTime.monthDay, false)

    -- Process future days if enabled
    if HolidayReminderDB.showUpcoming then
        local daysToCheck = HolidayReminderDB.lookAheadDays
        local currentDay = currentCalendarTime.monthDay
        local monthInfo = C_Calendar.GetMonthInfo(0)
        local daysInMonth = monthInfo.numDays
        
        for i = 1, daysToCheck do
            local checkDay = currentDay + i
            local monthOffset = 0
            
            -- Handle month rollover
            if checkDay > daysInMonth then
                checkDay = checkDay - daysInMonth
                monthOffset = 1
            end
            
            processEvents(monthOffset, checkDay, true)
        end
    end

    -- Sort both lists by time remaining
    table.sort(holidays, function(a, b) return a.timeRemaining < b.timeRemaining end)
    table.sort(upcomingHolidays, function(a, b) return a.timeRemaining < b.timeRemaining end)

    -- Build and display message
    local messageText = ""
    if #holidays == 0 then
        messageText = "No active holidays found for today."
    else
        messageText = "|cFFFFFF00Active Holidays:|r\n"
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

    -- Upcoming holidays
    if #upcomingHolidays > 0 then
        if #holidays > 0 then
            messageText = messageText .. "\n"
        end
        messageText = messageText .. "|cFFFFFF00Upcoming Holidays:|r\n"
        for i, holiday in ipairs(upcomingHolidays) do
            local title = holiday.info.title
            if #title > 50 then
                title = title:sub(1, 50) .. "..."
            end

            local eventTitle = string.format("|cFF88CC88%s|r", title)
            local startString = string.format("Starts in %s", 
                HolidayReminder.Utils:FormatTimeString(holiday.days, holiday.hours, holiday.minutes))

            messageText = messageText .. eventTitle .. "\n    - " .. startString .. "\n"
            if i < #upcomingHolidays then
                messageText = messageText .. "\n"
            end
        end
    end

    -- Display results
    if (#holidays > 0 or #upcomingHolidays > 0 or HolidayReminderDB.showEmptyPopup) then
        if HolidayReminderDB.showPopup then
            HolidayReminder.Utils:ShowPopup(messageText)
        end
    end
    if HolidayReminderDB.showChat then
        print("|cFF00FF00Holiday Reminder:|r")
        for line in messageText:gmatch("[^\r\n]+") do
            print(line:match("^%s*(.-)%s*$"))
        end
    end

    -- Cleanup
    holidays = nil
    upcomingHolidays = nil
    activeHolidayTitles = nil
    processedEventTitles = nil
    processedDays = nil
    messageText = nil
    collectgarbage("collect")
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
    end
end)

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

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

