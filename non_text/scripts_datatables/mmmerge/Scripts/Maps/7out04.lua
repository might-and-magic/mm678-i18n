-- Dimension door

function events.TileSound(t)
	if t.X == 84 and t.Y == 94 then
		TownPortalControls.DimDoorEvent()
	end
end

-- Clanker's Laboratory
Game.MapEvtLines:RemoveEvent(503)
evt.map[503] = function()

	if Party.QBits[710] then
		evt.MoveNPC{427, 395}
		Game.Houses[395].ExitMap = 86
		Game.Houses[395].ExitPic = 1
		evt.EnterHouse{395}
	else
		evt.MoveToMap{0,-709,1,512,0,0,395,9,"7d12.blv"}
	end

end
