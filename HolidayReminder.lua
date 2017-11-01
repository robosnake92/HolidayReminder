ignoredHolidays = {};

local frame = CreateFrame("FRAME", "");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST");
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("VARIABLES_LOADED");

if (not IsAddOnLoaded("Blizzard_Calendar")) then
		UIParentLoadAddOn("Blizzard_Calendar");
end

local function eventHandler(self, event, ...)
	if (event == "VARIABLES_LOADED") then
		ignoredHolidays = ignoredHolidays;
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		frame:UnregisterEvent("PLAYER_ENTERING_WORLD");
		OpenCalendar();
	end
	if (event == "CALENDAR_UPDATE_EVENT_LIST") then
		frame:UnregisterEvent("CALENDAR_UPDATE_EVENT_LIST");
		holidayReminder();
	end
end

frame:SetScript("OnEvent", eventHandler);

SLASH_HOLIDAYREMINDER1 = "/hr";
function SlashCmdList.HOLIDAYREMINDER(msg)
	if (msg == "ignored") then
		if(getNumIgnored() > 0) then
			printIgnored();
		else
			print("No holidays currently ignored");
		end
	elseif (string.lower(msg) == "togglefade") then
		if (ignoredHolidays[string.lower(msg)] == true) then
			print("Setting Holiday Reminder to remain until closed");
			ignoredHolidays[string.lower(msg)] = false;
		else
			ignoredHolidays[string.lower(msg)] = true;
			print("Setting Holiday Reminder to fade");
		end
	elseif (msg ~= "") then
		if (ignoredHolidays[string.lower(msg)] == true) then
			print("Removing "..msg.." from the ignore list");
			msg = string.lower(msg);
			ignoredHolidays[msg] = false;
		else
			print("Adding "..msg.." to the ignore list");
			msg = string.lower(msg);
			ignoredHolidays[msg] = true;
		end	
	else
		holidayReminder();
	end
end

function getNumIgnored()
	local n = 0;
	for k,v in pairs(ignoredHolidays) do 
		if (ignoredHolidays[k]) then
			n = n + 1;
		end
	end
	
	return n;
end

function holidayReminder()
	weekday, todayMonth, todayDay, todayYear = CalendarGetDate();
	serverHour, serverMinute = GetGameTime();
	
	for i=1,CalendarGetNumDayEvents(0, todayDay) do
		local event = C_Calendar.GetDayEvent(0, todayDay, i);
		local numDays = 1;
				
		local endDay = event.endTime.monthDay;
		local endMonth = event.endTime.month;
		local endYear = event.endTime.year;

		local title = event.title;
		local sequenceType = event.sequenceType;
		local holidayHourStart = event.startTime.hour;
		local holidayHourEnd = event.endTime.hour;
		local texture = getTexture(0, todayDay, title);
		
		if (not isIgnored(title)) then
			if (sequenceType == "START") then
				if (serverHour > holidayHourStart) then
					numDays = getDaysLeft(todayMonth, todayDay, todayYear, endMonth, endDay, endYear);
					createHolidayFrame(title, texture, numDays, "during");
				else
					numDays = getHoursUntil(serverHour, holidayHourStart);
					createHolidayFrame(title, texture, numDays, "before")
				end
			elseif (sequenceType == "END") then
				if (serverHour < holidayHourEnd) then
					local numHours = getHoursLeft(serverHour, holidayHourEnd);
					createHolidayFrame(title, texture, numHours, "lastDay");
				end
			elseif (sequenceType == "ONGOING") then
				numDays = getDaysLeft(todayMonth, todayDay, todayYear, endMonth, endDay, endYear);
				createHolidayFrame(title, texture, numDays, "during");
			elseif (sequenceType == "") then
				if (serverHour < holidayHourEnd and serverHour > holidayHourStart) then
					local numHours = getHoursLeft(serverHour, holidayHourEnd);
					createHolidayFrame(title, texture, numHours, "lastDay");
				elseif (serverHour < holidayHourStart) then
					local numHours = getHoursUntil(serverHour, holidayStartHour);
					createHolidayFrame(title, texture, numHours, "before");
				end
			end
		end
	end
end

function createHolidayFrame(title, texture, num, isLastDay)
	local Toast = LibStub("LibToast-1.0")
	
	Toast:Register("HolidayReminder", function(toast, title, texture, num)
		toast:SetTitle("Holiday Reminder");
		
		if (isLastDay == "during") then
			if (num > 1) then
				toast:SetText(title..":|n     "..num.." days left");
			else
				toast:SetText(title..":|n     "..num.." day left")
			end
		elseif (isLastDay == "lastDay") then
			if (num > 1) then
				toast:SetText(title..":|n     "..num.." hours left");
			else
				toast:SetText(title..":|n     "..num.." hour left");
			end
		else
			if (num > 1) then
				toast:SetText(title..":|n     starting in "..num.." hours");
			else
				toast:SetText(title..":|n     starting in "..num.." hour");
			end
		end
		
		toast:SetIconTexture(texture);

		if (not ignoredHolidays["togglefade"]) then
			toast:MakePersistent();
		end
	end)
	
	Toast:Spawn("HolidayReminder", title, texture, num)
end

function getDaysLeft(todayMonth, todayDay, todayYear, endMonth, endDay, endYear)
	local numDays = 0;
	
	local today = time{day=todayDay, year=todayYear, month=todayMonth};
	local endDay = time{day=endDay, year="20"..endYear, month=endMonth};
		
	numDays = math.floor(difftime(endDay, today) / (24 * 60 * 60));
	--test	
	return numDays + 1;
end

function getHoursLeft(serverHour, holidayEndHour)
	local numHours = 0;
	
	numHours = holidayEndHour - serverHour;
	
	return numHours;
end

function getHoursUntil(serverHour, holidayStartHour)
	local numHours = 0;
	
	numHours = holidayStartHour - serverHour;
	
	return numHours;
end

function getTexture(month, day, title)
	local texture = nil;
	
	for i=1,CalendarGetNumDayEvents(month, day) do
		local event = C_Calendar.GetDayEvent(month, day, i);
		
		if (event.title == title) then
			if (event.sequenceType == "START" or event.sequenceType == "") then
				texture = event.iconTexture;
			else
				if (day > 1) then
					texture = getTexture(month, day - 1, title);
				else
					texture = getTexture(month - 1, 31, title);
				end
			end
		end
	end
	
	-- HC SVNT DRACONES
	if (texture == nil) then
		texture = getTexture(month, day - 1, title);
	end
	
	return texture;
end

function isIgnored(title)
	title = string.lower(title);
	
	if (ignoredHolidays[title]) then
		return true;
	end
	
	return false;
end

function printIgnored()
	for k,v in pairs(ignoredHolidays) do 
		if (ignoredHolidays[k] and k ~= "togglefade") then
			print(k.." is ignored"); 
		end
	end
end