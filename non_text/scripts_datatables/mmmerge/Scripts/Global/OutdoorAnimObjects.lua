OutdoorAnimObjects = {}

local DoorTimers = {}
local min, max, floor, ceil, abs = math.min, math.max, math.floor, math.ceil, abs
local rad, sqrt, sin, acos = math.rad, math.sqrt, math.sin, math.acos

-- Doors setup
local function Nor(a, b)
	return sqrt(a^2 + b^2)
end

local function CalcNCoords(m, dx, dy, dz, FId)
	local X, Y, Z
	local NF = m.Facets[FId or 0]
	local nx, ny, nz = NF.NormalX, NF.NormalY, NF.NormalZ
	local nh = sqrt(nx^2 + ny^2)
	local Snx, Sny, Snz = nx/nh, ny/nh, nz/sqrt(nx^2 + nz^2)

	if nx == 0 then
		X = dx
	else
		X = Snx*dx + Snx*dy + Snx*dz
	end

	if ny == 0 then
		Y = dy
	else
		Y = Sny*dx + Sny*dy + Sny*dz
	end

	Z = dz
	return X, Y, Z
end

local DoorSettings = {}

--m, dx, dy, dz, Time, Period, MoveParty, Normal, NFacetId, StopSound
local function MoveModelOverTime(t)

	local m = t.Model
	local eX,eY,eZ = t.dx, t.dy, t.dz
	local EndTime = Game.Time + t.Time

	if t.Normal then
		eX, eY, eZ = CalcNCoords(m, eX, eY, eZ, t.NFacetId)
	end

	eX, eY, eZ = m.X + eX, m.Y + eY, m.Z + eZ

	local f = function()

			local X,Y,Z	= 0,0,0
			local cX, cY, cZ
			local Last	= false

			if Game.Time > EndTime then
				X, Y, Z = eX - m.X, eY - m.Y, eZ - m.Z
				DoorSettings[m.Name].InMove = false
				RemoveTimer(DoorTimers[m.Name])
				Last = true
			else
				local tLeft = (EndTime - Game.Time)/t.Period
				if tLeft > 0 then
					X, Y, Z = (eX - m.X)/tLeft, (eY - m.Y)/tLeft, (eZ - m.Z)/tLeft
				else
					X, Y, Z = eX - m.X, eY - m.Y, eZ - m.Z
				end
			end
			DoorSettings[m.Name].LastMove = Game.Time

			MoveModel(m, X, Y, Z, MoveParty)

			if Last then
				if t.InMove then
					t.InMove = false
				end
				if t.StopSound then
					evt.PlaySound(t.StopSound)
				end
			end
		end

	DoorTimers[m.Name] = f
	Timer(f, t.Period)

end
OutdoorAnimObjects.MoveModelOverTime = MoveModelOverTime

local function FindModel(Name)
	for i,v in Map.Models do
		if v.Name == Name then
			return v
		end
	end
end
OutdoorAnimObjects.FindModel = FindModel

function SwitchDoor(Model, To)

	local t

	if type(Model) == "string" then
		t = DoorSettings[Model]
	else
		t = DoorSettings[Model.Name]
	end

	if not t or t.InMove then
		return false
	end

	if To == t.Closed then
		return true
	end

	t.InMove = true
	if t.StartSound then
		evt.PlaySound{t.StartSound}
	end

	if t.Closed then
		t.Closed = false
		MoveModelOverTime(t)
	else
		t.Closed = true
		t = table.copy(t)
		t.dx = -t.dx
		t.dy = -t.dy
		t.dz = -t.dz
		MoveModelOverTime(t)
	end

	return true

end
OutdoorAnimObjects.SwitchDoor = SwitchDoor

-- Model, EvtId, DefState, ApplyEvt, Closed, dx, dy, dz,
-- Time, Period, MoveParty, Normal, Fid, Condition, StartSound, StopSound
local function SetDoor(t)

	if type(t.Model) == "string" then
		t.Model = FindModel(t.Model)
	end

	if not t.Model then
		return
	end

	if t.EvtId then
		for i,v in t.Model.Facets do
			v.Event = t.EvtId
			v.TriggerByClick = true
		end
	end

	t.InMove = false
	DoorSettings[t.Model.Name] = t

end
OutdoorAnimObjects.SetDoor = SetDoor

function events.LeaveMap()
	DoorSettings = {}
	collectgarbage("collect")
end

