-- This script makes Might and Magic 6/7/8's program name localizable

-- Create a `ProgramName.txt` plain text file, the only content of this text file is the localized or changed program name,
-- the text file should be saved in your local encoding, put `ProgramName.txt` file into the /Data/ folder.

-- WARNING:
-- MM8 (or MMMerge) and MM7 have a max limit of 23 characters (23 single-byte characters or 11.5 double-byte characters)
-- MM6 (or MMMerge) has a max limit of 19 characters (19 single-byte characters or 9.5 double-byte characters)


local mmver = offsets.MMVersion
local function mmv(...)
	return select(mmver - 5, ...)
end

local function getIniValueByKey(iniContent, key) -- returns nil if can't find the key
	return string.match("\n" .. iniContent .. "\n", "\n" .. key .. "=([^\n]*)\n")
	-- = ; and other special char do not need escape in ini
end

local fs = io.open("Data/LocalizeConf.ini", "r")
if fs then
	local iniContent = fs:read("*all")
	fs:close()
	local ProgramName = getIniValueByKey(iniContent, "program_name")
	if ProgramName then
		ProgramName = string.sub(ProgramName, 1, mmv(19, 23, 23))
		mem.copy(mmv(0x4C083C, 0x4E9FCC, 0x4F9D28), ProgramName .. "\0")
	end
end
