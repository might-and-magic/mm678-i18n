
-- Weather states from 0 - sunny to 7 - storm, 5 - raining, 0,1,2,3,4 - sky and fog setups.
-- EaxEnvironments: 5 - Stoneroom, 8 - Cave, 15 - Forest, 16 - City, 22 - Underwater, 26 - Plains/Mountain
local MapExtra
local WeatherState
local EffectActive	= false
local CurrentEffect	= 0
local SkyStates = {}

local function ResetWeather()
	CustomUI.ShowSFTAnim()
end

local function GenerateWeatherState()

	if not Map.IsOutdoor() or table.find({5,8,22}, Game.MapStats[Map.MapStatsIndex].EaxEnvironments) then
		WeatherState = 0
		mapvars.LastWeatherState = WeatherState
		mapvars.LastVisitDay = Game.DayOfMonth
		return
	end

	if mapvars.LastWeatherState and mapvars.LastVisitDay and mapvars.LastVisitDay == Game.DayOfMonth then
		WeatherState = mapvars.LastWeatherState or 0

	else
		local Continent = TownPortalControls.GetCurrentSwitch()

		WeatherState = (Game.Hour > 21 or Game.Hour < 5) and 1 or 0
		WeatherState = WeatherState + Game.Month < 3 and 1 or Game.Month < 6 and 2 or Game.Month < 9 and 0 or Game.Month < 12 and 1
		WeatherState = WeatherState + math.random(0, #SkyStates[Continent]-2)
		WeatherState = math.max(WeatherState, 0)
		mapvars.LastWeatherState = WeatherState
	end
	mapvars.LastVisitDay = Game.DayOfMonth
	return WeatherState
end

function SetSkyTexture(texture)
	if texture == nil or texture == "" then
		return
	end

	local SkyBitmap = Game.BitmapsLod:LoadBitmap(texture)
	Game.BitmapsLod.Bitmaps[SkyBitmap]:LoadBitmapPalette()
	Map.LoadedSkyBitmap = SkyBitmap
end

local CustomSky = false
local function SetSky()

	local Continent = TownPortalControls.GetCurrentSwitch()
	local SkySet = SkyStates[Continent]

	WeatherState = WeatherState or 1
	WeatherState = math.min(WeatherState, #SkySet)

	local SkyBitmap = CustomSky or SkySet[WeatherState]

	SetSkyTexture(SkyBitmap)

end

local function SetWeatherEffect()

	local Continent = TownPortalControls.GetCurrentSwitch()
	WeatherState = mapvars.LastWeatherState
	WeatherState = WeatherState or 0

	if WeatherState > math.floor(#SkyStates[Continent]/2) then
		if evt.CheckSeason{3} or (evt.CheckSeason{2} and math.random(0,1) == 1) then
			CurrentEffect = 0
		else
			CurrentEffect = 2
		end
	else
		CurrentEffect = -1
	end
	mapvars.CurrentWeatherEffect = CurrentEffect
end

local function SetWeather()
	local Continent = TownPortalControls.GetCurrentSwitch()
	WeatherState = WeatherState or 0
	if Game.IsD3D then
		if WeatherState > math.floor(#SkyStates[Continent]/3) then
			Game.Weather.New()
			Game.Weather.FogRange1 = math.floor(4096/WeatherState*2)
			Game.Weather.FogRange2 = math.floor(8096/WeatherState*2)
			Game.Weather.Fog = true
		else
			Game.Weather.Fog = false
		end
	end
	SetWeatherEffect()
end

local MapWeather
local function WeatherTimer()
	WeatherState = WeatherState or 0

	local WeatherEffects = Game.ShowWeatherEffects and MapWeather

	if mapvars.LastVisitDay ~= Game.DayOfMonth then
		if WeatherEffects then
			ResetWeather()
		end
		GenerateWeatherState()
		SetSky()
		SetWeather()
	elseif WeatherEffects and WeatherState <= 3 then
		ResetWeather()
	elseif WeatherEffects and (mapvars.EffectWasActive or  math.random(0,1) == 1) then
		if mapvars.EffectWasActive == nil then
			EffectActive = not EffectActive
		else
			EffectActive = mapvars.EffectWasActive
			mapvars.EffectWasActive = nil
		end
		CurrentEffect = mapvars.CurrentWeatherEffect
		if CurrentEffect then
			evt.SetSnow{CurrentEffect, EffectActive}
		end
	end

end

function events.AfterLoadMap()
	WeatherState = GenerateWeatherState()
	MapExtra = Game.Bolster.MapsSource[Map.MapStatsIndex]
	CustomSky = MapExtra.CustomSky
	SetSky()

	MapWeather = MapExtra and MapExtra.Weather
	if MapWeather then
		SetWeatherEffect()
		Timer(WeatherTimer, const.Hour, true)
	end
end

function events.BeforeSaveGame()
	mapvars.EffectWasActive = EffectActive
end

local TargetTransp, CurTransp, StepTransp, FadeTimer
local function FadeWeatherEffect(Period, StartStep, TargetStep)

	CurTransp = StartStep
	TargetTransp = TargetStep
	if StartStep > TargetStep then
		StepTransp = -1
	else
		StepTransp = 1
	end

	FadeTimer = function()
		if CurTransp ~= TargetTransp then
			CurTransp = CurTransp + StepTransp
			CustomUI.ShowSFTAnim{Transparency = CurTransp}
		else
			RemoveTimer(FadeTimer)
			if TargetTransp == 0 then
				CustomUI.ShowSFTAnim()
			end
		end
	end

	Timer(FadeTimer, Period)

end

function events.GameInitialized2()

	-- Load sky sets
	for k,v in pairs(Game.ContinentSettings) do
		SkyStates[k] = v.Skies
		if #SkyStates[k] == 0 then
			SkyStates[k] = Game.ContinentSettings[1].Skies
		end
	end

	-- evt.SetSnow
	mem.hook(0x444ec3, function(d)
		if not Game.IsD3D then
			return
		end

		if d.edx == 0 then
			if d.ecx == 0 then
				FadeWeatherEffect(const.Minute/32, Game.SnowOpacity or 70, 0)
			elseif d.ecx == 2 then
				FadeWeatherEffect(const.Minute/32, Game.RainOpacity or 50, 0)
			end
		else
			if d.ecx == 0 then
				FadeWeatherEffect(const.Minute/32, 0, Game.SnowOpacity or 70)
				CustomUI.ShowSFTAnim{SFTGroupName = "Snow",	Transparency = 0, Period = 55,
					Width = 831, Height = 420, X = -193, Y = -20,
					Start = 23339, End = 23388}
			elseif d.ecx == 2 then
				FadeWeatherEffect(const.Minute/32, 0, Game.RainOpacity or 50)
				CustomUI.ShowSFTAnim{SFTGroupName = "Rain",	Transparency = 0, Period = 55,
					Width = 831, Height = 420, X = -193, Y = -20}
			end
		end
	end)

	function events.LeaveMap()
		ResetWeather()
	end

	function events.LeaveGame()
		ResetWeather()
		RemoveTimer(WeatherTimer)
	end

	-- Make Awaken spell clear weather effects
	local WTimer
	WTimer = function()
		FadeWeatherEffect(const.Minute/32, 70, 0)
		RemoveTimer(WTimer)
	end
	mem.autohook2(0x4287ed, function(d)
		if CustomUI.SFTAnimActive() then
			Timer(WTimer, const.Minute)
		end
	end)

end

