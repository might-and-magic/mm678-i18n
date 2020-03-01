
function events.LoadMap()
	Party.QBits[185] = true -- Town portal

	-- stop winter quest
	if Party.QBits[1252] then
		Game.Bolster.MapsSource[Map.MapStatsIndex].Weather = true
	else
		Game.Bolster.MapsSource[Map.MapStatsIndex].Weather = false
		SetSkyTexture("sky04")
		Game.Weather.SetFog(100,1000)
		Sleep(100,100)
		evt.SetSnow{0,1}
	end

	-- Archers guards
	for i,v in Map.Monsters do
		if v.Group == 39 then
			v.Ally = 9999
			v.Hostile = false
		end
	end
end

----------------------------------------
-- Loretta Fleise's fix prices quest

Game.MapEvtLines:RemoveEvent(31)
evt.house[31] = 476
evt.map[31] = function() StdQuestsFunctions.CheckPrices(476, 1517) end

Game.MapEvtLines:RemoveEvent(32)
evt.house[32] = 476
evt.map[32] = function() StdQuestsFunctions.CheckPrices(476, 1517) end

----------------------------------------
-- Dragon tower

if not Party.QBits[1180] then

	local function DragonTower()
		StdQuestsFunctions.DragonTower(-6606, 15546, 2550, 1185)
	end
	Timer(DragonTower, 5*const.Minute)

	function events.LeaveMap()
		RemoveTimer(DragonTower)
	end

end

Game.MapEvtLines:RemoveEvent(210)
evt.map[210] = function()
	if not Party.QBits[1185] and evt.ForPlayer("All").Cmp{"Inventory", 2106} then
		evt.Set{"QBits", 1185}
		StdQuestsFunctions.SetTextureOutdoors(114, 42, "t1swbu")
	end
end

evt.map[214] = function()
	if Party.QBits[1185] then
		StdQuestsFunctions.SetTextureOutdoors(114, 42, "t1swbu")
	end
end
