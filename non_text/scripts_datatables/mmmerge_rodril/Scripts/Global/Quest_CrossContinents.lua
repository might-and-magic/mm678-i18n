
local VerdantNPC 	= 803
local RunChaosNPC	= 1092
local CCScrollID 	= {770, 771, 772}
local CCTimers 		= {}

vars.Quest_CrossContinents = vars.Quest_CrossContinents or {}

local QSet = vars.Quest_CrossContinents

QSet.GotReward 			= QSet.GotReward or {}
QSet.ContinentFinished 	= QSet.ContinentFinished or {}
QSet.MapBolster 		= Game.Bolster.Maps

---------------------------------------
-- Quest NPC's travels: Move Verdant to random Tavern or Boat of current map.

QSet.LastVerdantMove = QSet.LastVerdantMove or 0

local function MoveVerdant(MapIndex)
	MapIndex = MapIndex or Map.MapStatsIndex
	local Done
	for i,v in Game.HousesExtra do
		if v.Map == MapIndex then
			local CurT = Game.Houses[i].Type
			if CurT == const.HouseType.Boats or CurT == const.HouseType.Tavern then
				Done = evt.MoveNPC{VerdantNPC, i}
				break
			end
		end
	end
	if Done then
		QSet.LastVerdantMove = Game.Time
	end
end

---------------------------------------
-- Cross continent quest schedule:
-- 1. [Once] [Amount of exp equal to level 10]
--		Get message scroll from random chest, with meet request at one of time-travel points.
--
-- 2. [Once] [Party got message scroll] OR [Party casts Town Portal at dedicated spot, being experienced enough] OR [8 months since game start]
--		Start conversation with Verdant.
--			NOTE: Spread text across topics and time. Make option to reenter conversation, in case player accidently interrupted it.
--
-- 3. [Repeatable] [*Condition to meet Verdant* -- swaping her between random houses does not seem good idea]
--		An option to meet Verdant again for "Saving Goobers" progression, hints, talks.
--
-- 4. [Once per continent] [Party finishes continent story line]
-- 		Set timer, after which Verdant will "catch" party giving rewards and inspiring to start other stories.
--
-- 5. [Once] [All continents finished]
--		Catch party and lead into final quest.
--

	-- 1. Generate Message Scroll
-- Once generated, may be get back by "I lost it" topic.

if not QSet.ScrollGotten then

	function events.OpenChest(i)
		if not QSet.ScrollGenerated and Party[0].Experience > 50000 then
			local CurCont = TownPortalControls.GetCurrentSwitch()
			local ScrollID = CCScrollID[CurCont] or CCScrollID[1]
			for i,v in Map.Chests[i].Items do
				if v.Number == 0 then
					v.Number = ScrollID
					break
				end
			end
			QSet.ScrollGenerated = true
			vars.LostItems[ScrollID] = TownPortalControls.GetCurrentSwitch()
		end
	end

	function events.GotItem(i)
		if not QSet.ScrollGotten and table.find(CCScrollID, i) then
			QSet.ScrollGotten = true
		end
	end

end

	-- 2. Meet Verdant.

-- a) Enter meet place with scroll
if not QSet.GotMainQuest then

	TownPortalControls.StdDimDoorEvent = TownPortalControls.StdDimDoorEvent or TownPortalControls.DimDoorEvent
	function TownPortalControls.DimDoorEvent()
		TownPortalControls.StdDimDoorEvent()
		if QSet.ScrollGotten and not QSet.GotMainQuest then
			evt.SetNPCGreeting{VerdantNPC, 329} -- Special greet in that case.
			evt.SpeakNPC{VerdantNPC}
		end
	end

end

-- b) Cast Town Portal at dedicated spot, being overexperienced, but without message scroll.
if not QSet.MetVerdant then

	local InterruptDelay = 0
	function events.CanCastTownPortal(t)
		if not QSet.MetVerdant then
			local CurSwicth = TownPortalControls.GetCurrentSwitch()
			if CurSwicth == 4 and Game.Time > InterruptDelay then
				t.CanCast = false
				-- Verdant interrupts cast and speaks with party.
				evt.SpeakNPC{VerdantNPC}
			end
			-- Allow party to be rude and ignore girl - she won't interrupt second cast for 8 minutes.
			InterruptDelay = Game.Time + const.Minute*8
		end
	end

