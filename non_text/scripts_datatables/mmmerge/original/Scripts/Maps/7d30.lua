
-- Enter Throne Room

Game.MapEvtLines:RemoveEvent(416)
evt.Hint[416] = evt.str[20]
evt.Map[416] = function()
	if Party.QBits[612] or not Party.QBits[611]
		or Party.EnemyDetectorYellow
		or Party.EnemyDetectorRed then

		Game.ShowStatusText(evt.str[21])
	else
		evt.EnterHouse{220}
	end
end
