
function events.GameInitialized2()

	local UI = {}

	---- Save/load values

	function events.LoadMap(WasInGame)

		if not WasInGame then
			Game.BolsterAmount 		= vars.BolsterAmount or 100
			Game.UseMonsterBolster	= (vars.UseMonsterBolster 	== nil) and true or vars.UseMonsterBolster
			Game.ShowWeatherEffects = (vars.ShowWeatherEffects 	== nil) and true or vars.ShowWeatherEffects

			-- reset appearance
			UI.BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
			if Game.UseMonsterBolster then
				UI.Bolster.IUpSrc = "blstr_on"
				UI.Bolster.IDwSrc = "blstr_off"
				UI.BolAmText.R = 255
				UI.BolAmText.G = 5
				UI.BolAmText.B = 0
			else
				UI.Bolster.IUpSrc = "blstr_off"
				UI.Bolster.IDwSrc = "blstr_on"
				UI.BolAmText.R = 150
				UI.BolAmText.G = 2
				UI.BolAmText.B = 0
			end
			if Game.ShowWeatherEffects then
				UI.Weather.IUpSrc = "wthr_on"
				UI.Weather.IDwSrc = "wthr_off"
			else
				UI.Weather.IUpSrc = "wthr_off"
				UI.Weather.IDwSrc = "wthr_on"
			end

			-- Custom Interface
			Game.UIDependsOnContinent = vars.UIDependsOnContinent or false
			Game.CustomInterface = vars.CustomInterface or 1

			UI.CustomUIText.Text = tostring(Game.CustomInterface)

			if Game.CustomInterface ~= GetCurrentUI() then
				Game.LoadUI(Game.CustomInterface)
			end

			if Game.UIDependsOnContinent then
				UI.SwapUIText.R, UI.SwapUIText.G, UI.SwapUIText.B = 15, 13, 0
			else
				UI.SwapUIText.R, UI.SwapUIText.G, UI.SwapUIText.B = 8, 4, 3
			end

			-- Infinity view
			Game.InfinityView = vars.InfinityView or false
			Editor.UpdateVisibility(Game.InfinityView)
			if Game.InfinityView then
				UI.InfinityView.R, UI.InfinityView.G, UI.InfinityView.B = 15, 13, 0
			else
				UI.InfinityView.R, UI.InfinityView.G, UI.InfinityView.B = 8, 4, 3
			end

		end

		if Game.UIDependsOnContinent then
			local NewUI = TownPortalControls.MapOfContinent(Map.MapStatsIndex)
			if not Game.UISets[NewUI] then
				NewUI = 1
			end
			if NewUI ~= GetCurrentUI() then
				Game.LoadUI(NewUI)
			end
		end

	end

	function events.BeforeSaveGame()
		vars.InfinityView		= Game.InfinityView
		vars.BolsterAmount 		= Game.BolsterAmount
		vars.UseMonsterBolster	= Game.UseMonsterBolster
		vars.ShowWeatherEffects = Game.ShowWeatherEffects
		vars.CustomInterface 	= Game.CustomInterface
		vars.UIDependsOnContinent	= Game.UIDependsOnContinent
	end

	---- Interface elements

	-- Toggle weather
	UI.Weather = CustomUI.CreateButton{
		IconUp 		= Game.ShowWeatherEffects and "wthr_on"		or "wthr_off",
		IconDown 	= Game.ShowWeatherEffects and "wthr_off"	or "wthr_on",
		Action = function(t)
			t.IUpSrc, t.IDwSrc = t.IDwSrc, t.IUpSrc
			t.IUpPtr, t.IDwPtr = t.IDwPtr, t.IUpPtr
			Game.ShowWeatherEffects = not Game.ShowWeatherEffects
			if not Game.ShowWeatherEffects then
				CustomUI.ShowSFTAnim()
			end
		end,
		Layer 	= 1,
		Screen 	= 2,
		Font = Game.Create_fnt,
		R = 255, 	G = 5,		B = 0,
		Screen 	= 2,
		X = 159, Y = 25}

	-- Bolster amount text representation
	UI.BolAmText = CustomUI.CreateText{
		Text = tostring(Game.BolsterAmount) .. "%",
		Layer 	= 1,
		Screen	= 2,
		Width = 60,	Height = 10,
		X = 208, 	Y = 86
		}

	-- Toggle bolster
	UI.Bolster = CustomUI.CreateButton{
		IconUp 		= Game.UseMonsterBolster and "blstr_on"		or "blstr_off",
		IconDown 	= Game.UseMonsterBolster and "blstr_off"	or "blstr_on",
		Action = function(t)
			t.IUpSrc, t.IDwSrc = t.IDwSrc, t.IUpSrc
			t.IUpPtr, t.IDwPtr = t.IDwPtr, t.IUpPtr
			Game.UseMonsterBolster = not Game.UseMonsterBolster
			if Game.UseMonsterBolster then
				UI.BolAmText.R = 255
				UI.BolAmText.G = 5
				UI.BolAmText.B = 0
			else
				UI.BolAmText.R = 150
				UI.BolAmText.G = 2
				UI.BolAmText.B = 0
			end
		end,
		Layer 	= 1,
		Screen 	= 2,
		X = 159, Y = 53}

	-- Decrease bolster
	CustomUI.CreateButton{
		IconUp 			= "ar_lt_up",
		IconDown 		= "ar_lt_dn",
		IconMouseOver 	= "ar_lt_ht",
		Action = function(t)
			evt.PlaySound{24}
			Game.BolsterAmount = math.max(Game.BolsterAmount - 5, 0)
			UI.BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
		end,
		Layer 	= 1,
		Screen 	= 2,
		X = 165, Y = 86}

	-- Increase bolster
	CustomUI.CreateButton{
		IconUp 			= "ar_rt_up",
		IconDown 		= "ar_rt_dn",
		IconMouseOver 	= "ar_rt_ht",
		Action = function(t)
			evt.PlaySound{23}
			Game.BolsterAmount = math.min(Game.BolsterAmount + 5, 200)
			UI.BolAmText.Text = tostring(Game.BolsterAmount) .. "%"
		end,
		Layer 	= 1,
		Screen 	= 2,
		X = 185, Y = 86}

	-- Choose UI
	CustomUI.CreateIcon{
		Icon = "UIExample",
		Layer	= 1,
		Screen	= 28,
		X = 368, Y = 213
	}

	UI.CustomUIText = CustomUI.CreateText{
		Text = "",
		Font = Game.Smallnum_fnt,
		Layer 	= 1,
		Screen	= 28,
		Width = 20,	Height = 10,
		X = 405, 	Y = 196
		}

	CustomUI.CreateText{
		Text = "< ",
		Action = function(t)
			evt.PlaySound{24}
			Game.CustomInterface = math.max(Game.CustomInterface - 1, 1)
			UI.CustomUIText.Text = tostring(Game.CustomInterface)
			Game.LoadUI(Game.CustomInterface)
		end,
		Font = Game.Smallnum_fnt,
		Layer 	= 1,
		Screen 	= 28,
		X = 397, Y = 196}

	CustomUI.CreateText{
		Text = " >",
		Action = function(t)
			evt.PlaySound{23}
			Game.CustomInterface = math.min(Game.CustomInterface + 1, #Game.UISets)
			UI.CustomUIText.Text = tostring(Game.CustomInterface)
			Game.LoadUI(Game.CustomInterface)
		end,
		Font = Game.Smallnum_fnt,
		Layer 	= 1,
		Screen 	= 28,
		X = 418, Y = 196}

	CustomUI.CreateText{
		Text = "Interface:",
		Font = Game.Smallnum_fnt,
		Layer 	= 1,
		Screen 	= 28,
		X = 317, Y = 196}

	UI.SwapUIText = CustomUI.CreateText{
		Text = "UI depends on continent",
		Action = function(t)
			evt.PlaySound{23}
			Game.UIDependsOnContinent = not Game.UIDependsOnContinent
			if Game.UIDependsOnContinent then
				t.R, t.G, t.B = 15, 13, 0
			else
				t.R, t.G, t.B = 8, 4, 3
			end
		end,
		Font = Game.Smallnum_fnt,
		Layer 	= 1,
		Screen 	= 28,
		X = 432, Y = 196,
		Width = 180}

	UI.InfinityView = CustomUI.CreateText{
		Text = "Increase view range",
		Action = function(t)
			evt.PlaySound{23}
			Game.InfinityView = not Game.InfinityView
			if Game.InfinityView then
				t.R, t.G, t.B = 15, 13, 0
			else
				t.R, t.G, t.B = 8, 4, 3
			end
			Editor.UpdateVisibility(Game.InfinityView)
		end,
		Font = Game.Smallnum_fnt,
		Layer 	= 1,
		Screen 	= 28,
		X = 375, Y = 348,
		Width = 180}

end

