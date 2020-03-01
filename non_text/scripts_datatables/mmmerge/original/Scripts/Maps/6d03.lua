-----------------------------------------
-- Rescue Sherry Carnegie quest (mm6)

evt.Map[22] = function()
	if Party.QBits[1703] then
		NPCFollowers.Add(978)
	end
end
