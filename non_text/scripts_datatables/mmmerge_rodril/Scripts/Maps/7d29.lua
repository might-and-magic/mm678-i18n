
-- Golem quest (wizard first promotion) (mm7)

evt.Map[376] = function()
	if Party.QBits[585] or Party.QBits[586] then
		NPCFollowers.Remove(395)
	end
end-- Golem join part is in StdQuestsFollowers.lua

-- Rest cost

function events.CalcRestFoodCost(t)
	if Party.QBits[610] then
		t.Amount = 0
	end
end

--

function events.LeaveMap()
	if Party.QBits[695] and evt.CheckMonstersKilled{1, 60, 0, 6} then
		Party.QBits[696] = true
		Party.QBits[702] = Party.QBits[696] and Party.QBits[697]
		Party.QBits[695] = not Party.QBits[702]
	end
end

Game.MapEvtLines:RemoveEvent(377)
function events.LoadMap()
	if Party.QBits[526] and Party.QBits[695] and not (Party.QBits[696] or Party.QBits[702]) then
		evt.SetMonGroupBit{60, const.MonsterBits.Hostile, true}
		evt.SetMonGroupBit{60, const.MonsterBits.Invisible, false}
		evt.Set{"BankGold", 0}
		evt.Subtract {"QBits", 693}
		evt.Subtract {"QBits", 694}
	else
		evt.SetMonGroupBit{60, const.MonsterBits.Hostile, false}
		evt.SetMonGroupBit{60, const.MonsterBits.Invisible, true}
	end
end

