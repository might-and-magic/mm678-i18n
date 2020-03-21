
local HousesByMaps = {}
local ClassSelfImpressions = {}
local ClassTypes, ClassStages
local LastClass = {}
local NPCMercenaries = {} -- Connection between NPCData.txt and Roster.txt

local ClassTypesByContinent = {
	[1] = {2, 3, 6, 7, 12, 13, 15}, 		-- Jadam
	[2] = {1, 2, 5, 6, 8, 9, 10, 11, 14}, 	-- Antagrich
	[3] = {1, 2, 5, 6, 8, 9, 10, 11, 14}  	-- Enroth
}

local MercenariesQBits = {

	---- party creation:
	[37] = 437,
	[38] = 438,
	[39] = 439,
	[40] = 440,
	[41] = 441,
	---- random:
	[42] = 442,
	[43] = 443,
	[44] = 444,
	[45] = 445,
	[46] = 446,
	[47] = 447,
	[48] = 448,
	[49] = 449,
	---- service:
	[50] = 450,
	}

local function HireMercenary()

	if Party.count == 5 then
		Message(Game.NPCText[1681])
		QuestBranch("")
		return
	end

	local CurNPC  = GetCurrentNPC()
	local CurMerc = NPCMercenaries[CurNPC] or CurNPC - 261
	if not CurMerc or CurMerc < 0 or CurMerc > 49 then
		Message("Can not find assigned mercenary from roster.txt")
		return
	end

	HireCharacter(CurMerc)

	QuestBranch("")
	local IsHouse = Game.CurrentScreen == 13
	evt.MoveNPC{CurNPC, 0}
	if not IsHouse then
		for i,v in Map.Monsters do
			if v.NPC_ID == CurNPC then
				v.AIState = 19
			end
		end
	end

	NPCFollowers.Remove(CurNPC)
	ExitCurrentScreen(IsHouse)

end

evt.IsPlayerInParty = function(RosterId)
	for i,v in Party.PlayersIndexes do
		if v == RosterId then
			return true
		end
	end
	return false
end

local function EmptyTopic(NPC, Branch, Slot)
	Quest{
		NPC = NPC,
		Branch = Branch,
		Slot = Slot,
		Texts = {Topic = ""}
		}
end

local function ResetBranch()
	QuestBranch("")
end

local function YesNoBranch()
	QuestBranch("YesNo")
end

local function CurNpcNotInParty()
	return not evt.IsPlayerInParty(NPCMercenaries[GetCurrentNPC()])
end

local function SetJoinEvent(npc)

	if not Quests["Merc" .. npc] then

		Quest{
			NPC = npc,
			Name = "Merc" .. npc,
			Branch = "",
			Slot = 1,
			CanShow = CurNpcNotInParty,
			Ungive = YesNoBranch,
			Texts = {Topic = Game.NPCTopic[100], --"Join",
				Ungive = ""}
			}

		EmptyTopic(npc, "", 2)

		Quest{
			NPC = npc,
			Name = "Merc" .. npc .. "Yes",
			Branch = "YesNo",
			Slot = 1,
			Ungive = HireMercenary,
			Texts = {
				Topic = Game.GlobalTxt[704],
				Ungive = ""}
			}

		Quest{
			NPC = npc,
			Name = "Merc" .. npc .. "No",
			Branch = "YesNo",
			Slot = 2,
			Ungive = ResetBranch,
			Texts = {
				Topic = Game.GlobalTxt[705],
				Ungive = ""}
			}

		EmptyTopic(npc, "YesNo", 0)
		EmptyTopic(npc, "YesNo", 3)
		EmptyTopic(npc, "YesNo", 4)

	end

end
NPCFollowers.SetJoinEvent = SetJoinEvent

