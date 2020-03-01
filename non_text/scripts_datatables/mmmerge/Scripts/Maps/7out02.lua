
-- Choose Judge quest

evt.Map[37] = function()
	NPCFollowers.Remove(416)
	NPCFollowers.Remove(417)
end

-- Enter castle Harmondale

Game.MapEvtLines:RemoveEvent(301)
evt.Hint = evt.str[30]
evt.Map[301] = function()
	if Party.QBits[519] then
		if Party.QBits[610] or Party.QBits[644] then
			if Party.QBits[610] then
				evt.MoveToMap{-5073, -2842, 1, 512, 0, 0, 382, 9, "7d29.blv"}
			else
				evt.MoveToMap{-5073, -2842, 1, 512, 0, 0, 390, 9, "7d29.blv"}
			end
		else
			Party.QBits[644] = true
			Party.QBits[587] = true

			evt.Add{"History3", 0}
			evt.MoveNPC {397, 240}
			evt.SpeakNPC{397}
		end
	else
		evt.FaceAnimation{Game.CurrentPlayer, const.FaceAnimation.DoorLocked}
	end
end

-- Mercenary guild - invasion

Party.QBits[608] = Party.QBits[611] or Party.QBits[612]

evt.Map[50] = function()
	if (Party.QBits[693] or Party.QBits[694]) and not (Party.QBits[702] or Party.QBits[695]) then
		mapvars.InvasionTime = mapvars.InvasionTime or Game.Time + const.Week*2
		if mapvars.InvasionTime < Game.Time then
			Party.QBits[695] = true
			evt.SetMonGroupBit {60,  const.MonsterBits.Hostile,  true}
			evt.SetMonGroupBit {60,  const.MonsterBits.Invisible, false}
			evt.Set{"BankGold", 0}
			evt.SpeakNPC{437}
		end
	end
end

-- Give "Scavenger hunt" advertisment

local CCTimers = {}

function events.AfterLoadMap()
	if not (mapvars.GotAdvertisment or Party.QBits[519] or evt.All.Cmp{"Inventory", 774}) then

		CCTimers.Catch = function()
			if not (Party.Flying or Party.EnemyDetectorRed or Party.EnemyDetectorYellow)
				and 4000 > math.sqrt((-13115-Party.X)^2 + (12497-Party.Y)^2) then

				mapvars.GotAdvertisment = true
				RemoveTimer(CCTimers.Catch)
				evt.ForPlayer(0).Add{"Inventory", 774}
				evt.SetNPCGreeting(649, 332)
				evt.SpeakNPC{649}

			end
		end
		Timer(CCTimers.Catch, false, const.Minute*3)

	end
end
