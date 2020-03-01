
local JadamMaps		= {}
local AntagrichMaps	= {}
local EnrothMaps	= {}
local MapsExtra = Game.Bolster.MapsSource

local function IsJadam(i)
	return (i >= 0 and i <= 61) or table.find(JadamMaps, i)
end

local function IsAntagrich(i)
	return (i >= 62 and i <= 136) or table.find(AntagrichMaps, i)
end

local function IsEnroth(i)
	return (i >= 137 and i <= 203) or table.find(EnrothMaps, i)
end

function TownPortalControls.MapOfContinent(Map)

	local MapId

	if type(Map) == "string" then
		for i,v in Game.MapStats do
			if v.FileName == Map then
				MapId = i
				break
			end
		end
	elseif type(Map) == "number" then
		MapId = Map
	else
		return TownPortalControls.GetCurrentSwitch()
	end

	if not MapId then
		return TownPortalControls.GetCurrentSwitch()
	end

	if MapsExtra[MapId].Continent then return MapsExtra[MapId].Continent
	elseif 	IsJadam(MapId) 		then return 1
	elseif 	IsAntagrich(MapId) 	then return 2
	elseif 	IsEnroth(MapId) 	then return 3
	end

end

function TownPortalControls.CheckSwitch()

	local i = Map.MapStatsIndex
	local SwitchTo = TownPortalControls.SwitchTo

	if MapsExtra[i].Continent then SwitchTo(MapsExtra[i].Continent)
	elseif 	IsJadam(i) 			then SwitchTo(1)
	elseif 	IsAntagrich(i) 		then SwitchTo(2)
	elseif 	IsEnroth(i) 		then SwitchTo(3)
	end

end

function events.BeforeLoadMap()
	TownPortalControls.CheckSwitch()
end