function GenerateMercenary(t) --RosterId, Class, Level, Skills, Items, Face, JoinText, Condition

	local RosterId, Class, Level, Skills, Items, Face, JoinText, Condition
	if type(t) == "table" then
		RosterId, Class, Level, Skills, Items, Face, JoinText, Condition = t.RosterId, t.Class, t.Level, t.Skills, t.Items, t.Face, t.JoinText, t.Condition
	elseif type(t) == "number" then
		RosterId = t
	else
		return false
	end

	local function CountExp(Level)
		local A = 0
		for i = 1, Level - 1 do
			A = A + i
		end
		return A * 1000
	end

	---- Character stats:

	local ClassByRace = Game.CharSelection.ClassByRace
		or {
			-- Human
		[0]	= {[0]=true,[4]=true,[12]=true,[16]=true,[22]=true,[26]=true,[30]=true,[34]=true,[42]=true,[44]=true},
			-- Vampire
		[1]	= {[40]=true},
			-- Dark elf
		[2]	= {[0]=true,[8]=true,[12]=true,[30]=true,[34]=true,[42]=true},
			-- Minotaur
		[3]	= {[4]=true,[12]=true,[16]=true,[20]=true},
			-- Troll
		[4]	= {[38]=true},
			-- Dragon
		[5]	= {[10]=true}}

	local PortraitsExceptions = Game.CharSelection.PortraitsExceptions
		or {
			-- Jadam
		{},
			-- Antagrich
		{8,9,10,11},
			-- Enroth
		{8,9,10,11}}

	Class = Class or math.random(0, Game.ClassNames.count-1)
	Level = Level or 5

	local Char = Party.PlayersArray[RosterId]
	local SkillPAmount = Level * 5 - 5

	vars.LastMercenaryPortraits = vars.LastMercenaryPortraits or {Party[0].Face}
	if not Face then
		local CurCont = TownPortalControls.GetCurrentSwitch()
		local Faces = {}
		local UniqueFaces = {}
		local ClassType = ClassTypes[Class]
		local ClassStart = ClassStages[ClassType][1]
		for i,v in Game.CharacterPortraits do
			if	v.Race ~= 10 -- zombie service race
				and(ClassTypes[v.DefClass] == ClassType or ClassByRace[v.Race] and ClassByRace[v.Race][ClassStart])
				and not table.find(PortraitsExceptions[CurCont], i) then

				table.insert(Faces, i)
			end
		end

		for k,v in pairs(Faces) do
			if not table.find(vars.LastMercenaryPortraits, v) then
				table.insert(UniqueFaces, v)
			end
		end

		if #UniqueFaces == 0 then
			vars.LastMercenaryPortraits = {}
			UniqueFaces = Faces
		end

		if #UniqueFaces == 0 then
			Face = math.random(0, 11)
		else
			Face = UniqueFaces[math.random(1, #UniqueFaces)]
		end
	end
	local Portrait = Game.CharacterPortraits[Face]
	local Names = Game.NPCNames[Portrait.DefSex == 0 and "M" or "F"]

	table.insert(vars.LastMercenaryPortraits, Face)

	Char.Face	= Face
	Char.Class	= Class
	Char.LevelBase	= Level
	Char.Experience = CountExp(Level)
	Char.Name	= Names[math.random(1, #Names)]
	Char.Voice	= Portrait.DefVoice

	-- Skills:

	local SkillLevels = {1, 4, 7, 10}
	local SkillPoints = {0, 9, 27, 54}

	if not Skills then
		Skills = {}
		local CurMax = math.ceil(4/50*Level)
		for k,v in Game.ClassKinds.StartingSkills[math.floor(Class/2)] do
			if v > 0 then
				Skills[k] = math.min((v == 2 and 1 or 0) + CurMax, 4)
			end
		end
	end

	for i,v in Char.Skills do
		Char.Skills[i] = 0
	end

	for k,v in pairs(Skills) do
		local CurMax = math.min(Game.Classes.Skills[Class][k], v)
		if CurMax > 0 then
			while CurMax > 0 do
				local Cost = SkillPoints[CurMax]
				if SkillPAmount - Cost >= 0 then
					Char.Skills[k] = JoinSkill(SkillLevels[CurMax], CurMax)
					SkillPAmount = SkillPAmount - Cost
					break
				end
				CurMax = CurMax - 1
			end
		end
	end

	Char.Skills[22] = math.max(GetMaxAvailableSkill(Char, 22) > 0 and 1 or 0, Char.Skills[22])
	Char.Skills[21] = math.max(GetMaxAvailableSkill(Char, 21) > 0 and 1 or 0, Char.Skills[21])

	Char.SkillPoints = SkillPAmount

	-- Items:

	for i,v in Char.Inventory do
		Char.Inventory[i] = 0
	end

	for i,v in Char.EquippedItems do
		Char.EquippedItems[i] = 0
	end

	for i,v in Char.Items do
		v.Number = 0
	end

	if not Items then
		-- Staff, Sword, Dagger, Axe, Spear, Bow, Mace, Blaster, Shield, Leather, Chain, Plate
		local ItemsBySkills = {[0] = 30, 23, 24, 25, 26, 27, 28, 11, 5, 31, 32, 33}
		Items = {}
		for i,v in Char.Skills do
			if #Items > 5 then
				break
			end
			if v > 2 then
				table.insert(Items, ItemsBySkills[i] or 22)
			end
		end
		for i,v in Game.ClassKinds.StartingSkills[math.floor(Class/2)] do
			if #Items > 5 then
				break
			end
			if v == 2 then
				table.insert(Items, ItemsBySkills[i] or 22)
			end
		end
		if #Items < 3 then
			table.insert(Items, 22)
			table.insert(Items, 11)
			table.insert(Items, 0)
		end
	end

	local ItemQuality = math.min(math.ceil(Level/8) + math.random(0, 1), 5)
	local mItem = Mouse.Item

	local CurMouseItem = mem.string(mItem["?ptr"], mItem["?size"], true)

	for i,v in ipairs(Items) do
		mItem:Randomize(ItemQuality, v)
		mItem.Identified = true
		GiveMouseItemDirectly(RosterId)
	end

	if Char.Class == const.Class.Peasant then
		mItem.Number = 1660
		mItem.Identified = true
		GiveMouseItemDirectly(RosterId)
	end

	mem.copy(mItem["?ptr"], CurMouseItem)

	-- Base stats:
	Char.AgeBonus = 0

	for i = 264, 270 do
		Char.UsedBlackPotions[i] = false
	end

	if vars and vars.PotionBuffs then
		vars.PotionBuffs.UsedPotions[RosterId] = {}
	end

	local Race = Game.CharacterPortraits[Char.Face].Race

	for i,v in Game.Classes.StartingStats[Race] do
		Char.Stats[i].Base = v.Add == 1 and math.ceil((v.Base + v.Max)/2) or v.Add < 1 and v.Base or v.Add > 1 and v.Max
	end
	local SPStat = Game.Classes.SPStats[Class]
	if SPStat == 1 or SPStats == 0 then
		Char.Stats[2].Base = Char.Stats[2].Base - Game.Classes.StartingStats[Race][2].Add*2
		Char.Stats[3].Base = Char.Stats[3].Base + Game.Classes.StartingStats[Race][3].Add*2
	end
	if SPStat == 2 or SPStats == 0 then
		Char.Stats[1].Base = Char.Stats[1].Base - Game.Classes.StartingStats[Race][1].Add*2
		Char.Stats[5].Base = Char.Stats[5].Base + Game.Classes.StartingStats[Race][5].Add*2
	end

	local BonusStatsPool = math.ceil(Level*1.5)
	while BonusStatsPool > 0 do
		for i = 0, 6 do
			local CurBonus = math.random(0, 4)
			Char.Stats[i].Base = Char.Stats[i].Base + CurBonus
			BonusStatsPool = BonusStatsPool - CurBonus
		end
	end

	-- Spells:
	for i = 0, Char.Spells.count - 1 do
		Char.Spells[i] = false
	end
	for i = 0, 8 do
		local CurS, CurM = SplitSkill(Char.Skills[i+12])
		for iL = 0 + i*11, CurS + i*11 - 1 do
			Char.Spells[iL] = true
		end
	end
	for i = 9, 11 do
		local CurS, CurM = SplitSkill(Char.Skills[i+12])
		for iL = 0 + i*11, CurM + i*11 - 1 do
			Char.Spells[iL] = true
		end
	end

	-- Resistances:
	for i = 0, 10 do
		Char.Resistances[i].Base = 0
	end

	if Class == 45 then
		Char.Resistances[7].Base = 65000
		Char.Resistances[8].Base = 65000
	end

	if Class == 40 or Class == 41 then
		Char.Resistances[7].Base = 65000
	end

	--------
	---- NPC appearance and dialog:

	for i,v in Char.Awards do
		Char.Awards[i] = false
	end

	Char.BirthYear = math.random(1132, 1154)
	Char.Biography = Char.Name .. " - " .. Game.ClassNames[Char.Class]
	Char.HP = Char:GetFullHP()
	Char.SP = Char:GetFullSP()

	for i,c in Char.Conditions do
		Char.Conditions[i] = 0
	end

	local CurNPC = table.find(NPCMercenaries, RosterId)

	if CurNPC then
		local CurQuest = Quests["Merc" .. CurNPC]

		if not CurQuest then
			SetJoinEvent(CurNPC)
			CurQuest = Quests["Merc" .. CurNPC]
		end

		Game.NPC[CurNPC].Name = Char.Name
		Game.NPC[CurNPC].Pic = Portrait.NPCPic

		CurQuest.Texts.Ungive = JoinText or string.format(Game.NPCText[1680], Char.Name, ClassSelfImpressions[math.min(math.ceil(Level/10), 5)], Game.ClassNames[Class])
		if Condition then
			CurQuest.Ungive = function()
				if Condition() then
					QuestBranch("YesNo")
				end
			end
		end
	end

	return true

end

function events.GameInitialized2()

	ClassSelfImpressions = string.split(Game.NPCText[1682], ",")

	ClassTypes	= {}
	ClassStages	= {}
	for k,v in pairs(Game.ClassesExtra) do
		ClassStages[v.Kind] = ClassStages[v.Kind] or {}
		ClassStages[v.Kind][v.Step + 1] = k
		ClassTypes[k] = v.Kind
	end

	if Game.CharSelection then
		local ClassByCont = Game.CharSelection.ClassesByContinent
		ClassTypesByContinent = {}
		for kR,vR in pairs(ClassByCont) do
			ClassTypesByContinent[kR] = {}
			for kL,vL in pairs(vR) do
				ClassTypesByContinent[kR][kL] = ClassTypes[vL]
			end
		end
	end

	math.randomseed(os.time())
	for i,v in Game.HousesExtra do
		local CurType = Game.Houses[i].Type
		if CurType ~= 29 then
			HousesByMaps[v.Map] = HousesByMaps[v.Map] or {}
			HousesByMaps[v.Map][CurType] = HousesByMaps[v.Map][CurType] or {}
			table.insert(HousesByMaps[v.Map][CurType], i)
		end
	end

	Game.HousesByMaps = HousesByMaps

end

function events.DismissCharacter(t)

	local CurMerc = Party.PlayersIndexes[t.PlayerId]
	local CurProps = vars.MercenariesProps[CurMerc]
	local CurCont = TownPortalControls.GetCurrentSwitch()

	if not CurProps then
		vars.MercenariesProps[CurMerc] = {LastRefill = 0, CurContinent = 0, Hired = false}
		CurProps = vars.MercenariesProps[CurMerc]
	end

	TownPortalControls.CheckSwitch()

	CurProps.Hired 			= true
	CurProps.LastRefill 	= Game.Time
	CurProps.CurContinent 	= CurCont

	local Bit = MercenariesQBits[Party.PlayersIndexes[t.PlayerId]] or (Party.PlayersIndexes[t.PlayerId] + 400)
	if Bit then
		Party.QBits[Bit] = true
	end

end

local function HaveFreeMerc()

	local MercProps
	for k,v in pairs(NPCMercenaries) do
		vars.MercenariesProps[v] = vars.MercenariesProps[v] or {LastRefill = -const.Year, CurContinent = 0, Hired = false}
		MercProps = vars.MercenariesProps[v]
		if not (MercProps.Hired or evt.IsPlayerInParty(v)) then
			return true, k, v
		end
	end

	return false

end
NPCFollowers.HaveFreeMerc = HaveFreeMerc

function events.LoadMap(WasInGame)

	TownPortalControls.CheckSwitch()

	if not WasInGame then

		vars.MercenariesProps = vars.MercenariesProps or {}
		vars.FreeMercenaries = vars.FreeMercenaries or {[303] = 42,[304] = 43,[305] = 44,[306] = 45,[307] = 46,[308] = 47,[309] = 48,[310] = 49}
		NPCMercenaries = vars.FreeMercenaries

		for k, v in pairs(NPCMercenaries) do
			if evt.IsPlayerInParty(v) then
				evt.MoveNPC{v+261, 0}
			end
			local Char = Party.PlayersArray[v]
			if not (Quests and Quests["Merc" .. k]) then
				SetJoinEvent(k)
			end
			Game.NPC[k].Name = Char.Name
			Quests["Merc" .. k].Texts.Ungive = string.format(Game.NPCText[1680], Char.Name, ClassSelfImpressions[math.min(math.ceil(Char.LevelBase/10), 5)], Game.ClassNames[Char.Class])
		end

	end

	local CurContinent	= TownPortalControls.GetCurrentSwitch()

	if CurContinent ~= LastContinent then
		for k,v in pairs(vars.MercenariesProps) do
			if not MercenariesQBits[k] then
				MercenariesQBits[k] = 400 + k
			end
			if mapvars.AllMercenaries then
				Party.QBits[MercenariesQBits[k]] = v.Hired
			else
				Party.QBits[MercenariesQBits[k]] = v.Hired and (v.CurContinent == CurContinent)
			end
			if evt.IsPlayerInParty(k) then
				evt.MoveNPC{k+261, 0}
			end
		end
	end

	if mapvars.LastMercsRefill ~= Game.Month and CurContinent ~= 4 and math.random(1,6) > Party.count then

		mapvars.LastMercsRefill = Game.Month

		local CurClass
		local NeedNewMerc, CurNPC, CurMerc = HaveFreeMerc()

		if NeedNewMerc then

			if evt.IsPlayerInParty(CurMerc) or (vars.NPCFollowers and table.find(vars.NPCFollowers, CurNPC)) then
				return
			end

			local MercProps = vars.MercenariesProps[CurMerc]

			MercProps.Hired 		= false
			MercProps.LastRefill 	= Game.Time
			Party.QBits[MercenariesQBits[CurMerc] or (CurMerc + 400)] = false

			CurClass = ClassTypesByContinent[CurContinent] or {2, 6, 14}
			if #CurClass > #LastClass then
				for k,v in pairs(LastClass) do
					local i = table.find(CurClass, v)
					if i then
						table.remove(CurClass, i)
					end
				end
			end

			local MaxClass = table.find(ClassStages[ClassTypes[Party[0].Class]], Party[0].Class) or 1

			CurClass = ClassStages[CurClass[math.random(1, #CurClass)]]
			CurClass = CurClass[math.random(1, math.min(MaxClass, #CurClass))]

			table.insert(LastClass, 1, CurClass)
			if #LastClass > 5 then
				table.remove(LastClass)
			end

			GenerateMercenary{RosterId = CurMerc, Level = math.max(Party[0].LevelBase + math.random(-5, 8), 1), Class = CurClass}

			local CurHouse = HousesByMaps[Map.MapStatsIndex] and (HousesByMaps[Map.MapStatsIndex][30] or HousesByMaps[Map.MapStatsIndex][21])
			if CurHouse then
				evt.MoveNPC{CurNPC, CurHouse[math.random(1, #CurHouse)]}
			end

		end

	end

end

-- Make button in Adventurer's inn to dismiss merc forever.
local LastDismissClick = 0
local function GetSelectedMerc()
	if Game.CurrentScreen == 29 then
		return mem.u4[mem.u4[0x100614c] + 0x130]
	else
		return Game.CurrentPlayer
	end
end

local function IsChooseCharScreen()
	return mem.u1[0x10061a0] == 1
end

local function IsQuestMerc(CharId)
	if CharId == 0 then
		return true
	elseif CharId == 34 and not (Party.QBits[19] or Party.QBits[20]) then
		return true
	elseif CharId == 4 and not Party.QBits[59] then
		return true
	end
end

local function DismissMercForever()
	local MercId = GetSelectedMerc()

	if LastDismissClick + 2 > os.time() then
		if evt.IsPlayerInParty(MercId) then
			if Party.count > 1 then
				Party.QBits[400+MercId] = true
				DismissCharacter(Game.CurrentPlayer)
			else
				evt.PlaySound{27}
				return
			end
		else
			if IsQuestMerc(MercId) then
				evt.PlaySound{27}
				return
			end

			local NPCId = 261 + MercId
			Party.QBits[MercId + 400] = false
			evt.MoveNPC{NPCId, 0}
			NPCMercenaries[NPCId] = MercId
			vars.MercenariesProps[MercId] = {LastRefill = -const.Year, CurContinent = 0, Hired = false}
		end

		LastDismissClick = 0
		RefreshAdevnturerInn() -- HardcodedTopicFunctions.lua

	else
		Game.ShowStatusText(Game.GlobalTxt[738])
		LastDismissClick = os.time()
		evt.PlaySound{205}
	end
end

function events.GameInitialized2()

	CustomUI.CreateButton{
		IconUp		  = "but26u",
		IconDown	  = "but26d",
		IconMouseOver = "but26h",

		Condition = IsChooseCharScreen,

		X = 520, Y = 415,

		Action	= DismissMercForever,
		Layer	= 0,
		Screen	= 29
	}
end
