-- Double-byte character set (DBCS) support for Might and Magic 6/7/8 GrayFace Patch
-- Use convert_dbcs_special.py to transform DBCS text files to "special" text files first
-- Then put FNT_DBCS.lua into \Scripts\General in GrayFace Patched MM6/7/8 with MMExtension (or MMMerge)
-- By Tom CHEN <tomchen.org>, MIT/Expat License



-- ============ SETTINGS START ============

-- font setting
-- "Size" means height here. One font have one height for all glyphs.
-- Your DBCS font files should be renamed as "DBCS_[Size]_[highByteHexNumber].fnt", e.g. DBCS_16_CA.fnt
-- Your special DBCS font files should be renamed as "DBCS_[Size][Tag]_[highByteHexNumber].fnt", e.g. DBCS_15b_E8.fnt
-- Your "normal" DBCS font should usually use "shadow" styled glyph shapes;
--   you should also define a "black" styled special DBCS font to be Autonote.fnt's DBCS version
-- Use fntgen.py to generate DBCS .fnt files
-- You can't use two different fonts with the same size
-- If original font is big enough (>= your font size) to use your font of a larger size,
--   then it'll use it, otherwise it'll try to use a smaller one in your font list
-- Original fonts (.fnt) 's sizes vary from 14 to 30, therefore,
--   your smallest font must be smaller than or equal to 14 (otherwise it'll throw errors),
--   your biggest font should be smaller than or equal to 30 (otherwise your large fonts will be useless)
-- Write your font sizes (heights) here
local fontSizes = {13, 16, 29}

-- special font can be one of Lucida, Smallnum, Arrus, Create, Comic, Book, Book2, Cchar, Autonote, Spell
local specialFonts = {
	Autonote = {15, "b"} -- {sizeNumber, "tag"}
}

-- ============ SETTINGS END ============



-- ============ GET SETTINGS FROM INI START ============

-- globalEncoding Can be set to "gb2312", "big5", "gbk", "euc_jp" and "euc_kr"
-- if globalEncoding is nil, then switch the script off
local globalEncoding

local function getIniValueByKey(iniContent, key) -- returns nil if can't find the key
	return string.match("\n" .. iniContent .. "\n", "\n" .. key .. "=([^\n]*)\n")
	-- = ; and other special char do not need escape in ini
end

local fs = io.open("Data/LocalizeConf.ini", "r")
if fs then
	local iniContent = fs:read("*all")
	fs:close()
	globalEncoding = getIniValueByKey(iniContent, "encoding")
end

-- ============ GET SETTINGS FROM INI END ============



-- ============ VARIABLES START ============

local encodingRegex = {
	gb2312 = "[\161-\169\176-\247][\160-\255]",
	big5 = "[\161-\199\201-\249][\64-\127\160-\255]",
	gbk = "[\129-\254][\64-\255]",
	euc_jp = "[\161-\168\173\176-\244][\160-\255]",
	euc_kr = "[\161-\172\176-\200\202-\253][\160-\255]"
}

local dbcsMode = false
local cachedSpaceWidth = {} -- {fontAddr = spaceWidth} table
local cachedCharShape = {} -- {fontAddr = charShape} table
local highByte = 0
local lowByte = 0
local lastByte = 0
local dbcsFnts = {}
local cachedWidth
local cachedSpaceBefore
local cachedSpaceAfter

local mmver = offsets.MMVersion

local function mmv(...)
	return select(mmver - 5, ...)
end

-- ============ VARIABLES END ============



-- FNT and DBCS libraries are global (public)
FNT = {}
DBCS = {}

-- ============ FNT library START ============

function FNT.getHeight(fontAddr)
	return mem.i2[fontAddr + 5]
end

function FNT.getCharWidth(fontAddr, charCode)
	return mem.i4[fontAddr + 36 + 12 * charCode]
end

function FNT.getCharSpaceBefore(fontAddr, charCode)
	return mem.i4[fontAddr + 32 + 12 * charCode]
end

function FNT.getCharSpaceAfter(fontAddr, charCode)
	return mem.i4[fontAddr + 40 + 12 * charCode]
end

function FNT.getCharStartingAddr(fontAddr, charCode)
	return mem.i4[fontAddr + 3104 + 4 * charCode] + 4128 + fontAddr
end

function FNT.getCharShape(fontAddr, charCode)
	return mem.string(
		FNT.getCharStartingAddr(fontAddr, charCode),
		FNT.getHeight(fontAddr) * FNT.getCharWidth(fontAddr, charCode),
		true
	)
end

function FNT.setHeight(fontAddr, value)
	mem.i2[fontAddr + 5] = value
end

function FNT.setCharWidth(fontAddr, charCode, value)
	mem.i4[fontAddr + 36 + 12 * charCode] = value
end

function FNT.setCharSpaceBefore(fontAddr, charCode, value)
	mem.i4[fontAddr + 32 + 12 * charCode] = value
end

function FNT.setCharSpaceAfter(fontAddr, charCode, value)
	mem.i4[fontAddr + 40 + 12 * charCode] = value
end

function FNT.setCharStartingAddr(fontAddr, charCode, value)
	mem.i4[fontAddr + 3104 + 4 * charCode] = value - 4128 - fontAddr
end

function FNT.setCharShape(fontAddr, charCode, shapeString)
	mem.copy(FNT.getCharStartingAddr(fontAddr, charCode), shapeString)
end

-- ============ FNT library END ============



-- ============ DBCS library START ============

function DBCS.loadDbcsFnt(heightAndDecoStr, highByte)
	local dbFntAddr
	if dbcsFnts[heightAndDecoStr] == nil then
		dbcsFnts[heightAndDecoStr] = {}
	end
	if dbcsFnts[heightAndDecoStr][highByte] == nil then
		dbFntAddr = Game.LoadDataFileFromLod("DBCS_" .. heightAndDecoStr .. "_" .. string.format("%02X", highByte) .. ".fnt")
		dbcsFnts[heightAndDecoStr][highByte] = dbFntAddr
	else
		dbFntAddr = dbcsFnts[heightAndDecoStr][highByte]
	end
	return dbFntAddr
end

-- get information of the DBCS equivalent font to use
function DBCS.getReplFontInfo(fontAddr)
	local origFontHeight = FNT.getHeight(fontAddr)
	for sFontName, sFont in pairs(specialFonts) do
		if Game[sFontName .. "_fnt"] == fontAddr then
			return {
				height = sFont[1],
				deco = sFont[2],
				origHeight = origFontHeight
			}
		end
	end
	if origFontHeight < fontSizes[1] then
		error("You must have a DBCS font with a size smaller than or equal to " .. tostring(origFontHeight))
	else
		for i = 2, #fontSizes do
			if origFontHeight < fontSizes[i] then
				return {
					height = fontSizes[i-1],
					deco = "",
					origHeight = origFontHeight
				}
			end
		end
		return {
			height = fontSizes[#fontSizes],
			deco = "",
			origHeight = origFontHeight
		}
	end
end

function DBCS.validateHighByte(encoding, highByte)
	if encoding == nil then
		return highByte >= 161 and highByte <= 255
	elseif encoding == "gb2312" then
		return (highByte >= 161 and highByte <= 169) or (highByte >= 176 and highByte <= 247)
	elseif encoding == "big5" then
		return (highByte >= 161 and highByte <= 199) or (highByte >= 201 and highByte <= 249)
	elseif encoding == "gbk" then
		return highByte >= 129 and highByte <= 254
	elseif encoding == "euc_jp" then
		return (highByte >= 161 and highByte <= 168) or highByte == 173 or (highByte >= 176 and highByte <= 244)
	elseif encoding == "euc_kr" then
		return (highByte >= 161 and highByte <= 172) or (highByte >= 176 and highByte <= 200) or (highByte >= 202 and highByte <= 253)
	end
end

function DBCS.encodeSpecial(str, encoding)
	local reg = encodingRegex[encoding]
	str = string.gsub(str, "(" .. reg .. ")", "\14\32\14%1\7\15")
	str = string.gsub(str, "\15\14", "")
	return str
end

function DBCS.decodeSpecial(str)
	str = string.gsub(str, "\32\14(..)\7", "%1")
	str = string.gsub(str, "\14([^\15]+)\15", "%1")
	return str
end

function DBCS.setPlayerName(number, str)
	Party[number - 1].Name = DBCS.encodeSpecial(str, globalEncoding)
end



-- ============ DBCS library END ============



local testCharOrigBegin = mmv(
	mem.asmproc([[
		cmp cl, dl
		jb absolute 0x44305C
		cmp cl, [ebp+1]
		jbe absolute 0x443074
		jmp absolute 0x44305C
	]]),
	mem.asmproc([[
		cmp cl, [edx]
		jb absolute 0x44C513
		cmp cl, [edx+1]
		jbe absolute 0x44C52A
		jmp absolute 0x44C513
	]]),
	mem.asmproc([[
		cmp cl, [edx]
		jb absolute 0x449C44
		cmp cl, [edx+1]
		jbe absolute 0x449C5B
		jmp absolute 0x449C44
	]])
)


local function dbcsProc(d)

	local fntAddrTemp
	local fontInfoToUse
	local fontHeightAndDeco
	local fontHeightDiff
	local fontTopHeightToAdd
	local fontBottomHeightToAdd
	local widthTemp

	local byte = d.cl
	local fontAddr = mmv(d.ebp, d.edx, d.edx)
	local counterByte = d.ebx

	local function switchOnDbcsMode()
		if cachedSpaceWidth[fontAddr] == nil then
			cachedSpaceWidth[fontAddr] = FNT.getCharWidth(fontAddr, 32)
		end
		FNT.setCharWidth(fontAddr, 32, 0)
		if cachedCharShape[fontAddr] == nil then
			-- cache cachedCharShape,
			-- assume glyph's width < height * 2,
			-- assume height * 2 < total width of printable chars (0-9 A-Z a-z etc)
			-- so cachedCharShape data won't go out of fnt area
			cachedCharShape[fontAddr] = mem.string(
				FNT.getCharStartingAddr(fontAddr, 7),
				FNT.getHeight(fontAddr)^2 * 2,
				true
			)
		end
		dbcsMode = true
	end

	local function switchOffDbcsMode() -- restore space and cachedCharShape
		if cachedSpaceWidth[fontAddr] ~= nil and cachedSpaceWidth[fontAddr] ~= 0 then
			FNT.setCharWidth(fontAddr, 32, cachedSpaceWidth[fontAddr])
		end
		if cachedCharShape[fontAddr] ~= nil then
			FNT.setCharShape(fontAddr, 7, cachedCharShape[fontAddr])
		end
		highByte = 0
		dbcsMode = false
	end

	local function emptyAndCacheCurrentByteInFont()
		cachedSpaceBefore = FNT.getCharSpaceBefore(fontAddr, byte)
		cachedSpaceAfter = FNT.getCharSpaceAfter(fontAddr, byte)
		cachedWidth = FNT.getCharWidth(fontAddr, byte)
		FNT.setCharSpaceBefore(fontAddr, byte, 0)
		FNT.setCharSpaceAfter(fontAddr, byte, 0)
		FNT.setCharWidth(fontAddr, byte, 0)
	end

	local function setHighByteInFontAsCached()
		FNT.setCharSpaceBefore(fontAddr, highByte, cachedSpaceBefore)
		FNT.setCharSpaceAfter(fontAddr, highByte, cachedSpaceAfter)
		FNT.setCharWidth(fontAddr, highByte, cachedWidth)
	end

	local function lastByteCheckAndCache(currentByte)
		-- lastByte could be:
		-- 0: initial state
		-- 14: [SO]
		-- 32: SP
		-- 10: LF
		-- 7: BEL
		-- 301: high byte
		-- 300: low byte
		local ret = true
		if currentByte == 301 and lastByte ~= 14 or -- high byte but last byte is not [SO]
		currentByte == 300 and lastByte ~= 301 then -- low byte but last byte is not high byte
			lastByteCheckAndCache(0)
			switchOffDbcsMode()
			ret = false
		end
		lastByte = currentByte
		return ret
	end

-- Double-byte characters
-- BD A4 BD A5
-- have been converted to
-- [SO] [SP] [SO] BD A4 [BEL] [SP] [SO] BD A5 [BEL] [SI]
-- before using the script

	if byte == 14 and lastByteCheckAndCache(byte) then -- [SO]
		if dbcsMode == false then
			switchOnDbcsMode()
		end
	elseif dbcsMode == true then
		if byte == 15 and lastByteCheckAndCache(0) then -- [SI]
			switchOffDbcsMode()
		elseif byte == 32 and lastByteCheckAndCache(byte) then -- SP
		elseif byte == 10 and lastByteCheckAndCache(byte) then -- LF
		elseif byte == 7 and lastByteCheckAndCache(byte) then -- [BEL]
			fontInfoToUse = DBCS.getReplFontInfo(fontAddr)
			fontHeightDiff = fontInfoToUse.origHeight - fontInfoToUse.height
			if fontHeightDiff % 2 == 0 then
				fontTopHeightToAdd = fontHeightDiff / 2
				fontBottomHeightToAdd = fontHeightDiff / 2
			else
				fontTopHeightToAdd = math.floor(fontHeightDiff / 2)
				fontBottomHeightToAdd = math.ceil(fontHeightDiff / 2)
			end
			fntAddrTemp = DBCS.loadDbcsFnt(tostring(fontInfoToUse.height) .. fontInfoToUse.deco, highByte)
			widthTemp = FNT.getCharWidth(fntAddrTemp, lowByte)
			FNT.setCharWidth(fontAddr, 7,
				widthTemp)
			FNT.setCharSpaceBefore(fontAddr, 7,
				FNT.getCharSpaceBefore(fntAddrTemp, lowByte))
			FNT.setCharSpaceAfter(fontAddr, 7,
				FNT.getCharSpaceAfter(fntAddrTemp, lowByte))
			FNT.setCharShape(fontAddr, 7,
				string.rep("\0", (fontTopHeightToAdd * widthTemp)) ..
				FNT.getCharShape(fntAddrTemp, lowByte) ..
				string.rep("\0", (fontBottomHeightToAdd * widthTemp))
			)
			setHighByteInFontAsCached()
			highByte = 0
			-- lowByte = 0
			-- cachedSpaceBefore = 0
			-- cachedSpaceAfter = 0
			-- cachedWidth = 0
		elseif highByte == 0 then -- high byte
			if not DBCS.validateHighByte(globalEncoding, byte) and lastByteCheckAndCache(0) then -- multiline fix
				-- (in this case, usually counterByte == 0, but exception exists)
				-- A line is likely broken into two lines, causing [SO] [SI] pair broken.
				-- Here we are at the beginning of the first line
				switchOffDbcsMode()
			elseif lastByteCheckAndCache(301) then
				emptyAndCacheCurrentByteInFont()
				highByte = byte
			end
		elseif lastByteCheckAndCache(300) then -- low byte
			setHighByteInFontAsCached()
			emptyAndCacheCurrentByteInFont()
			lowByte = byte
		end
	end

end


if globalEncoding == "gb2312" or
	globalEncoding == "big5" or
	globalEncoding == "gbk" or
	globalEncoding == "euc_jp" or
	globalEncoding == "euc_kr" then
		mem.hook(testCharOrigBegin, dbcsProc)
		mem.asmpatch(mmv(0x443053, 0x44C50A, 0x449C3B), "jmp absolute " .. testCharOrigBegin, mmv(9, 9, 9))
end