end

-- c) If party have not met her after 8 months of game time, she'll catch them.
if not QSet.MetVerdant then

	function events.AfterLoadMap()

		if not QSet.MetVerdant then

			if not QSet.MeetTime then
				QSet.MeetTime = Game.Time + const.Month*8

			elseif Game.Time > QSet.MeetTime then

				CCTimers.FirstCatch =
					CCTimers.FirstCatch or function()

					if Game.CurrentScreen == 0 and not (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) then
						RemoveTimer(CCTimers.FirstCatch)
						evt.SpeakNPC(VerdantNPC)
					end
				end
				Timer(CCTimers.FirstCatch, const.Minute*10, false)

				-- If party has ignored her, she'll "catch" again in two days.
				QSet.MeetTime = Game.Time + const.Day*2
			end

		end
	end

end

-- d) If Party have not started Enroth quest, Verdant will catch them to give the letter.
if not Party.QBits[1104] then

	function events.AfterLoadMap()
		if QSet.MetVerdant and not Party.QBits[1104] then
			local CurCont = TownPortalControls.GetCurrentSwitch()
			if CurCont == 3 then
				evt.Add{"QBits", 1104}
				evt.Add{"QBits", 1105}
				evt.ForPlayer(0).Add{"Inventory", 2125}
				evt.SetNPCGreeting{VerdantNPC, 330}
				evt.SpeakNPC{VerdantNPC}
			end
		end
	end

end

	-- 3. Ways to meet Verdant again.

-- a) Fixed spot for each continent: Regna, Free Haven, Evenmourn island.
if not QSet.QuestFinished then

	local MeetSpots = {185, 641, 1195}
	function events.AfterLoadMap()
		if QSet.MetVerdant and not QSet.QuestFinished then
			local CurCont = TownPortalControls.GetCurrentSwitch()
			if CurCont ~= QSet.VerdantAt and CurCont <= 3 and not QSet.HideVerdant then
				QSet.VerdantAt = CurCont
				evt.MoveNPC{VerdantNPC, MeetSpots[CurCont]}
			end
		end
	end

end

-- b) Connector stone - chargeable item, allows to speak with Verdant anywhere.
if not QSet.GotConnectorStone then

	local MapsForConnStone = {"oute3.odm", "7out02.odm", "out03.odm"} -- Sorpigal, Harmonadale, Alvar
	function events.AfterLoadMap()

		local CurCont = TownPortalControls.GetCurrentSwitch()
		if 	not QSet.GotConnectorStone
			and QSet.GotMainQuest
			and CurCont ~= QSet.StartedAt then

			local MapN = table.find(MapsForConnStone, Map.Name)
			local StartTime = Game.Time + const.Minute*5
			if MapN then

				CCTimers.ConnStone =
					CCTimers.ConnStone or function()

					if 	Game.CurrentScreen == 0
						and not (Party.EnemyDetectorRed or Party.EnemyDetectorYellow)
						and not Party.Flying
						and Game.Time > StartTime then

						RemoveTimer(CCTimers.ConnStone)
						QSet.GotConnectorStone = true
						evt.ForPlayer(0).Add{"Inventory", 624}
						vars.LostItems[625] = CurCont

						evt.SetNPCGreeting{VerdantNPC, 331}
						evt.SpeakNPC{VerdantNPC}
					end
				end
				Timer(CCTimers.ConnStone, false, const.Minute*2)
			end
		end

	end
	-- inspect UsableItems.lua

end

	-- 4. Catch party, after continent's story finished.
