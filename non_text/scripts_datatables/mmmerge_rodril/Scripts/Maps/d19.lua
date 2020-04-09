
Game.MapEvtLines:RemoveEvent(15)
evt.hint[15] = evt.str[2]
evt.map[15] = function()
	if Party.QBits[20] or Party.QBits[19] or evt.IsPlayerInParty(34) then
		evt.SetDoorState{5,0}
	elseif evt.Cmp{evt.VarNum.Invisible} then
		evt.FaceAnimation{Game.CurrentPlayer, 18}
	else
		evt.SetNPCGreeting{45, 107}
		evt.SpeakNPC{45}
	end
end
