local FunctionFile = debug.FunctionFile

local _KNOWNGLOBALS_F = Game, Party, Map, Keys, keys

local timeGetTime_add = 0
local timeGetTime_last = 0
function timeGetTime()
	local ret = mem.call(internal.timeGetTime, 0)
	if ret < timeGetTime_last then
		timeGetTime_add = timeGetTime_add + 4294967296
	end
	timeGetTime_last = ret
	return ret + timeGetTime_add
end

local LastTick
local timers -- function, period, start, next_time
local sleeps -- coroutine, wake time, realtime wake time, screens
local CurTimer, CurTotal = 0, 0

local function NextExact(time, period, LastTick)
	local cur = Game.Time
	if cur - time < period then
		return time + period
	end
	return cur - (cur - time) % period + period
end

local function NextPeriod(time, period, LastTick)
	return Game.Time + period
end

-- f = function (TriggerTime, Period, LastTick, Tick):
--   Called when the timer is triggered.
-- Period is 1 minute if not specified.
-- Possible 'start' values:
--   false, nil:  Fires first time after 'period' since called.
--   true:  Fires first time at the next tick after the call.
--   number: The time of start.
-- Possible 'exact' values:
--   false:  re-fires after 'period' passes since last invocation (this is default if 'start' is not a number).
--   true:  fires whenever (start + period*N) line is crossed (this is default if 'start' is a number).
--   function (TriggerTime, Period, LastTick, Tick):  returns next trigger time when called.
-- Note that the timer remembers last time you were in the location, so for example,
-- an exact weekly timer would fire right away if you haven't visited the map for a week.
function Timer(f, period, start, exact)
	period = period or 256
	if exact == nil then
		exact = (start and start ~= true)
	end
	if exact == true then
		exact = NextExact
	elseif not exact then
		exact = NextPeriod
	end
	
	if start == true then
		start = Game.Time
	elseif start and start <= Game.Time and start <= LastTick then
		start = exact(start, period, LastTick)
	end
	timers[#timers+1] = {f, period, start or Game.Time + period, exact} -- Game.Map.LastRefillDay*0x5A000})
end


local function NextRefillStd(time, period, LastTick)
	return math.max(Game.Time, time + period)
end

local function GetRefills()
	local s = Map.Name
	local sgd = internal.SaveGameData
	sgd.TimerPassed = sgd.TimerPassed or {}
	local t = sgd.TimerPassed[s] or {}
	sgd.TimerPassed[s] = t
	return t
end

local function NextRefill(time, period, LastTick)
	time = Game.Time + period
	GetRefills()[period] = time
	return time
end

-- f = function (TriggerTime, Period, LastTick, Tick):
--   Called when the timer is triggered.
-- Period is 1 minute if not specified.
-- std = true mode:
-- Acts exactly like standard refill timers used with wells etc.
-- If 'period' has passed since last visit or map is refilled, triggers right away.
-- Otherwise, triggers at Game.Time + period.
-- So, if you visit the location before the refill period passes, you effectively reset refill timeout.
--
-- std = false mode (default):
-- Doesn't reset refill timeout.
function RefillTimer(f, period, std)
	if std then
		Timer(f, period, Game.Time - LastTick >= period or Map.Refilled and true, NextRefillStd)
	else
		local t = GetRefills()
		t[period] = not Map.Refilled and t[period] or Game.Time
		Timer(f, period, t[period], NextRefill)
	end
end

function Sleep(time, realtime, screens)
	local c = coroutine.running()
	if c then
		if realtime then
			realtime = timeGetTime() + time  -- 7.8125 = 1 / 0.128
			time = 0
		else
			time = Game.Time + time
			realtime = 0
		end
		screens = table.invert(screens or {0, Game.CurrentScreen})
		table.insert(sleeps, {c, time, realtime, screens})--, FunctionFile(2)})
		return coroutine.yield(c)
	elseif realtime then
		mem.dll.kernel32.Sleep(time)
	end
end


function RemoveTimer(f)
	for i = 1, #timers do
		if timers[i][1] == f then
			table.remove(timers, i)
			CurTotal = CurTotal - 1
			if CurTimer >= i then
				CurTimer = CurTimer - 1
			end				
			return
		end
	end
end

function internal.StartTimers()
	timers = {}
	sleeps = sleeps or {}
	local s = Map.Name
	local sgd = internal.SaveGameData
	sgd.TimerTick = sgd.TimerTick or {}
	LastTick = sgd.TimerTick[s] or -1
	if Map.Refilled and sgd.TimerPassed then
		sgd.TimerPassed[s] = nil
	end
end

function internal.TimersSaveGame()
	internal.SaveGameData.TimerTick[Map.Name] = LastTick
end

function internal.TimersLeaveMap(t)
	timers = {}
	sleeps = {}
	internal.TimersSaveGame()
end

function internal.TimersLeaveGame()
	timers = nil
	sleeps = nil
end

--------- keys

keys = keys or {}
Keys = Keys or {}

--!(key:const.Keys)
function Keys.IsPressed(key)
	return mem.call(internal.GetKeyState, 0, assertnum(key, 2)):And(0x8000) ~= 0
end

--!(key:const.Keys)
function Keys.IsToggled(key)
	return mem.call(internal.GetKeyState, 0, assertnum(key, 2)):And(1) ~= 0
end

local _, keyHandlers = events.new(Keys)
local pressedKeys = {}

--------- OnTick

local function CallTimers(tick, last)
	CurTimer, CurTotal = 1, #timers
	while CurTimer <= CurTotal do
		local v = timers[CurTimer]
		if tick >= v[3] then
			local period, time, next_time = v[2], v[3], v[4]
			coroutine.resume2(coroutine.create(v[1]), time, period, last, tick)
			if timers[CurTimer] == v then
				v[3] = next_time(time, period, last)
				if not v[3] then
					table.remove(timers, CurTimer)
					CurTimer = CurTimer - 1
				end
			end
		end
		CurTimer = CurTimer + 1
	end
end

function internal.OnTimer()
	local tick = Game.Time
	if sleeps then
		local rtick = timeGetTime()
		local screen = Game.CurrentScreen
		for i = #sleeps, 1, -1 do
			local v = sleeps[i]
			if tick >= v[2] and rtick >= v[3] and (v[4][screen] or v[4].All or v[4].all) then
				table.remove(sleeps, i)
				coroutine.resume2(v[1], true)
			end
		end
	end
	if tick ~= LastTick and not Game.Paused and not Game.MoveToMap.Defined and timers then
		CallTimers(tick, LastTick)
		LastTick = tick
	end
	events.cocalls("Tick")
	for k, _ in pairs(keyHandlers) do
		if type(k) == "number" and k > 0 and k <= 255 then
			local wasPressed = pressedKeys[k]
			local pressed = Keys.IsPressed(k)
			pressedKeys[k] = pressed
			if pressed and not wasPressed then
				Keys[k]()
			end
		end
	end
	if internal.OnWaitMessage then
		internal.OnWaitMessage()
	end
end
