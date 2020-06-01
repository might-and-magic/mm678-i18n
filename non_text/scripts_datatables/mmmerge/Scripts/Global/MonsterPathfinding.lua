local abs, max, min, sqrt, ceil, floor, random = math.abs, math.max, math.min, math.sqrt, math.ceil, math.floor, math.random
local deg, asin, sin, rad = math.deg, math.asin, math.sin, math.rad
local tinsert, tremove = table.insert, table.remove
local costatus, coresume, coyield, cocreate = coroutine.status, coroutine.resume, coroutine.yield, coroutine.create

if not Pathfinder then
	require "PathfinderAsm"
end
Pathfinder = Pathfinder or {}

local TickEndTime = 0 -- end time for coroutines in current tick.
local HaveMapData = false
local MapFloors, MapAreas, NeighboursWays = {}, {}, {}
local MonsterWays = {}
local MonStuck = {}
local IsOutdoor = false

--------------------------------------------------
--					Base functions				--
--------------------------------------------------

local function EqualCoords(a, b, Precision)
	if not Precision then
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	else
		return	a.X > b.X - Precision and a.X < b.X + Precision and
				a.Y > b.Y - Precision and a.Y < b.Y + Precision and
				a.Z > b.Z - Precision and a.Z < b.Z + Precision
	end
end

local function GetDist(px, py, pz, x, y, z)
	return sqrt((px-x)^2 + (py-y)^2 + (pz-z)^2)
end

local function GetDist2(p1, p2)
	local px, py, pz = XYZ(p1)
	local x, y, z = XYZ(p2)
	return sqrt((px-x)^2 + (py-y)^2 + (pz-z)^2)
end

local function GetDistXY(px, py, x, y)
	return sqrt((px-x)^2 + (py-y)^2)
end

local function DirectionToPoint(From, To)
	local angle, sector
	local X, Y = From.X - To.X, From.Y - To.Y
	local Hy = sqrt(X^2 + Y^2)

	angle = asin(abs(Y)/Hy)
	angle = (angle/rad(90))*512

	if X < 0 and Y < 0 then
		angle = angle + 1024
	elseif X < 0 and Y >= 0 then
		angle = 1024 - angle
	elseif X >= 0 and Y < 0 then
		angle = 2048 - angle
	end

	return floor(angle)
end

local function FacetToPoint(Facet)
	return {X = ceil((Facet.MinX + Facet.MaxX)/2), Y = ceil((Facet.MinY + Facet.MaxY)/2), Z = ceil((Facet.MinZ + Facet.MaxZ)/2)}
end

local function DistanceBetweenFacets(f1, f2) -- Approx
	return floor(GetDist2(FacetToPoint(f1), FacetToPoint(f2)))
end

local function AreaOfTarget(Target)
	return mem.call(Pathfinder.AreaFromPoint, 0, Target.X, Target.Y, Target.Z)
end
Pathfinder.AreaOfTarget = AreaOfTarget

local function SharedVertexes(f1, f2)
	local count = 0
	for i1,v1 in f1.VertexIds do
		for i2, v2 in f2.VertexIds do
			if EqualCoords(Map.Vertexes[v1], Map.Vertexes[v2], 5) then
				count = count + 1
			end
		end
	end
	return count
end

local function FacetS(Facet)
	-- Approximation with ignoring Z size
	local cV, pV
	local sum = 0
	for i,v in Facet.VertexIds do
		pV = cV or Map.Vertexes[Facet.VertexIds[Facet.VertexesCount-1]]
		cV = Map.Vertexes[v]
		sum = sum + pV.X*cV.Y
	end
	cV, pV = nil, nil
	for i,v in Facet.VertexIds do
		pV = cV or Map.Vertexes[Facet.VertexIds[Facet.VertexesCount-1]]
		cV = Map.Vertexes[v]
		sum = sum - pV.Y*cV.X
	end
	return abs(floor(sum/2))
end
--------------------------------------------------
--					Tracer						--
--------------------------------------------------

local function TraceSight(From, To)
	return mem.call(Pathfinder.TraceLineAsm, 0, 0, 0, From.X, From.Y, From.Z+35, To.X, To.Y, To.Z+35) == 1
end
Pathfinder.TraceSight = TraceSight

--Pathfinder.TraceMonWayAsm(1, Map.Monsters[1], Map.Monsters[1], Party, 30)
local function TraceMonWayAsm(MonId, Monster, From, To, Radius)
	return mem.call(Pathfinder.TraceAsm, 0, MonId, Radius, From.X, From.Y, From.Z, To.X, To.Y, To.Z) == 1
