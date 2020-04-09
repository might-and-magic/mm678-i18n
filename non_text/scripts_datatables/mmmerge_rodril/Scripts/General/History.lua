
local LastContinent = -1

----------------------------------
--			History.txt			--
----------------------------------

-- continent id = txt file from EnglishT.lod
local HistoryFiles = {
[1] = "history.txt",
[2] = "mm7history.txt"
}

local ForwardHistory = {
[1] = {1},
[2] = {1,2}
}

local function CurrentHistory(Continent)
	vars.History = vars.History or {}
	vars.History[Continent] = vars.History[Continent] or {}

	return vars.History[Continent]
end

local function UpdateHistoryTxt(Continent)

	for i,v in Game.HistoryTxt do
		v.Text	= ""
		--v.Time	= 0
		v.Title	= ""
	end

	local History = HistoryFiles[Continent]
	if not History then
		return
	end

	History = Game.LoadTextFileFromLod(History)
	local Lines = string.split(History, "\13")
	if #Lines == 0 then
		return
	end

	table.remove(Lines, 1) -- remove header
	local cnt = 2
	local lim = Game.HistoryTxt.limit
	for i,line in ipairs(Lines) do
		local Words = string.split(line, "\9")
		local HistoryItem = Game.HistoryTxt[cnt]
		HistoryItem.Text	= Words[2]
		HistoryItem.Title	= Words[4]
		cnt = cnt + 1
		if cnt > lim then
			break
		end
	end

end

function events.LoadMap()
	local CurCont = TownPortalControls.MapOfContinent(Map.MapStatsIndex)
	local History = CurrentHistory(CurCont)

	for i,v in Party.History do
		Party.History[i] = History[i] or 0
	end

	if CurCont ~= LastContinent then
		UpdateHistoryTxt(CurCont)
	end
end

function events.AfterLoadMap()
	local CurCont = TownPortalControls.MapOfContinent(Map.MapStatsIndex)
	if ForwardHistory[CurCont] then
		for i,v in pairs(ForwardHistory[CurCont]) do
			Party.History[v] = i
			Game.HistoryTxt[v].Time = i
		end
	end
end

function events.LeaveMap()
	local CurCont = TownPortalControls.MapOfContinent(Map.MapStatsIndex)
	local History = CurrentHistory(CurCont)

	for i,v in Party.History do
		History[i] = v
	end

	LastContinent = CurCont
end

----------------------------------
--		Obelisk autonotes		--
----------------------------------

local ObeliskAutonotes = {
[1] = {8,9,10,11,12,13,14,15,16},
[2] = {309,310,311,312,313,314,315,316,317,318,319,320,322},
[3] = {442,443,444,445,446,447,448,449,450,451,452,453,454,455,456}
}

function events.LoadMap()
	local CurCont = TownPortalControls.MapOfContinent(Map.MapStatsIndex)

	if CurCont == LastContinent then
		return
	end

	local Obelisks = ObeliskAutonotes[CurCont]

	vars.ObeliskBits = vars.ObeliskBits or {}
	for _,v in pairs(ObeliskAutonotes) do
		for __,bit in pairs(v) do
			vars.ObeliskBits[bit] = vars.ObeliskBits[bit] or Party.AutonotesBits[bit]
			Party.AutonotesBits[bit] = false
		end
	end

	if Obelisks then
		for k,v in pairs(Obelisks) do
			Party.AutonotesBits[v] = vars.ObeliskBits[v]
		end
	end
end
