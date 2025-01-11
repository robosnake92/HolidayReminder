local ADDON_NAME, HolidayReminder = ...
HolidayReminder.Config = {
    defaults = {
        showChat = true,
        showPopup = true,
        fontSize = 12,
        fadeTimer = 10,
        frameStrata = "MEDIUM",
        lockPopup = false,
        showEmptyPopup = true,
        blockedHolidays = {},
        knownHolidays = {},
        blockByDefault = false,
        windowStatus = {
            width = 300,
            height = 200,
            top = nil,
            left = nil
        }
    }
} 