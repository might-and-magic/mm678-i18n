
-----------------------------------------
-- Rescue Emmanuel quest (mm6)

evt.Map[25] = function()
	if Party.QBits[1702] then
		NPCFollowers.Add(893)
	end
end
