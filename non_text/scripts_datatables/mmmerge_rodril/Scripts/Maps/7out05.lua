
function events.AfterLoadMap()
	LocalHostileTxt()
	Game.HostileTxt[91][0] = 0

	evt.SetMonGroupBit {56,  const.MonsterBits.Hostile,  true}
	evt.SetMonGroupBit {55,  const.MonsterBits.Hostile,  Party.QBits[611]}
end

function events.ExitNPC(i)
	if i == 461 and not Party.QBits[761] then
		evt.SummonMonsters{3, 3, 5, Party.X, Party.Y, Party.Z + 400, 59}
		evt.SetMonGroupBit{59, const.MonsterBits.Hostile, true}
	end
end
