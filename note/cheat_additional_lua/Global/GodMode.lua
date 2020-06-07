local mmver = Game.Version

function god(lev)
	-- get all spells
	for _,pl in Party do
		for i in pl.Spells do
			pl.Spells[i] = true
		end
	end

	-- get all learned skills to Master 12
	for _, pl in Party do
		for i, val in pl.Skills do
			-- if val ~= 0 then
				local skill, mastery = SplitSkill(val)
				pl.Skills[i] = JoinSkill(math.max(skill, 12), math.max(mastery, const.GM))
			-- end
		end
	end
		
	-- level 20 to all
	for _,pl in Party do
		pl.LevelBase = math.max(pl.LevelBase, 20)
	end
	
	-- clear conditions
	for _, a in Party do
		for i in a.Conditions do
			a.Conditions[i] = 0
		end
	end

	-- full HP, SP
	for _,pl in Party do
		pl.HP = pl:GetFullHP()
		pl.SP = pl:GetFullSP()
	end
	
	Game.NeedRedraw = true
end
