
function events.AfterLoadMap()
	LocalHostileTxt()
	Game.HostileTxt[211][0] = 0
	Game.HostileTxt[211][173] = 2
	Game.HostileTxt[211][181] = 2
	Game.HostileTxt[173][211] = 1
	Game.HostileTxt[181][211] = 1
	Party.QBits[182] = true -- Town portal
end

----------------------------------------
-- Loretta Fleise's fix prices quest

Game.MapEvtLines:RemoveEvent(10)
evt.house[10] = 475
evt.map[10] = function() StdQuestsFunctions.CheckPrices(475, 1521) end

Game.MapEvtLines:RemoveEvent(11)
evt.house[11] = 475
evt.map[11] = function() StdQuestsFunctions.CheckPrices(475, 1521) end

----------------------------------------
-- Dragon tower

if not Party.QBits[1180] then

	local function DragonTower()
		StdQuestsFunctions.DragonTower(11032, -8940, 2830, 1182)
	end
	Timer(DragonTower, 5*const.Minute)

	function events.LeaveMap()
		RemoveTimer(DragonTower)
	end

end

Game.MapEvtLines:RemoveEvent(210)
evt.map[210] = function()
	if not Party.QBits[1182] and evt.ForPlayer("All").Cmp{"Inventory", 2106} then
		evt.Set{"QBits", 1182}
		StdQuestsFunctions.SetTextureOutdoors(117, 42, "t1swbu")
	end
end

evt.map[226] = function()
	if Party.QBits[1182] then
		StdQuestsFunctions.SetTextureOutdoors(117, 42, "t1swbu")
	end
end
