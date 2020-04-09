
function events.GameInitialized2()

	local VarsToStore = {"UseMonsterBolster", "BolsterAmount", "ShowWeatherEffects", "InfinityView", "ImprovedPathfinding"}

	-- Setup special screen for interface manager
	local ExSetScr = 98
	const.Screens.ExtraSettings = ExSetScr
	CustomUI.NewScreen(ExSetScr)

	local function ExitExtSetScreen()
		Editor.UpdateVisibility(Game.InfinityView)
		Game.CurrentScreen = 2
	end

	-- simplify tumbler creation
	local Tumblers = {}
	local function ToggleTumbler(Tumbler)
		Tumbler.IUpSrc, Tumbler.IDwSrc = Tumbler.IDwSrc, Tumbler.IUpSrc
		Tumbler.IUpPtr, Tumbler.IDwPtr = Tumbler.IDwPtr, Tumbler.IUpPtr

		Game.NeedRedraw = true
		Game[Tumbler.VarName] = Tumbler.IUpSrc == "TmblrOn"
		evt.PlaySound{25}
	end

	local function OnOffTumbler(X, Y, VarName)
		local Tumbler = CustomUI.CreateButton{
			IconUp	 	= "TmblrOn",
			IconDown	= "TmblrOff",
			Screen		= ExSetScr,
			Layer		= 0,
			X		=	X,
			Y		=	Y,
			Action	=	ToggleTumbler}

		table.insert(Tumblers, Tumbler)
		Tumbler.VarName = VarName
	end

	-- Create elements
	CustomUI.CreateButton{
		IconUp	 	  = "ExtSetDw",
		IconDown	  = "ExtSetUp",
		IconMouseOver = "ExtSetup",
		Screen		= {ExSetScr, 2},
		Layer		= 0,
		X		=	159,
		Y		=	25,
		Action	=	function(t)
			if Game.CurrentScreen == 2 then
				for k,v in pairs(Tumblers) do
					if Game[v.VarName] then
						v.IUpSrc = "TmblrOn"
						v.IDwSrc = "TmblrOff"
					else
						v.IUpSrc = "TmblrOff"
						v.IDwSrc = "TmblrOn"
					end
				end
				Game.CurrentScreen = ExSetScr
			else
				ExitExtSetScreen()
			end
			evt.PlaySound{412}
		end}

	local ESCAPE = const.Keys.ESCAPE
	CustomUI.CreateIcon{
		Icon = "ExSetScr",
		X = 0,
		Y = 0,
		Layer = 1,
		Condition = function()
			if Keys.IsPressed(ESCAPE) then
				ExitExtSetScreen()
			end
			Game.Paused = true
			return true
		end,
		BlockBG = true,
		Screen = ExSetScr}

	OnOffTumbler(95, 175, VarsToStore[1])
	OnOffTumbler(95, 251, VarsToStore[3])
	OnOffTumbler(95, 288, VarsToStore[4])
	OnOffTumbler(95, 326, VarsToStore[5])

	local BolsterCX, BolsterCY = 103, 220

	-- Bolster amount text representation
	Game.BolsterAmount = Game.BolsterAmount or 100
	local BolAmText = CustomUI.CreateText{
		Text = tostring(Game.BolsterAmount) .. "%",
		Layer 	= 0,
		Screen	= ExSetScr,
		Width = 60,	Height = 10,
		X = BolsterCX + 40, Y = BolsterCY}

	BolAmText.R = 255
	BolAmText.G = 5
	BolAmText.B = 0

		-- Decrease bolster
	CustomUI.CreateButton{
		IconUp 			= "ar_lt_up",
		IconDown 		= "ar_lt_dn",
		IconMouseOver 	= "ar_lt_ht",
		Action = function(t)
			evt.PlaySound{24}
			Game.BolsterAmount = math.max(Game.BolsterAmount - 5, 0)
			BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
		end,
		Layer 	= 0,
		Screen 	= ExSetScr,
		X = BolsterCX, Y = BolsterCY}

	-- Increase bolster
	CustomUI.CreateButton{
		IconUp 			= "ar_rt_up",
		IconDown 		= "ar_rt_dn",
		IconMouseOver 	= "ar_rt_ht",
		Action = function(t)
			evt.PlaySound{23}
			Game.BolsterAmount = math.min(Game.BolsterAmount + 5, 200)
			BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
		end,
		Layer 	= 0,
		Screen 	= ExSetScr,
		X = BolsterCX + 20, Y = BolsterCY}

	-- events
	function events.BeforeSaveGame()
		vars.ExtraSettings = vars.ExtraSettings or {}
		local ExSet = vars.ExtraSettings
		for k,v in pairs(VarsToStore) do
			ExSet[v] = Game[v]
		end
	end

	function events.LoadMap(WasInGame)
		if not WasInGame then
			vars.ExtraSettings = vars.ExtraSettings or {}
			local ExSet = vars.ExtraSettings

			ExSet.BolsterAmount = ExSet.BolsterAmount or 100
			ExSet.InfinityView	= ExSet.InfinityView  or false
			for k,v in pairs(VarsToStore) do
				Game[v] = (ExSet[v] == nil) and true or ExSet[v]
			end
		end
	end

end
