-- Dimension door

function events.TileSound(t)
	if t.X == 63 and t.Y == 59 then
		TownPortalControls.DimDoorEvent()
	end
end
