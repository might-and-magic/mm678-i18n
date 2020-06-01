ExtraQuickSpells = {}
ExtraQuickSpells.SlotsAmount = 4

local function NewSpellSlots()
	local SpellSlots = {}
	for PlayerId, Player in Party.PlayersArray do
		SpellSlots[PlayerId] = {}
		for i = 1, ExtraQuickSpells.SlotsAmount do
			SpellSlots[PlayerId][i] = 0
		end
	end
	return SpellSlots
end
ExtraQuickSpells.NewSpellSlots = NewSpellSlots
ExtraQuickSpells.SpellSlots = NewSpellSlots()

local function CastSlotSpell(SlotNumber)
	if Game.CurrentScreen ~= 0 then
		return
	end

	if Game.TurnBasedPhase == 3 then
		Game.TurnBasedPhase = 1
		return
	end

	if Game.CurrentPlayer < 0 then
		return
	end

	local SpellSlots = ExtraQuickSpells.SpellSlots
	local Player = Party[Game.CurrentPlayer]
	local PlayerId = Party.PlayersIndexes[Game.CurrentPlayer]
	local SpellId = SpellSlots[PlayerId][SlotNumber] or 0

	-- check for basic spell cost, despite player's mastery, because only spell with different cost by mastery is wizard eye, rest have same.
	if SpellId == 0 or Player.SP < Game.Spells[SpellId].SpellPoints[1] then
		-- perform standart attack
		DoGameAction(23,0,0)
	elseif Player.RecoveryDelay > 0 then
		if Game.CurrentPlayer >= Party.count-1 then
			Game.CurrentPlayer = 0
		else
			Game.CurrentPlayer = Game.CurrentPlayer + 1
		end
	else
		CastQuickSpell(Game.CurrentPlayer, SpellId) -- from HardcodedTopicFunctions.lua
	end
end

local function SetSlotSpell(PlayerId, SlotNumber, SpellId)
	PlayerId = Party.PlayersIndexes[PlayerId]
	local SpellSlots = ExtraQuickSpells.SpellSlots
    if SpellSlots[PlayerId][SlotNumber] == SpellId then
		SpellSlots[PlayerId][SlotNumber] = 0
		Game.PlaySound(142)
	else
		SpellSlots[PlayerId][SlotNumber] = SpellId
		Party[Game.CurrentPlayer]:ShowFaceAnimation(const.FaceAnimation.SetQuickSpell)
	end
end

function GetSelectedSpellId()
	local PlayerId = Game.CurrentPlayer
	if PlayerId < 0 then
		return 0
	end

	local SpellId = mem.u4[0x517b1c]
	local SpellSchool = mem.u1[Party[PlayerId]["?ptr"] + 0x1c44]

	SpellId = SpellId + SpellSchool*11
	if SpellId > 0 and not Party[PlayerId].Spells[SpellId-1] then
		SpellId = 0
	end
	return SpellId
end

function ShowSlotSpellName(SlotNumber)
	local SpellId
	if SlotNumber == 0 then -- original quick spell
		SpellId = Party[Game.CurrentPlayer].QuickSpell
	else
		local PlayerId = Party.PlayersIndexes[Game.CurrentPlayer]
		SpellId = ExtraQuickSpells.SpellSlots[PlayerId][SlotNumber] or 0
	end

	if SpellId == 0 then
		Game.ShowStatusText(Game.GlobalTxt[72])
	else
		Game.ShowStatusText(Game.SpellsTxt[SpellId].Name)
	end
end

function events.GameInitialized2()

	-- new quick spell buttons
	for i = 1, ExtraQuickSpells.SlotsAmount do
		CustomUI.CreateButton{
			IconUp = "stssu",
			IconDown = "stssd",
			Screen = 8,
			Layer = 1,
			X =	0,
			Y =	380 - i*50,
			Masked = true,
			Action = function() SetSlotSpell(Game.CurrentPlayer, i, GetSelectedSpellId()) end,
			MouseOverAction = function() ShowSlotSpellName(i) end
		}

		-- slot number
		CustomUI.CreateText{
			Key = "QSSlotNum_" .. i,
			AlignLeft = true,
			Font =  Game.Smallnum_fnt,
			ColorStd = 0xAAAA, -- brown
			Screen = 8,
			Layer = 0,
			X = 17,
			Y = 382 - i*50,
			Text = " " .. tostring(i)}

	end

	-- overlay for original button
	CustomUI.CreateButton{
			IconUp = "stssu",
			Screen = 8,
			Layer = 3,
			X =	0,
			Y =	380,
			Action = function() return true end,
			MouseOverAction = function() ShowSlotSpellName(0) end
		}
end

-- default values:
local function DefaultKeybinds()
	return {
		[const.Keys.F5] = 1,
		[const.Keys.F6] = 2,
		[const.Keys.F7] = 3,
		[const.Keys.F8] = 4}
end
ExtraQuickSpells.DefaultKeybinds = DefaultKeybinds
ExtraQuickSpells.KeyBinds = DefaultKeybinds()

