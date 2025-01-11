local ADDON_NAME, HolidayReminder = ...
HolidayReminder.Utils = {}
local Utils = HolidayReminder.Utils
local popup

function Utils:GetTimeRemaining(eventInfo)
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

function Utils:FormatTimeString(days, hours, minutes)
    local parts = {}
    
    if days then
        if days == 1 then
            table.insert(parts, "1 day")
        else
            table.insert(parts, days .. " days")
        end
    end
    
    if hours then
        if hours == 1 then
            table.insert(parts, "1 hour")
        else
            table.insert(parts, hours .. " hours")
        end
    end
    
    if minutes then
        if minutes == 1 then
            table.insert(parts, "1 minute")
        else
            table.insert(parts, minutes .. " minutes")
        end
    end
    
    return table.concat(parts, ", ")
end

function Utils:ShowPopup(messageText)
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