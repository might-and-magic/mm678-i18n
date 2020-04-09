
local function BadEnd()
	evt.ShowMovie{1,0,"mm6end2"}
	evt.PlaySound{130}

	-- exit to main menu
	--mem.u4[0x6ceb28] = 7
	DoGameAction(132, 0, 0, true)
	DoGameAction(132)
end

local function GoodEnd()
	evt.Subtract{"QBits", 1222}
	evt.Add{"QBits", 784}
	evt.Subtract{"Inventory", 2164}
	evt.ForPlayer("All").Set{"Awards", 78}

	evt.ShowMovie{1,0,"mm6end1"}
end

function events.CalcDamageToMonster(t)

	if (t.Monster.Id == 647 or t.Monster.Id == 648) and t.DamageKind == 4 then
		t.Result = math.random(2, 40)
	end

end

function events.MonsterKilled(mon)
	if mapvars.ReactorKilled and mon.Id == 646 then
		mapvars.QueenKilled = true
		Party.QBits[1226] = true

	elseif mon.Id == 647 or mon.Id == 648 then

		if evt.ForPlayer("All").Cmp{"Inventory", 2164} then
			mapvars.ReactorKilled = true

			evt.SetDoorState{30, 1}
			evt.SetDoorState{51, 0}
			evt.SetDoorState{52, 0}
			evt.SetDoorState{53, 1}

			evt.SummonMonsters{1, 1, 5, 6044, 21380, -2255, 0, 0}
			evt.SummonMonsters{1, 2, 5, 2780, 22390, -2255, 0, 0}
			evt.SummonMonsters{2, 1, 5, 4462, 24698, -2255, 0, 0}

			evt.ForPlayer("All").Set{"MainCondition", 0}
			evt.ForPlayer("All").Add{"HasFullHP", 0}
			evt.ForPlayer("All").Add{"HasFullSP", 0}

		else
			BadEnd()
		end

	end
end

function events.LeaveMap()
	if mapvars.ReactorKilled then
		if mapvars.QueenKilled then
			GoodEnd()
		else
			BadEnd()
		end
	end
end

function events.ShowDeathMovie(t)
	if mapvars.ReactorKilled and not mapvars.QueenKilled then
		t.movie = ""
	end
end

Game.MapEvtLines:RemoveEvent(60)
evt.hint[60] = evt.str[27]
evt.Map[60] = function()
	if evt.Cmp{"QBits", 1226} then
		evt.MoveToMap{0,0,0,0,0,0,0,0,"oute3.odm"}
	else
		evt.StatusText{25}
	end
end