---- events ----

function events.KeyDown(t)
	local Slot = ExtraQuickSpells.KeyBinds[t.Key]
	if Slot then
		t.Handled = true
		CastSlotSpell(Slot)
	end
end

---- Extra settings menu ----

function events.GameInitialized2()

	local KeyLabels = {}
	local QuickSpellsSlots = {}
	local ActiveText
	local SelectionStarted = false
	local ExSetScrKeys = 96
	CustomUI.NewSettingsPage(ExSetScrKeys, "ExtraKeybinds")

	function events.ExitExtraSettingsMenu()
		SelectionStarted = false
		ActiveText = nil
		ExtraQuickSpells.KeyBinds = {}
		for k,v in pairs(QuickSpellsSlots) do
			v.Label.CStd = 0xFFFF -- white
			ExtraQuickSpells.KeyBinds[v.KeyId] = k
		end
	end

	local NOKEY = "-NO KEY-"
	local function TextChooseKey(t, Key)
		if SelectionStarted then
			if ActiveText == t then
				local KeyName = table.find(const.Keys, Key)
				if KeyName then
					for k,v in pairs(QuickSpellsSlots) do
						if v.KeyId == Key then
							v.Key.Text = NOKEY
						end
						if v.Label == t then
							v.KeyId = Key
						end
					end
				else
					KeyName = NOKEY
				end

				t.CStd = 0xFFFF -- white
				SelectionStarted = false
				ActiveText = nil
				KeyLabels[t].Text = KeyName
			elseif ActiveText then
				Game.PlaySound(27)
			end
		elseif t then
			SelectionStarted = true
			ActiveText = t
			t.CStd = 0xe664 -- gold
		end
	end

	-- background
	CustomUI.CreateIcon{
		Icon = "ExSetScrK",
		X = 0,
		Y = 0,
		Layer = 1,
		Condition = function()
				if Keys.IsPressed(const.Keys.RETURN) then
					if SelectionStarted then
						SelectionStarted = false
						ActiveText.CStd = 0xFFFF
						ActiveText = nil
					end
				elseif Keys.IsPressed(const.Keys.ESCAPE) and not SelectionStarted then
					CustomUI.ExitExtraSettingsMenu()
				end
				return true
			end,
		BlockBG = true,
		Screen = ExSetScrKeys}

	-- keybinds GUI
	for i = 1, ExtraQuickSpells.SlotsAmount do
		local Label, Key, X, Y
		if i < 6 then
			X = 107
			Y = i
		else
			X = 334
			Y = i-5
		end

		Label = CustomUI.CreateText{Text = "Q. SPELL " .. i,
			X = X, Y = 193 + Y*28,
			AlignLeft = true,
			Action = TextChooseKey,
			Layer = 0,
			Screen = ExSetScrKeys,
			Font = Game.Lucida_fnt}

		Key = CustomUI.CreateText{Text = NOKEY,
			X = X + 120, Y = 193 + Y*28,
			AlignLeft = true,
			Action = function() TextChooseKey(QuickSpellsSlots[i].Label) end,
			Layer = 0,
			Screen = ExSetScrKeys,
			Font = Game.Lucida_fnt}

		KeyLabels[Label] = Key
		QuickSpellsSlots[i] = {Key = Key, Label = Label, KeyId = 0}
	end

	-- register new keybinds
	function events.KeyDown(t)
		if Game.CurrentScreen == ExSetScrKeys and SelectionStarted then
			TextChooseKey(ActiveText, t.Key)
		end
	end

	-- save/load
	local function SaveQSKeybinds()
		vars.ExtraSettings = vars.ExtraSettings or {}
		vars.ExtraSettings.SpellSlots = ExtraQuickSpells.SpellSlots
		vars.ExtraSettings.QSKeybinds = ExtraQuickSpells.KeyBinds
	end

	local function LoadQSKeybinds()
		vars.ExtraSettings = vars.ExtraSettings or {}
		ExtraQuickSpells.SpellSlots = vars.ExtraSettings.SpellSlots or ExtraQuickSpells.NewSpellSlots()
		ExtraQuickSpells.KeyBinds = vars.ExtraSettings.QSKeybinds or ExtraQuickSpells.DefaultKeybinds()
		for k,v in pairs(QuickSpellsSlots) do
			local Key = table.find(ExtraQuickSpells.KeyBinds, k)
			if Key then
				v.KeyId = Key
				v.Key.Text = table.find(const.Keys, Key) or NOKEY
			else
				v.KeyId = 0
				v.Key.Text = NOKEY
			end
		end

		for k,v in pairs(ExtraQuickSpells.KeyBinds) do
			QuickSpellsSlots[v].Key.Text = table.find(const.Keys, k) or NOKEY
		end
	end

	function events.BeforeSaveGame()
		SaveQSKeybinds()
	end

	function events.LoadMap(WasInGame)
		if not WasInGame then
			LoadQSKeybinds()
		end
	end
end