if not QSet.GotFinalQuest then

	function events.AfterLoadMap()

		QSet.ContinentFinished[1] = Party.QBits[228]
		QSet.ContinentFinished[2] = Party.QBits[783]
		QSet.ContinentFinished[3] = Party.QBits[784]

		local CurCont = TownPortalControls.GetCurrentSwitch()
		if CurCont < 4 and QSet.ContinentFinished[CurCont] and not QSet.GotReward[CurCont] then

			local RewCount = 0
			for k,v in pairs(QSet.GotReward) do
				RewCount = v and RewCount + 1 or RewCount
			end

			local CurGreet = 328 - CurCont
			evt.SetNPCGreeting{VerdantNPC, CurGreet}

			CCTimers.GiveReward =
				CCTimers.GiveReward or function(i)

				if i == VerdantNPC then
					if RewCount == 0 then
						-- Shared life ring.
						Mouse:ReleaseItem()
						Mouse.Item.Number = 543
						Mouse.Item.Identified = true

					elseif RewCount == 1 then
						-- Shared life ring.
						Mouse:ReleaseItem()
						Mouse.Item.Number = 543
						Mouse.Item.Identified = true

					elseif RewCount == 2 then
						-- Allow connector stone to cast "Divine Intervention".
						LocalFile(Game.NPCGreet[CurGreet])
						Game.NPCGreet[CurGreet][0] = Game.NPCGreet[CurGreet][0] .. " " .. Game.NPCText[2161]

						QSet.ImporvedConnector	= true
						QSet.AllStoriesFinished	= true
						QSet.ShowInterlude		= true
						QSet.MeetTime			= Game.Time + const.Month*2

					end

					QSet.GotReward[CurCont] = true
					RemoveTimer(CCTimers.RewCatch)
					events.Remove("EnterNPC", CCTimers.GiveReward)
				end
			end

			CCTimers.RewCatch =
				CCTimers.RewCatch or function()

				if Game.CurrentScreen == 0 and not (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) and not Party.Flying then
					evt.SpeakNPC{VerdantNPC}
				end
			end

			events.EnterNPC = CCTimers.GiveReward
			Timer(CCTimers.RewCatch, const.Minute*10, false)

		end

		if QSet.AllStoriesFinished and not QSet.GotFinalQuest then
			QSet.HideVerdant = true
			evt.MoveNPC{VerdantNPC, 0}
			QSet.FQCatchTime = QSet.FQCatchTime or Game.Time + const.Week

			if Game.Time >= QSet.FQCatchTime then
				CCTimers.RewCatch = function()
					if Game.CurrentScreen == 0 and not (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) and not Party.Flying then
						RemoveTimer(CCTimers.RewCatch)
						Party.QBits[1713] = true
						evt.SetNPCGreeting{VerdantNPC, 324}
						evt.Add{"Experience", 0} -- Quest animation
						QSet.GotFinalQuest = true
						QSet.ShowInterlude = false
						evt.SpeakNPC{VerdantNPC}
					end
				end

				Timer(CCTimers.RewCatch, const.Minute*10, false)
			end

		end

	end

end

--------------------------------------------
	-- Continent and "Hints" topics

-- Empty topics - placeholders.
NPCTopic{NPC = VerdantNPC, Branch = "", Slot = 0, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "", Slot = 1, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "", Slot = 2, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "", Slot = 3, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "", Slot = 4, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "", Slot = 5, Topic = ""}

NPCTopic{NPC = VerdantNPC, Branch = "Hints", Slot = 0, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "Hints", Slot = 1, Topic = ""}
NPCTopic{NPC = VerdantNPC, Branch = "Hints", Slot = 2, Topic = ""}

