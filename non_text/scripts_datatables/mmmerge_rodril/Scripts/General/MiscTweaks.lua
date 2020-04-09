
	local NewCode

	-- Change main menu soundtrack.
	mem.IgnoreProtection(true)
	mem.u1[0x46103c] = 16
	mem.u1[0x4bd38d] = 16
	mem.IgnoreProtection(false)

	-- Override water settings from mm8.ini
	Game.PatchOptions.HDWTRCount = 14
	Game.PatchOptions.HDWTRDelay = 15

	-- 0x4b067b - increase amount of house sound sets
	mem.asmpatch(0x4b067d, "add eax, 0xbb8")
	mem.asmpatch(0x4b0683, "imul eax, eax, 0xa")

	-- Other kinds of sounds:
	mem.asmpatch(0x4a9b23, "movzx eax, word [ds:edi+0x4c]")

	-- Disable standart lich-transformation by evt.Set{"ClassIs", X}
	-- Use Party[Y].Face = Z, and SetCharFace(Y, Z) instead.
	-- Y - char id in party, Z - portrait id form "Character portraits.txt".

	mem.asmpatch(0x447dba, "jmp 0x447def - 0x447dba")

	-- Disable mind and soul immunity setting after lich-transformation, use
	--		Party[X].Resistances[7].Base = 65000
	--		Party[X].Resistances[8].Base = 65000

	mem.asmpatch(0x447d9b, "jmp absolute 0x447dad")
	mem.asmpatch(0x447d43, "jmp absolute 0x4482eb")

	-- Fix crown of final dominion (Remove unstackable "Of Dark" bonus)
	mem.asmpatch(0x48e7b7, "jmp absolute 0x48ec2d")
	-- Eclipse
	mem.asmpatch(0x48e73f, "jmp absolute 0x48ec2d")
	-- Staff of elements
	mem.asmpatch(0x48e86c, "jmp absolute 0x48e890")
	-- Ring of fusion
	mem.asmpatch(0x48e8f3, "jmp absolute 0x48e8fc")

	-- Reduce traveling cost from arena to four days and zero food.
	mem.asmpatch(0x446ee6, "push 0x0")
	mem.asmpatch(0x446f3c, "push 0x0")
	mem.nop(0x446f07, 3)

	-- Fix jumping on nonflat structures in outdoor maps.
	mem.asmpatch(0x47312d, [[
	cmp dword [ss:ebp-0x5c], ecx
	je @end

	mov eax, dword [ds:0xb7ca88]
	bt eax, 3
	jc @bad

	cmp dword [0xB21588], 100  ; max upward speed
	jg @bad
	cmp dword [0xB21588], -100  ; max downward speed
	jnl @end

	@bad:
	jmp absolute 0x47316c

	@end:
	]])

	-- fix flickering during crossing portals in indoor maps
	-- Use party Z instead of camera Z, when checking portals:
	mem.asmpatch(0x4af29c, "mov edx, dword [ds:0xB2155C]")
	-- Increase offset for MinX, MaxX, MinY, MaxY, MinZ
	mem.asmpatch(0x4af257, "push 0x7f")
	-- Increase offset for MaxZ
	mem.asmpatch(0x4af2ae, "add edi, 0x7f")

	-- make "spirit lash" work correctly and damage few party members
	mem.asmpatch(0x40548d, "jle 0x40546f - 0x40548d")

	-- Fix monsters flickering in indoor maps.
	function events.LoadMap()

		if not Map.IsIndoor() then
			return
		end

		local function fix(strData, strRoomData)
			local tData = mapvars[strData]
			if tData and type(tData) == "table" then
				for RoomId,Room in pairs(tData) do
					local RoomData = Map.Rooms[RoomId][strRoomData]
					for i,v in RoomData do
						RoomData[i] = -1
					end
					local count = 0
					for i,DataId in pairs(Room) do
						RoomData[i] = DataId
						count = count + 1
					end
					RoomData.count = count
				end
			else
				local cRoomId
				mapvars[strData] = {}
				for RoomId,Room in Map.Rooms do
					for i,DataId in Room[strRoomData] do
						cRoomId = Map.RoomFromPoint(Map[strRoomData][DataId])
						if cRoomId ~= RoomId and cRoomId ~= 0 then
							Room[strRoomData][i] = -1
						end
					end

					mapvars[strData][RoomId] = {}
					local RoomFix = mapvars[strData][RoomId]
					local pos = 0
					for i,v in Room[strRoomData] do
						if v >= 0 then
							RoomFix[pos] = v
							Room[strRoomData][pos] = v
							pos = pos + 1
						end
					end
					Room[strRoomData].count = pos
				end
			end
		end

		fix("RoomSpritesFix", "Sprites")
		fix("RoomLightsFix", "Lights")

		-- fix portals Z bounds
		local F
		for RoomId, Room in Map.Rooms do
			for _, FId in Room.Portals do
				F = Map.Facets[FId]
				F.MinZ = Room.MinZ
				F.MaxZ = Room.MaxZ
			end
		end

	end

	-- Fix evt.Question (was not supposed to be called outside houses in mm8, now it should)
	mem.asmpatch(0x4d9e95, [[
	test ecx, ecx
	je absolute 0x4d9f08
	test ecx, 3]])

	mem.asmpatch(0x44203a, [[
	mov dword [ds:ebp-0x8], eax
	cmp dword [ds:0x4f37d8], 0xd
	je absolute 0x44210a
	jmp absolute 0x44204a]])

	-- Don't show final cutscene, don't change map, just print image (cutscene can be shown by evt.ShowMovie)
	mem.asmpatch(0x4bd454, "push 4")
	mem.asmpatch(0x4bd88b, "jmp 0x4bd8c4 - 0x4bd88b")
	Game.PrintEndCard = function(Text, BackImg)
		if Text then
			Game.GlobalTxt[676] = Text
		end
		if BackImg then
			mem.copy(0x5014e0, BackImg, 11)
		end
		mem.call(0x4bd3e1)
	end

	-- Fix Ice Bolt spell selection for monsters.
	local IceBlast = "IceBlast"
	mem.hook(0x4522e0, function(d) d.ebx = mem.topointer(IceBlast) end)

	local IceBolt = "IceBolt"
	mem.autohook2(0x4522e9, function(d) d.ebx = mem.topointer(IceBolt) end)

	-- Show correct transition texts for mm6/7 maps.
	local TransTexts = {
	["7d18.blv"] = 9,
	["7d14.blv"] = 398,
	["mdr01.blv"] = 12,
	["mdk03.blv"] = 12,
	["mdr02.blv"] = 12,
	["d01.blv"] = 392,
	["7d16.blv"] = 412,
	["mdr03.blv"] = 12,
	["mdk05.blv"] = 12,
	["mdr04.blv"] = 12,
	["mdt01.blv"] = 12,
	["mdr05.blv"] = 12,
	["mdt02.blv"] = 12,
	["zddb01.blv"] = 22,
	["oracle.blv"] = 166,
	["mdt09.blv"] = 8,
	["mdt03.blv"] = 12,
	["sci-fi.blv"] = 451,
	["mdt10.blv"] = 15,
	["mdt04.blv"] = 12,
	["mdk01.blv"] = 12,
	["7d15.blv"] = 396,
	["mdk04.blv"] = 12,
	["mdt05.blv"] = 12,
	["mdk02.blv"] = 12,
	["d43.blv"] = 806,
	["d44.blv"] = 815,
	["d48.blv"] = 845}

	function events.GetTransitionText(t)
		local TextId = TransTexts[t.EnterMap]
		if TextId then
			t.TransId = TextId
		end
	end

	-- set const.Race
	const.Race = {
		Human 	 = 0,
		Vampire	 = 1,
		DarkElf	 = 2,
		Minotaur = 3,
		Troll	 = 4,
		Dragon	 = 5,
		Undead	 = 6,
		Elf		 = 7,
		Goblin	 = 8,
		Dwarf	 = 9,
		Zombie	 = 10
	}

	-- correct const.Class
	const.Class = {
		Archer			=	0,
		WarriorMage		=	1,
		MasterArcher	=	2,
		Sniper			=	3,
		Cleric			=	4,
		Priest			=	5,
		PriestLight		=	6,
		PriestDark		=	7,
		DarkElf			=	8,
		Patriarch		=	9,
		Dragon			=	10,
		GreatWyrm		=	11,
		Druid			=	12,
		GreatDruid		=	13,
		Warlock			=	14,
		ArchDruid		=	15,
		Knight			=	16,
		Cavalier		=	17,
		BlackKnight		=	18,
		Champion		=	19,
		Minotaur		=	20,
		MinotaurLord	=	21,
		Monk			=	22,
		Initiate		=	23,
		Master			=	24,
		Ninja			=	25,
		Paladin			=	26,
		Crusader		=	27,
		Hero			=	28,
		Villain			=	29,
		Ranger			=	30,
		Hunter			=	31,
		BountyHunter	=	32,
		RangerLord		=	33,
		Thief			=	34,
		Rogue			=	35,
		Assassin		=	36,
		Spy				=	37,
		Troll			=	38,
		WarTroll		=	39,
		Vampire			=	40,
		Nosferatu		=	41,
		Sorcerer		=	42,
		Wizard			=	43,
		Necromancer		=	44,
		Lich			=	45,
		ArchMage		=	46,
		nuAM			=	47,
		Peasant			=	48,
		nuPeas			=	49,
		HighPriest		=	50,
		MasterWizard	=	51,

	}

	-- Roster.txt processing
	mem.nop(0x494a67, 3)
	mem.hook(0x494a6a, function(d)

		local ClassConns = {

			necromancer  = 44,
			necromancer2 = 45,
			cleric 		 = 4,
			cleric2		 = 6,
			knight 		 = 16,
			knight2		 = 19,
			troll 		 = 38,
			troll2 		 = 39,
			minotaur 	 = 20,
			minotaur2 	 = 21,
			darkelf 	 = 8,
			darkelf2 	 = 9,
			vampire 	 = 40,
			vampire2 	 = 41,
			dragon 		 = 10,
			dragon2		 = 11
		} -- Use class indexes for rest.

		d.ecx = mem.u4[d.eax+8]
		local CurClassName = mem.string(d.ecx)
		d.eax = tonumber(CurClassName) or ClassConns[CurClassName] or const.Class[CurClassName] or 16

	end)

	-- Make Town Portal be always sccessfull for GM and always successfull for M if there are no hostile enemies.
	function events.CanCastTownPortal(t)
		t.Handled = true
		if t.Mastery == 4 or not (Party.EnemyDetectorRed or Party.EnemyDetectorYellow) then
			t.CanCast = true
		else
			t.CanCast = false
			Game.ShowStatusText(Game.GlobalTxt[480])
		end
	end

	-- Use Game.NPCNames during player selection to avoid screwing with names by gender.
	mem.hook(0x48e0f0, function(d)
		local NamesTable = Game.NPCNames[Game.CharacterPortraits[Party[0].Face].DefSex == 0 and "M" or "F"]
		Party[0].Name = NamesTable[math.random(1, #NamesTable)]
	end)

	-- negative value of FacetId leads to use facet itself instead of facet group.
	-- evt.SetFacetBit correction.
	mem.autohook(0x445d05, function(d)
		if Map.IsOutdoor() or d.ecx >= 0 or -d.ecx > Map.Facets.count -1 then return end
		d.ecx = math.abs(d.ecx)
		for k, v in pairs(const.FacetBits) do
			if v == d.edx then
				Map.Facets[d.ecx][k] = mem.u4[d.esp+4] == 1
				d.ecx = 0
			end
		end
	end)

	-- evt.SetTexture correction.
	mem.autohook(0x44597e, function(d)
		if d.ecx >= 0 then return end
		d.ecx = math.abs(d.ecx)
		local CurBitmap = mem.string(d.edx)
		local Facet = Map.Facets[d.ecx]
		if Facet.AnimatedTFT then
			for i,v in Game.TFTBin do
				if v.Name == CurBitmap then
					for a = i, i+255 do
						local TFT = Game.TFTBin[a]
						CurBitmap = TFT.Name
						CurBitmap = Game.BitmapsLod:LoadBitmap(CurBitmap)
						Game.BitmapsLod.Bitmaps[CurBitmap]:LoadBitmapPalette()
						TFT.Index = CurBitmap
						if not TFT.NotGroupEnd then
							break
						end
					end
					Facet.BitmapId = i
					break
				end
			end
		else
			CurBitmap = Game.BitmapsLod:LoadBitmap(CurBitmap)
			Game.BitmapsLod.Bitmaps[CurBitmap]:LoadBitmapPalette()
			Facet.BitmapId = CurBitmap
		end
		d.ecx = 0
	end)

	-- evt.SetSprite correction.
	mem.autohook(0x445bd2, function(d) --0x445bd2, 0x445bee
		if d.ecx >= 0  then return end
		d.ecx = math.abs(d.ecx)
		local DecName = mem.string(mem.u4[d.esp+4])
		Map.Sprites[d.ecx].Invisible = d.edx == 0
		if DecName ~= "0" then
			Map.Sprites[d.ecx].DecName = DecName
		end
	end)

	-- evt.SetLight correction.
	mem.autohook(0x445c9a, function(d)
		if d.ecx >= 0 then
			return
		end
		d.ecx = math.abs(d.ecx)
		Map.Lights[d.ecx].Off = d.edx == 0
		d.ecx = -1
	end)

	-- Trigger "LeaveMap" event during traveling by boats/stables.
	mem.autohook2(0x4b516b, function(d) -- 0x4bab72
		if Party.Gold >= d.ecx then
			internal.OnLeaveMap()
		end
	end)

	-- Need to inspect this, sometimes gives crahes at spacebar action:
	mem.asmpatch(0x4685d9, [[
	movsx ecx, word [ds:ecx+0x6b1458]
	cmp ecx, 0x7fff
	jnz @end
	xor ecx, ecx
	@end:
	]])

	-- Prevent looting of items too far away from party.
	local function GetDist(x,y,z)
		local px, py, pz  = XYZ(Party)
		return math.sqrt((px-x)^2 + (py-y)^2 + (pz-z)^2)
	end

	mem.autohook2(0x468514, function(d)
		local obj = Mouse:GetTarget()
		if d.edx ~= obj.Index or (obj.Kind == 2 and GetDist(XYZ(Map.Objects[obj.Index])) > 500) then
			d:push(0x4686a5)
			return true
		end
	end)

	-- Remove artifacts found limit
	function events.LoadMap(WasInGame)
		if not WasInGame then
			for i,v in Party.ArtifactsFound do
				Party.ArtifactsFound[i] = false
				break
			end
		end
	end
	mem.nop(0x44dd82, 7)
	mem.nop(0x4541b4, 7)

	-- Fix GM staff usage with Unarmed skill (Damage bonus).
	local UNARMED = const.Skills.Unarmed
	function events.CalcStatBonusBySkills(t)
		if t.Stat == const.Stats.MeleeDamageBase
			or t.Stat == const.Stats.MeleeDamageMin
			or t.Stat == const.Stats.MeleeDamageMax then

			if t.Player.ItemMainHand > 0 and t.Player.Skills[UNARMED] > 0 then
				local Item = t.Player.Items[t.Player.ItemMainHand]
				if Item.Broken then
					return
				end

				local ItemSkill = Game.ItemsTxt[Item.Number].Skill
				if ItemSkill == 0 then
					local US, UM = SplitSkill(t.Player:GetSkill(UNARMED))

					if UM > 1 then
						local SS, SM = SplitSkill(t.Player:GetSkill(const.Skills.Staff))

						if SM > 3 then
							local bonus = 0
							if UM == 2 then
								bonus = US
							elseif UM > 2 then
								bonus = US*2
							end
							t.Result = t.Result + math.max(bonus, SS)
						end
					end
				end
			end
		end
	end

	-- Repair unarmed skill dodge chance
	function events.GetArmorClass(t)
		local Skill, Mas = SplitSkill(t.Player:GetSkill(UNARMED))
		if Mas == 4 and math.random(1,100) < Skill then
			t.AC = 10000
		end
	end

	-- Fix Dragon's AC and Dmg bonuses by skill
	mem.IgnoreProtection(true)
	mem.u1[0x48cc04 + 1] = const.Class.Dragon
	mem.u1[0x48cc09 + 1] = const.Class.GreatWyrm

	mem.u1[0x48cca1 + 1] = const.Class.Dragon
	mem.u1[0x48cca6 + 1] = const.Class.GreatWyrm

	mem.u1[0x48e2e5 + 1] = const.Class.Dragon
	mem.u1[0x48e2e9 + 1] = const.Class.GreatWyrm
	mem.IgnoreProtection(false)

	function events.CalcStatBonusBySkills(t)
		if t.Stat == const.Stats.MeleeAttack
			or t.Stat == const.Stats.MeleeDamageBase then

			local mas, skill = SplitSkill(t.Player:GetSkill(const.Skills.DragonAbility))
			t.Result = t.Result + skill*mas
		end
	end

	-- Make zombie/lich dragon breath white projectile
	function events.DragonBreathProjectile(t)
		local PL = Party.PlayersArray[t.PlayerIndex]
		if PL.Face == 68 then
			t.ObjId = 8000
		end
	end

	-- Make regeneration skill and spell mm7-alike
	function events.RegenTick(Player)
		local Cond = Player:GetMainCondition()
		if Cond == 18 or Cond < 14 then
			local RegS, RegM = SplitSkill(Player:GetSkill(const.Skills.Regeneration))
			local RegP = RegS > 0 and 0.5 or 0
			RegP = RegP + RegS/10*RegM

			local Buff = Player.SpellBuffs[const.PlayerBuff.Regeneration]
			if Buff.ExpireTime > Game.Time then
				RegS, RegM = SplitSkill(Buff.Skill)
				RegP = RegP + RegS/10*RegM + 0.5
			end

			if RegP > 0 then
				local FHP = Player:GetFullHP()
				Player.HP = math.min(Player.HP + math.ceil(FHP*RegP/100), FHP)
			end
		end
	end

	-- Add a bit of sp regeneration by meditation skill
	function events.RegenTick(Player)
		local Cond = Player:GetMainCondition()
		if Cond == 18 or Cond == 17 or Cond < 14 then
			local RegS, RegM = SplitSkill(Player:GetSkill(const.Skills.Meditation))
			if RegM > 0 then
				local FSP	= Player:GetFullSP()
				--local RegP	= 0.25*(2^(RegM-1))/100
				--Player.SP	= math.min(FSP, Player.SP + math.ceil(FSP*RegP))
				local Add = RegM + math.floor(RegS/10)
				Player.SP = math.min(FSP, Player.SP + Add)
			end
		end
	end

	-- Correct resistances by Class/Race
	function events.CalcStatBonusByItems(t)

		local Res = t.Stat
		if not (Res >= 10 and Res <= 15) then
			return
		end

		local Race = GetRace(t.Player, t.PlayerIndex)

		if Race == 6 and (Res == 15 or Res == 14) then -- Lich's immunities
			t.Result = 65000
			t.Player.Resistances[6].Base = 65000
			t.Player.Resistances[7].Base = 65000

		elseif Race == 1 and Res == 14 then -- Vampire's mind immunity
			t.Result = 65000
			t.Player.Resistances[7].Base = 65000

		elseif Race == 4 and (Res == 13 or Res == 15) then -- Troll's Earth and Body resistance.
			t.Result = t.Result + 5

		elseif Race == 9 and (Res == 12 or Res == 13) then -- Dwarf's water and earth resistance.
			t.Result = t.Result + 5

		elseif Race == 5 then -- Dragon's bonuses
			t.Result = t.Result + 5

		end

	end

	local function PartyCanLearn(skill)
		for _,pl in Party do
			if pl.Skills[skill] == 0 and GetMaxAvailableSkill(pl, skill) > 0 then
				return true
			end
		end
		return false
	end

	local function PlayerCanLearn(skill)
		local pl = Party[math.max(Game.CurrentPlayer,0)]
		return pl.Skills[skill] == 0 and GetMaxAvailableSkill(pl, skill) > 0
	end

	-- Correct learn skills in single-school guilds.
	function events.DrawLearnTopics(t)
		if (t.HouseType >= 5 and t.HouseType <= 8) then
			t.Handled = true
			t.NewTopics[1] = 0x2b + t.HouseType
			t.NewTopics[2] = const.LearnTopics.Learning
		elseif (t.HouseType >= 9 and t.HouseType <= 11) then
			t.Handled = true
			t.NewTopics[1] = 0x2b + t.HouseType
			t.NewTopics[2] = const.LearnTopics.Meditation
		end
	end

	-- For characters without SP factor, but with Meditation skill - add linear amount of SP
	local gameSPStats = Game.Classes.SPStats
	local statSP = const.Stats.SP
	function events.CalcStatBonusBySkills(t)
		if t.Stat == statSP and gameSPStats[t.Player.Class] == 0 then
			local Skill, Mas = SplitSkill(t.Player.Skills[const.Skills.Meditation])
			t.Result = Skill * Mas
		end
	end

	mem.IgnoreProtection(true)
	mem.u4[0x48da9d] = 0x48da87
	mem.IgnoreProtection(false)

	-- Correct learn skills in temples
	function events.DrawLearnTopics(t)
		if t.HouseType == const.HouseType.Temple then
			t.Handled = true
			t.NewTopics[1] = const.LearnTopics.Unarmed
			t.NewTopics[2] = const.LearnTopics.Dodging
			t.NewTopics[3] = const.LearnTopics.Regeneration
			t.NewTopics[4] = const.LearnTopics.Merchant
		end
	end

	-- Clean out map of removed corpses and summons by shrinking Map.Monsters table.
	function events.LoadMap(WasInGame)
		local lim = Map.Monsters.limit
		if WasInGame and Map.Monsters.count >= lim then
			local MonsToKeep = {}
			local size = Map.Monsters[0]["?size"]

			for i,v in Map.Monsters do
				if v.AIState ~= const.AIState.Removed and not (v.Summoner ~= 0 and v.HP <= 0) then
					table.insert(MonsToKeep, i)
				end
			end

			for i,v in ipairs(MonsToKeep) do
				if i ~= v + 1 then
					mem.copy(Map.Monsters[i-1]["?ptr"], Map.Monsters[v]["?ptr"], size)
				end
			end

			Map.Monsters.count = math.min(#MonsToKeep, lim)
		end
	end

	-- Repair Town hall's bounty hunt topic:
	BountyHuntFunctions = {}
	local BountyText = ""
	local function CheckMon(MonId, MaxLevel)
		MaxLevel = MaxLevel or Party[0].LevelBase + 20
		return not Game.Bolster.MonstersSource[MonId].NoArena and Game.MonstersTxt[MonId].Level <= MaxLevel and not evt.CheckMonstersKilled{2, MonId - 1, 1}
	end
	BountyHuntFunctions.CheckMon = CheckMon

	local function SetCurrentHunt()
		vars.BountyHunt = vars.BountyHunt or {}

		local MonId, BountyText, BountyHunt
		local random = math.random

		if vars.BountyHunt[Map.Name] and Game.Month == vars.BountyHunt[Map.Name].Month then
			MonId = vars.BountyHunt[Map.Name].MonId
			if not MonId then
				vars.BountyHunt[Map.Name] = nil
				BountyHuntFunctions.SetCurrentHunt()
			end

			if vars.BountyHunt[Map.Name].Done or evt.CheckMonstersKilled{2, MonId - 1, 1} then
				if vars.BountyHunt[Map.Name].Claimed then
					BountyText = Game.NPCText[135]
				else
					local Reward = Game.MonstersTxt[MonId].Level * 100
					BountyText = string.replace(Game.NPCText[134], "%lu", tostring(Reward))
					BountyText = string.format(BountyText, Game.MonstersTxt[MonId].Name, tostring(Reward))

					for i,v in Party do
						v.Awards[43] = true
					end

					evt.ForPlayer("Current")

					evt.Add{"Gold", Reward}
					evt.Add{"MontersHunted", Reward}
					evt.Subtract{"Reputation", math.ceil(Reward/2000)}

					vars.BountyHunt[Map.Name].Claimed = true
				end
			else
				BountyText = string.replace(Game.NPCText[133], "%lu", tostring(Game.MonstersTxt[MonId].Level * 100))
				BountyText = string.format(BountyText, Game.MonstersTxt[MonId].Name)
			end

		else
			MonId = random(1, Game.MonstersTxt.count - 1)
			local lim = 30
			local MaxLevel = Party[0].LevelBase + 20
			while not CheckMon(MonId, MaxLevel) and lim > 0 do
				MonId = random(1, Game.MonstersTxt.count - 1)
				lim = lim - 1
			end
			vars.BountyHunt[Map.Name] = {}
			BountyHunt = vars.BountyHunt[Map.Name]
			BountyText = string.replace(Game.NPCText[133], "%lu", tostring(Game.MonstersTxt[MonId].Level * 100))
			BountyText = string.format(BountyText, Game.MonstersTxt[MonId].Name)

			local X, Y, Z
			if Map.IsIndoor() and Map.Facets.count > 0 then
				local Room = Map.Rooms[random(Map.Rooms.count-1)]
				local Facet
				if Room.Floors.count == 0 then
					Facet = Map.Facets[Room.Walls[random(Room.Walls.count-1)]]
				else
					Facet = Map.Facets[Room.Floors[random(Room.Floors.count-1)]]
				end
				X, Y, Z = Facet.MinX + (Facet.MaxX - Facet.MinX)/2, Facet.MinY + (Facet.MaxY - Facet.MinY)/2, Facet.MaxZ
			elseif Map.IsOutdoor() then
				X, Y, Z = random(-15000, 15000), random(-15000, 15000), 1000

				local Tile = Game.CurrentTileBin[Map.TileMap[(64 - Y / 0x200):floor()][(64 + X / 0x200):floor()]]
				local Cnt = 5
				while Cnt > 0 do
					if not Tile.Water then
						break
					end
					X, Y, Z = random(-15000, 15000), random(-15000, 15000), 1000
					Tile = Game.CurrentTileBin[Map.TileMap[(64 - Y / 0x200):floor()][(64 + X / 0x200):floor()]]
					Cnt = Cnt - 1
				end
			else
				X, Y, Z = random(-15000, 15000), random(-15000, 15000), 1000
			end

			local mon = SummonMonster(MonId, X, Y, Z)
			mon.Group = 39
			mon.Hostile = true
			mon.HostileType = 4

			local MonBuff = mon.SpellBuffs[const.MonsterBuff.Berserk]
			MonBuff.ExpireTime = Game.Time + const.Month
			MonBuff.Power = 4
			MonBuff.Skill = 4
			MonBuff.Caster = -1

			vars.BountyHunt[Map.Name] = {MonId = MonId, Month = Game.Month, Claimed = false, Done = false}
		end

		return BountyText

	end
	BountyHuntFunctions.SetCurrentHunt = SetCurrentHunt

	function events.LeaveMap()
		if not vars.BountyHunt then return end
		for k,v in pairs(vars.BountyHunt) do
			if v.MonId then
				v.Done = v.Claimed or v.Done or evt.CheckMonstersKilled{2, v.MonId - 1, 1}
			else
				vars.BountyHunt[k] = nil
			end
		end
	end

	NewCode = mem.asmproc([[
	nop
	nop
	nop
	nop
	nop
	jmp absolute 0x4bb3f0]])
	mem.asmpatch(0x4bae73, "jmp absolute " .. NewCode)
	mem.hook(NewCode, function(d)
		BountyText = BountyHuntFunctions.SetCurrentHunt()
		mem.u4[0xffd410] = mem.topointer(BountyText)
	end)
