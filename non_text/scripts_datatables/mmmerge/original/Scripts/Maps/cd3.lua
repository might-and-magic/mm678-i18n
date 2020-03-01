local QuestionPlaceholder = Game.NPCText[499]

-- Guardian of Kriegspire

Game.MapEvtLines:RemoveEvent(13)
evt.hint[13] = evt.str[8]
evt.Map[13] = function()
	if Party.QBits[1364] then
		evt.MoveToMap {13487, 3117, 673, 0, 0, 0, 0, 0, "0"}
	else
		Game.NPCText[499] = evt.str[9]
		local Answer = string.lower(Question(evt.str[9]))
		if (Answer == string.lower(evt.str[11]) or Answer == string.lower(evt.str[12])) and Party.Gold >= 50000 then
			evt.Subtract{"Gold", 50000}
			evt.MoveToMap {13487, 3117, 673, 0, 0, 0, 0, 0, "0"}
		else
			Game.ShowStatusText(evt.str[13])
		end
		Game.NPCText[499] = QuestionPlaceholder
	end
end

-- Kurator of Kriegspire

Game.MapEvtLines:RemoveEvent(27)
evt.hint[27] = evt.str[14]
evt.Map[27] = function()

	Game.NPCText[499] = evt.str[15]
	local Answer = string.lower(Question(evt.str[15]))
	if (Answer == string.lower(evt.str[11]) or Answer == string.lower(evt.str[12])) and Party.Gold >= 10000 then
		evt.ForPlayer(0)
		evt.Subtract{"Gold", 10000}
		evt.Add{"Reputation", 50}

		evt.ForPlayer("All")
		evt.Set{"MainCondition", 0}
		evt.Add{"HasFullHP", 0}
		evt.Add{"HasFullSP", 0}
	else
		Game.ShowStatusText(evt.str[13])
	end
	Game.NPCText[499] = QuestionPlaceholder

end

