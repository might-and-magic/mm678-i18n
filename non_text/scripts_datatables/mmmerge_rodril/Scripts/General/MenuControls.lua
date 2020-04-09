
function events.GameInitialized2()

	local UI = {}

	---- Save/load values

	function events.LoadMap(WasInGame)

		if not WasInGame then

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
		vars.CustomInterface 	= Game.CustomInterface
		vars.UIDependsOnContinent	= Game.UIDependsOnContinent
	end

	---- Interface elements

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

