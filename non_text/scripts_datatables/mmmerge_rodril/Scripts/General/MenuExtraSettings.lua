local Pages = {}
local CurrentPage = 1

-- Setup special screen for interface manager
local function NewSettingsPage(ScreenId, ScreenName)
	const.Screens[ScreenName] = ScreenId
	CustomUI.NewScreen(ScreenId)
	table.insert(Pages, ScreenId)
end
CustomUI.NewSettingsPage = NewSettingsPage

local function ExitExtSetScreen()
	Editor.UpdateVisibility(Game.InfinityView)
	if not Game.ShowWeatherEffects then
		CustomUI.ShowSFTAnim() -- stop current animation
	end
	events.call("ExitExtraSettingsMenu")

	Game.CurrentScreen = 2
end
CustomUI.ExitExtraSettingsMenu = ExitExtSetScreen

function events.GameInitialized2()

	local ExSetScr = 98
	local VarsToStore = {"UseMonsterBolster", "BolsterAmount", "ShowWeatherEffects", "InfinityView", "ImprovedPathfinding"}
	local RETURN = const.Keys.RETURN
	local ESCAPE = const.Keys.ESCAPE
	NewSettingsPage(ExSetScr, "ExtraSettings")

	---- Switch extra screen ----
	local RightSwitch = CustomUI.CreateButton{
		IconUp 			= "ar_rt_up",
		IconDown 		= "ar_rt_dn",
		IconMouseOver 	= "ar_rt_ht",
		Action = function(t)
			Game.PlaySound(23)
			if CurrentPage < #Pages then
				CurrentPage = CurrentPage + 1
			else
				CurrentPage = 1
			end
			Game.CurrentScreen = Pages[CurrentPage]
		end,
		Condition = function() return #Pages > 1 end,
		Layer 	= 0,
		Screen 	= {ExSetScr},
		X = 554, Y = 422}

	local LeftSwitch = CustomUI.CreateButton{
		IconUp 			= "ar_lt_up",
		IconDown 		= "ar_lt_dn",
		IconMouseOver 	= "ar_lt_ht",
		Action = function(t)
			Game.PlaySound(24)
			if CurrentPage > 1 then
				CurrentPage = CurrentPage - 1
			else
				CurrentPage = #Pages
			end
			Game.CurrentScreen = Pages[CurrentPage]
		end,
		Condition = function() return #Pages > 1 end,
		Layer 	= 0,
		Screen 	= {ExSetScr},
		X = 69, Y = 422}

	---- first page creation ----

	-- simplify tumbler creation
	local Tumblers = {}
	local function ToggleTumbler(Tumbler)
		Tumbler.IUpSrc, Tumbler.IDwSrc = Tumbler.IDwSrc, Tumbler.IUpSrc
		Tumbler.IUpPtr, Tumbler.IDwPtr = Tumbler.IDwPtr, Tumbler.IUpPtr

		Game.NeedRedraw = true
		Game[Tumbler.VarName] = Tumbler.IUpSrc == "TmblrOn"
		Game.PlaySound(25)
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
	local ExSetBtn
	ExSetBtn = CustomUI.CreateButton{
		IconUp	 	  = "ExtSetDw",
		IconDown	  = "ExtSetUp",
		IconMouseOver = "ExtSetUp",
		Screen		= {ExSetScr, ExSetScrKeys, 2},
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
				for k,v in pairs(Pages) do
					CustomUI.ActiveElements[v].Buttons[0][RightSwitch.Key] = RightSwitch
					CustomUI.ActiveElements[v].Buttons[0][LeftSwitch.Key] = LeftSwitch
					CustomUI.ActiveElements[v].Buttons[0][ExSetBtn.Key] = ExSetBtn
				end
				CurrentPage = table.find(Pages, ExSetScr)
				Game.CurrentScreen = ExSetScr
			else
				ExitExtSetScreen()
			end
			Game.PlaySound(412)
		end}

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
			Game.PlaySound(24)
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
			Game.PlaySound(23)
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
