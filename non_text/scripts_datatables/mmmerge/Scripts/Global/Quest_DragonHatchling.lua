
-- New NPC texts used: 1685, 1686, 1687, 1688

vars.Quest_DragonHatchling = vars.Quest_DragonHatchling or {}

local QSet = vars.Quest_DragonHatchling
local DragonNPC = 396

-- Refresh NPC's name.
function events.LoadMap(WasInGame)
	if not WasInGame and QSet.NameChosen then
		Game.NPC[DragonNPC].Name = QSet.DragonName
	end
end

-- Make warlock promotion quest acessblie from both light and dark side.
evt.Global[852]:clear()
evt.Global[852] = function()
	if (Party.QBits[1613] or Party.QBits[1614]) then
		if Party.QBits[611] or Party.QBits[612] then
			Message(Game.NPCText[1161])
			evt.Set{"QBits", 567}
			evt.SetNPCTopic{390, 0, 853}
		else
			Message(Game.NPCText[1163])
		end
	else
		Message(Game.NPCText[1162])
	end
end

-- Same for Arch Druid promotion quest.
evt.Global[850]:clear()
evt.Global[850] = function()
	if (Party.QBits[1613] or Party.QBits[1614]) then
		if Party.QBits[611] or Party.QBits[612] then
			Message(Game.NPCText[1156])
			evt.Set{"QBits", 566}
			evt.SetNPCTopic{389, 1, 851}
		else
			Message(Game.NPCText[1157])
		end
	else
		Message(Game.NPCText[1157])
	end
end

-- Override dismiss behaivor for hatchling - put him into NPCFollowers, don't send to Adventurer's Inn.
function events.DismissCharacter(t)

	local CharId = Party.PlayersIndexes[t.PlayerId]
	if CharId == QSet.DragonRosterId then
		NPCFollowers.Add(DragonNPC)
		Sleep(10) -- Allow engine's function to set bits.
		Party.QBits[CharId + 400] = false
		vars.MercenariesProps[CharId].CurContinent = -1
	end

end

-- Create Dragon player upon first hiring.
local function MakeDragonChar()
	local cHave, cNPC, cRosterId = NPCFollowers.HaveFreeMerc()
	if cHave then
		local Char = Party.PlayersArray[cRosterId]
		QSet.DragonRosterId = cRosterId
		GenerateMercenary{RosterId = cRosterId, Class = 10, Level = 1, Items = {}, Face = 71, Skills = {[const.Skills.DragonAbility] = 1, [const.Skills.Learning] = 1}}
		Char.Name = Game.NPC[DragonNPC].Name
		Char.BirthYear = Game.Year - 1
		Char.Biography = Char.Name .. " - " .. Game.ClassNames[Char.Class]

		vars.MercenariesProps[cRosterId] = {LastRefill = 0, CurContinent = -1, Hired = true}
	end
	return cHave
end

-- Feed Dragon
NPCTopic{
	NPC = DragonNPC,
	Branch = "",
	Slot = 0,
	Topic = Game.NPCText[1692], -- "Feed dragon"
	CanShow = function()
		return not QSet.DragonGrown
	end,
	Ungive = function()
		if QSet.DragonGrown then
			Message(Game.NPCText[1684])
			return
		end

		QSet.FirstFeed = QSet.FirstFeed or Game.Time
		QSet.FoodEaten = QSet.FoodEaten or 0
		if QSet.FoodEaten >= 100 then
			if Game.Time - QSet.FirstFeed > const.Month then
				QSet.DragonGrown = true
				Game.NPC[DragonNPC].Pic = Game.CharacterPortraits[71].NPCPic
				Message(Game.NPCText[1689]) -- "Dragon grown"
			else
				Message(Game.NPCText[1684]) -- "Dragon ate enough"
			end
		elseif Party.Food >= 5 then
			Party.Food = Party.Food - 5
			QSet.FoodEaten = QSet.FoodEaten + 5
			evt.PlaySound{205} -- error sound
		else
			evt.PlaySound{27} -- error sound
		end
	end}

-- Choose Dragon's name.
NPCTopic{
	NPC = DragonNPC,
	Branch = "",
	Slot = 0,
	Topic = Game.NPCTopic[789],
	CanShow = function()
		return QSet.DragonGrown and not QSet.NameChosen
	end,
	Ungive = function()
		local Name = Question(Game.NPCText[1685])
		if Name and string.len(Name) > 0 then
			local Answer = Question(string.format(Game.NPCText[1686], Name))
			if string.lower(Answer) == "y" then
				Game.NPC[DragonNPC].Name = Name
				QSet.DragonName = Name
				QSet.NameChosen = true
			end
		end
	end}

-- Move Dragon to Party.
NPCTopic{
	NPC = DragonNPC,
	Branch = "",
	Slot = 0,
	Topic =  Game.NPCTopic[616],
	CanShow = function()
		return QSet.DragonGrown and QSet.NameChosen
	end,
	Ungive = function()
		if not QSet.DragonRosterId and not MakeDragonChar() then
			Message(Game.NPCText[1687])
			return
		end
		if Party.count >= 5 then
			Message(Game.NPCText[1688])
			return
		end
		HireCharacter(QSet.DragonRosterId)
		NPCFollowers.Remove(DragonNPC)
		Sleep(100, 100)
		if Game.CurrentScreen == 4 then
			ExitCurrentScreen()
		end
	end}

