
function events.LoadMap()
	for i = 5, 8 do
		evt.SetDoorState(i, 1)
	end
	for i = 9, 10 do
		evt.SetDoorState(i, 0)
	end
end

--Game.MapEvtLines:RemoveEvent(51)
