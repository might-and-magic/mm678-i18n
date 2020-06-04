local type = type
local unpack = unpack
local error = error
local assert = assert
local format = string.format
local string_byte = string.byte
local string_sub = string.sub
local string_gsub = string.gsub
local string_find = string.find

local next = next
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local rawget = rawget
local rawset = rawset
local getfenv = getfenv
local setfenv = setfenv
local pcall = pcall
local xpcall = xpcall
local pcall2
local os_time = os.time
local loadfile = loadfile
local loadstring = loadstring
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local table_sort = table.sort
local math_min = math.min
local math_floor = math.floor
local math_ceil = math.ceil
local abs = math.abs
local co_yield = coroutine.yield
local co_running = coroutine.running
local io_open = io.open
local select = select
local getmetatable = debug.getmetatable
local d_setmetatable = debug.setmetatable
local debug_getinfo = debug.getinfo
local debug_getupvalue = debug.getupvalue
local debug_getlocal = debug.getlocal

local _KNOWNGLOBALS_F = nil, path

--------- table

local function table_swap(t, min, max)
	min = min or 1
	max = max or #t
	for i = 1, (max - min + 1):div(2) do
		t[min], t[max] = t[max], t[min]
		min, max = min + 1, max + 1
	end
end
table.swap = table_swap

local function table_move(t, from, to)
	local it = t[from]
	if from < to then
		for i = from, to - 1 do
			t[i] = t[i+1]
		end
	elseif from > to then
		for i = from, to + 1, -1 do
			t[i] = t[i-1]
		end
	end
	t[to] = it
end
table.move = table_move

function table.copy(src, dest, overwrite)
	if not dest or overwrite then
		dest = dest or {}
		for k,v in pairs(src) do
			dest[k] = v
		end
	else
		for k,v in pairs(src) do
			if dest[k] == nil then
				dest[k] = v
			end
		end
	end
	return dest
end

function table.find(t, v0)
	for k, v in pairs(t) do
		if v == v0 then
			return k
		end
	end
end

function table.ifind(t, v0)
	local k = 1
	local v = rawget(t, k)
	while v ~= nil do
		if v == v0 then
			return k
		end
		k = k + 1
		v = rawget(t, k)
	end
end

function table.invert(t, out)
	local out = out or {}
	for k, v in pairs(t) do
		out[v] = k
	end
	return out
end

--------- coroutine

function coroutine.yieldN(n, ...)
	if n >= 1 then
		for i = 2, n do
			co_yield(...)
		end
		return co_yield(...)
	end
end

--------- path

path = {}

local string_match = string.match

function path.ext(s)
	return string_match(s, "%.[^%.\\/:]*$") or ""
end
path.Ext = path.ext

function path.setext(s, ext)
	return (string_match(s, "(.*)%.[^%.\\/:]*$") or s)..ext
end
path.SetExt = path.setext

function path.name(s)
	return string_match(s, "[^\\/:]*$")
end
path.Name = path.name

function path.dir(s)
	return string_match(s, "(.*[\\/:]).-$") or ""
end
path.Dir = path.dir


local slash1, slash2 = string_byte('/', 1), string_byte('\\', 1)

function path.addslash(s)
	local c = string_byte(s, #s)
	if c == slash1 or c == slash2 then
		return s
	end
	return s.."/"
end
path.AddSlash = path.addslash

function path.noslash(s)
	local c = string_byte(s, #s)
	if c == slash1 or c == slash2 then
		return string_sub(s, 1, -2)
	end
	return s
end
path.NoSlash = path.noslash

--------- io

function io.SaveString(path, s, translate)
	local f = assert(io_open(path, translate and "wt" or "wb"))
	f:setvbuf("no")
	f:write(s)
	f:close()
end

function io.LoadString(path, translate)
	local f = assert(io_open(path, translate and "rt" or "rb"))
	local s = f:read("*a")
	f:close()
	return s
end

function PrintToFile(fname)

	local opened
	
	local function print1(t, n, arg, ...)
		if n ~= 0 then
			t[#t + 1] = tostring(arg)
			if n ~= 1 then
				t[#t + 1] = "\t"
				return print1(t, n - 1, ...)
			end
		end
	end
	
	function print(...)
		local f = io_open(fname, opened and "at" or "wt")
		opened = true
		local t = {}
		print1(t, select('#', ...), ...)
		t[#t + 1] = "\n"
		f:write(table_concat(t))
		f:close()
	end
	
	return function()
		return opened, fname
	end
end

-- string

function string.split(str, delim, plain)
	local t, i, n = {}, 1, 1
	repeat
		local n1, n2 = string_find(str, delim, n, plain)
		t[i] = string_sub(str, n, n1 and n1 - 1)
		n, i = n2 and n2 + 1, i + 1
	until n == n1
	return t
end

do
	local string_split = string.split
	local compiled = {}

	function string.csplit(str, charlist)
		local d = charlist or " "
		local delim = compiled[d]
		if delim == nil then
			delim = format("[%s]", string_gsub(d, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
			compiled[d] = delim
		end
		return string_split(str, delim)
	end
end

function string.replace(str, old, new)
	old = string_gsub(old, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	new = string_gsub(new, "%%", "%%%%")
	return string_gsub(str, old, new)
end

-- sortpairs

do
	local types = {
		number = 1,
		boolean = 2,
		string = 3,
		userdata = 4,
		table = 5,
		["function"] = 6,
		thread = 7,
	}

	local function rawcompare(a, b)
		return a < b
	end

	local function compare(a, b)
		local t1, t2 = type(a), type(b)
		if t1 ~= t2 then
			return types[t1] < types[t2]
		elseif t1 == "number" or t1 == "string" then
			return a < b
		else
			local ok, ret = pcall(rawcompare, a, b)
			if ok then
				return ret
			else
				return tostring(a) < tostring(b)
			end
		end
	end

	function sortpairs(t)
		local order = {}
		local i = 1
		for k in next, t do -- pairs(t) do
			order[i] = k
			i = i + 1
		end
		table_sort(order, compare)
		i = 0
		return function()
			i = i + 1
			local k = order[i]
			return k, rawget(t, k) -- t[k]
		end
	end
end

-- debug

local function DebugFind(Name, f, param)
  local name, val
  local up = 0
  repeat
      up = up + 1
      name, val = f(param, up)
  until name == Name or name == nil
  return name and up, val
end

function debug.findupvalue(f, name)
	return DebugFind(name, debug_getupvalue, f)
end

function debug.findlocal(thread, lev, name)
	if name then  -- 'thread' parameter specified
		if co_running() == thread then
			lev = lev + 3
		end
		local function f(thread, n)
			local n, v = debug_getlocal(thread, lev, n)
			return n, v  -- because tail calls may or may not change stack level depending on version
		end
		local n, v = DebugFind(name, f, thread)
		return n, v
	end
	local n, v = DebugFind(lev, debug_getlocal, thread + 2)
	return n, v
end
