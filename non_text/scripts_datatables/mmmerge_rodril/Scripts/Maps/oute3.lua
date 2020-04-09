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

function events.AfterLoadMap()
	LocalHostileTxt()
	Game.HostileTxt[185][0] = 0
	Party.QBits[183] = true -- Town portal
end

----------------------------------------
-- Loretta Fleise's fix prices quest

Game.MapEvtLines:RemoveEvent(15)
evt.house[15] = 470
evt.map[15] = function() StdQuestsFunctions.CheckPrices(470, 1523) end

Game.MapEvtLines:RemoveEvent(16)
evt.house[16] = 470
evt.map[16] = function() StdQuestsFunctions.CheckPrices(470, 1523) end

----------------------------------------
-- Dragon tower

if not Party.QBits[1180] then

	local function DragonTower()
		StdQuestsFunctions.DragonTower(-6152, -9208, 2700, 1180)
	end
	Timer(DragonTower, 5*const.Minute)

	function events.LeaveMap()
		RemoveTimer(DragonTower)
	end

end

Game.MapEvtLines:RemoveEvent(231)
evt.map[231] = function()
	if not Party.QBits[1180] and evt.ForPlayer("All").Cmp{"Inventory", 2106} then
		evt.Set{"QBits", 1180}
		StdQuestsFunctions.SetTextureOutdoors(84, 42, "t1swbu")
	end
end

evt.map[232] = function()
	if Party.QBits[1180] then
		StdQuestsFunctions.SetTextureOutdoors(84, 42, "t1swbu")
	end
end

----------------------------------------
-- Dimension door

evt.map[140] = function()
	if not evt.Cmp{"MapVar50", 1} then
		TownPortalControls.DimDoorEvent()
	end
end
