local i4, i2, i1, u4, u2, u1, pchar = mem.i4, mem.i2, mem.i1, mem.u4, mem.u2, mem.u1, mem.pchar
local mmver = offsets.MMVersion

local function mmv(...)
	local ret = select(mmver - 5, ...)
	assert(ret ~= nil)
	return ret
end

function shot()
	local t = os.date("!*t")
	local s = ("%d_%.2d_%.2d %.2dh%.2dm%.2ds"):format(t.year, t.month, t.day, t.hour, t.min, t.sec)
	while path.FindFirst(s) do
		s = s.."0"
	end
	Game.Dll.SaveBufferToBitmap(("%s/Screenshots/%s.bmp"):format(AppPath, s), u4[mmv(0x9B108C, 0xE31B54, 0xF01A6C)], 640, 480, 16)
end

Keys[const.Keys.SNAPSHOT] = shot