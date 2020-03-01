
local CreateButton, CreateIcon, Unload = CustomUI.CreateButton, CustomUI.CreateIcon, CustomUI.UnloadIcon
local SlJadam, SlEnroth, SlAntagrich, SlBackground

 -- Disable mm8 intro. Show it after continent selection.

 mem.nop(0x4a7bf3, 6)
 mem.asmpatch(0x4a7bf3, "jmp absolute 0x4a7c45")

 -- Process "Continent settings.txt"

local function ProcessContSets()

	local TxtTab = io.open("Data/Tables/Continent settings.txt", "r")
	if not TxtTab then
		Game.ContinentSettings = {[1] = {}, [2] = {}, [3] = {}, [4] = {}}

		Game.DeathMaps =	{{[1] = {n = "out01.odm", X = 3560, Y = 7696, Z = 544, Dir = 0},		[2] = {n = "out02.odm", X = 10219, Y = -15624, Z = 265, Dir = -12}},

							{[1] = {n = "7out01.odm", X = 12552, Y = 800, Z = 193, Dir = 512},		[2] = {n = "7out02.odm", X = -16832, Y = 12512, Z = 372, Dir = 0}},

							{[1] = {n = "oute3.odm", X = -9728, Y = -11319, Z = 160, Dir = 512}, 	[2] = {n = "oute3.odm", X = -9728, Y = -11319, Z = 160, Dir = 512}}}
		return
	end

	local ContSets = {}
	local DeathMaps = {}
	local LineIt = TxtTab:lines()

	LineIt() -- skip header
	for line in LineIt do
		local Words = string.split(line, "\9")

		table.insert(ContSets, {
			UseRep		= Words[3] == "x" or Words[4] == "x" or Words[5] == "x",
			RepGuards	= Words[3] == "x",
			RepShops	= Words[4] == "x",
			RepNPC		= Words[5] == "x",
			ProfNews	= Words[6] == "x",
			NPCFollowers= Words[7] == "x",
			Saturation	= tonumber(Words[8]),
			Softness	= tonumber(Words[9]),
			DeathMovie	= Words[10],
			Water		= string.split(string.replace(Words[11], " ", ""), ","),
			Skies		= string.split(string.replace(Words[22], " ", ""), ","),
			LoadingPics	= string.split(string.replace(Words[23], " ", ""), ",")
		})

		table.insert(DeathMaps, {	[1] = {n = Words[12], X = tonumber(Words[13]) or 0, Y = tonumber(Words[14]) or 0, Z = tonumber(Words[15]) or 0, Dir = tonumber(Words[16]) or 0},
									[2] = {n = Words[17], X = tonumber(Words[18]) or 0, Y = tonumber(Words[19]) or 0, Z = tonumber(Words[20]) or 0, Dir = tonumber(Words[21]) or 0}})
	end

	io.close(TxtTab)
	Game.ContinentSettings = ContSets
	Game.DeathMaps = DeathMaps

end
ProcessContSets()

 --	Menu

local SelectionStarted = false

local function SlCond()
	return SelectionStarted
end

local function SlChosen(StartMap, Continent)
	SlBackground.Active = false
	SlJadam.Active		= false
	SlEnroth.Active		= false
	SlAntagrich.Active	= false
	SelectionStarted	= false

	if StartMap then
		local Intros = {"intro", "7intro", "6intro"}
		Game.NewGameMap = StartMap
		TownPortalControls.SwitchTo(Continent)
		mem.u4[0x6ceb24] = 1
		mem.u4[0x51e330] = 1
		evt.ShowMovie{1, 0, Intros[Continent]}
	end

end

local function MOStd()
	evt.PlaySound{12100}
end

function events.GameInitialized2()

	SlBackground	= CreateIcon{Icon = "SlBackgr",
							Condition = function()
								if SelectionStarted and Keys.IsPressed(const.Keys.ESCAPE) then
									SlChosen()
								end
								return true
							end,
							Layer		= 1,
							Active		= false}

	SlJadam 		= CreateButton{IconUp = "SlJadamDw", IconDown = "SlJadamUp", IconMouseOver = "SlJadamUp",
							Action = function()
								SlChosen("out01.odm", 1)
							end,
							MouseOverAction = MOStd,
							Layer		= 1,
							IsEllipse 	= true,
							Active		= false,
							X = 208, Y = 31}

	SlAntagrich		= CreateButton{IconUp = "SlAntagDw", IconDown = "SlAntagUp", IconMouseOver = "SlAntagUp",
							Action = function()
								SlChosen("7out01.odm", 2)
							end,
							MouseOverAction = MOStd,
							Layer		= 0,
							IsEllipse 	= true,
							Active		= false,
							X = 322, Y = 228}

	SlEnroth		= CreateButton{IconUp = "SlEnrothDw", IconDown = "SlEnrothUp", IconMouseOver = "SlEnrothUp",
							Action = function()
								SlChosen("oute3.odm", 3)
							end,
							MouseOverAction = MOStd,
							Layer		= 0,
							IsEllipse 	= true,
							Active		= false,
							X = 94, Y = 229}

end

function events.MenuAction(t)

	if SelectionStarted and Game.CurrentScreen == 0 then
		t.Handled = true
		if t.Action == 113 then
			SlChosen()
		end

	elseif t.Action == 54 then
		t.Handled = true
		evt.PlaySound{66}
		SlBackground.Active = true
		SlJadam.Active		= true
		SlEnroth.Active		= true
		SlAntagrich.Active	= true
		SelectionStarted	= true

	elseif SelectionStarted and t.Action == 65 then
		SlChosen()

	end

end
