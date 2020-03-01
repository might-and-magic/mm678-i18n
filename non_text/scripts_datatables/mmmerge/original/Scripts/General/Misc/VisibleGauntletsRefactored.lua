-- Visible Gauntlets - mini-mod

local function CheckGautlets()
	return Game.Party[Game.CurrentPlayer].ItemGountlets ~= 0
end

local function IsShieldEquiped()
	local PL = Game.Party[Game.CurrentPlayer]

	if PL.ItemExtraHand ~= 0 then
		return Game.ItemsTxt[PL.Items[PL.ItemExtraHand].Number].EquipStat == 4
	end
	return false
end

local function LeftWeaponEquiped()
	local PL = Game.Party[Game.CurrentPlayer]

	if PL.ItemExtraHand ~= 0 then
		return Game.ItemsTxt[PL.Items[PL.ItemExtraHand].Number].EquipStat == 0
	end
	return false
end

local function RightWeaponEquiped()
	local PL = Game.Party[Game.CurrentPlayer]

	if PL.ItemMainHand ~= 0 then
		return Game.ItemsTxt[PL.Items[PL.ItemMainHand].Number].EquipStat == 0
	end
	return false
end

local function RightWeapon2HEquiped()
	local PL = Game.Party[Game.CurrentPlayer]

	if PL.ItemMainHand ~= 0 then
		return Game.ItemsTxt[PL.Items[PL.ItemMainHand].Number].EquipStat == 1
	end
	return false
end

local function RightNormCond()
	return Game.Party[Game.CurrentPlayer].ItemMainHand == 0
end

local function LeftNormCond()
	return Game.Party[Game.CurrentPlayer].ItemExtraHand == 0 and RightWeapon2HEquiped() == false
end

local function RightWeapCond()
	return (RightWeaponEquiped() or RightWeapon2HEquiped())
end

local function LeftWeapCond()
	return LeftWeaponEquiped()
end

local function LeftOpenCond()
	return RightWeapon2HEquiped()
end

local loupeActive = false

function events.GameInitialized2()

	local function actLupa()
		loupeActive = mem.u4[0x523040] > 0
	end


	local Cords = {} -- cords for all gauntlets for current doll [#]
	Cords[0] = {--man
		RHdX=490,
		RHdY=155,

		RHuX=508,
		RHuY=163,

		LHdX=592,
		LHdY=170,

		LHuX=594,
		LHuY=169,

		LHoX=582,
		LHoY=169
	}
	Cords[1] = {--women
		RHdX=490,
		RHdY=155,

		RHuX=508,
		RHuY=163,

		LHdX=592,
		LHdY=170,

		LHuX=594,
		LHuY=169,

		LHoX=582,
		LHoY=169
	}
	Cords[2] = {--minotaur
		RHdX=490,
		RHdY=155,

		RHuX=508,
		RHuY=163,

		LHdX=592,
		LHdY=170,

		LHuX=594,
		LHuY=169,

		LHoX=582,
		LHoY=169
	}
	Cords[3] = {--troll
		RHdX=490,
		RHdY=155,

		RHuX=508,
		RHuY=163,

		LHdX=592,
		LHdY=170,

		LHuX=594,
		LHuY=169,

		LHoX=582,
		LHoY=169
	}
	Cords[4] = {--dragon
		RHdX=0,
		RHdY=0,

		RHuX=0,
		RHuY=0,

		LHdX=0,
		LHdY=0,

		LHuX=0,
		LHuY=0,

		LHoX=0,
		LHoY=0
	}

	Cords[5] = {--dwarf
		RHdX=0,
		RHdY=0,

		RHuX=0,
		RHuY=0,

		LHdX=0,
		LHdY=0,

		LHuX=0,
		LHuY=0,

		LHoX=0,
		LHoY=0
	}

	local Gauntlets = {}

	-- Icon names will be used for handler's key generation, even though these icons do not exist.

	Gauntlets.RHd = CustomUI.CreateIcon{
							Icon = "RHd", -- right hand normal
							X = 0,
							Y = 0,
							Condition = function(v) return CheckGautlets() and RightNormCond() end,
							Layer = 4,
							Screen = 7,
							NoPending = true,
							Masked = true}

	Gauntlets.RHu = CustomUI.CreateIcon{
							Icon = "RHu", -- right hand weapon
							X = 0,
							Y = 0,
							Condition = function(v) return CheckGautlets() and RightWeapCond() end,
							Layer = 4,
							Screen = 7,
							NoPending = true,
							Masked = true}

	Gauntlets.LHd = CustomUI.CreateIcon{
							Icon = "LHd", -- left hand normal
							X = 0,
							Y = 0,
							Condition = function(v) return CheckGautlets() and LeftNormCond() end,
							Layer = 4,
							Screen = 7,
							NoPending = true,
							Masked = true}

	Gauntlets.LHu = CustomUI.CreateIcon{
							Icon = "LHu", -- left hand weapon
							X = 0,
							Y = 0,
							Condition = function(v) return CheckGautlets() and LeftWeapCond() end,
							Layer = 4,
							Screen = 7,
							NoPending = true,
							Masked = true}

	Gauntlets.LHo = CustomUI.CreateIcon{
							Icon = "LHo", -- left hand open
							X = 0,
							Y = 0,
							Condition = function(v) return CheckGautlets() and LeftOpenCond() end,
							Layer = 4,
							Screen = 7,
							NoPending = true,
							Masked = true}

	local loupeButton = CustomUI.CreateButton{
							IconUp = "MAGNIF-B",
							IconDown = "MAGNIF-A",
							IconMouseOver = "MAGNIF-A",
							X = 603,
							Y = 299,
							Action = actLupa,
							Layer = 1,
							Screen = 7,
							Width = 75,
							Height = 26,
							Masked = true}

	function events.LoadInventoryPics(PL)

		local Active = PL.ItemGountlets ~= 0
		local DollId = Game.CharacterPortraits[PL.Face].DollType
		local ItemId = Active and PL.Items[PL.ItemGountlets].Number or 0

		loupeActive = mem.u4[0x523040] > 0

		for k,v in pairs(Gauntlets) do
			v.Active = Active
			if Active then
				v.MainIcon = tostring(ItemId) .. "v" .. (DollId + 1) .. k -- icon name template, current: 000v1RHd - item id + "v" + doll type + key
				v.X = Cords[DollId][k .. "X"]
				v.Y = Cords[DollId][k .. "Y"]
			end
		end

	end

	function events.CanWearItem(t)

		if t.Available and Game.ItemsTxt[t.ItemId].EquipStat == 8 then
			local PL = Party[t.PlayerId]
			local DollId = Game.CharacterPortraits[PL.Face].DollType

			for k,v in pairs(Gauntlets) do
				v.Active = true
				v.MainIcon = tostring(t.ItemId) .. "v" .. (DollId + 1) .. k -- icon name template, current: 000v1RHd - item id + "v" + doll type + key
				v.X = Cords[DollId][k .. "X"]
				v.Y = Cords[DollId][k .. "Y"]
			end
		end

	end

end
