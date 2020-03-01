local TileSounds = {[6] = {[0] = 91, 	[1] = 52}}

function events.TileSound(t)
	local Grp = TileSounds[Game.CurrentTileBin[Map.TileMap[t.X][t.Y]].TileSet]
	if Grp then
		t.Sound = Grp[t.Run]
	end
end

function events.AfterLoadMap()
	LocalHostileTxt()
	Game.HostileTxt[196][0] = 0
	Party.QBits[181] = true -- Town portal

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

Game.MapEvtLines:RemoveEvent(10)
evt.house[10] = 478
evt.map[10] = function() StdQuestsFunctions.CheckPrices(478, 1516) end

Game.MapEvtLines:RemoveEvent(11)
evt.house[11] = 478
evt.map[11] = function() StdQuestsFunctions.CheckPrices(478, 1516) end

----------------------------------------
-- Kilburn's shield

function events.OpenChest(i)
	if not vars.LostItems[2119] and i == 1 then
 		local Chest = Map.Chests[i]

		for i,v in Chest.Items do
			if v.Number == 2119 then
				return
			end
		end

		local Item = Chest.Items[1]
		Item.Number = 2119
		Item.Bonus = 0
		Item.Bonus2 = 0
	end
end

----------------------------------------
-- Dragon tower

if not Party.QBits[1180] then

	local function DragonTower()
		StdQuestsFunctions.DragonTower(-17921, 9724, 2742, 1184)
	end
	Timer(DragonTower, 5*const.Minute)

	function events.LeaveMap()
		RemoveTimer(DragonTower)
	end

end

Game.MapEvtLines:RemoveEvent(211)
evt.map[211] = function()
	if not Party.QBits[1184] and evt.ForPlayer("All").Cmp{"Inventory", 2106} then
		evt.Set{"QBits", 1184}
		StdQuestsFunctions.SetTextureOutdoors(61, 42, "t1swbu")
	end
end

evt.map[213] = function()
	if Party.QBits[1184] then
		StdQuestsFunctions.SetTextureOutdoors(61, 42, "t1swbu")
	end
end
