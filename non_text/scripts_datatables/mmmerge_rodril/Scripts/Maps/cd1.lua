local QuestionPlaceholder = Game.NPCText[499]

Game.MapEvtLines:RemoveEvent(69)
evt.hint[69] = ""
evt.Map[69] = function()
	if not evt.Cmp{"MapVar6", 1} then
		Game.NPCText[499] = evt.str[21] .. "\n" .. evt.str[14]
		local Answer = Question(Game.NPCText[499])
		if string.lower(Answer) == evt.str[16] then
			evt.Set{"MapVar6", 1}
			Game.ShowStatusText(evt.str[19])
		else
			evt.MoveToMap {-3136, 2240, 224, 1024, 0, 0, 0, 0, "0"}
			Game.ShowStatusText(evt.str[17])
		end
		Game.NPCText[499] = QuestionPlaceholder
	end
end
