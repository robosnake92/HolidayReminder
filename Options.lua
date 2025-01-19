local ADDON_NAME, HolidayReminder = ...
HolidayReminder.Options = {}
local Options = HolidayReminder.Options

-- Configuration defaults for the addon
-- These values are used when initializing the addon for the first time
-- or when a setting is missing from the saved variables
Options.defaults = {
    defaults = {
        -- Chat and popup display settings
        showChat = true,        -- Show holiday information in chat
        showPopup = true,       -- Show holiday information in popup window
        showEmptyPopup = true,  -- Show popup even when no holidays are active
        lookAheadDays = 7,      -- Number of days to look ahead for upcoming holidays
        showUpcoming = true,    -- Whether to show upcoming holidays
        
        -- Popup window appearance
        fontSize = 12,          -- Font size for popup text
        fadeTimer = 10,         -- Time in seconds before popup fades (0 = never fade)
        frameStrata = "MEDIUM", -- Window layer for popup (controls what appears above/below)
        lockPopup = false,      -- Prevent popup from being moved or resized
        
        -- Window position and size (saved between sessions)
        windowStatus = {
            width = 300,
            height = 200,
            top = nil,          -- Y position from top of screen
            left = nil,         -- X position from left of screen
        },
        
        -- Holiday filtering
        blockByDefault = false,  -- Automatically block newly discovered holidays
        blockedHolidays = {},   -- List of holidays user has chosen to hide
        knownHolidays = {},     -- List of all holidays encountered
    }
}

-- Options table for AceConfig-3.0
-- Defines the structure and behavior of the addon's configuration panel
local options = {
    name = "Holiday Reminder",
    handler = {},
    type = 'group',
    args = {
        -- Alert Settings Section
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
                blockByDefault = {
                    type = "toggle",
                    name = "Block by Default",
                    desc = "Block all new holidays by default",
                    get = function() return HolidayReminderDB.blockByDefault end,
                    set = function(_, value) HolidayReminderDB.blockByDefault = value end,
                    order = 3,
                },
                showUpcoming = {
                    type = "toggle",
                    name = "Show Upcoming Holidays",
                    desc = "Show holidays starting in the next few days",
                    get = function() return HolidayReminderDB.showUpcoming end,
                    set = function(_, value) HolidayReminderDB.showUpcoming = value end,
                    order = 4,
                },
                lookAheadDays = {
                    type = "range",
                    name = "Look Ahead Days",
                    desc = "Number of days to look ahead for upcoming holidays",
                    min = 1,
                    max = 30,
                    step = 1,
                    get = function() return HolidayReminderDB.lookAheadDays end,
                    set = function(_, value) HolidayReminderDB.lookAheadDays = value end,
                    order = 5,
                    disabled = function() return not HolidayReminderDB.showUpcoming end,
                },
            },
        },
        
        -- Popup Appearance Section
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
        
        -- Holiday Filter Section
        holidayFilters = {
            type = "group",
            name = "Holiday Filters",
            desc = "Choose which holidays to show or hide",
            order = 3,
            args = {},
        },
    },
}

-- Returns the options table for AceConfig registration
function Options:GetOptionsTable()
    return options
end

-- Updates the holiday filter buttons in the options panel
-- Called when holidays are discovered or when the options panel is opened
function Options:UpdateHolidayButtons()
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

-- Shows the configuration panel and updates holiday filters
function Options:ShowConfig()
    self:UpdateHolidayButtons()
end

HolidayReminder.options = options