local CanShowContTopic = false
if not QSet.AllStoriesFinished then

	local function SetVerdantTopics(CurCont)
		local CurQuest = Quests["Verdant - ContTopic"]
		CurQuest.Texts.Topic	= Game.NPCTopic[1781 + CurCont]
		CurQuest.Texts.Ungive	= Game.NPCText[2153 + CurCont]

		CurQuest = Quests["Verdant - Hint"]

		if Party.QBits[611] and CurCont == 2 then
			CurQuest.StdTopic = 894
		elseif Party.QBits[612] and CurCont == 2 then
			CurQuest.StdTopic = 892
		else
			CurQuest.StdTopic = select(CurCont, 732, 888, 1359)
		end
	end

	function events.EnterNPC(i)
		if i == VerdantNPC then
			if not QSet.GotMainQuest then
				QSet.GotIntro1	= false
				QSet.GotIntro2	= false
				if QSet.MetVerdant then
					Quests["Verdant - FirstLine"].Texts.Topic = Game.NPCTopic[1779]
				end
			end

			local CurCont = TownPortalControls.GetCurrentSwitch()
			CanShowContTopic = QSet.GotMainQuest and not QSet.ContinentFinished[CurCont]

			SetVerdantTopics(CurCont <= 3 and CurCont or TownPortalControls.MapOfContinent(vars.LastOutdoorMap))
		end
	end

	NPCTopic{
		NPC 	= VerdantNPC,
		Name	= "Verdant - ContTopic",
		Branch 	= "",
		Slot 	= 0,
		CanShow = function() return CanShowContTopic end,
		Texts = {	Topic 	= "",
					Ungive 	= ""}
		}

	if not QSet.GotMainQuest then

		NPCTopic{
			NPC 	= VerdantNPC,
			Name	= "Verdant - FirstLine",
			Branch 	= "",
			Slot 	= 1,
			CanShow = function() return not QSet.GotMainQuest end,
			Ungive	 = function(t)
				if not QSet.MetVerdant then
					QSet.MetVerdant = true
					t.Texts.Topic	= Game.NPCTopic[1779]
					Message(Game.NPCText[2149])

				elseif not QSet.GotIntro1 then
					QSet.GotIntro1	= true
					t.Texts.Topic	= Game.NPCTopic[1779]
					Message(Game.NPCText[2150])

				elseif not QSet.GotIntro2 then
					QSet.GotIntro2	= true
					t.Texts.Topic	= Game.NPCTopic[1780]
					Message(Game.NPCText[2151])

				else
					QSet.GotMainQuest	= true
					CanShowContTopic	= true
					Message(Game.NPCText[2152])

					evt.Add{"Experience", 0} -- Quest animation
					evt.SetNPCGreeting{VerdantNPC, 328}
				end

			end,
			Texts = {	Topic 	= Game.NPCTopic[1778],
						Ungive 	= Game.NPCText[2149]}
			}

	end

end

NPCTopic{
	Topic	= Game.NPCTopic[732],
	Text	= Game.NPCGreet[26][1],
	NPC 	= VerdantNPC,
	Name	= "Verdant - HintsBranch",
	Branch 	= "",
	Slot 	= 1,
	Ungive	= function() QuestBranch("Hints") end,
	CanShow = function() return QSet.GotMainQuest end
	}

NPCTopic{
	Topic	= Game.NPCTopic[1781],
	Text	= Game.NPCText[2153],
	NPC 	= VerdantNPC,
	Name	= "Verdant - TTGuide",
	Branch 	= "Hints",
	Slot 	= 0
	}

NPCTopic{
	Topic	= Game.MapStats[204].Name,
	Text	= Game.NPCTopic[186],
	NPC 	= VerdantNPC,
	CanShow = function() return QSet.QuestFinished and Map.MapStatsIndex ~= 204 end,
	Ungive	= function()
		QuestBranch("")
		Message(Game.NPCTopic[186])
		Sleep(1024,1024)
		ExitCurrentScreen()
		Sleep(100,100)
		evt.MoveToMap{0,0,0,0,0,0,0,0,"Breach.odm"}
		end,
	Name	= "Verdant - BreachTravel",
	Branch 	= "Hints",
	Slot 	= 3
	}

if not QSet.AllStoriesFinished then

	NPCTopic{
		NPC 	= VerdantNPC,
		Name	= "Verdant - Hint",
		Branch 	= "Hints",
		Slot 	= 1,
		StdTopic = 732,
		CanShow = function() return not QSet.ContinentFinished[math.min(TownPortalControls.GetCurrentSwitch(), 3)] end
		}

end

NPCTopic{
	Topic 	= Game.NPCTopic[1788],
	Text 	= Game.NPCText[2160],
	NPC 	= VerdantNPC,
	Name	= "Verdant - ConStone",
	Branch 	= "Hints",
	Slot 	= 2,
	Ungive	= function() if not (evt.ForPlayer("All").Cmp{"Inventory", 624} or evt.ForPlayer("All").Cmp{"Inventory", 625}) then evt.ForPlayer(0).Add{"Inventory", 624} end end,
	CanShow = function() return QSet.GotConnectorStone end
	}

--------------------------------------------
	-- Final quest topics