end
Pathfinder.TraceMonWayAsm = TraceMonWayAsm

local function TraceReach(MonId, Monster, Target)
	if not TraceSight(Monster, Target) then
		return false
	end

	if Monster.Attack1.Missile > 0 or Monster.Attack2.Missile > 0 then
		return true
	end

	-- if there're water tiles between monster and target, and monster cannot shoot, return false
	return TraceMonWayAsm(MonId, Monster, Monster, Target, Monster.BodyRadius)
end

--------------------------------------------------
--				Way generation			--
--------------------------------------------------
local function ShrinkMonWay(WayMap, MonId, StepSize, Async)
	MonId = MonId or 1
	StepSize = StepSize or #WayMap
	local Current = 1
	local Monster = Map.Monsters[MonId]
	local TraceRadius = ceil(Monster.BodyRadius/3)

	while Current < #WayMap do
		for i = min(Current + StepSize, #WayMap), Current + 1, -1 do
			if TraceMonWayAsm(MonId, Monster, WayMap[Current], WayMap[i], TraceRadius) then
				for _ = Current + 1, i - 1 do
					tremove(WayMap, Current + 1)
				end
				break
			end
		end
		Current = Current + 1
		if Async and timeGetTime() > TickEndTime then
			coyield()
		end
	end

	return WayMap
end
Pathfinder.ShrinkWay = ShrinkMonWay

local function AStarWay(MonId, Monster, Target, AvAreas, Async, CustomStart, limit)
	local t = {MonId = MonId, ToX = Target.X, ToY = Target.Y, ToZ = Target.Z, Async = Async, AvAreas = AvAreas}
	if CustomStart then
		t.FromX = CustomStart.X
		t.FromY = CustomStart.Y
		t.FromZ = CustomStart.Z
	end
	return Pathfinder.AStarWayAsm(t)
end
Pathfinder.AStarWay = AStarWay

local function NeighboursWay(FromArea, ToArea, Async, limit)
	local Reachable = {FromArea}
	local AreaWay = {}
	local Explored = {[FromArea] = true}
	local CurArea = FromArea
	local PathFound = false
	local Way = {}
	local count = 0
	local limit = limit or 1/0

	while #Reachable > 0 do
		for k,v in pairs(Reachable) do
			CurArea = v
			tremove(Reachable, k)
			break
		end

		if CurArea == ToArea then
			PathFound = true
			break
		end

		count = count + 1
		if count > limit then
			break
		end

		for k,v in pairs(MapAreas[CurArea].Neighbours) do
			if not Explored[k] then
				AreaWay[k] = CurArea
				tinsert(Reachable, k)
				Explored[k] = true
			end
		end

		if Async and timeGetTime() > TickEndTime then
			coyield()
		end
	end

	if PathFound then
		while CurArea ~= FromArea do
			tinsert(Way, 1, CurArea)
			CurArea = AreaWay[CurArea]
		end
	end

	return Way
end
Pathfinder.NWay = NeighboursWay

--------------------------------------------------
--				Import/Export					--
--------------------------------------------------
local function ImportAreasInfo(Path)
	HaveMapData = false
	Path = Path or "Data/BlockMaps/" .. Map.Name .. ".txt"
	local File = io.open(Path, "r")

	if not File then
		return false
	end

	local Floors, Areas, NWays = {}, {}, {}
	local LineIt = File:lines()
	local Words, Items, Area, Ways, Val
	local AllPoints = {}
	for line in LineIt do
		Words = string.split(line, "\9")
		if Words[1] == "." then
			AllPoints[tonumber(Words[2])] = {
				X = tonumber(Words[3]),
				Y = tonumber(Words[4]),
				Z = tonumber(Words[5]),
				StableZ = tonumber(Words[5]),
				NeedJump = string.lower(Words[2]) == "x"}

		elseif Words[1] == "*" then
			Area = Areas[tonumber(Words[2])]
			Area.Ways[tonumber(Words[3])] = string.split(Words[6], "|")

		elseif Words[1] == ">" then
			Area = tonumber(Words[2])
			Val = tonumber(Words[3])
			Items = string.split(Words[6] or "", "|")
			if Area and Val and #Items > 0 then
				for i,v in pairs(Items) do
					Items[i] = tonumber(v)
				end
				NWays[Area] = NWays[Area] or {}
				NWays[Area][Val] = Items
			end
		else
			Area = tonumber(Words[1])
			if Area then
				Areas[Area] = {
				Id = Area,
				WayPoint = {X = tonumber(Words[2]), Y = tonumber(Words[3]), Z = tonumber(Words[4])},
				S = tonumber(Words[5]),
				Ways = {},
				Floors = {},
				Neighbours = {}}

				Area = Areas[Area]

				Items = string.split(Words[6], "|")
				for k,v in pairs(Items) do
					Val = tonumber(v)
					if Val then
						tinsert(Area.Floors, Val)
					end
				end

				Items = string.split(Words[7], "|")
				for k,v in pairs(Items) do
					Val = tonumber(v)
					if Val then
						Area.Neighbours[Val] = true
					end
				end
			end
		end
	end

	for AreaId, Area in pairs(Areas) do
		for _,F in pairs(Area.Floors) do
			Floors[F] = AreaId
		end
	end

	for AId, A in pairs(Areas) do
		for A2Id, Way in pairs(A.Ways) do
			for WId, WayPoint in pairs(Way) do
				Way[WId] = AllPoints[tonumber(WayPoint)]
			end
		end
	end

	io.close(File)
	MapFloors, MapAreas, NeighboursWays = Floors, Areas, NWays
	HaveMapData = true
	return Floors, Areas, NWays
end

local function ExportAreasInfo(Areas, NWays, Path)
	local AllPoints = {}
	local CurId = 1
	for AId, A in pairs(Areas) do
		for A2Id, Way in pairs(A.Ways) do
			for WId, WayPoint in pairs(Way) do
				AllPoints[CurId] = WayPoint
				Way[WId] = tostring(CurId)
				CurId = CurId + 1
			end
		end
	end

	Path = Path or "Data/BlockMaps/" .. Map.Name .. ".txt"
	File = io.open(Path, "w")

	for i, P in ipairs(AllPoints) do
		File:write(".\9" .. i .. "\9" .. P.X .. "\9" .. P.Y .. "\9" .. P.Z .. "\9" .. (P.NeedJump and "X" or "-") .. "\n")
	end

	local cNeighbours
	for _, Area in pairs(Areas) do
		cNeighbours = {}
		for AreaId, NeighId in pairs(Area.Neighbours) do
			tinsert(cNeighbours, AreaId)
		end

		File:write(
			Area.Id .. "\9" ..
			Area.WayPoint.X .. "\9" ..
			Area.WayPoint.Y .. "\9" ..
			Area.WayPoint.Z .. "\9" ..
			Area.S .. "\9" ..
			table.concat(Area.Floors, "|") .. "\9" ..
			table.concat(cNeighbours, "|") .. "\n")

		for AreaId, Way in pairs(Area.Ways) do
			File:write("*\9" ..	Area.Id .. "\9" .. AreaId .. "\9" ..  "\9" .. "\9" .. table.concat(Way,"|") .. "\n")

		end
	end

	for FromA, Ways in pairs(NWays) do
		for ToA, Way in pairs(Ways) do
			File:write(">\9" .. FromA .. "\9" .. ToA .. "\9" .. "\9" .. "\9" .. table.concat(Way, "|") .. "\n")
		end
	end
	io.close(File)

	for AId, A in pairs(Areas) do
		for A2Id, Way in pairs(A.Ways) do
			for WId, WayPoint in pairs(Way) do
				Way[WId] = AllPoints[tonumber(WayPoint)]
			end
		end
	end

	AllPoints = nil
	collectgarbage("collect")
end

local function MakeAreasFromRooms(Floors, Areas, NWays, StartTime, Log)
	local CurArea

	-- Make areas
	for RoomId, Room in Map.Rooms do
		if Room.Portals.count > 0 then
			CurArea = {Id = RoomId, Floors = {}, Neighbours = {}, Ways = {}, WayPoint = {X = 0, Y = 0, Z = 0}, S = 0}
			Areas[RoomId] = CurArea

			-- Assign floors
			for _, FId in Room.Floors do
				Floors[FId] = RoomId
				table.insert(CurArea.Floors, FId)
			end
		end
	end

	-- Set neighbours
	local Facet
	for RoomId, Room in Map.Rooms do
		for _, PId in Room.Portals do
			Facet = Map.Facets[PId]
			Areas[Facet.RoomBehind].Neighbours[Facet.Room] = true
			Areas[Facet.Room].Neighbours[Facet.RoomBehind] = true
		end
	end
end

local function MakeAreasFromFacets(Floors, Areas, NWays, StartTime, Log)

	local MaxAreaSize = 6000000
	local MinAreaSize = 500000

	-- Init facets (FacetId = AreaId)
	for i,v in Map.Facets do
		if v.PolygonType == 3 or v.PolygonType == 4 or v.IsPortal then
			Floors[i] = 0
		end
	end

	for i,v in Map.Doors do
		for _, F in v.FacetIds do
			Floors[F] = 0
		end
	end

	-- Make Areas
	local CurArea
	local TotalS = 0
	local FoundAnother
	local f1, f2

	for FacetId, AreaId in pairs(Floors) do
		if AreaId == 0 then
			CurArea = {Id = #Areas + 1, Floors = {FacetId}, Neighbours = {}, Ways = {}, WayPoint = {X = 0, Y = 0, Z = 0}, S = 0}
			Floors[FacetId] = CurArea.Id
			Areas[CurArea.Id] = CurArea
			TotalS = 0
			FoundAnother = true
			while TotalS < MaxAreaSize and FoundAnother do
				FoundAnother = false
				for F, A in pairs(Floors) do
					if A == 0 and TotalS < MaxAreaSize then
						for k,v in pairs(CurArea.Floors) do
							f1 = Map.Facets[F]
							f2 = Map.Facets[v]
							if f1.Room == f2.Room and SharedVertexes(f1, f2) > 1 then
								tinsert(CurArea.Floors, F)
								Floors[F] = CurArea.Id
								TotalS = TotalS + FacetS(f1)
								CurArea.S = TotalS
								FoundAnother = true
								break
							end
						end
					end
				end
			end
		end
	end
	tinsert(Log, "Making areas: " .. os.time() - StartTime)

	-- Unassign facets from small areas
	local cNeighbours, SharedAmount
	for AreaId, Area in pairs(Areas) do
		if Area.S < MinAreaSize then
			cNeighbours = {}
			for AId, A in pairs(Areas) do
				if AreaId ~= AId then
					SharedAmount = 0
					for _, F1 in pairs(Area.Floors) do
						for __, F2 in pairs(A.Floors) do
							SharedAmount = SharedAmount + SharedVertexes(Map.Facets[F1], Map.Facets[F2])
							if SharedAmount > 2 then
								tinsert(cNeighbours, AId)
								break
							end
						end
					end
				end
			end

			if #cNeighbours > 0 then
				CurArea = cNeighbours[1]
				for k,v in pairs(cNeighbours) do
					if Areas[CurArea].S < Areas[v].S then
						CurArea = v
					end
				end
				CurArea = Areas[CurArea]
				CurArea.S = CurArea.S + Area.S
				Area.S = 0
				for k,v in pairs(Area.Floors) do
					Floors[v] = CurArea.Id
					Area.Floors[k] = nil
					tinsert(CurArea.Floors, v)
				end
			else
				for k,v in pairs(Area.Floors) do
					Floors[v] = 0
					Area.Floors[k] = nil
				end
				Area.S = 0
				XYZ(Area.WayPoint, -30000, -30000, -30000)
			end
		end
	end
	tinsert(Log, "Merging areas, step 1: " .. os.time() - StartTime)

	-- Rebuild array
	local Rebuild = {}
	for k,v in pairs(Areas) do
		if v.S ~= 0 then
			v.Id = #Rebuild + 1
			for _,F in pairs(v.Floors) do
				Floors[F] = v.Id
			end
			Rebuild[v.Id] = v
		end
	end
	Areas = Rebuild

	-- Remove empty areas and reassign facets to larger neighbours.
	local Distances
	local LastDist
	for FacetId, AreaId in pairs(Floors) do
		f1 = Map.Facets[FacetId]
		CurArea = nil
		if AreaId == 0 then
			Distances = {}
			for AId, Area in pairs(Areas) do
				for _,F in pairs(Area.Floors) do
					if SharedVertexes(f1, Map.Facets[F]) > 1 then
						CurArea = AId
						break
					end
					Distances[AId] = min(Distances[AId] or 1/0, DistanceBetweenFacets(f1, Map.Facets[F]))
				end
				if CurArea then
					break
				end
			end
			if not CurArea then
				LastDist = 1/0
				for AId, Dist in pairs(Distances) do
					if Dist < LastDist then
						LastDist = Dist
						CurArea = AId
					end
				end
			end
			Floors[FacetId] = CurArea or 0
			tinsert(Areas[CurArea].Floors, FacetId)
		end
	end

end

local function MakeWayPoints()
	local Floors, Areas, NWays = {}, {}, {}
	local StartTime = os.time()
	local Log = {}
	local counter = 0

	if Map.Rooms.count > 2 then
		MakeAreasFromRooms(Floors, Areas, NWays, StartTime, Log)
	else
		MakeAreasFromFacets(Floors, Areas, NWays, StartTime, Log)
	end

	-- Set way points
	local S, LastS, f1
	for AreaId, Area in pairs(Areas) do
		LastS = 0
		for _, F in pairs(Area.Floors) do
			S = FacetS(Map.Facets[F])
			if S > LastS then
				LastS = S
				f1 = F
			end
		end
		XYZ(Area.WayPoint, XYZ(FacetToPoint(Map.Facets[f1])))
	end
	tinsert(Log, "Merging areas, step 2: " .. os.time() - StartTime)

	-- Prepare for building ways
	MapAreas, MapFloors, NeighboursWays = Areas, Floors, NWays
	--local Mon, MonId = SummonMonster(1, XYZ(Party))
	--local MapInTxt = Game.MapStats[Map.MapStatsIndex]
	--Mon.AIState = const.AIState.Removed

	--local function tmpTargetArea(target)
	--	local _, F = Map.GetFloorLevel(XYZ(target))
	--	return Floors[F] or 0
	--end

	--local function CutWay(WayMap, StartArea, EndArea)
	--	while #WayMap >= 2 and tmpTargetArea(WayMap[1]) ~= StartArea do
	--		tremove(WayMap, 1)
	--	end
	--	while #WayMap >= 2 and tmpTargetArea(WayMap[2]) == StartArea do
	--		tremove(WayMap, 1)
	--	end
	--	while #WayMap >= 2 and tmpTargetArea(WayMap[#WayMap]) ~= EndArea do
	--		tremove(WayMap, #WayMap)
	--	end
	--	while #WayMap >= 2 and tmpTargetArea(WayMap[#WayMap-1]) == EndArea do
	--		tremove(WayMap, #WayMap)
	--	end
	--end

	-- Bake neighbour ways
	for AreaId, Area in pairs(Areas) do
		NWays[AreaId] = {}
		for AId, A in pairs(Areas) do
			if AreaId == AId then
				NWays[AreaId][AId] = {}
			else
				NWays[AreaId][AId] = NeighboursWay(AreaId, AId, false)
			end
		end
	end
	NeighboursWays = NWays
	tinsert(Log, "Baking neighbour ways: " .. os.time() - StartTime)

	-- TEST: Display areas
	--for AId,Area in pairs(Areas) do
	--	for k,v in pairs(Area.Floors) do
	--		Map.Facets[v].BitmapId = AId + 100
	--	end
	--end

	ExportAreasInfo(Areas, NWays)
	HaveMapData = true
	return Areas, Floors, NWays, table.concat(Log, "\n")
end
Pathfinder.MakeWayPoints = MakeWayPoints

--------------------------------------------------
--				Game handler					--
--------------------------------------------------
local AStarQueue = {}
Pathfinder.AStarQueue = AStarQueue

local function AStarQueueSort(v1, v2)
	return v1.Dist < v2.Dist
end
local function SortQueue()
	local Way, v, Mon
	for i = #AStarQueue, 1, -1 do
		v = AStarQueue[i]
		if v.MonId >= Map.Monsters.count then
			tremove(AStarQueue, i)
		elseif HaveMapData then
			Way = NeighboursWays[AreaOfTarget(Map.Monsters[v.MonId])]
			Way = Way and Way[AreaOfTarget(MonsterWays[v.MonId])]
			v.Dist = Way and #Way > 0 and #Way or 1/0
			if Map.Monsters[v.MonId].Fly == 1 then
				v.Dist = v.Dist + 10
			end
			v.Dist = v.Dist + v.MonWay.FailCount*10
		else
			Mon = Map.Monsters[v.MonId]
			v.Dist = GetDist2(Mon, v.Target)
			if Map.Monsters[v.MonId].Fly == 1 then
				v.Dist = v.Dist + 1000
			end
			v.Dist = v.Dist + v.MonWay.FailCount*1000
		end
	end
	table.sort(AStarQueue, AStarQueueSort)
end

local function ProcessThreads()
	if #AStarQueue == 0 then
		return
	end

	TickEndTime = timeGetTime() + 3
	SortQueue()

	local co = AStarQueue[1] and AStarQueue[1].co
	while co and timeGetTime() < TickEndTime do
		if costatus(co) == "dead" then
			tremove(AStarQueue, 1)
			co = AStarQueue[1] and AStarQueue[1].co
		else
			local err, res = coresume(co)
			if type(res) == "string" then
				debug.Message(res)
			end
		end
	end
end

local function BuildWayUsingMapData(FromArea, ToArea, MonId, Monster, Target, Async)
	local WayMap
	if not HaveMapData or ToArea == 0 then
		WayMap = AStarWay(MonId, Monster, Target, nil, Async)

	elseif FromArea == ToArea then
		WayMap = AStarWay(MonId, Monster, Target, {[FromArea] = true}, Async)

	elseif MapAreas[FromArea].Neighbours[ToArea] then
		WayMap = AStarWay(MonId, Monster, Target, {[FromArea] = true, [ToArea] = true}, Async)

	else
		WayMap = NeighboursWays[FromArea][ToArea]
		if WayMap and #WayMap > 0 then
			local AvAreas = {}
			AvAreas[FromArea] = true
			for k,v in pairs(WayMap) do
				AvAreas[v] = true
			end
			WayMap = AStarWay(MonId, Monster, Target, AvAreas, Async)
		else
			WayMap = AStarWay(MonId, Monster, Target, nil, Async)
		end
	end
	return WayMap
end
Pathfinder.BuildWayUsingMapData = BuildWayUsingMapData

local function MakeMonWay(cMonWay, cMonId, cTarget)
	cMonWay.InProcess = true
	cMonWay.NeedRebuild = false
	cMonWay.X = cTarget.X
	cMonWay.Y = cTarget.Y
	cMonWay.Z = cTarget.Z
	coyield()

	cMonWay.HoldMonster = true
	local WayMap
	local Monster = Map.Monsters[cMonId]
	local TooFar = false
	local FromArea, ToArea = AreaOfTarget(Monster), AreaOfTarget(cTarget)

	WayMap = BuildWayUsingMapData(FromArea, ToArea, cMonId, Monster, cTarget, true)

	if #WayMap > 0 then
		cMonWay.GenTime = Game.Time
		cMonWay.FailCount = 0
	else
		 -- delay next generation if previous one failed
		cMonWay.FailCount = cMonWay.FailCount + 1
		cMonWay.GenTime = Game.Time + const.Minute*4
	end
	Monster.AIState = 6
	cMonWay.WayMap = WayMap
	cMonWay.Step = 1
	cMonWay.TargetArea = ToArea
	cMonWay.Size = #cMonWay.WayMap
	cMonWay.HoldMonster = false
	cMonWay.InProcess = false
end

local function SetQueueItem(MonWay, MonId, Target)
	local co = cocreate(MakeMonWay)
	coresume(co, MonWay, MonId, Target)
	tinsert(AStarQueue, {co = co, MonId = MonId, Dist = ceil(GetDist2(Map.Monsters[MonId], Target)), Target = Target, MonWay = MonWay})
end

local function StuckCheck(MonId, Monster)
	if AreaOfTarget(Monster) == 0 then
		return true
	end

	MonStuck[MonId] = MonStuck[MonId] or {X = 0, Y = 0, Z = 0, Time = Game.Time, Stuck = 0}
	local StuckCheck = MonStuck[MonId]
	if Monster.AIState == 6 and EqualCoords(StuckCheck, Monster) then
		StuckCheck.Stuck = Game.Time - StuckCheck.Time
		if StuckCheck.Stuck > 512 then
			StuckCheck.Stuck = 0
			return true
		end
	else
		StuckCheck.Time = Game.Time
		StuckCheck.Stuck = 0
		StuckCheck.X = Monster.X
		StuckCheck.Y = Monster.Y
		StuckCheck.Z = Monster.Z
	end

	return false
end

local function MonsterNeedsProcessing(Mon)
	local result = true
	if not (Mon.Active and Mon.HP > 0) then
		return false
	end

	if IsOutdoor then
		result = Mon.Fly == 0 and GetDist2(Mon, Party) < 12000
	else
		if Mon.Fly == 1 then
			result = GetDist2(Mon, Party) < 6000
		else
			result = GetDist2(Mon, Party) < 12000
		end
	end
	return result and (Mon.AIState == 6 or (Mon.ShowAsHostile and Mon.AIState == 1))
end

local NextMon = 0
local function ProcessNextMon()
	if Game.TurnBased == 1 then
		return
	end

	if IsOutdoor and Party.Z - Map.GetFloorLevel(XYZ(Party)) > 200 then
		return
	end

	local Target, TargetRef, Monster, MonWay
	local count = 0
	if NextMon >= Map.Monsters.count then
		NextMon = 0
	end

	for MonId = NextMon, Map.Monsters.count - 1 do
		if count > 20 then
			break
		end

		count = count + 1
		NextMon = MonId + 1
		Monster = Map.Monsters[MonId]

		if MonsterNeedsProcessing(Monster) then

			TargetRef, Target = GetMonsterTarget(MonId)
			-- 11 is const.PartyBuff.Invisibility
			if TargetRef == 4 and Party.SpellBuffs[11].ExpireTime < Game.Time then
				Target = Party
			elseif TargetRef == 3 and Target < Map.Monsters.count then
				Target = Map.Monsters[Target]
			else
				Target = false
			end

			--Target = Party

			MonWay = MonsterWays[MonId] or {
				WayMap = {},
				NeedRebuild = true,
				InProcess = false,
				TargetInSight = false,
				GenTime	= 0,
				StuckTime = 0,
				TargetArea = 0,
				Size = 0,
				Step = 0,
				FailCount = 0}

			MonsterWays[MonId] = MonWay

			if Target then
				if IsOutdoor then
					MonWay.TargetInSight = GetDist2(Target, Monster) < 2500 and TraceReach(MonId, Monster, Target)
				else
					MonWay.TargetInSight = GetDist2(Target, Monster) < 2500 and TraceSight(Monster, Target) and TraceSight(Target, Monster)
				end
			else
				MonWay.TargetInSight = true
			end

			if StuckCheck(MonId, Monster) then
				if not IsOutdoor and #MonWay.WayMap > 0 and MonWay.Step > 1 and MonWay.Step <= #MonWay.WayMap then
					XYZ(Monster, XYZ(MonWay.WayMap[MonWay.Step-1]))
					Monster.Z = Monster.Z + 5
				end
				MonWay.NeedRebuild = true
			end

			if not Target or MonWay.TargetInSight then
				-- skip

			elseif MonWay.HoldMonster then
				Monster.GraphicState = 0
				Monster.AIState = 0
				Monster.CurrentActionLength = 100
				Monster.CurrentActionStep = 0

			elseif MonWay.NeedRebuild then
				if MonWay.InProcess then
					MonWay.NeedRebuild = false
				elseif #AStarQueue < 50 then
					SetQueueItem(MonWay, MonId, Target)
				end

			elseif #MonWay.WayMap > 0 then
				local Way = MonWay.WayMap[MonWay.Step]

				Monster.GraphicState = 1
				Monster.AIState = 6
				Monster.CurrentActionLength = 100
				Monster.CurrentActionStep = 0

				if not IsOutdoor and Way.Z < Monster.Z - 35 then
					local StableZ = Map.GetFloorLevel(XYZ(Monster))
					if abs(StableZ - Monster.Z) < 5 then
						Monster.VelocityZ = 500
					end
				end

				if not MonWay.InProcess and AreaOfTarget(Target) ~= MonWay.TargetArea then
					MonWay.NeedRebuild = true
				end

			elseif MonWay.InProcess then
				-- let it roam
			else
				if Game.Time - MonWay.GenTime > const.Minute*2 then
					MonWay.NeedRebuild = true
				end
			end
		end
	end
end

local function PositionCheck()
	if Game.TurnBased == 1 then
		return
	end

	local Monster
	for k,v in pairs(MonsterWays) do
		if k >= Map.Monsters.count then
			MonsterWays[k] = nil
			return
		end
		Monster = Map.Monsters[k]
		if not v.TargetInSight and v.WayMap and v.Size > 0 and MonsterNeedsProcessing(Monster) then
			local WayPoint = v.WayMap[v.Step]
			if WayPoint then
				Monster.Direction = DirectionToPoint(WayPoint, Monster)
				if GetDistXY(WayPoint.X, WayPoint.Y, Monster.X, Monster.Y) < Monster.BodyRadius then
					if v.Step >= v.Size then
						v.WayMap = {}
						v.Size = 0
						if not v.InProcess then
							v.NeedRebuild = true
						end
					else
						v.Step = v.Step + 1
					end
				end
			elseif not v.InProcess and Game.Time > MonWay.GenTime then
				v.NeedRebuild = true
			end
		end
	end
end

local function PathfinderTick()
	ProcessNextMon()
	ProcessThreads()
	--PositionCheck()
end

--------------------------------------------------
--					Events						--
--------------------------------------------------

function events.AfterLoadMap()
	MonsterWays = {}
	MonStuck = {}
	Pathfinder.MonsterWays = MonsterWays
	Pathfinder.MonStuck = MonStuck

	events.Remove("Tick", PathfinderTick)
	events.Remove("MonstersChooseDirection", PositionCheck)

	if not Game.ImprovedPathfinding then
		return
	end

	IsOutdoor = Map.IsOutdoor()

	if IsOutdoor then
		Pathfinder.HaveMapData = false
		Pathfinder.StartQueueHandler()
		if Pathfinder.QueueStatus() == const.AStarQueueStatus.Working then
			events.Tick = PathfinderTick
			events.MonstersChooseDirection = PositionCheck
		end
	else
		MapFloors, MapAreas, NeighboursWays = {}, {}, {}
		ImportAreasInfo()
		Pathfinder.HaveMapData = HaveMapData
		Pathfinder.MapFloors = MapFloors
		Pathfinder.MapAreas = MapAreas
		Pathfinder.NWays = NeighboursWays

		events.Tick = PathfinderTick
		events.MonstersChooseDirection = PositionCheck
	end
end

----------------------------------------------
--					SERVICE					--
----------------------------------------------

--~ --TestPerfomance(AStarWay, 10, 2, Map.Monsters[2], Party, nil, false, MapAreas[16].WayPoint)
--~ function TestPerfomance(f, loopamount, ...)
--~ 	loopamount = loopamount or 100
--~ 	local Start = timeGetTime()
--~ 	for i = 1, loopamount do
--~ 		f(...)
--~ 	end
--~ 	return timeGetTime() - Start
--~ end

--~ function ShowWay(WayMap, Pause)
--~ 	Pause = Pause or 300
--~ 	local Step = 1
--~ 	local PrevCell, NextCell = WayMap[Step], WayMap[Step + 1]
--~ 	while NextCell do
--~ 		Party.X = NextCell.X
--~ 		Party.Y = NextCell.Y
--~ 		Party.Z = NextCell.Z + 5
--~ 		Sleep(Pause,Pause)

--~ 		Step = Step + 1
--~ 		PrevCell, NextCell = WayMap[Step], WayMap[Step + 1]
--~ 	end
--~ end

--~ function ClosestMonster()
--~ 	local MinDist, Mon = 30000, 123
--~ 	for i,v in Map.Monsters do
--~ 		local Dist = GetDist2(Party, v)
--~ 		if MinDist > Dist then
--~ 			MinDist, Mon = Dist, i
--~ 		end
--~ 	end
--~ 	return Mon
--~ end

--~ DisableOutdoorHandler = DisableOutdoorHandler or mem.asmpatch(0x401ab1, "retn")

--~ function ClosestItem(t)
--~ 	local MinDist, Mon = 1/0, nil
--~ 	for i,v in pairs(t) do
--~ 		local Dist = GetDist2(Party, v)
--~ 		if MinDist > Dist then
--~ 			MinDist, Mon = Dist, i
--~ 		end
--~ 	end
--~ 	return Mon
--~ end

--~ function GetPoint(t)
--~ 	return {X = t.X, Y = t.Y, Z = t.Z} -- -1215 -1206
--~ end

--~ function events.AfterLoadMap()
--~ 	function CreateTESTWidget()
--~ 		TESTWidget = CustomUI.CreateText{Text = "", Key = "TESTWidget", X = 200, Y = 240, Width = 400, Height = 100, AlignLeft = true}

--~ 		local function WidgetTimer()
--~ 			TESTWidget.Text = tostring(mem.call(Pathfinder.AltGetFloorLevelAsm, 0, Party.X, Party.Y, Party.Z)) ..
--~ 				" - " .. tostring(Map.GetFloorLevel(XYZ(Party))) .. " : " .. Pathfinder.QueueStatus() .. " - " ..  tostring(#AStarQueue)
--~ 			Game.NeedRedraw = true
--~ 		end

--~ 		Timer(WidgetTimer, const.Minute/64)
--~ 	end
--~ 	CreateTESTWidget()
--~ end

