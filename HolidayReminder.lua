ignoredHolidays = {};

local frame = CreateFrame("FRAME", "");
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("VARIABLES_LOADED");
frame:RegisterEvent("PLAYER_STARTED_MOVING");

if (not IsAddOnLoaded("Blizzard_Calendar")) then
		UIParentLoadAddOn("Blizzard_Calendar");
end

local function eventHandler(self, event, ...)
	if (event == "VARIABLES_LOADED") then
		ignoredHolidays = ignoredHolidays;
	end
	if (event == "PLAYER_STARTED_MOVING") then
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
	frame:UnregisterEvent("PLAYER_STARTED_MOVING");
	
	local dateTime = C_DateAndTime.GetCurrentCalendarTime()
	
	monthDay = dateTime.monthDay;
	weekDay = dateTime.weekDay;
	month = dateTime.month;
	minute = dateTime.minute;
	hour = dateTime.hour;
	year = dateTime.year;
	
	for i=1,C_Calendar.GetNumDayEvents(0, monthDay) do
		local event = C_Calendar.GetDayEvent(0, monthDay, i);
		local numDays = 1;
				
		local endDay = event.endTime.monthDay;
		local endMonth = event.endTime.month;
		local endYear = event.endTime.year;
		
		local startDay = event.startTime,monthDay;
		local startMonth = event.startTime.month;
		local startYear = event.startTime.year;

		local title = event.title;
		local sequenceType = event.sequenceType;
		local holidayHourStart = event.startTime.hour;
		local holidayHourEnd = event.endTime.hour;
		
		local texture = getTexture(0, monthDay, title);
		
		if (not isIgnored(title)) then
			if (sequenceType == "START") then
				if (hour > holidayHourStart) then
					numDays = getDaysLeft(month, monthDay, year, endMonth, endDay, endYear);
					createHolidayFrame(title, texture, numDays, "during");
				else
					numDays = getHoursUntil(hour, holidayHourStart);
					createHolidayFrame(title, texture, numDays, "before")
				end
			elseif (sequenceType == "END") then
				if (hour < holidayHourEnd) then
					local numHours = getHoursLeft(hour, holidayHourEnd);
					createHolidayFrame(title, texture, numHours, "lastDay");
				end
			elseif (sequenceType == "ONGOING") then
				numDays = getDaysLeft(month, monthDay, year, endMonth, endDay, endYear);
				createHolidayFrame(title, texture, numDays, "during");
			elseif (sequenceType == "") then
				if (hour < holidayHourEnd and hour > holidayHourStart) then
					local numHours = getHoursLeft(hour, holidayHourEnd);
					createHolidayFrame(title, texture, numHours, "lastDay");
				elseif (hour < holidayHourStart) then
					local numHours = getHoursUntil(hour, holidayHourStart);
					createHolidayFrame(title, texture, numHours, "before");
				end
			end
		end
	end
end

function createHolidayFrame(title, texture, num, isLastDay)
	local Toast = LibStub("LibToast-1.0")
	
	Toast:Register("HolidayReminder", function(toast, title, texture, num)
		toast:SetTitle(title);
		
		if (isLastDay == "during") then
			if (num > 1) then
				toast:SetText(num.." days left");
			else
				toast:SetText(num.." day left")
			end
		elseif (isLastDay == "lastDay") then
			if (num > 1) then
				toast:SetText(num.." hours left");
			else
				toast:SetText(num.." hour left");
			end
		elseif (isLastDay == "before") then
			if (num > 1) then
				toast:SetText("Starting in "..num.." hours");
			else
				toast:SetText("Starting in "..num.." hour");
			end
		end
		
		toast:SetIconTexture(texture);

		if (not ignoredHolidays["togglefade"]) then
			toast:MakePersistent();
		end
	end)
	
	Toast:Spawn("HolidayReminder", title, texture, num)
end

function getDaysLeft(month, monthDay, year, endMonth, endDay, endYear)
	local numDays = 0;
	
	local today = time{day=monthDay, year=year, month=month};
	local lastDay = time{day=endDay, year=endYear, month=endMonth};
		
	numDays = math.floor(difftime(lastDay, today) / (24 * 60 * 60));

	return numDays + 1;
end

function getHoursLeft(hour, holidayEndHour)
	local numHours = 0;
	
	numHours = holidayEndHour - hour;
	
	return numHours;
end

function getHoursUntil(hour, holidayStartHour)
	local numHours = 0;
	
	numHours = holidayStartHour - hour;
	
	return numHours;
end

function getTexture(month, day, title)
	local texture = nil;
		
	for i=1,C_Calendar.GetNumDayEvents(month, day) do
		local event = C_Calendar.GetDayEvent(month, day, i);
		
		if (event.title == title) then
			if (event.sequenceType == "START" or event.sequenceType == "") then
				if (event.iconTexture == nil) then
					return nil;
				else
					texture = event.iconTexture;
				end
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
