-- Final part of Cross continents quest
local QSet = vars.Quest_CrossContinents
if QSet and QSet.GotFinalQuest then

	function events.CanCastTownPortal(t)
		if 600 > math.sqrt((15103-Party.X)^2 + (-9759-Party.Y)^2) then
			t.CanCast = false
			evt.MoveToMap{0,0,0,0,0,0,0,0, QSet.QuestFinished and "Breach.odm" or "BrAlvar.odm"}
		end
	end

end
