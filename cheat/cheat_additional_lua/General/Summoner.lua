	--TODO - Problems with this script: Cannot target ground, summons disappear after a few seconds, lack of documentation and then line specific TODOs
	local u2 = mem.u2
	
	local function isDruid(Caster, SP)--TODO Keys.IsPressed(const.Keys.CTRL) should be in a standalone function, or the isDruid function should be renamed to reflect this part.
		return Keys.IsPressed(const.Keys.CTRL) and Caster.SP >= SP and (Caster.Class == const.Class.Druid or Caster.Class == const.Class.GreatDruid or Caster.Class == const.Class.Warlock or Caster.Class == const.Class.ArchDruid)
	end
	
	local function changeSummonName(str)--TODO: Doesn't work (no A, B or C at the end of names when right clicking a summoned monster)
		for i = 1, #str do
			local c = str:sub(i,i)
			u2[0x4f7dfc + i - 1] = string.byte(c)
			u2[0x4f7e0c + i - 1] = string.byte(c)
			u2[0x4f7e1c + i - 1] = string.byte(c)
		end

		u2[0x4f7dfc + #str] = string.byte('A\0')
		u2[0x4f7e0c + #str] = string.byte('B\0')
		u2[0x4f7e1c + #str] = string.byte('C\0')	
	end
	
	local function DruidSummon(Spell, SP, str)--TODO where is Spell used in this function?
		local Caster = Party.PlayersArray[u2[0x51d822]]
		if isDruid(Caster, SP) then
			Caster.SP = Caster.SP + 25 - SP--TODO explain functionality. Also why are 25 SP always added? 
			changeSummonName(str)
			u2[0x51d820] = 0x52--TODO explain functionality
			u2[0x51d82a] = Caster:GetSkill(const.Skills.Earth)
		end		
	end
	
	function events.GetSpellSkill(t)
		local Spell = u2[0x51d820]
		-- Normal
		if Spell == 34 then -- stun
			DruidSummon(Spell, 1, 'Dire Wolf ')
		elseif Spell == 35 then -- slow
			DruidSummon(Spell, 2, 'Elf Archer ')--TODO a table was made for summons. Current continent can be getted. It really makes no sense for a druid to summon elves (I know they did it in H4, but there it was because the game was really unfinished and they needed to fill in the slots for animals that didn't make the cut)
		elseif Spell == 36 then -- Earth Resistance
			DruidSummon(Spell, 3, 'Elf Spearman ')
		elseif Spell == 37 then -- Deadly Swarm
			DruidSummon(Spell, 4, 'Griffin ')
		-- Expert
		elseif Spell == 38 then -- Stone Skin
			DruidSummon(Spell, 5, 'Wasp Warrior ')
		elseif Spell == 39 then -- Blades
			DruidSummon(Spell, 8, 'Genie ')
		elseif Spell == 40 then -- Stone to Flesh
			DruidSummon(Spell, 10, 'Efreeti ')
		-- Master
		elseif Spell == 41 then -- Rock Blast
			DruidSummon(Spell, 15, 'Wyvern ')
		elseif Spell == 42 then -- Telekinesis
			DruidSummon(Spell, 20, 'Unicorn ')
		elseif Spell == 43 then -- Death Blossom
			DruidSummon(Spell, 25, 'Thunderbird ')
		-- Grand Master
		elseif Spell == 44 then
			DruidSummon(Spell, 30, 'Phoenix ')
		elseif Spell == 0x52 and not Keys.IsPressed(const.Keys.CTRL) then--TODO explain functionality
			changeSummonName('Angel ')
		end
		
	end

