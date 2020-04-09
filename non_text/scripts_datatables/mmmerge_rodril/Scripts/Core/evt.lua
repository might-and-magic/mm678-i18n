local i4, i2, i1, u4, u2, u1 = mem.i4, mem.i2, mem.i1, mem.u4, mem.u2, mem.u1
local mmver = offsets.MMVersion

evt = {[0] = {}, {}, {}, {}, (mmver == 8 and {} or nil), All = {}, Random = {}, Current = {}}
Evt = evt

for _, t in pairs(evt) do
	for k, v in pairs(evt) do
		t[k] = v
	end
end

local _KNOWNGLOBALS = vars, Vars, mapvars, MapVars, Game, Party, Map

local function MakeEventsTable()
	local ret = events.new()
	local m = getmetatable(ret)
	local get = m.__index
	local set = m.__newindex
	local defcall = ret.call
	function m.__index(t, a)
		if type(a) ~= "number" then
			return rawget(t, a)
		end
		local function index(_, a1)
			if type(a1) == "number" then
				return get(t, a*256 + a1)
			else
				return get(t, a*256)[a1]
			end
		end
		local function newindex(_, a1, v)
			set(t, a*256 + a1, v)
		end
		local function call(_, ...)
			return defcall(a*256, ...)
		end
		return setmetatable({}, {__index = index, __newindex = newindex, __call = call})
	end
	function m.__newindex(t, a, v)
		if type(a) ~= "number" then
			return rawset(t, a, v)
		end
		set(t, a*256, v)
	end
	return ret
end

local ResetMapStr
local ClearMapStr
local UpdateEventJustHint

local CurMapScripts = {}
local GlobalScripts = {}
local MayShow = 0  -- 0 in loading screen, 1 after the game was loaded
local WasInGame

local function OnLeaveMap()
	events.cocall("LeaveMap")
	events.RemoveFiles(CurMapScripts)
	evt.global.RemoveFiles(CurMapScripts)
	internal.TimersLeaveMap(CurMapScripts)
	CurMapScripts = {}
	internal.MonstersRestore()
	ClearMapStr()
	internal.MapName = nil
end
internal.OnLeaveMap = OnLeaveMap

local function OnLeaveGame()
	MayShow = 0
	if internal.InGame then
		events.cocall("LeaveGame")
		internal.TimersLeaveGame()
		internal.InGame = false
	end
	table.copy(CurMapScripts, GlobalScripts)
	events.RemoveFiles(GlobalScripts)
	GlobalScripts = {}
	CurMapScripts = {}
	internal.SaveGameData = nil
	ClearMapStr()
	internal.MapName = nil
end
internal.OnBeforeLoadGame = OnLeaveGame
internal.OnExitToMainMenu = OnLeaveGame

function internal.BeforeMapLoad()
	MayShow = 0
	local sgd = internal.SaveGameData or {}
	internal.SaveGameData = sgd
	sgd.Vars = sgd.Vars or {}
	sgd.Maps = sgd.Maps or {}
	--!v Variables that are stored in save game
	vars = sgd.Vars
	Vars = vars
	if mmver == 6 then
		evt.MazeInfo = nil
	end
	internal.MapName = nil  -- safeguard
	local MapName = mem.string(offsets.MapName, 20):lower()
	--!v Variables stored in a saved game that belong to current map
	mapvars = sgd.Maps[MapName] or {}
	MapVars = mapvars
	sgd.Maps[MapName] = mapvars
	WasInGame = internal.InGame
	if not WasInGame then
		internal.InGame = true
		evt.Global = MakeEventsTable()
		evt.global = evt.Global
		if mmver > 6 then
			--!v([]) [MM7+] Functions that can return true or false to change topic visibility
			evt.CanShowTopic = events.new()
		end
		for f in path.find("Scripts/Global/*.lua") do
			local chunk, err = loadfile(f)
			if chunk == nil then
				debug.ErrorMessage(err)
			else
				GlobalScripts[debug.FunctionFile(chunk)] = true
				coroutine.resume2(coroutine.create(chunk))
			end
		end
	end
	events.cocall("BeforeLoadMap", WasInGame)
end

function internal.OnLoadMap()
	local MapName = mem.string(offsets.MapName, 20):lower()
	internal.MapName = MapName  -- this is needed because my OnMapLeave works in MM6 when map name is already changed
	Map.Refilled = nil
	internal.MapRefilled = (internal.MapRefilled == 1)
	if internal.MapRefilled then
		Map.Refilled = internal.SaveGameData.Maps[MapName] or {}
		mapvars = {}
		MapVars = mapvars
		internal.SaveGameData.Maps[MapName] = mapvars
	end
	--!v([]) Event handlers
	--
	-- Event indexes convention:
	-- Indexes 20000 - 22999 are for sprite events, so that event (20000 + i) corresponds to Map.Sprites[i].
	evt.map = MakeEventsTable()
	evt.Map = evt.map
	--!v([])
	evt.hint = {}
	evt.Hint = evt.hint
	if mmver == 6 then
		--!v [MM6]
		evt.MazeInfo = nil
	end
	ResetMapStr()
	internal.StartTimers()
	internal.LoadMonsterIds()
	CurMapScripts = {}
	for f in path.find("Scripts/Maps/*."..path.SetExt(MapName, ".lua")) do
		local chunk, err = loadfile(f)
		if chunk == nil then
			debug.ErrorMessage(err)
		else
			CurMapScripts[debug.FunctionFile(chunk)] = true
			coroutine.resume2(coroutine.create(chunk))
		end
	end
	for f in path.find("Scripts/Maps/"..path.SetExt(MapName, ".lua")) do
		local chunk, err = loadfile(f)
		if chunk == nil then
			debug.ErrorMessage(err)
		else
			CurMapScripts[debug.FunctionFile(chunk)] = true
			coroutine.resume2(coroutine.create(chunk))
		end
	end
	events.cocall("LoadMap", WasInGame)
	UpdateEventJustHint()
	MayShow = 1
end

function internal.AfterLoadMap()
	events.cocall("AfterLoadMap")
end

----------- Hint, MazeInfo

local TextBuffer = internal.TextBuffer

local function GetHouseHint(id)
	if id and id < 600 then
		return Game.Houses[id].Name
	end
end

