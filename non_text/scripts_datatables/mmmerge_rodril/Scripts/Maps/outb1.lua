
local TileSounds = {
[6] = {[0] = 90, 	[1] = 51}
}

function events.TileSound(t)
	local Grp = TileSounds[Game.CurrentTileBin[Map.TileMap[t.X][t.Y]].TileSet]
	if Grp then
		t.Sound = Grp[t.Run]
	end
end

----------------------------------------
-- Loretta Fleise's fix prices quest

Game.MapEvtLines:RemoveEvent(8)
evt.house[8] = 477
evt.map[8] = function() StdQuestsFunctions.CheckPrices(477, 1515) end

Game.MapEvtLines:RemoveEvent(9)
evt.house[9] = 477
evt.map[9] = function() StdQuestsFunctions.CheckPrices(477, 1515) end
