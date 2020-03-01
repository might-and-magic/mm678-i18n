
-- Pick portrait
Game.MapEvtLines:RemoveEvent(376)
evt.Hint[376] = mapvars.PortraitTaken and "" or evt.str[15]

evt.Map[376] = function()
	if mapvars.PortraitTaken then
		return
	end

	evt.SetTexture{15,"t2bs"}
	evt[0].Add{"Inventory", 1423}
	Party.QBits[778] = true

	evt.Hint[376] = ""
	mapvars.PortraitTaken = true
end