function internal.OnGetEventHint(evtId)
	local h = evt.house and (events.call("GetEventHint", evtId) or evt.hint[evtId] or GetHouseHint(evt.house[evtId]))
	if h then
		mem.copy(TextBuffer, h, #h + 1)
	end
	return h and 1 or 0
end

if mmver == 6 then
	function internal.OnGetMazeInfo()
		local h = events.call("GetMazeInfo") or evt.MazeInfo
		if h then
			mem.copy(TextBuffer, h, #h + 1)
		end
		return h and 1 or 0
	end
end

----------- UpdateEventJustHint

function UpdateEventJustHint()
	if mmver == 6 or not evt.house then
		-- do nothing
	elseif Map.IsIndoors() then
		for _, a in Map.FacetData do
			local ev = a.Event
			if ev ~= 0 and (evt.house[ev] or evt.map.exists(ev*256)) then
				Map.Facets[a.FacetIndex].IsEventJustHint = false
			elseif ev ~= 0 and evt.hint[ev] then
				Map.Facets[a.FacetIndex].IsEventJustHint = true
			end
		end
	else
		for _, a in Map.Models do
			for _, a in a.Facets do
				local ev = a.Event
				if ev ~= 0 and (evt.house[ev] or evt.map.exists(ev*256)) then
					a.IsEventJustHint = false
				elseif ev ~= 0 and evt.hint[ev] then
					a.IsEventJustHint = true
				end
			end
		end
	end
end

----------- CanShowTopic

function internal.CanShowTopic(topic, def)
	local ret = evt.CanShowTopic[topic]()
	if ret == nil then
		return def
	end
	return ret and 1 or 0
end

----------- Str

local strbuf = {}

local function str_index(t, a)
	if a >= 500 or a < 0 then
		error("evt.str index out of bounds [0..499]", 2)
	end
	return mem.string(offsets.MapStrBuf + u4[offsets.MapStrOffsets + a*4])
end

local function str_newindex(t, a, v)
	if a >= 500 or a < 0 then
		error("evt.str index out of bounds [0..499]", 2)
	end
	local buf = strbuf[a]
	if buf then
		mem.free(buf)
	end
	buf = mem.malloc(#v + 1)
	strbuf[a] = buf
	mem.copy(buf, v, #v + 1)
	u4[offsets.MapStrOffsets + a*4] = buf - offsets.MapStrBuf
end

function ClearMapStr()
	if strbuf then
		for i, v in pairs(strbuf) do
			mem.free(v)
		end
	end
	strbuf = nil
	evt.str = nil
	evt.Str = nil
	evt.house = nil
	evt.House = nil
end

function ResetMapStr()
	strbuf = {}
	--!v([])
	evt.str = setmetatable({}, {__index = str_index, __newindex = str_newindex})
	evt.Str = evt.str
	--!v([])
	evt.house = {}
	evt.House = evt.house
end

----------- AfterProcessEvent

local GlobalEventInfo, TargetObj
local AsyncProc, AsyncTrue, AsyncPlayer, AsyncCurrentPlayer, AsyncTargetObj

function internal.AfterProcessEvent(evtId, seq, globalEventInfo, targetObj, param, retseq)
	if evt.house == nil then  -- OnLoadMap wasn't executed
		return
	end
	local old1, old2, old3, old4 = GlobalEventInfo, TargetObj, evt.Player, evt.CurrentPlayer
	GlobalEventInfo, TargetObj, MayShow, evt.Player = globalEventInfo, targetObj, param, u4[offsets.CurrentPlayer] - 1
	if evt.Player < 0 then
		--!v
		evt.Player = math.random(offsets.PlayersCount) - 1
	end
	--!v
	evt.CurrentPlayer = evt.Player
	local f = AsyncProc
	AsyncProc = nil
	if evtId ~= 0x7FFF then
		local ev = (globalEventInfo == 0) and evt.map or evt.global
		local evn = evtId*256 + seq
		if ev.exists(evn) then
			ev.cocall(evn, evtId, seq)
		elseif globalEventInfo == 0 and evt.house[evtId] then
			evt.EnterHouse(evt.house[evtId])
		end
		events.cocall((globalEventInfo == 0) and "EvtMap" or "EvtGlobal", evtId, seq)
	elseif f then
		evt.Player, evt.CurrentPlayer = AsyncPlayer, AsyncCurrentPlayer
		if type(f) == "thread" then
			coroutine.resume2(f, retseq == AsyncTrue)
		else
			pcall2(f, retseq == AsyncTrue)
		end
	end
	GlobalEventInfo, TargetObj, evt.Player, evt.CurrentPlayer = old1, old2, old3, old4
end

--------- Some Functions

function evt.InGlobal()
	return GlobalEventInfo and GlobalEventInfo ~= 0 or Game.CurrentScreen == 4 or Game.CurrentScreen == 13
end

function evt.ForPlayer(n)
	if type(n) == "table" then
		n = n.Id or n[1]
	end
	if type(n) == "string" then
		evt.Player = evt.Players[n]
	else
		evt.Player = n
	end
	return evt
end

local function JoinStr(s1, s2, sep)
	return (s1 and s2 and s1..sep..s2 or s1 or s2)
end

--------- Call Events

local CmdDef = {}
local CmdStructs = {}
local CmdNames = {}
local CmdInfo = {}
local DeclareCmd = {}

local EvtBuf = internal.EvtBuf
local BufPtr, LineN

local function FillLine()
	local p = offsets.CurrentEvtLines + LineN*12
	u4[p] = 0x7FFF
	u4[p + 4] = LineN
	u4[p + 8] = BufPtr - EvtBuf
	LineN = LineN + 1
end

local CurInfo -- arguments for MakeCmd

local function MakeCmd(name, num, f, invis)
	CurInfo = {FieldTypes = {}}
	local offs0
	local cmdStruct = mem.struct(function(define, ...)
		offs0 = define.offsets
		if invis then
			define.Info(false)
		end
		return f(define, ...)
	end)
	CmdStructs[num] = cmdStruct
	CmdNames[num] = name
	local textName = CurInfo.TextName
	local def = CmdDef[num]
	local order = {}
	CurInfo.FieldsOrder = order
	CmdInfo[num] = CurInfo
	local jump, jumpTrue = CurInfo.Jump, (CurInfo.JumpY and 3 or 2)
	CurInfo.CanEmit = CurInfo.CanEmit or not invis

	if cmdStruct["?size"] ~= #def - ((num == 6 or num == 0xD) and 1 or 0) then
		error(("Cmd%d size(%d) doesn't match CmdDef size(%d)"):format(num, cmdStruct["?size"], #def - (num == 6 and 1 or 0)), 2)
	end

	-- fill order
	do
		local offs = {}
		for a, b in pairs(offs0) do
			offs[b] = a
		end
		local j = 0
		local s
		for i = 0, cmdStruct["?size"] - 1 do
			s = offs[i]
			if s and s ~= jump then
				j = j + 1
				order[j] = s
			end
		end
	end

	DeclareCmd[num] = function(t)
		u2[BufPtr + 1] = 0x7FFF
		u1[BufPtr + 3] = LineN
		u1[BufPtr + 4] = num
		FillLine()
		local len = #def
		mem.copy(BufPtr + 5, def, len)
		if t then
			local a = cmdStruct:new(BufPtr + 5)
			local kn
			for k,v in pairs(t) do
				kn = order[k] or k
				a[kn] = v
				if kn == textName then
					len = cmdStruct["?size"] + #v
				end
			end
		end
		u1[BufPtr] = len + 4
		BufPtr = BufPtr + len + 5
	end

	if invis ~= nil then
		return
	end
	
	local function MakeEvt(player)
		return function(t, ...)
			if t == nil or type(t) ~= "table" then
				t = {t, ...}
			end
			if jump then
				t[jump] = 3
			end

			BufPtr = EvtBuf
			LineN = 0
			DeclareCmd[0]()  -- for buggy commands like 0x1A
			DeclareCmd[num](t)
			DeclareCmd[1]()
			DeclareCmd[1]()  -- for jump

			if num == 3 then
				Game.LoadSound(t.Id or 0)
			end

			u4[offsets.CurrentEvtLinesCount] = LineN
			local oldGlobalEventInfo
			if GlobalEventInfo or u4[offsets.GlobalEventInfo] == 0 then
				oldGlobalEventInfo = u4[offsets.GlobalEventInfo]
				u4[offsets.GlobalEventInfo] = GlobalEventInfo or (Game.CurrentScreen == 4 or Game.CurrentScreen == 13) and 1 or 0
			end
			u4[offsets.EvtTargetObj] = TargetObj or 0
			local player = player or evt.Player
			if not player or player == evt.Players.Current then
				player = evt.CurrentPlayer or evt.Players.Current
			end
			local ret = mem.call(internal.CallProcessEvent, 0, 0x7FFF, 0, player, MayShow)
			if oldGlobalEventInfo then
				u4[offsets.GlobalEventInfo] = oldGlobalEventInfo
			end

			if ret == 0 then -- async command
				AsyncTrue = jumpTrue
				AsyncProc = t.OnDone
				AsyncPlayer, AsyncCurrentPlayer = evt.Player, evt.CurrentPlayer
				local c = not AsyncProc and not t.NoYield and coroutine.running()
				if c then
					AsyncProc = c
					return coroutine.yield()
				end
			end
			return (ret == jumpTrue)
		end
	end
	evt[name] = MakeEvt()
	for i = 0, (mmver == 8 and 4 or 3) do
		evt[i][name] = MakeEvt(i)
	end
	evt.All[name] = MakeEvt(5)
	evt.Random[name] = MakeEvt(6)
	evt.Current[name] = MakeEvt(mmver == 8 and 7 or 4)
end

--------- Decompile

local VarNumToStr, PlayerToStr
local FromFile = {}

function evt.Decompile(fileName, funcMode, outFile, asTxt)

	local InLua = not asTxt
	local funcMode = funcMode or (InLua and 1 or 0)
	local evtStr
	local evtStrHigh = 0
	local IsGlobal = path.name(fileName):lower() == "global.evt"
	local ds = 1
	
	-- write
	local str, strN = {}, 0
	local function S(s)
		strN = strN + 1
		str[strN] = (s and tostring(s) or "")
		return strN
	end	
	local function SN(s)
		return S((s or "").."\n")
	end
	local function SF(s, ...)
		return S(s:format(...))
	end

	local function Error(s, ...)
		SF(("-- ERROR: "..s.."\n"):format(...))
	end

	local function Comment(comment, space)
		space = space or "  "
		if comment and comment:find("\n") then
			return space.."--[[ "..comment.." ]]"
		end
		return comment and comment ~= "" and space.."-- "..comment or ""
	end
	
	local function AsEvtStr(v)
		return ("evt.str[%s]%s"):format(v, Comment(evtStr[v + ds]))
	end

	local function BaseDecompileStr(str)
		evtStr = str:split("\000", 1, true)
		if not evtStr[2] then
			evtStr = str:split("\r\n", 1, true)  -- #0 are changed into #13#10 by extractors
		end
	end

	local function DecompileStr(str)
		BaseDecompileStr(str)
		for i, v in ipairs(evtStr) do
			if v:sub(1, 1) ~= '"' then
				evtStr[i] = ('"%s"'):format(v)
			end
		end
	end

	local function DecompileStrLua(str)
		BaseDecompileStr(str)
		for i, v in ipairs(evtStr) do
			if v:sub(1, 1) == '"' and v:sub(-1, -1) == '"' then
				v = v:sub(2, -2)
			end
			if v ~= "" then
				evtStrHigh = i
			end
			evtStr[i] = ("%q"):format(v)
		end
	end
	
	local function GetFromArray(arr, n, name)
		if n >= arr.low and n <= arr.high then
			return '"'..(name and arr[n][name] or arr[n])..'"'
		elseif n > 0 and arr ~= Game.SpellsTxt then
			if InLua then
				Error("Not found")
			else
				return "not found!"
			end
		end
	end

	local function GetStr(n)
		return IsGlobal and GetFromArray(Game.NPCText, n) or evtStr[n + ds]
	end

	local function GetFromFile(fname, n, col, quotes, headRows)
		if not FromFile[fname] then
			local t = {}
			FromFile[fname] = t
			for s in Game.LoadTextFileFromLod(fname):gmatch("\r\n"..("[^\t]*\t"):rep(col-1).."([^\t]*)") do
				t[#t+1] = (s:sub(1,1) == '"' and s:sub(2, -2) or s)
			end
			for i = 1, (headRows or 1) - 1 do
				t[i] = nil
			end
		end
		local s = FromFile[fname][n]
		if s then
			return quotes and '"'..s..'"' or s
		elseif InLua then
			Error("Not found")
		else
			return "not found!"
		end
	end

	local function FindConst(name, v)
		local a = table.find(const[name] or {}, v)
		if a then
			return "const."..name.."."..a
		elseif name:match("^.*Bits$") then --if InLua then
			local t = {}
			local _, k = math.frexp(v)
			k = math.ldexp(0.5, k)
			if k ~= v then
				while v ~= 0 and k >= 1 do
					if v >= k then
						t[#t+1] = FindConst(name, k) or ("0x%X"):format(k)
						v = v - k
					end
					k = k/2
				end
			end
			if t[1] then
				return table.concat(t, " + ")
			end
		end
		Error("Const not found")
	end
	
	local function GetVarNumComment(k, v)
		if k == '"ClassIs"' then
			-- return GetFromArray(Game.ClassNames, v)
			return nil, FindConst("Class", v)
		elseif k == '"Awards"' then
			return GetFromArray(Game.AwardsTxt, v)
		elseif k == '"QBits"' then
			local ret = GetFromArray(Game.QuestsTxt, v)
			local desc = GetFromFile("quests.txt", v, 3)
			return ret ~= '""' and ret or desc ~= "" and desc or nil
		elseif k == '"Inventory"' then
			return GetFromArray(Game.ItemsTxt, v, 'Name')
		elseif k == '"MainCondition"' then
			return nil, FindConst("Condition", v)
		elseif k == '"AutonotesBits"' then
			return GetFromArray(Game.AutonoteTxt, v)
		elseif k == '"NPCs"' then
			return GetFromArray(Game.NPCDataTxt, v, 'Name')
		elseif k == '"HasNPCProfession"' then
			return nil, FindConst("NPCProfession", v)
		end
	end
	
	local function CmdComment(num, struct)
		local comment
		if num == 0x02 then
			local i = struct.Id
			if i == 600 then
				comment = (mmver == 7) and "Win Good" or "Win"
			elseif i == 601 then
				comment = (mmver == 7) and "Win Evil" or "Lose"
			else
				comment = GetFromArray(Game.Houses, struct.Id, 'Name')
			end
		elseif num == 0x0F and (struct.State == 2 or struct.State == 3) then
			comment = "switch state"
		elseif num == 0x15 then
			comment = GetFromArray(Game.SpellsTxt, struct.Spell, 'Name')
		elseif num == 0x16 then
			comment = GetFromArray(Game.NPCDataTxt, struct.NPC, 'Name')
		elseif num == 0x1A then
			if mmver == 8 then
				comment = GetStr(struct.Question)  -- answers are in map strings!
			else
				comment = "("..JoinStr(GetStr(struct.Answer1), struct.Answer2 ~= struct.Answer1 and GetStr(struct.Answer2), ", ")..")"
				comment = JoinStr(GetStr(struct.Question), comment, " ")
			end
		elseif num == 0x22 then
			if mmver == 8 then
				comment = GetFromArray(Game.ItemsTxt, struct.Type % 1000, 'Name')
			else
				local _, a = Game.ObjListBin.Find(struct.Type)
				comment = a and a.Name or GetFromArray(Game.ObjListBin, Game.ObjListBin.count)
			end
		elseif num == 0x29 then  -- GiveItem
			if struct.Id ~= 0 then
				comment = GetFromArray(Game.ItemsTxt, struct.Id, 'Name')
			end
		elseif num == 0x40 or num == 0x41 then
			comment = JoinStr(GetFromArray(Game.ItemsTxt, struct.MinItemIndex, 'Name'), GetFromArray(Game.ItemsTxt, struct.MaxItemIndex, 'Name'), "...")
		elseif num == 0x44 then
			comment = GetFromFile("roster.txt", struct.Id + 2, 2, true, 2)
		end
		return comment
	end
	
	local function CmdParams(num, struct, jump)
		local info = CmdInfo[num]
		local order = info.FieldsOrder
		local func = (funcMode == 2 or funcMode == 1 and (#order <= 1 or CmdInfo[num].Simple) or num == 0x23)
		S(func and "(" or "{")
		local comment = CmdComment(num, struct)
		local varValue
		local hasParams
		
		-- command call
		for i = 1, #order + (jump and 1 or 0) do
			local a = order[i] or jump
			local v = struct[a]
			if v or a == "On" or a == "Has" or a == "RandomAngle" or a == "Visible" or func then
				if hasParams then
					S(", ")
				end
				hasParams = true
				local vn = (a == "VarNum" and (VarNumToStr[v] or v))
								-- or (a == "Player" and PlayerToStr[v])
								or (a == "Mastery" and v <= 4 and table.find(const, v) and "const."..table.find(const, v))
								or (info.FieldTypes[a] and FindConst(info.FieldTypes[a], v))
				if a == "VarNum" then
					comment, varValue = GetVarNumComment(v, struct.Value)
				elseif a == "Str" then
					comment = GetStr(v)
				elseif a == "Event" or a == "NewEvent" then
					comment = JoinStr(comment, GetFromArray(Game.NPCTopic, v, "Name"), " : ")
				elseif a == "Greeting" then
					comment = JoinStr(comment, GetFromArray(Game.NPCGreet, v, 1), " : ")
				elseif a == "NPC" then
					comment = GetFromArray(Game.NPCDataTxt, v, 'Name')
				elseif a == "HouseId" then
					comment = JoinStr(comment, v > 0 and GetFromArray(Game.Houses, v, "Name"), " -> ")  -- 2 comments in evt.MoveNPC case
				elseif a == "Item" then
					comment = JoinStr(comment, GetFromArray(Game.ItemsTxt, v, 'Name'), " : ")
				elseif a == "NPCGroup" then
					comment = struct.NPCGroup > 0 and GetFromFile("npcgroup.txt", struct.NPCGroup + 1, 4, true)
				elseif a == "NPCNews" then
					comment = JoinStr(comment, GetFromArray(Game.NPCNews, v), " : ")
				elseif a == "Value" and varValue then
					vn = varValue
				end
				if not func and (not vn or i ~= 1) then
					S(a.." = ")
				end
				if vn then
					S(vn)
				elseif type(v) == "string" then
					S(('%q'):format(v))
				elseif a == "Bit" then
					S(("0x%X"):format(v))
				else
					S(tostring(v))
				end
			end
		end
		S(func and ")" or "}")
		return comment and "       "..Comment(comment)
	end
	
	local function DecompileCmd(p, wasShowTopic, firstLine, pend)
		local label = u1[p + 3]
		local num = u1[p + 4]
		local struct = CmdStructs[num]
		if not struct then
			return "unknown command: "..num, false
		elseif p + 5 + struct["?size"] > pend then
		-- elseif 4 + struct["?size"] > u1[p] then
			return "invalid command size ("..CmdNames[num]..")"
		end
		struct = struct:new(p + 5)
		local showTopic = (CmdNames[num]:sub(1, #"CanShowTopic.") == "CanShowTopic.")
		if wasShowTopic ~= nil and showTopic ~= wasShowTopic then
			SN()
		end
		local s = struct.Decompile and struct:Decompile(num)
		if s then
			if not firstLine then
				SN()
			end
			S("      "..s)
		-- elseif num == 0x23 then
		-- 	S((label < 10 and "  %s:  Player = %s" or "  %s: Player = %s"):format(label, PlayerToStr[struct.Player] or struct.Player))
		elseif (num == 4 or num == 5) and label == 0 then
			local v = struct.Str
			local comment = evtStr[v + ds]
			if comment then
				S(("      %s = str[%s]  -- %s"):format(CmdNames[num], v, comment))
			else
				S(("      %s = str[%s]"):format(CmdNames[num], v))
			end
		else
			S((label < 10 and "  %s:  %s  " or "  %s: %s  "):format(label, CmdNames[num]))
			local comment = CmdParams(num, struct, CmdInfo[num].Jump)
			S(comment)
		end
		SN()
		return num == 1 or num == 0x24, showTopic  -- exit or goto
	end

	local function DecompileBuffer(p, size)
		if evtStr then
			for i, v in ipairs(evtStr) do
				SN(('str[%s] = %q'):format(i - ds, v:sub(2, -2)))
			end
			SN("\n")
		else
			evtStr = {}
		end

		local curEvt
		local s, needLine, showTopic, firstLine
		size = p + size
		while p < size and p + u1[p] < size do
			local evt = u2[p + 1]
			if evt ~= curEvt then
				showTopic = nil
				if curEvt then
					SN("end\n")
				end
				s = "event "..evt
				if IsGlobal and evt >= Game.NPCTopic.low and evt <= Game.NPCTopic.high then
					local s1 = Game.NPCTopic[evt]
					if s1 and s1 ~= "" then
						s = s..(('  -- "%s"'):format(s1))
					end
				end
				SN(s)
				curEvt = evt
				firstLine = true
			elseif needLine then
				SN()
				firstLine = true
			end
			needLine, showTopic = DecompileCmd(p, showTopic, firstLine, size)
			firstLine = false
			p = p + u1[p] + 1
		end
		if curEvt then
			SN("end")
		end
	end
	
	-- Decompilation to Lua

	local EvtCmd = {}
	local EvtHouse = {}
	local EvtHint = {}
	local MazeInfo          -- only used by PrepareCmd
	local SoundLoaded = {}  -- only used by PrepareCmd
	local NExit = {Next = {}}
	local InplaceForPlayer
	
	local function PrepareCmd(p, pend)
		local evtId = u2[p + 1]
		local label = u1[p + 3]
		local i = evtId*256 + label
		local num = u1[p + 4]
		local struct = CmdStructs[num]
		struct = struct and struct:new(p + 5)
		if struct and p + 5 + struct["?size"] > pend then
			return
		end
		if num == 4 then  -- Hint
			EvtHint[evtId] = struct.Str
			return
		elseif num == 5 and MazeInfo then  -- MazeInfo
			return
		elseif num == 5 then
			MazeInfo = struct.Str
			return SN("evt.MazeInfo = "..AsEvtStr(MazeInfo))
		elseif num == 2 and struct.Id < 600 and EvtHint[evtId] then  -- EnterHouse
			EvtHouse[evtId] = EvtHouse[evtId] or struct.Id
		elseif num == 2 and struct.Id < 600 then  -- EnterHouse
			Error("evt.house[%s] not assigned for hint, because Hint command is missing", evtId)
		elseif num == 3 and not SoundLoaded[struct.Id] then  -- PlaySound
			SF("Game.LoadSound(%s)\n", struct.Id)
			SoundLoaded[struct.Id] = true
		end
		if EvtCmd[i] then
			Error("Duplicate label: %s:%s", evtId, label)
			if label == 0 or EvtCmd[i - 1] and EvtCmd[i - 1].p < EvtCmd[i].p then
				return
			end
		end
		local info = CmdInfo[num] or {}
		local t = {p = p, evtId = evtId, label = label, num = num, struct = struct, info = info}
		EvtCmd[i] = t
		local cmdName = CmdNames[num] and CmdNames[num]:match("^CanShowTopic.(.*)")
		t.ShowTopic = cmdName and true or false
		t.cmdName = (cmdName or CmdNames[num])
		t.CanEmit = info.CanEmit
		if num == 1 or num == 0x2D then  -- exit
			t.CanEmit = false
			t.Next = {}
		elseif num == 0x24 then  -- GoTo
			t.CanEmit = false
			t.Next = {struct.jump}
		elseif num == 0x19 then  -- RandomGoTo
			local order = info.FieldsOrder
			local jumps = {}
			for i = 1, #order do
				local k = struct[order[i]]
				if k > 0 then
					jumps[#jumps+1] = k
				end
			end
			table.insert(jumps, 1, jumps[#jumps])  -- Next[0] is emitted last
			jumps[#jumps] = nil
			t.Next = jumps
		else
			t.Next = {label + 1}
			if info.Jump then
				t.Next[2] = struct[info.Jump]
			end
			t.FragileLabel = true  -- next label must be placed further in the file, otherwise it's ignored
		end
	end
	
	local function BuildGraph(evtId, label, ShowTopic)
		local Nodes = {}
		local function AddNode(label)
			local cmd = label and label >= 0 and EvtCmd[evtId*256 + label]
			if not cmd then
				return
			end
			local node = Nodes[label] or {cmd = cmd, JumpY = cmd.info.JumpY, ForPlayer = {}}
			if node.Next then
				return
			end
			Nodes[label] = node
			node.CanEmit = (cmd.CanEmit and cmd.ShowTopic == ShowTopic)
			local FragileLabel = cmd.FragileLabel
			if cmd.ShowTopic == ShowTopic then
				node.Next = table.copy(cmd.Next)
			elseif cmd.num == 1 then  -- Exit also works in ShowTopic mode
				node.Next = {}
				FragileLabel = false
			else
				node.Next = {label + 1}
				FragileLabel = true
			end
			if FragileLabel and node.Next[1] >= 0 then
				local c2 = EvtCmd[evtId*256 + node.Next[1]]
				if c2 and c2.p < cmd.p then
					Error("Misplaced label, ignored: %s:%s", evtId, node.Next[1])
					Error("Calling label: %s:%s (%s)", evtId, label, cmd.cmdName)
					node.Next[1] = -1
				end
			end
			for i = 2, #node.Next do
				AddNode(node.Next[i])
			end
			return AddNode(node.Next[1])
		end
		AddNode(label)
		return Nodes
	end
	
	local function N(n1)
		return n1 ~= NExit and n1
	end
	
	local function TraceSingle(n1)
		local start
		while n1 and n1.Ref < 2 and n1 ~= start do
			n1, start = n1.Next[1], start or n1
		end
		return n1
	end
	
	local function Priority(n1, n2)
		local n
		local start
		while N(n1) do
			if n1 == n2 then
				return -1000
			elseif n1.Ref > 1 or n1 == start then
				return 1/0
			elseif n1.Next[2] then
				n = -1
			end
			n1, start = n1.Next[1], start or n1
			n = n or -10
		end
		return n or 0
	end
	
	local function FlipJumps(node)
		node.Next[1], node.Next[2] = node.Next[2], node.Next[1]
		node.JumpY = not node.JumpY
		if node.Dup then
			node.Dup[1], node.Dup[2] = node.Dup[2], node.Dup[1]
		end
		node.Flipped = not node.Flipped
	end
	local function OptimizeNext(node, keepNode)  -- to get rid of some labels
		local n1, n2 = node.Next[1], node.Next[2]
		local p1, p2 = Priority(n1, n2), Priority(n2, n1)
		if p1 < p2 or p1 == p2 and n2 and n1.Ref > 1 and n2.Ref == 1 then
			if keepNode and Priority(n2, keepNode) ~= -1000 then
				return
			end
			FlipJumps(node)
		end
	end

	local function SimplifyGraph(Nodes, label)
		local function ChangeLabel(old, new)
			label = (label == old and new or label)
			for k, node in pairs(Nodes) do
				for i, k in ipairs(node.Next) do
					if k == old then
						node.Next[i] = new
					elseif not Nodes[k] then
						node.Next[i] = -1
					end
				end
			end
		end
		local function DropNodes()
			local found
			for k, node in pairs(Nodes) do
				if not node.CanEmit or InplaceForPlayer and node.cmd.num == 0x23 then
					if node.Next[1] then
						ChangeLabel(k, node.Next[1])
					end
					Nodes[k] = nil
					found = true
				end
			end
			return found
		end
		local function ColapseLabels()
			local found
			ChangeLabel()  -- convert empty labels to -1
			for k, node in pairs(Nodes) do
				if node.Next[2] then
					local t = {}
					local Dup0 = node.Dup or {}
					local Dup = {}
					for i, k in ipairs(node.Next) do
						if Dup[k] then
							Dup[k] = Dup[k] + (Dup0[i] or 1)
						else
							t[#t+1] = k
							Dup[k] = (Dup0[i] or 1)
						end
					end
					if #t ~= #node.Next then
						found = true
						Dup0 = {}
						for i, k in ipairs(t) do
							Dup0[i] = Dup[k]
						end
						node.Next, node.Dup = t, Dup0
						if not t[2] and node.cmd.num == 0x19 then  -- collapse RandomGoTo
							node.CanEmit = false
						end
					end
				end
			end
			return found
		end
		local function CountRefs()
			(Nodes[label] or {}).Ref = 1
			for k, node in pairs(Nodes) do
				for i, k in ipairs(node.Next) do
					local t = Nodes[k] or NExit
					t.Ref = (t.Ref or 0) + 1
					node.Next[i] = t
				end
			end
			NExit.Ref = 1
		end
		local function OptimizeJumps()
			for _, node in sortpairs(Nodes) do
				if node.Next[2] then
					OptimizeNext(node)
				end
			end
			for _, node in sortpairs(Nodes) do
				if node.Next[2] then
					if node.Flipped then
						FlipJumps(node)
					end
					OptimizeNext(node)
				end
			end
		end
		local function CheckForPlayer(label, pl)
			local node = Nodes[label]
			if not node or not InplaceForPlayer or node.ForPlayer[pl] then
				return
			elseif next(node.ForPlayer) and node.cmd.info.ForPlayer then
				InplaceForPlayer = false
				return
			end
			node.ForPlayer[pl] = true
			if node.cmd.num == 0x23 then
				pl = node.cmd.struct.Player
			end
			for i = 2, #node.Next do
				CheckForPlayer(node.Next[i], pl)
			end
			return CheckForPlayer(node.Next[1], pl)
		end
		
		-- InplaceForPlayer = true
		-- CheckForPlayer(label, "Current")
		while DropNodes() or ColapseLabels() do
		end
		CountRefs()
		OptimizeJumps()
		return Nodes[label]
	end
	
	-- block
	local block
	local Tab = "\t"
	local Tab2 = "\t\t"
	local Queue
	local LastGoto
	local ResultStart
	
	local function BeginBlock(t)
		block = t
		t.NeedLabel = {}
		t.BeginLine = S()
		t.Locals = {}
	end
	
	local function EndBlock()
		for node in pairs(block.NeedLabel) do
			str[block[node]] = ("::_%s::\n\t"):format(node.cmd.label)
		end
		if strN == block.BeginLine then
			strN, str[strN] = strN - 1, nil
		else
			local loc = next(block.Locals)
			str[block.BeginLine] = block.Begin..(loc and "\n\tlocal "..loc or "").."\n"
			SN(block.End or "end\n")
		end
		block = nil
	end
	
	local function Goto(node, tab)
		tab = tab or Tab2
		if N(node) then
			block.NeedLabel[node] = true
			Queue[#Queue + 1] = node
			SN(tab.."goto _"..node.cmd.label)
		elseif not block.ShowTopic then
			SN(tab.."return")
		elseif ResultStart then
			str[ResultStart] = "return "
		elseif block.Locals.result then
			SN(tab.."return result")
		else
			SN(tab.."return true")
		end
		ResultStart = nil
		LastGoto = strN
	end
	
	local function Return()
		if block.ShowTopic then
			SN(Tab.."do return result end")
		else
			SN(Tab.."do return end")
		end
	end
	
	local EmitIf
	
	local function EmitElse(node, Else)
		if Else and N(node.Next[1]) then
			if node.Next[1] ~= Else then
				SN(Tab.."else")
			end
			node.Next[1] = EmitIf(node.Next[1], nil, Else)
		end
		SN(Tab.."end")
	end
	
	local function EmitCmd(node, keepNode)
		local Else
		if node.Next[2] then
			OptimizeNext(node, keepNode)
			Else = true
			local Same = N(TraceSingle(node.Next[1]))
			for _, n1 in ipairs(node.Next) do
				Else = Else and (Priority(n1) ~= 1/0)
				Same = (TraceSingle(n1) == Same) and Same
			end
			Else = Else or Same
			-- if Same and Else == Same then
			-- 	SF(Tab.."-- Same Cmd: %s", Same.cmd.cmdName)
			-- 	CmdParams(Same.cmd.num, Same.cmd.struct)
			-- 	SN()
			-- end
		end
		
		if ResultStart then
			block.Locals.result, ResultStart = true, nil
		end
		local cmd = node.cmd
		local num = cmd.num
		local struct = cmd.struct
		block[node] = S(Tab)
		-- special commands
		if num == 0x19 then  -- RandomGoto
			local Next = node.Next
			local Dup = node.Dup or {1,1,1,1,1,1}
			local n = Dup[1]
			block.Locals.i = true
			SN("i = Game.Rand() % "..#cmd.Next)
			for i = 2, #Next do
				if i == 2 then
					S(Tab.."if ")
				else
					S(Tab.."elseif ")
				end
				local k = Dup[i]
				if k == 1 then
					SF("i == %s then\n", n)
				elseif k == 2 then
					SF("i == %s or i == %s then\n", n, n + 1)
				else
					SF("i >= %s and i <= %s then\n", n, n + k - 1)
				end
				EmitIf(Next[i], Next[1], Else)
				n = n + k
			end
			return EmitElse(node, Else)
		elseif num == 0x2E then  -- CanShowTopic.Set
			ResultStart = S("result = ")
			return SN(tostring(struct.Visible))
		end
		-- normal commands
		local jump = node.Next[2]
		if jump and block.ShowTopic then  -- CanShowTopic optimization
			local n2, n1 = N(jump), N(node.Next[1])
			if n1 and n1.cmd.num == 0x2E and not N(n1.Next[1]) and n2 and n2.cmd.num == 0x2E and not N(n2.Next[1]) and
				 n1.cmd.struct.Visible ~= n2.cmd.struct.Visible then
				n1.Ref = n1.Ref - 1
				n2.Ref = n2.Ref - 1
				jump, node.Next = nil, {}
				ResultStart = S("result = ")
				if n2.cmd.struct.Visible ~= node.JumpY then
					S("not ")
				end
			end
		end
		if jump and node.JumpY then
			S("if ")
		elseif jump then
			S("if not ")
		end
		if InplaceForPlayer and cmd.info.ForPlayer and next(node.ForPlayer) ~= "Current" then
			local s = next(node.ForPlayer)
			if type(s) == "number" then
				s = "["..s.."]"
			else
				s = "."..s
			end
			SF("evt%s.%s", s, cmd.cmdName)
		else
			SF("evt.%s", cmd.cmdName)
		end
		local comment = CmdParams(num, struct)
		if jump then
			S(" then")
		end
		SN(comment)
		if jump then
			EmitIf(jump, node.Next[1], Else)
			EmitElse(node, Else)
		end
	end
	
	function EmitIf(node, main, Else)
		node = N(node)
		local Same = (Else ~= true and Else)
		local oldTab, oldTab2 = Tab, Tab2
		if node and node.Ref == 1 then
			Tab, Tab2 = Tab2, Tab2.."\t"
		end
		while node and node.Ref == 1 and node ~= Same do
			EmitCmd(node, Same)
			node = N(node.Next[1])
		end
		Tab, Tab2 = oldTab, oldTab2
		if node ~= main and (not Else or not Same and node) then
			Goto(node)
		-- elseif node and node == main or node and main and Same then
			-- node.Ref = node.Ref - 1
		end
		return Same and node or nil
	end
	
	local function DecompileEvt(evtId, label)
		-- Sorted by first use:
		Queue = {SimplifyGraph(BuildGraph(evtId, label, block.ShowTopic), label)}
		LastGoto = strN
		local q = 1
		while true do
			while block[Queue[q]] do  -- find what isn't emitted yet
				q = q + 1
			end
			local node = Queue[q]  -- label in need of writing
			if not node then
				break
			elseif LastGoto ~= strN then
				Return()  -- end previous branch
			end
			while N(node) do
				EmitCmd(node)
				assert(block[node])
				node = node.Next[1]
				if block[node] then
					Goto(node, Tab)
					break
				end
			end
			assert(block[Queue[q]])
		end
		for i = 1, q - 1 do
			assert(Queue[i])
		end
		if block.ShowTopic then
			Goto(NExit, Tab)
		end
		EndBlock()
	end
	
	local function EmitHint(evtId)
		if EvtHouse[evtId] then
			local v = EvtHouse[evtId]
			local comment = GetFromArray(Game.Houses, v, "Name")
			SF("evt.house[%s] = %s%s\n", evtId, v, Comment(comment))
		elseif EvtHint[evtId] then
			SF("evt.hint[%s] = %s\n", evtId, AsEvtStr(EvtHint[evtId]))
		end
	end
	
	local evtDone = {[false] = {}, [true] = {}}
	local evtEmpty = {}
	
	local function DecompileCmdLua(p, pend)
		local evtId = u2[p + 1]
		local label = u1[p + 3]
		local num = u1[p + 4]
		local struct = CmdStructs[num]
		if not struct then
			return Error("Unknown command: %s:%s (0x%X)", evtId, label, num)
		elseif 4 + struct["?size"] > u1[p] then
			Error("Invalid command size: %s:%s (%s)",  evtId, label, CmdNames[num])
			if p + 5 + struct["?size"] > pend then
				return
			end
		end
		struct = struct:new(p + 5)
		local ShowTopic = CmdNames[num]:match("^CanShowTopic.(.*)") and true or false
		
		-- emit standard event
		if not evtDone[ShowTopic][evtId] then
			evtDone[ShowTopic][evtId] = true
			if not ShowTopic then
				EmitHint(evtId)
			end
			if IsGlobal and not evtDone[not ShowTopic][evtId] then
				SN(Comment(GetFromArray(Game.NPCTopic, evtId), ""))
			end
			local s = ShowTopic and "CanShowTopic" or IsGlobal and "global" or "map"
			s = ("evt.%s[%s] = function()"):format(s, evtId)
			if not IsGlobal and EvtCmd[evtId*256] and EvtCmd[evtId*256].struct.Decompile then
				s = s..Comment(EvtCmd[evtId*256].struct:Decompile(EvtCmd[evtId*256].num))
			end
			BeginBlock{Evt = evtId, ShowTopic = ShowTopic, Begin = s}
			if not ShowTopic and EvtHouse[evtId] then
				S()  -- keep event function if it's just a hint
			end
			local lastN = strN
			DecompileEvt(evtId, 0)
			evtEmpty[evtId] = (strN <= lastN)
		end
		
		-- emit special event
		local s = struct.Decompile and struct:Decompile(num)
		if s and not IsGlobal then
			local s1, s2 = s:match("^(.*)<function>(.*)")
			if label ~= 0 or evtEmpty[evtId] then
				BeginBlock{Evt = evtId, ShowTopic = ShowTopic,
					Begin = (s1 and s1.."function()" or s),
					End = s2 and "end"..s2.."\n"
				}
				DecompileEvt(evtId, label)
			elseif s1 then
				SF("%sevt.map[%s].last%s\n\n", s1, evtId, s2)
			else
				SF("%s = evt.map[%s].last\n\n", assert(s:match("^function (.*)%(%)$"), evtId))
			end
		elseif s then
			Error("Event in GLOBAL.txt: "..s)
		end
	end
	
	local function PrepareEvtPtr(p, size)
		size = p + size
		while p < size and p + u1[p] < size do
			PrepareCmd(p, size)
			p = p + u1[p] + 1
		end
		SN()
	end

	local function DecompileBufferLua(p, size)
		evtStr = evtStr or {}
		if not IsGlobal then
			SN("local TXT = Localize{")
			for i = 1, evtStrHigh do
				SN(("%s[%s] = %s,"):format(Tab, i - ds, evtStr[i]))
			end
			SN("}")
			SN("table.copy(TXT, evt.str, true)\n")
		end
		SN("-- Deactivate all standard events")
		SN("Game."..(IsGlobal and "GlobalEvtLines" or "MapEvtLines")..".Count = 0\n")

		PrepareEvtPtr(p, size)
		
		size = p + size
		while p < size and p + u1[p] < size do
			DecompileCmdLua(p, size)
			p = p + u1[p] + 1
		end
	end
	
	if InLua then
		DecompileStr = DecompileStrLua
		DecompileBuffer = DecompileBufferLua
	end

	-- do it
	local s, size, buf

	for f in path.find(path.SetExt(fileName, ".str")) do
		DecompileStr(io.LoadString(f))
	end
	s = io.LoadString(fileName)
	if #s < 5 then
		return nil
	end
	size = #s
	buf = mem.malloc(size + 30)
	mem.copy(buf, s, size + 1)  -- +30 and size + 1 are here to be sure no out-of-bounds problems occur
	DecompileBuffer(buf, size)
	mem.free(buf)
	s = table.concat(str):gsub("\r?\n", "\r\n")
	if outFile then
		io.SaveString(outFile, s)
	end
	return s
end

--------------------------------------------------------------------------------

local function DeclareCommands()

	local types_u1
	do
		mem.struct(function(define)  types_u1 = define.u1  end)
	end
	local function EvtVar(name)
		local a = mmver == 6 and u1 or u2
		return mem.structs.CustomType(name or "VarNum", mmver == 6 and 1 or 2,
			function(o, obj, name, val)
				local p = obj["?ptr"] + o
				if val then
					a[p] = evt.VarNum[val] or val
				else
					val = a[p]
					return VarNumToStr[val] or val --a[p]
				end
			end
		).Info{Type = "evt.VarNum"}
	end

	local function TEvtString(name)
		CurInfo.TextName = name
		return mem.structs.CustomType(name, 1,
			function(o, obj, name, val)
				local p = obj["?ptr"] + o
				if val then
					mem.copy(p, val, #val + 1)
				else
					return mem.string(p)
				end
			end
		)
	end

	local function YJump(name)
		CurInfo.Jump = name
		CurInfo.JumpY = true
		return types_u1(name).Info(false)
	end

	local function NJump(name)
		CurInfo.Jump = name
		CurInfo.JumpY = false
		return types_u1(name).Info(false)
	end

	local getdefine = mem.structs.getdefine
	local function Type(kind)
		local define = getdefine()
		CurInfo.FieldTypes[define.LastDefinedMemberName] = kind
		return define.Info{Kind = "const."..kind}
	end

	local function Mastery(name)
		return mem.structs.CustomType(name or 'Mastery', 1,
			function(o, obj, name, val)
				local p = obj["?ptr"] + o
				if val == nil then
					return u1[p] + 1
				end
				u1[p] = val - 1
			end
		).Info{Type = "const.*"}
	end

	local function Player(name)
		mem.structs.CustomType(name or 'Player', 1,
			function(o, obj, name, val)
				local p = obj["?ptr"] + o
				if val then
					u1[p] = evt.Players[val] or val
				else
					val = u1[p]
					return PlayerToStr[val] or val
				end
			end
		)
		return Type("Players")
	end

	---------------------------
	MakeCmd("Cmd00", 0x00, function(define)
	end, true)
	
	---------------------------
	MakeCmd("Exit", 0x01, function(define)
		define
		.size = 1
	end, true)

	---------------------------
	MakeCmd("EnterHouse", 0x02, function(define)
		define
		.u4  'Id'
		 .Info ("In 2DEvents.txt\n"..
		  "600 = you won\n"..
		  "601 = you won 2 / you lost")
	end)

	---------------------------
	MakeCmd("PlaySound", 0x03, function(define)
		define
		.i4  'Id'
		.i4  'X'
		.i4  'Y'
	end)

	---------------------------
	MakeCmd("Hint", 0x04, function(define)
		define
		.u1  'Str'
	end, true)

	---------------------------
	MakeCmd("MazeInfo", 0x05, function(define)
		define
		.u1  'Str'
	end, true)

	---------------------------
	MakeCmd("MoveToMap", 0x06, function(define)
		define.Info ("Notes:\n"..
		 "If cancel is pressed, the execution is stopped\n"..
		 "If X,Y,Z,Direction,LookAngle,SpeedZ are all 0, the party isn't moved\n"..
		 "If HouseId and Icon are 0, the enter dungeon dialog isn't shown")

		define
		.i4  'X'
		.i4  'Y'
		.i4  'Z'
		.i4  'Direction'
		 .Info "-1 = special case"
		.i4  'LookAngle'
		.i4  'SpeedZ'
		if mmver == 8 then
			define.u2  'HouseId'
			 .Info "In 2DEvents.txt"
		else
			define.u1  'HouseId'
			 .Info "In 2DEvents.txt"
		end
		define.u1  'Icon'
		TEvtString 'Name'
		 .Info 'if starts with "0" => current map'
	end)

	---------------------------
	MakeCmd("OpenChest", 0x07, function(define)
		define
		.u1  'Id'
	end)

	---------------------------
	MakeCmd("FaceExpression", 0x08, function(define)
		Player()
		.u1  'Frame'
	end)

	---------------------------
	MakeCmd("DamagePlayer", 0x09, function(define)
		Player()
		.u1  'DamageType'
		 Type("Damage")
		.i4  'Damage'
	end)

	---------------------------
	MakeCmd("SetSnow", 0x0A, function(define)
		define
		.u1  'EffectId'
		 .Info "only 0 available"
		.b1  'On'
	end)

	---------------------------
	MakeCmd("SetTexture", 0x0B, function(define)
		define
		.i4  'Facet'
		TEvtString 'Name'
	end)

	---------------------------
	if mmver ~= 6 then
		MakeCmd("ShowMovie", 0x0C, function(define)
			define
			.u1  'DoubleSize'
			.b1  'ExitCurrentScreen'
			 .Info ("Use 'true' only before using evt.MoveToMap command in houses and before showing game ending.\n"
			   .."Prevents loading of house anmation after the movie stops playing, but doesn't exit the screen properly.")
			TEvtString 'Name'
		end)
	else
		MakeCmd("SetTextureOutdoors", 0x0C, function(define)
			define
			.u4  'Model'
			.u4  'Facet'
			TEvtString 'Name'
		end)
	end

	---------------------------
	MakeCmd("SetSprite", 0x0D, function(define)
		define
		.i4  'SpriteId'
		.u1  'Visible'
		 .Info "bit 0x20 of sprite"
		TEvtString 'Name'
		 .Info[[If Name is "0", the sprite isn't changed]]
	end)

	---------------------------
	MakeCmd("Cmp", 0x0E, function(define)
		define.Info "Usually performs Variable >= Value comparison"
		EvtVar  'VarNum'
		.i4  'Value'
		YJump  '  jump'
		
		CurInfo.Simple = true
		CurInfo.ForPlayer = true
	end)

	---------------------------
	MakeCmd("SetDoorState", 0x0F, function(define)
		define
		.u1  'Id'
		.u1  'State'
		 .Info "0 - state (0),\n1 - state (1),\n2 - switch state if the door isn't moving,\n3 - switch state"
	end)

	---------------------------
	MakeCmd("Add", 0x10, function(define)
		EvtVar  'VarNum'
		.i4  'Value'
		
		CurInfo.Simple = true
		CurInfo.ForPlayer = true
	end)

	---------------------------
	MakeCmd("Subtract", 0x11, function(define)
		EvtVar  'VarNum'
		.i4  'Value'
		
		CurInfo.Simple = true
		CurInfo.ForPlayer = true
	end)
	evt.Sub = evt.Subtract

	---------------------------
	MakeCmd("Set", 0x12, function(define)
		EvtVar  'VarNum'
		.i4  'Value'
		
		CurInfo.Simple = true
		CurInfo.ForPlayer = true
	end)
	
	---------------------------
	MakeCmd("SummonMonsters", 0x13, function(define)
		define
		.u1  'TypeIndexInMapStats'
		.u1  'Level'
		.u1  'Count'
		.i4  'X'
		.i4  'Y'
		.i4  'Z'
		if mmver ~= 6 then
			define
			.i4  'NPCGroup'
			.i4  'unk'
		end
	end)

	---------------------------
	MakeCmd("Cmd14", 0x14, function(define)
		define
		.i4  'unk_1'
		.u1  'unk_2'
	end, true)

	---------------------------
	MakeCmd("CastSpell", 0x15, function(define)
		define
		.u1  'Spell'
		Mastery()
		.u1  'Skill'
		.i4  'FromX'
		.i4  'FromY'
		.i4  'FromZ'
		.i4  'ToX'
		.i4  'ToY'
		.i4  'ToZ'
	end)

	---------------------------
	MakeCmd("SpeakNPC", 0x16, function(define)
		define
		.i4  'NPC'
	end)

	---------------------------
	MakeCmd("SetFacetBit", 0x17, function(define)
		define
		.i4  'Id'
		 .Info "Id of facets group in MM7-8. Index in Map.Facets indoors in MM6."
		.u4  'Bit'
		 Type("FacetBits")
		.b1  'On'
	end)

	---------------------------
	if mmver == 6 then
		MakeCmd("SetFacetBitOutdoors", 0x18, function(define)
			define
			.i4  'Model'
			 .Info "Model index in Map.Models"
			.i4  'Facet'
			 .Info "-1 = for all faces of model"
			.i4  'Bit'
			 Type("FacetBits")
			.b1  'On'
		end)
	else
		MakeCmd("SetMonsterBit", 0x18, function(define)
			define
			.i4  'Monster'
			.i4  'Bit'
			 Type("MonsterBits")
			.b1  'On'
		end)
	end

	---------------------------
	MakeCmd("RandomGoTo", 0x19, function(define)
		define
		.u1  'jumpA'
		.u1  'jumpB'
		.u1  'jumpC'
		.u1  'jumpD'
		.u1  'jumpE'
		.u1  'jumpF'
		 .Info "0 to skip a label"
		CurInfo.CanEmit = true
	end, true)

	---------------------------
	MakeCmd("Question", 0x1A, function(define)
		define
		 .Info 'Use Question function instead, e.g.\n  if Question("Restricted area - Keep out.", "What\'s the password?"):lower() == "jbard" then ...'
		.i4  'Question'
		.i4  'Answer1'
		.i4  'Answer2'
		YJump  '  jump(ok)'
	end)

	---------------------------
	MakeCmd("Cmd1B", 0x1B, function(define)
		define
		.u1  'unk_1'
		.u1  'unk_2'
	end, true)

	---------------------------
	MakeCmd("Cmd1C", 0x1C, function(define)
		define
		.u1  'unk_1'
	end, true)

	---------------------------
	MakeCmd("StatusText", 0x1D, function(define)
		define
		 .Info 'Use Game.ShowStatusText function instead, e.g.\n  Game.ShowStatusText("Hi!")'
		.i4  'Str'
	end)

	---------------------------
	MakeCmd("SetMessage", 0x1E, function(define)
		define
		 .Info 'Use Message function instead, e.g.\n  Message("Hi!")'
		.i4  'Str'
	end)

	---------------------------
	local function DeclareTimer(define)
		define
		.b1  'EachYear'
		.b1  'EachMonth'
		.b1  'EachWeek'
		 .Info "else each day after the Start"
		.u1  'StartHour'
		.u1  'StartMinute'
		.u1  'StartSecond'
		.u2  'IntervalInHalfMinutes'
		.skip(2)
		
		local Timer = "Timer(<function>, "
		
		function define.f:Decompile(cmd)
			local s
			if self.IntervalInHalfMinutes ~= 0 then
				local s, n = "/2*const.Minute", self.IntervalInHalfMinutes
				-- if n % 2 == 0 then
					s, n = "*const.Minute", n/2
					if n % 60 == 0 then
						s, n = "*const.Hour", n/60
					end
				-- end
				return Timer..n..s..")"
			elseif self.EachYear then
				s = "const.Year"
			elseif self.EachMonth then
				s = "const.Month"
			elseif self.EachWeek then
				s = "const.Week"
			else
				local s = (self.StartHour ~= 0 and self.StartHour.."*const.Hour")
				local n = self.StartMinute*60 + self.StartSecond
				local s1 = (n % 30 ~= 0 and n.."*const.Second" or n ~= 0 and (n/60).."*const.Minute")
				s = (s and s1 and s.." + "..s1 or s or s1 or "0")
				return Timer.."const.Day, "..s..")"
			end
			if cmd == 0x1F then
				return Timer..s..")"
			end
			return "Refill"..Timer..s..", true)"
		end
	end
	
	MakeCmd("OnTimer", 0x1F, DeclareTimer, true)

	---------------------------
	MakeCmd("SetLight", 0x20, function(define)
		define
		.i4  'Id'
		 .Info "[MM6, MM7] Map.Lights index\n[MM8] Light group id"
		.b1  'On'
	end)

	---------------------------
	MakeCmd("SimpleMessage", 0x21, function(define)
		define
		 .Info 'Use Message function instead, e.g.\n  Message("Hi!")'
		.skip(1)
	end)

	---------------------------
	MakeCmd("SummonObject", 0x22, function(define)
		define
		.i4  'Type'
		 .Info([[
[MM6, MM7] Object kind index (ObjList.txt)
[MM8] Item index. Index over 1000 means random item of the same kind as Type % 1000 of strength Type div 1000.]])
		.i4  'X'
		.i4  'Y'
		.i4  'Z'
		.i4  'Speed'
		.u1  'Count'
		.b1  'RandomAngle'
	end)

	---------------------------
	MakeCmd("ForPlayer", 0x23, function(define)
		define
		.Info([[
Usually a better approach is to specify player after "evt", this way it only effects one call that follows:
  evt.All.Add("Exp", 1000)
  evt[0].Add("Gold", 1000)
evt.ForPlayer is actually a function that returns evt, so you can write things like this:
  evt.ForPlayer("All").Add("Exp", 1000)
You can also manipulate evt.Player and evt.CurrentPlayer variables.]])
		Player()
	end, false)

	---------------------------
	MakeCmd("GoTo", 0x24, function(define)
		YJump  'jump'
	end, true)

	---------------------------
	MakeCmd("OnLoadMap", 0x25, function(define)
		define
		.skip(1)
		
		function define.f:Decompile(cmd)
			return "function events.LoadMap()"
		end
	end, true)

	---------------------------
	MakeCmd("OnLongTimer", 0x26, DeclareTimer, true)

	---------------------------
	MakeCmd("SetNPCTopic", 0x27, function(define)
		define
		.i4  'NPC'
		.u1  'Index'
		.i4  'Event'
	end)

	---------------------------
	MakeCmd("MoveNPC", 0x28, function(define)
		define
		.u4  'NPC'
		.u4  'HouseId'
		 .Info "In 2DEvents.txt"
	end)

	---------------------------
	MakeCmd("GiveItem", 0x29, function(define)
		define
		.u1  'Strength'
		 .Info "1-6 (like described in the end of STDITEMS.TXT)"
		.u1  'Type'
		 Type("ItemType")
		.u4  'Id'
		 .Info ("If Id is 0, a random item is chosen from the specified class with specified strength,\n"..
		  "otherwise, Type and Strength determine the enchantments")
	end)

	---------------------------
	MakeCmd("ChangeEvent", 0x2A, function(define)
		define
		.u4  'NewEvent'
		 .Info "Changes global event for barrels, pedestals etc. The kinds of sprites with such events are hard-coded."
	end)

	---------------------------
	MakeCmd("CheckSkill", 0x2B, function(define)
		define
		 .Info 'Checks that the skill meets specified Mastery and Level requirements'
		.u1  'Skill'
		 Type("Skills")
		Mastery()
		.i4  'Level'
		 .Info 'Includes "Double effect" enchantments and NPC bonuses'
		YJump  '  jump(>=)'
		CurInfo.ForPlayer = true
	end)

	--------------------------- MM7

	if mmver < 7 then
		return
	end

	---------------------------
	MakeCmd("CanShowTopic.Cmp", 0x2C, function(define)
		EvtVar  'VarNum'
		.i4  'Value'
		YJump  '  jump'
		
		CurInfo.Simple = true
		CurInfo.CanEmit = true
	end, true)

	---------------------------
	MakeCmd("CanShowTopic.Exit", 0x2D, function(define)
		define
		.skip(1)
	end, true)

	---------------------------
	MakeCmd("CanShowTopic.Set", 0x2E, function(define)
		define
		.b1  'Visible'
		CurInfo.CanEmit = true
	end, true)

	---------------------------
	MakeCmd("SetNPCGroupNews", 0x2F, function(define)
		define
		.u4  'NPCGroup'
		.u4  'NPCNews'
	end)

	---------------------------
	MakeCmd("SetMonsterGroup", 0x30, function(define)
		define
		.u4  'Monster'
		.u4  'NPCGroup'
	end)

	---------------------------
	MakeCmd("SetNPCItem", 0x31, function(define)
		define
		.i4  'NPC'
		.i4  'Item'
		.b1  'On'
	end)

	---------------------------
	MakeCmd("SetNPCGreeting", 0x32, function(define)
		define
		.i4  'NPC'
		.i4  'Greeting'
	end)

	---------------------------
	local function CheckMonstersKilled(define)
		define
		.u1  'CheckType'
		 .Info "0 - any monster, 1 - in group, 2 - of type, 3 - specific monster, 4 - specific monster by name (MM8)"
		.u4  'Id'
		 .Info "0 - not used, 1 - group id, 2 - monster type minus 1, 3 - monster id, 4 - id in placemon.txt (MM8 only)"
		.u1  'Count'
		 .Info "0 - all must be killed, else a number of monsters that must be killed"
		if mmver == 8 then
			define.u1  'InvisibleAsDead'
			 .Info "a monster can be invisible, like pirates in Ravenshore in MM8 before you enter Regna"
		end
		YJump  '  jump(>=)'
		CurInfo.CanEmit = true
	end
	
	MakeCmd("CheckMonstersKilled", 0x33, CheckMonstersKilled)

	---------------------------
	MakeCmd("CanShowTopic.CheckMonstersKilled", 0x34, CheckMonstersKilled, true)

	---------------------------
	MakeCmd("OnLeaveMap", 0x35, function(define)
		define
		.skip(1)

		function define.f:Decompile(cmd)
			return "function events.LeaveMap()"
		end
	end, true)

	---------------------------
	MakeCmd("ChangeGroupToGroup", 0x36, function(define)
		define
		.i4  'Old'
		.i4  'New'
	end)
	
	---------------------------
	MakeCmd("ChangeGroupAlly", 0x37, function(define)
		define
		.i4  'Group'
		.i4  'Ally'
	end)
	
	---------------------------
	MakeCmd("CheckSeason", 0x38, function(define)
		define
		.u1  'Season'
		YJump  '  jump(ok)'
	end)

	---------------------------
	MakeCmd("SetMonGroupBit", 0x39, function(define)
		define
		.i4  'NPCGroup'
		.u4  'Bit'
		 Type("MonsterBits")
		.b1  'On'
	end)

	---------------------------
	MakeCmd("SetChestBit", 0x3A, function(define)
		define
		.i4  'ChestId'
		.u4  'Bit'
		 Type("ChestBits")
		.b1  'On'
	end)

	---------------------------
	MakeCmd("FaceAnimation", 0x3B, function(define)
		Player()
		.u1  'Animation'
	end)

	---------------------------
	MakeCmd("SetMonsterItem", 0x3C, function(define)
		define
		.i4  'Monster'
		.i4  'Item'
		.b1  'Has'
	end)

	--------------------------- MM8

	if mmver < 8 then
		return
	end

	---------------------------
	MakeCmd("OnDateTimer", 0x3D, function(define)
		define
		.u1  'Id'
		 .Info "0x3D00 is added to this"
		.u1  'HourPlus1'
		.u1  'DayPlus1'
		.u1  'WeekPlus1'
		.u1  'YearPlus1'
		.u2  'FullYearPlus1'
		.u1  'EnableAfter'
		 .Info ("works every half of second\n"..
		  "By default date timer is disabled!")
		CurInfo.CanEmit = true
	end, true)

	---------------------------
	MakeCmd("EnableDateTimer", 0x3E, function(define)
		define
		.u2  'IdPlus0x3D00'
		 .Info "add 0x3D00 to Id of Cmd_3D"
		.b1  'On'
		CurInfo.CanEmit = true
	end, true)

	---------------------------
	MakeCmd("StopDoor", 0x3F, function(define)
		define
		.i4  'Id'
	end)

	---------------------------
	MakeCmd("CheckItemsCount", 0x40, function(define)
		define
		.u2  'MinItemIndex'
		.u2  'MaxItemIndex'
		.u2  'Count'
		YJump  '  jump(>=)'
	end)

	---------------------------
	MakeCmd("RemoveItems", 0x41, function(define)
		define
		.u2  'MinItemIndex'
		.u2  'MaxItemIndex'
		.u2  'Count'
	end)

	---------------------------
	MakeCmd("Jump", 0x42, function(define)
		define
		.i2  'Direction'
		.i2  'ZAngle'
		.i4  'Speed'
	end)

	---------------------------
	MakeCmd("IsTotalBountyInRange", 0x43, function(define)
		define
		.i4  'MinGold'
		.i4  'MaxGold'
		YJump  '  jump(ok)'
	end)

	---------------------------
	MakeCmd("IsPlayerInParty", 0x44, function(define)
		define
		.u4  'Id'
		 .Info "Roster.txt"
		YJump  '  jump(ok)'
	end)

end

--------------------------------------------------------------------------------

CmdDef[0x00] = ""
CmdDef[0x01] = "\0"
CmdDef[0x02] = "\0\0\0\0"
CmdDef[0x03] = "\0\0\0\0\0\0\0\0\0\0\0\0"
CmdDef[0x04] = "\0"
CmdDef[0x05] = "\0" -- MM6
if mmver == 8 then
	CmdDef[0x06] = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\48\0"
else
	CmdDef[0x06] = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\48\0"
end
CmdDef[0x07] = "\0"
CmdDef[0x08] = "\4\0" -- MM6
if mmver == 8 then
	CmdDef[0x09] = "\7\0\0\0\0\0"
else
	CmdDef[0x09] = "\4\0\0\0\0\0"
end
CmdDef[0x0A] = "\0\0" -- MM6
CmdDef[0x0B] = "\0\0\0\0\0"
if mmver ~= 6 then
	CmdDef[0x0C] = "\1\0\0" -- (ShowMovie)
else
	CmdDef[0x0C] = "\0\0\0\0\0\0\0\0\0"
end
CmdDef[0x0D] = "\0\0\0\0\1\48\0"
if mmver ~= 6 then
	CmdDef[0x0E] = "\0\0\0\0\0\0\0"
else
	CmdDef[0x0E] = "\0\0\0\0\0\0"
end
CmdDef[0x0F] = "\0\0"
if mmver ~= 6 then
	CmdDef[0x10] = "\0\0\0\0\0\0"
else
	CmdDef[0x10] = "\0\0\0\0\0"
end
if mmver ~= 6 then
	CmdDef[0x11] = "\0\0\0\0\0\0"
else
	CmdDef[0x11] = "\0\0\0\0\0"
end
if mmver ~= 6 then
	CmdDef[0x12] = "\0\0\0\0\0\0"
else
	CmdDef[0x12] = "\0\0\0\0\0"
end
if mmver ~= 6 then
	CmdDef[0x13] = "\1\1\1\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
else
	CmdDef[0x13] = "\1\1\1\0\0\0\0\0\0\0\0\0\0\0\0"
end
CmdDef[0x14] = "\0\0\0\0\1"
CmdDef[0x15] = "\0\3\5\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
CmdDef[0x16] = "\0\0\0\0"
CmdDef[0x17] = "\0\0\0\0\0\0\0\0\0"
if mmver ~= 6 then
	CmdDef[0x18] = "\0\0\0\0\0\0\0\0\0"
else
	CmdDef[0x18] = "\0\0\0\0\255\255\255\255\0\0\0\0\0"
end
CmdDef[0x19] = "\1\0\0\0\0\0"
CmdDef[0x1A] = "\0\0\0\0\0\0\0\0\0\0\0\0\0"
CmdDef[0x1B] = "\0\0"
CmdDef[0x1C] = "\0"
CmdDef[0x1D] = "\0\0\0\0"
CmdDef[0x1E] = "\0\0\0\0"
CmdDef[0x1F] = "\0\0\0\0\0\0\0\0\0\0"
CmdDef[0x20] = "\1\0\0\0\0"
CmdDef[0x21] = "\0"
CmdDef[0x22] = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\232\3\0\0\1\0"
CmdDef[0x23] = "\0"
CmdDef[0x24] = "\0"
CmdDef[0x25] = "\0"
CmdDef[0x26] = "\0\0\0\0\0\0\0\0\0\0"
CmdDef[0x27] = "\0\0\0\0\0\0\0\0\0"
CmdDef[0x28] = "\0\0\0\0\0\0\0\0"
CmdDef[0x29] = "\1\0\0\0\0\0"
CmdDef[0x2A] = "\0\0\0\0"
CmdDef[0x2B] = "\0\3\40\0\0\0\0"
CmdDef[0x2C] = "\0\0\0\0\0\0\0"
CmdDef[0x2D] = "\0"
CmdDef[0x2E] = "\0"
CmdDef[0x2F] = "\0\0\0\0\0\0\0\0"
CmdDef[0x30] = "\0\0\0\0\0\0\0\0"
CmdDef[0x31] = "\0\0\0\0\0\0\0\0\0"
CmdDef[0x32] = "\0\0\0\0\0\0\0\0"
if mmver == 8 then
	CmdDef[0x33] = "\0\0\0\0\0\0\1\0"
else
	CmdDef[0x33] = "\0\0\0\0\0\0\0"
end
CmdDef[0x34] = CmdDef[0x33]
CmdDef[0x35] = "\0"
CmdDef[0x36] = "\0\0\0\0\0\0\0\0"
CmdDef[0x37] = "\0\0\0\0\0\0\0\0"
CmdDef[0x38] = "\0\0"
CmdDef[0x39] = "\0\0\0\0\0\0\0\0\0"
CmdDef[0x3A] = "\0\0\0\0\1\0\0\0\0"
if mmver == 8 then
	CmdDef[0x3B] = "\7\18"
else
	CmdDef[0x3B] = "\4\18"
end
CmdDef[0x3C] = "\0\0\0\0\0\0\0\0\1"
CmdDef[0x3D] = "\0\0\0\0\0\0\0\0"
CmdDef[0x3E] = "\0\0\0"
CmdDef[0x3F] = "\0\0\0\0"
CmdDef[0x40] = "\0\0\0\0\0\0\0"
CmdDef[0x41] = "\0\0\0\0\0\0"
CmdDef[0x42] = "\0\0\0\0\220\5\0\0"
CmdDef[0x43] = "\0\0\0\0\0\0\0\0\0"
CmdDef[0x44] = "\0\0\0\0\0"

DeclareCommands()

----------- Enums

local SkillNamesList = {}
for k, v in pairs(const.Skills) do
	SkillNamesList[v + 1] = k
end

if mmver ~= 8 then
	evt.Players = {
		[0] = 0,
		[1] = 1,
		[2] = 2,
		[3] = 3,
		Current = 4,
		current = 4,
		All = 5,
		all = 5,
		Random = 6,
		random = 6,
	}
else
	evt.Players = {
		[0] = 0,
		[1] = 1,
		[2] = 2,
		[3] = 3,
		[4] = 4,
		All = 5,
		all = 5,
		Random = 6,
		random = 6,
		Current = 7,
		current = 7,
	}
end

PlayerToStr = {}

for k, v in pairs(evt.Players) do
	if type(k) ~= "number" and k ~= k:lower() then
		PlayerToStr[v] = k  -- "Players."..k
	end
end


do
	local p = 1
	evt.VarNum = {}
	VarNumToStr = {}
	local function add(name, name2)
		if name then
			evt.VarNum[name] = p
			VarNumToStr[p] = '"'..name..'"'
		end
		if name2 then
			evt.VarNum[name] = p
		end
		p = p + 1
	end
	
	add("SexIs")                     -- 01
	add("ClassIs")                   -- 02
	add("HP")                        -- 03
	add("HasFullHP")                 -- 04
	add("SP")                        -- 05
	add("HasFullSP")                 -- 06
	add("ArmorClass", "AC")          -- 07
	add("ArmorClassBonus", "ACBonus")-- 08
	add("BaseLevel")                 -- 09
	add("LevelBonus")                -- 0A
	add("AgeBonus")                  -- 0B
	add("Awards")                    -- 0C
	add("Experience", "Exp")         -- 0D
	add(nil)                         -- 0E : not used
	add(nil)                         -- 0F : not used
	add("QBits")                     -- 10
	add("Inventory")                 -- 11
	add("HourIs")                    -- 12
	add("DayOfYearIs")               -- 13
	add("DayOfWeekIs")               -- 14
	add("Gold")                      -- 15
	add("GoldAddRandom")             -- 16
	add("Food")                      -- 17
	add("FoodAddRandom")             -- 18
	add("MightBonus")                -- 19
	add("IntellectBonus")            -- 1A
	add("PersonalityBonus")          -- 1B
	add("EnduranceBonus")            -- 1C
	add("SpeedBonus")                -- 1D
	add("AccuracyBonus")             -- 1E
	add("LuckBonus")                 -- 1F
	add("BaseMight")                 -- 20
	add("BaseIntellect")             -- 21
	add("BasePersonality")           -- 22
	add("BaseEndurance")             -- 23
	add("BaseSpeed")                 -- 24
	add("BaseAccuracy")              -- 25
	add("BaseLuck")                  -- 26
	add("CurrentMight")              -- 27
	add("CurrentIntellect")          -- 28
	add("CurrentPersonality")        -- 29
	add("CurrentEndurance")          -- 2A
	add("CurrentSpeed")              -- 2B
	add("CurrentAccuracy")           -- 2C
	add("CurrentLuck")               -- 2D
	evt.VarNum.BaseStats = {}
	evt.VarNum.CurrentStats = {}
	for k, v in pairs(const.Stats) do
		if v < 7 then
			evt.VarNum.BaseStats[v] = assert(evt.VarNum["Base"..k])
			evt.VarNum.CurrentStats[v] = assert(evt.VarNum["Current"..k])
		end
	end
	if mmver == 6 then
		add("FireResistance")          -- 2E
		add("ElecResistance")          -- 2F
		add("ColdResistance")          -- 30
		add("PoisonResistance")        -- 31
		add("MagicResistance")         -- 32
		add("FireResBonus")            -- 33
		add("ElecResBonus")            -- 34
		add("ColdResBonus")            -- 35
		add("PoisonResBonus")          -- 36
		add("MagicResBonus")           -- 37
	else
		add("FireResistance")          -- 2E
		add("AirResistance")           -- 2F
		add("WaterResistance")         -- 30
		add("EarthResistance")         -- 31
		add("SpiritResistance")        -- 32
		add("MindResistance")          -- 33
		add("BodyResistance")          -- 34
		add(nil)                       -- 35 : LightResistance
		add(nil)                       -- 36 : DarkResistance
		add(nil)                       -- 37 : PhysResistance
		add(nil)                       -- 38 : MagicResistance
		add("FireResBonus")            -- 39
		add("AirResBonus")             -- 3A
		add("WaterResBonus")           -- 3B
		add("EarthResBonus")           -- 3C
		add("SpiritResBonus")          -- 3D
		add("MindResBonus")            -- 3E
		add("BodyResBonus")            -- 3F
		add(nil)                       -- 40 : LightResBonus
		add(nil)                       -- 41 : DarkResBonus
		add(nil)                       -- 42 : PhysResistance
		add(nil)                       -- 43 : MagicResistance
	end
	evt.VarNum.Skills = {}           -- 38-56/44-68/44-6A
	for i, v in ipairs(SkillNamesList) do
		evt.VarNum.Skills[i - 1] = p
		add(v.."Skill")
	end
	add("Cursed")                    -- 57/69/6B
	add("Weak")                      -- 58/6A
	add("Asleep")                    -- 59/6B
	add("Afraid")                    -- 5A/6C
	add("Drunk")                     -- 5B/6D
	add("Insane")                    -- 5C/6E
	add("PoisonedGreen")             -- 5D/6F
	add("DiseasedGreen")             -- 5E/70
	add("PoisonedYellow")            -- 5F/71
	add("DiseasedYellow")            -- 60/72
	add("PoisonedRed")               -- 61/73
	add("DiseasedRed")               -- 62/74
	add("Paralysed")                 -- 63/75
	add("Unconscious")               -- 64/76
	add("Dead")                      -- 65/77
	add("Stoned")                    -- 66/78
	add("Eradicated")                -- 67/79
	add("MainCondition")             -- 68/7A/7C
	evt.VarNum.MapVars = {}          -- 69-CC/7B-DE/7D-E0
	for i = 0, 99 do
		evt.VarNum.MapVars[i] = p
		add("MapVar"..i)
	end
	add("AutonotesBits")             -- CD/DF/E1
	add("IsMightMoreThanBase")       -- CE/E0
	add("IsIntellectMoreThanBase")   -- CF/E1
	add("IsPersonalityMoreThanBase") -- D0/E2
	add("IsEnduranceMoreThanBase")   -- D1/E3
	add("IsSpeedMoreThanBase")       -- D2/E4
	add("IsAccuracyMoreThanBase")    -- D3/E5
	add("IsLuckMoreThanBase")        -- D4/E6
	add("PlayerBits")                -- D5/E7/E9
	add(mmver ~= 8 and "NPCs" or nil)-- D6/E8
	add("ReputationIs")              -- D7/E9
	for i = 0, 5 do  add(nil)  end   -- D8-DD/... : something time-related in 0x90E85C/...
	add("Flying")                    -- DE/F0/F2
	add("HasNPCProfession")          -- DF/F1
	add("TotalCircusPrize")          -- E0/F2
	add("SkillPoints")               -- E1/F3
	add("MonthIs")                   -- E2/F4
	if mmver >= 7 then
		add("Counter1")                -- F5/F7
		add("Counter2")                -- F6
		add("Counter3")                -- F7
		add("Counter4")                -- F8
		add("Counter5")                -- F9
		add("Counter6")                -- FA
		add("Counter7")                -- FB
		add("Counter8")                -- FC
		add("Counter9")                -- FD
		add("Counter10")               -- FE/100
		for i = 0x101, 0x114 do
			add(nil)                     -- FF-112/101-114 : set something to current time and play sound (not used by CMP)
			                             -- (no metter what value you use) (the value set is never used)
		end
		add("Reputation")              -- 113/115
		evt.VarNum.History = {}        -- 114/116
		for i = 1, 29 do
			evt.VarNum.History[i] = p
			add("History"..i)
		end
		add("MapAlert")                -- 131/133
		add("BankGold")                -- 132/134
		add("Deaths")                  -- 133/135
		add("MontersHunted")           -- 134/136
		add("PrisonTerms")             -- 135/137
		add("ArenaWinsPage")           -- 136/138
		add("ArenaWinsSquire")         -- 137/138
		add("ArenaWinsKnight")         -- 138/13A
		add("ArenaWinsLord")           -- 139/13B
		add("Invisible")               -- 13A/13C
		add("IsWearingItem")           -- 13B/13D
		if mmver == 8 then
			add("Players")               -- 13E
		end
	end
	
	if mmver == 6 and evt.VarNum.MonthIs ~= 0xE2 or mmver == 7 and evt.VarNum.IsWearingItem ~= 0x13B or mmver == 8 and evt.VarNum.Players ~= 0x13E then
		error("wrong evt.VarNum")
	end
end