if not QSet.QuestFinished then

	-- Interlude topic
	if not QSet.GotFinalQuest then

		NPCTopic{
			Topic	= Game.NPCTopic[1787],
			Text	= Game.NPCText[2159],
			NPC		= VerdantNPC,
			Name	= "Verdant - Fin_Inter",
			Branch	= "",
			Slot	= 0,
			CanShow	= function() return QSet.ShowInterlude end
			}

	end

	local function SetFinalQuest()
		QSet.GotInstructions = true
		if not Party.QBits[1713] then
			evt.Add{"QBits", 1713} -- QBit for quest note
		end
	end

	if not QSet.GotInstructions then

		NPCTopic{
			NPC		= VerdantNPC,
			Name	= "Verdant - Fin_1",
			Branch	= "",
			Slot	= 0,
			CanShow	= function() return QSet.GotFinalQuest and not QSet.QuestFinished and not QSet.GotInstructions end,
			Ungive  = function(t)
				if not QSet.GotInstructions then
					QSet.GotInstructions = true
					t.Texts.Topic = Game.NPCTopic[1786]
					t.Texts.Ungive = Game.NPCText[2158]
				else
					SetFinalQuest()
				end
			end,
			Texts	= {
				Topic	= Game.NPCTopic[1785],
				Ungive	= Game.NPCText[2157]
				}
			}

	end

	NPCTopic{
		NPC		= VerdantNPC,
		Name	= "Verdant - Fin_2",
		Branch	= "",
		Slot	= 0,
		CanShow	= function() return QSet.GotFinalQuest and not QSet.QuestFinished and QSet.GotInstructions end,
		Ungive	= SetFinalQuest,
		Texts	= {
			Topic	= Game.NPCTopic[1786],
			Ungive	= Game.NPCText[2158]
			}
		}

	local ChaosPortraits = {354, 358, 66, 167, 257, 273}
	local ChaosNames = {
		Game.NPCText[2709], -- "Anya Charo"
		Game.NPCText[2710], -- "Wan Ruchos"
		Game.NPCText[2711], -- "Noah Charo"
		Game.NPCText[2712], -- "Chan Os Wy"
		Game.NPCText[2713], -- "R.C. Wosch"
		Game.NPCDataTxt[RunChaosNPC].Name} -- "Runaway Chaos"

	local ChaosProfs = {24,33,77,42,65,0}
	local NPC = Game.NPC[RunChaosNPC]
	QSet.RiddlesAnswered = QSet.RiddlesAnswered or 0
	NPC.Pic			= ChaosPortraits[QSet.RiddlesAnswered+1] or ChaosPortraits[#ChaosPortraits]
	NPC.Name		= ChaosNames[QSet.RiddlesAnswered+1] or ChaosNames[#ChaosNames]
	NPC.Profession	= ChaosProfs[QSet.RiddlesAnswered+1] or ChaosProfs[#ChaosProfs]
	NPC.EventA	 	= 0
	NPC = nil

	local Riddles = {

	[ 1] = {text = Game.NPCText[2218], answer = Game.NPCText[2219]},
	[ 2] = {text = Game.NPCText[2220], answer = Game.NPCText[2221]},
	[ 3] = {text = Game.NPCText[2222], answer = Game.NPCText[2223]},
	[ 4] = {text = Game.NPCText[2224], answer = Game.NPCText[2225]},
	[ 5] = {text = Game.NPCText[2226], answer = Game.NPCText[2227]},
	[ 6] = {text = Game.NPCText[2228], answer = Game.NPCText[2229]},
	[ 7] = {text = Game.NPCText[2230], answer = Game.NPCText[2231]},
	[ 8] = {text = Game.NPCText[2232], answer = Game.NPCText[2233]},
	[ 9] = {text = Game.NPCText[2234], answer = Game.NPCText[2235]},
	[10] = {text = Game.NPCText[2236], answer = Game.NPCText[2237]},
	[11] = {text = Game.NPCText[2238], answer = Game.NPCText[2239]},

	}

	-- Reunite with friends
	-- Friend's text consist of: 1. Group leader greet if it is not random char 2. Place description 3. Hint.
	local FQGreets = {
	[1] = Game.NPCText[2241],
	[2] = Game.NPCText[2242],
	[3] = Game.NPCText[2243],
	[4] = Game.NPCText[2244]
	}

	local FQRndGreets = {
	[1] = Game.NPCText[2245],
	[2] = Game.NPCText[2246],
	[3] = Game.NPCText[2245],
	[4] = Game.NPCText[2246]
	}

	local FQPlaceDescriptions = {
	[1] = Game.NPCText[2247],
	[2] = Game.NPCText[2248],
	[3] = Game.NPCText[2249],
	[4] = Game.NPCText[2250]
	}

	local FQHints = {
	[1] = Game.NPCText[2251],
	[2] = Game.NPCText[2252],
	[3] = Game.NPCText[2253],
	[4]	= Game.NPCText[2254]
	}

	local FQRefuses = {
	[1] = Game.NPCText[2255],
	[2] = Game.NPCText[2256],
	[3] = Game.NPCText[2257]
	}

	local FQRiddleStart = {
	[1] = Game.NPCText[2258],
	[2] = Game.NPCText[2259],
	[3] = Game.NPCText[2260],
	[4] = Game.NPCText[2261]
	}

	QSet.GotFQHints = QSet.GotFQHints or 0
	QSet.HintByNPC = QSet.HintByNPC or {}
	QSet.FQMercRnd = QSet.FQMercRnd or {}

	for i = 1, 4 do
		NPCTopic{
				Topic	= Game.NPCTopic[1793],
				NPC		= i+771,
				Name	= "RunChaos - Hint" .. i,
				Branch	= "",
				Slot	= 0,
				Ungive	= function(t)
					local HId = QSet.HintByNPC[t.NPC]

					if not HId then
						HId = QSet.GotFQHints + 1
						QSet.GotFQHints = HId
						QSet["GotFQHint" .. HId] = true
						QSet.HintByNPC[t.NPC] = HId
						evt.Add{"Experience", 0}
					end

					t.StdTopic = 1789
					t.Texts.Topic = "Join"

					Message((QSet.FQMercRnd[t.NPC] and FQRndGreets[i] or string.format(FQGreets[i], Party[0].Name)) .. "\n" .. FQPlaceDescriptions[i] .. "\n" .. FQHints[HId])
				end
			}
	end

	NPCTopic{
		Topic	= Game.NPCTopic[1794],
		NPC		= RunChaosNPC,
		Name	= "RunChaos - RC",
		Branch	= "",
		Slot	= 0,
		CanShow = function() return QSet.GotFQHint2 and not QSet.CoughtChaos end,
		Ungive	= function(t)
			if QSet.GotFQHint3 and QSet.RiddlesAnswered >= 5 then
				if t.Texts.Topic == Game.NPCTopic[1792] then
					QSet.CoughtChaos = true
					NPCFollowers.Add(RunChaosNPC)
					evt.MoveNPC{RunChaosNPC, 0}
					if Game.CurrentScreen == 13 then
						RefreshHouseScreen()
					end
				else
					t.Texts.Topic = Game.NPCTopic[1792]
					Message(Game.NPCText[2262])
					Game.NPC[t.NPC].Name = Game.NPCDataTxt[RunChaosNPC].Name
				end
			else
				local Seed = math.random(1,3)
				local MessageText = FQRefuses[Seed]
				if Seed == 1 then
					ExitCurrentScreen()
					CCTimers.ExpelParty = CCTimers.ExpelParty or function()
						Message(MessageText)
						RemoveTimer(CCTimers.ExpelParty)
					end
					Timer(CCTimers.ExpelParty, const.Second, false)
				else
					Message(MessageText)
				end
			end
		end
	}

	QSet.RiddlesLeft = QSet.RiddlesLeft or {1,2,3,4,5,6,7,8,9,10,11}

	--local CurrentRiddle

	--function events.EnterNPC(NpcId)
	--	if NpcId == RunChaosNPC and #QSet.RiddlesLeft > 0 then
	--		CurrentRiddle = math.random(1,#QSet.RiddlesLeft)
	--	end
	--end

	NPCTopic{
		Topic	= Game.NPCTopic[1790],
		NPC		= RunChaosNPC,
		Name	= "RunChaos - Riddles",
		Branch	= "",
		Slot	= 1,
		Ungive	= function()

			if #QSet.RiddlesLeft == 0 then
				Message(Game.NPCText[2263])
				return
			end

			local CurrentRiddle = math.random(1,#QSet.RiddlesLeft)
			local riddle = Riddles[QSet.RiddlesLeft[CurrentRiddle]]
			local Answer = Question(FQRiddleStart[math.random(1, #FQRiddleStart)] .. "\n\n" .. riddle.text)

			if Game.CurrentScreen == 13 then
				evt.MoveNPC{RunChaosNPC, 0}
			end

			local MessageText

			if string.lower(Answer) == string.lower(riddle.answer) then
				MessageText = Game.NPCText[2264]
				table.remove(QSet.RiddlesLeft, CurrentRiddle)
				QSet.RiddlesAnswered = QSet.RiddlesAnswered + 1
			else
				MessageText = Game.NPCText[2265]
			end

			if QSet.RiddlesAnswered <= 5 or not QSet.GotFQHint4 then
				ExitCurrentScreen()
				CCTimers.Riddle = CCTimers.Riddle or function()
					local NPC = Game.NPC[RunChaosNPC]
					NPC.Pic			= ChaosPortraits[QSet.RiddlesAnswered+1] or ChaosPortraits[#ChaosPortraits]
					NPC.Name		= ChaosNames[QSet.RiddlesAnswered+1] or ChaosNames[#ChaosNames]
					NPC.Profession	= ChaosProfs[QSet.RiddlesAnswered+1] or ChaosProfs[#ChaosProfs]
					Message(MessageText)
					RemoveTimer(CCTimers.Riddle)
				end
				Timer(CCTimers.Riddle, const.Second, false)
			else
				Message(MessageText)
			end

		end,
		CanShow	= function() return QSet.GotFQHint3 and QSet.RiddlesAnswered < 5 or QSet.CoughtChaos end
		}

end

---------------------------------------------
-- Extra tweaks

-- Override exiting dialog with outdoor npc in case if dialog is branched
function events.Action(t)
	if t.Action == 113 and Game.CurrentScreen == 4 then
		if QuestBranch() ~= "" then
			t.Handled = true

			QuestBranch("")
			events.call("ShowNPCTopics", GetCurrentNPC())
		end
	end
end

-- No dimension door scrolls, untill party met Verdant
function events.ItemGenerated(Item)
	if not QSet.MetVerdant and Item.Number == 190 then
		Item.Number = math.random(177, 186)
	end
end

-- Compatibility with old savegames
function events.LoadMap(WasInGame)
	if not WasInGame then
		local VerTab = Game.NPC[VerdantNPC]
		local VerSrc = Game.NPCDataTxt[VerdantNPC]
		if VerTab.Name == "" or VerTab.Pic == 0 then
			for k,v in pairs({"EventA","EventB","EventC","EventD","EventE","EventF","Greet","House","Name","Pic"}) do
				VerTab[v] = VerSrc[v]
			end
		end
	end
end

-- Verdant's connector gem.
QSet.NextConRecharge = QSet.NextConRecharge or 0
function events.LeaveMap()
	if evt.Cmp{"Inventory", 625} and (TownPortalControls.GetCurrentSwitch() == 4 or Game.Time > QSet.NextConRecharge) then
		for iP, Player in Party do
			for i,v in Player.Items do
				if v.Number == 625 then
					v.Number = 624
				end
			end
		end
	end
end

local function NeedDivInt()
	if Party.PlayersArray[49].DevineInterventionCasts ~= 0 then
		return false
	end
	for i,v in Party do
		if v.HP < v:GetFullHP() or v.SP < v:GetFullSP() then
			return true
		end
	end
	return false
end

evt.UseItemEffects[624] = function(Target, Item)
	if QSet.ImporvedConnector and NeedDivInt() then
		CastSpellDirect(88)
	end

	if Game.CurrentScreen == 13 then
		return 3
	elseif Party.EnemyDetectorRed or Party.EnemyDetectorYellow then
		evt.PlaySound{142}
		Game.ShowStatusText(Game.GlobalTxt[480])
		return 0
	else
		Item.Number = 625
		QSet.NextConRecharge = Game.Time + math.random(const.Hour*6, const.Day*2)
		while Game.CurrentScreen ~= 0 do
			ExitCurrentScreen(false, true)
		end
		evt.PlaySound{157}
		evt.SpeakNPC{803}
		return 0
	end
end
