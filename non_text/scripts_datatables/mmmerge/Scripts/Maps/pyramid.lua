local QuestionPlaceholder = Game.NPCText[499]

-- VARN codes.

Game.MapEvtLines:RemoveEvent(1)
evt.hint[1] = evt.str[21]
evt.Map[1] = function()
	evt.Set{"MapVar0", 0}
	if evt.Cmp{"Inventory", 2157} then
		if evt.Cmp{"MapVar27", 1} then
			Game.NPCText[499] = evt.str[44]
			local Answer = string.lower(Question(""))
			if Answer == string.lower(evt.str[43]) then
				evt.Set{"MapVar15", 1}
				evt.Subtract{"Inventory", 2157}
				evt.Subtract{"QBits", 1255}
				evt.SetDoorState{1, 1}
				Game.ShowStatusText(evt.str[15])
			else
				Game.ShowStatusText(evt.str[45])
				evt.Subtract{"HP", 5}
				evt.FaceExpression{"Current", 44}
			end
			Game.NPCText[499] = QuestionPlaceholder
		else
			Game.ShowStatusText(evt.str[46])
			evt.Subtract{"HP", 25}
			evt.FaceExpression{"Current", 35}
		end
	end
end

local function SetCode(ItemId, CodeId, TextId, QuestionId, AnswerId, QBit, FaceExpr)
	evt.Set{"MapVar0", 0}
	if evt.Cmp{"Inventory", ItemId} then
		Game.NPCText[499] = evt.str[TextId] -- .. "\n" .. evt.str[AnswerId]

		local Answer = string.lower(Question(""))
		if Answer == string.lower(evt.str[AnswerId]) then

			evt.Set{"MapVar" .. CodeId, 1}
			local AllVars = true
			for i = 10, 14 do
				if not evt.Cmp{"MapVar" .. i, 1} then
					AllVars = false
					break
				end
			end

			if AllVars then
				evt.Set{"MapVar27", 1}
			end

			evt.ForPlayer("All").Subtract{"Inventory", ItemId}
			evt.Subtract{"QBits", QBit}

		else

			Game.ShowStatusText(evt.str[45])
			evt.FaceExpression{"Current", FaceExpr}
			evt.Subtract{"HP", 5}

		end

		Game.NPCText[499] = QuestionPlaceholder
	end
end

Game.MapEvtLines:RemoveEvent(21)
evt.hint[21] = evt.str[26]
evt.Map[21] = function() SetCode(2158, 10, 32, 44, 33, 1253, 48) end

Game.MapEvtLines:RemoveEvent(22)
evt.hint[22] = evt.str[26]
evt.Map[22] = function() SetCode(2159, 11, 34, 44, 35, 1256, 33) end

Game.MapEvtLines:RemoveEvent(23)
evt.hint[23] = evt.str[26]
evt.Map[23] = function() SetCode(2160, 12, 36, 44, 37, 1258, 50) end

Game.MapEvtLines:RemoveEvent(24)
evt.hint[24] = evt.str[26]
evt.Map[24] = function() SetCode(2161, 13, 38, 44, 39, 1257, 46) end

Game.MapEvtLines:RemoveEvent(25)
evt.hint[25] = evt.str[26]
evt.Map[25] = function() SetCode(2162, 14, 40, 44, 41, 1254, 13) end
