
Pathfinder = {}

local CellItemSize = 20
local CellsAmount = 8000
local AllCellsPtr = mem.StaticAlloc(CellItemSize*(CellsAmount+2))
local ReachableAsm = mem.StaticAlloc(CellsAmount*2)

local MAXTracingPrecision, MINTracingPrecision = 1500, 100
local AllowedDirections = {
{X =  0, 	Y =  1,		Z = 0},
{X = -1, 	Y =  1, 	Z = 0},
{X = -1, 	Y =  0,		Z = 0},
{X = -1, 	Y = -1,		Z = 0},
{X =  0, 	Y = -1,		Z = 0},
{X =  1, 	Y = -1,		Z = 0},
{X =  1, 	Y =  0,		Z = 0},
{X =  1, 	Y =  1,		Z = 0},

{X =  0, 	Y =  1,		Z = 1},
{X = -1, 	Y =  1, 	Z = 1},
{X = -1, 	Y =  0,		Z = 1},
{X = -1, 	Y = -1,		Z = 1},
{X =  0, 	Y = -1,		Z = 1},
{X =  1, 	Y = -1,		Z = 1},
{X =  1, 	Y =  0,		Z = 1},
{X =  1, 	Y =  1,		Z = 1},

{X =  0, 	Y =  1,		Z = -1},
{X = -1, 	Y =  1, 	Z = -1},
{X = -1, 	Y =  0,		Z = -1},
{X = -1, 	Y = -1,		Z = -1},
{X =  0, 	Y = -1,		Z = -1},
{X =  1, 	Y = -1,		Z = -1},
{X =  1, 	Y =  0,		Z = -1},
{X =  1, 	Y =  1,		Z = -1},

--~ {X =  0, 	Y =  0,		Z = -1},
--~ {X =  0, 	Y =  0,		Z = 1}
}

local function cdataPtr(obj)
	return tonumber(string.sub(tostring(obj), -10))
end

local AvAreasAsm = mem.StaticAlloc(20)
local Floors = 0
local FloorsPtr = mem.StaticAlloc(8)
local EndOfFloors = FloorsPtr + 4
local function BakeFloors(MapFloors)
	-- Causes random crashes. Disabled for now.
--~ 	if not MapFloors then
--~ 		return
--~ 	end
--~ 	local n = 0
--~ 	for k,v in pairs(MapFloors) do
--~ 		n = n + 1
--~ 	end
--~ 	if n == 0 then
--~ 		return
--~ 	end
--~ 	n = math.max(n, 1)

--~ 	Floors = mem.malloc(Map.Facets.count*2)
--~ 	for k,v in pairs(MapFloors) do
--~ 		mem.u2[Floors + k*2] = v
--~ 	end

--~ 	mem.u4[FloorsPtr] = Floors
--~ 	mem.u4[EndOfFloors] = Floors + n*2
end
Pathfinder.BakeFloors = BakeFloors

function events.BeforeLoadMap()
	if Floors > 0 then
		mem.free(Floors)
	end
	mem.u4[FloorsPtr] = 0
	mem.u4[EndOfFloors] = 0
end

mem.hookalloc(0x1000)

------------------------------------------------------
--					GetFloorLevel					--
------------------------------------------------------
-- Unlike Map.GetFloorLevel, does not mess game data, when executed in separate thread

-- Takes two vectors, returns cosine in st0
local GetCosVec = mem.asmproc([[
	push ebp
	mov ebp, esp

	; get scalar mul
	mov edx, dword [ss:ebp+0x8]
	mov eax, dword [ds:edx]
	mov edx, dword [ss:ebp+0xC]
	mov edx, dword [ds:edx]
	imul eax, edx

	mov edx, dword [ss:ebp+0x8]
	mov ecx, dword [ds:edx+0x4]
	mov edx, dword [ss:ebp+0xC]
	mov edx, dword [ds:edx+0x4]
	xchg eax, ecx
	imul eax, edx
	add eax, ecx

	mov edx, dword [ss:ebp+0x8]
	mov ecx, dword [ds:edx+0x8]
	mov edx, dword [ss:ebp+0xC]
	mov edx, dword [ds:edx+0x8]
	xchg eax, ecx
	imul eax, edx
	add eax, ecx
	push eax; store scalar mul for future FPU manipulations

	; get V1 module
	mov edx, dword [ss:ebp+0x8]
	mov eax, dword [ds:edx]
	imul eax, eax
	xchg eax, ecx
	mov eax, dword [ds:edx+0x4]
	imul eax, eax
	add eax, ecx
	xchg eax, ecx
	mov eax, dword [ds:edx+0x8]
	imul eax, eax
	add eax, ecx
	push eax; store V1 module for future FPU manipulations.

	; get V2 module
	mov edx, dword [ss:ebp+0xC]
	mov eax, dword [ds:edx]
	imul eax, eax
	xchg eax, ecx
	mov eax, dword [ds:edx+0x4]
	imul eax, eax
	add eax, ecx
	xchg eax, ecx
	mov eax, dword [ds:edx+0x8]
	imul eax, eax
	add eax, ecx
	push eax; store V2 module for future FPU manipulations.

	fild dword [ss:esp]
	pop eax
	fild dword [ss:esp]
	pop eax
	fild dword [ss:esp]
	pop eax

	fxch st2
	fsqrt
	fxch
	fsqrt
	fmul st0, st1
	fstp st1
	fxch
	fdiv st0, st1
	fstp st1

	mov esp, ebp
	pop ebp
	retn]])

-- Takes two vectors, returns angle in st0
local GetAngleVec = mem.asmproc([[
	push ebp
	mov ebp, esp

	; get scalar mul
	mov edx, dword [ss:ebp+0x8]
	mov eax, dword [ds:edx]
	mov edx, dword [ss:ebp+0xC]
	mov edx, dword [ds:edx]
	imul eax, edx

	mov edx, dword [ss:ebp+0x8]
	mov ecx, dword [ds:edx+0x4]
	mov edx, dword [ss:ebp+0xC]
	mov edx, dword [ds:edx+0x4]
	xchg eax, ecx
	imul eax, edx
	add eax, ecx

	mov edx, dword [ss:ebp+0x8]
	mov ecx, dword [ds:edx+0x8]
	mov edx, dword [ss:ebp+0xC]
	mov edx, dword [ds:edx+0x8]
	xchg eax, ecx
	imul eax, edx
	add eax, ecx
	push eax; store scalar mul for future FPU manipulations

	; get V1 module
	mov edx, dword [ss:ebp+0x8]
	mov eax, dword [ds:edx]
	imul eax, eax
	xchg eax, ecx
	mov eax, dword [ds:edx+0x4]
	imul eax, eax
	add eax, ecx
	xchg eax, ecx
	mov eax, dword [ds:edx+0x8]
	imul eax, eax
	add eax, ecx
	push eax; store V1 module for future FPU manipulations.

	; get V2 module
	mov edx, dword [ss:ebp+0xC]
	mov eax, dword [ds:edx]
	imul eax, eax
	xchg eax, ecx
	mov eax, dword [ds:edx+0x4]
	imul eax, eax
	add eax, ecx
	xchg eax, ecx
	mov eax, dword [ds:edx+0x8]
	imul eax, eax
	add eax, ecx
	push eax; store V2 module for future FPU manipulations.

	fild dword [ss:esp]
	pop eax
	fild dword [ss:esp]
	pop eax
	fild dword [ss:esp]
	pop eax

	fxch st2
	fsqrt
	fxch
	fsqrt
	fmul st0, st1
	fstp st1
	fxch
	fdiv st0, st1

	; get acos
	fst st1
	fmul st0, st0
	fld1
	fsub st0, st1
	fsqrt
	fstp st1
	fxch
	fpatan

	mov esp, ebp
	pop ebp
	retn]])

-- Takes two points, returns vector from first to second
local MakeVec3D = mem.asmproc([[
	push ecx
	push edi

	mov edx, dword [ss:esp+0xC]; From
	mov ecx, dword [ss:esp+0x10]; To
	mov edi, dword [ss:esp+0x14]; Dest

	mov eax, dword [ds:ecx]
	sub eax, dword [ds:edx]
	mov dword [ds:edi], eax

	mov eax, dword [ds:ecx+0x4]
	sub eax, dword [ds:edx+0x4]
	mov dword [ds:edi+0x4], eax

	mov eax, dword [ds:ecx+0x8]
	sub eax, dword [ds:edx+0x8]
	mov dword [ds:edi+0x8], eax

	pop edi
	pop ecx

	retn]])

-- Ignores Z coordinate
local MakeVec2D = mem.asmproc([[
	push ecx
	push edi

	mov edx, dword [ss:esp+0xC]; From
	mov ecx, dword [ss:esp+0x10]; To
	mov edi, dword [ss:esp+0x14]; Dest

	mov eax, dword [ds:ecx]
	sub eax, dword [ds:edx]
	mov dword [ds:edi], eax

	mov eax, dword [ds:ecx+0x4]
	sub eax, dword [ds:edx+0x4]
	mov dword [ds:edi+0x4], eax

	mov dword [ds:edi+0x8], 0

	pop edi
	pop ecx

	retn]])

-- Takes two points, returns vector from first to second
local VectorMul = mem.asmproc([[
	push edi
	push esi
	push ebx

	mov ebx, dword [ss:esp+0x10]; From
	mov esi, dword [ss:esp+0x14]; To
	mov edi, dword [ss:esp+0x18]; Dest

	; calc X
	mov eax, dword [ds:ebx+0x4]
	mov ecx, dword [ds:esi+0x8]
	imul eax, ecx
	mov edx, eax

	mov eax, dword [ds:ebx+0x8]
	mov ecx, dword [ds:esi+0x4]
	imul eax, ecx
	sub edx, eax

	mov dword [ds:edi], edx

	; calc Y
	mov eax, dword [ds:ebx+0x8]
	mov ecx, dword [ds:esi]
	imul eax, ecx
	mov edx, eax

	mov eax, dword [ds:ebx]
	mov ecx, dword [ds:esi+0x8]
	imul eax, ecx
	sub edx, eax

	mov dword [ds:edi+0x4], edx

	; calc Z
	mov eax, dword [ds:ebx]
	mov ecx, dword [ds:esi+0x4]
	imul eax, ecx
	mov edx, eax

	mov eax, dword [ds:ebx+0x4]
	mov ecx, dword [ds:esi]
	imul eax, ecx
	sub edx, eax

	mov dword [ds:edi+0x8], edx

	pop ebx
	pop esi
	pop edi

	retn]])

-- takes X, Y, Z, VertexIds List, VertexesCount,
-- returns 1 in eax if point is in projection of polygon, defined by vertex list.
-- mem.call(Pathfinder.PointInProjection, 0, X, Y, Z, VertexIds, VertexesCount)
local PointInProjection = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x28
	mov edi, esp

	mov eax, dword [ss:ebp+0x8]
	mov dword [ds:edi], eax
	mov eax, dword [ss:ebp+0xC]
	mov dword [ds:edi+0x4], eax
	mov eax, dword [ss:ebp+0x10]
	mov dword [ds:edi+0x8], eax

	fldpi; Pi to check 180 deg angles
	fldz; 0.00 to accumulate total angle

	dec dword [ss:ebp+0x18]
	xor ecx, ecx
	dec ecx
	mov dword [ss:edi+0x24], ecx
	mov eax, dword [ss:ebp+0x18]
	jmp @start

	@rep:
	mov eax, ecx
	@start:
	imul eax, eax, 0x2
	add eax, dword [ss:ebp+0x14]; VertexIds List
	movsx eax, word [ds:eax]; Vertex Id
	imul eax, eax, 0x6
	add eax, dword [ds:0x6f3c7c]; MapVertexes ptr

	movsx edx, word [ds:eax]
	mov dword [ds:edi+0xC], edx
	movsx edx, word [ds:eax+0x2]
	mov dword [ds:edi+0x10], edx
	movsx edx, word [ds:eax+0x4]
	mov dword [ds:edi+0x14], edx

	mov eax, ecx
	inc eax
	imul eax, eax, 0x2
	add eax, dword [ss:ebp+0x14]; VertexIds List
	movsx eax, word [ds:eax]; Vertex Id
	imul eax, eax, 0x6
	add eax, dword [ds:0x6f3c7c]; MapVertexes ptr

	movsx edx, word [ds:eax]
	mov dword [ds:edi+0x18], edx
	movsx edx, word [ds:eax+0x2]
	mov dword [ds:edi+0x1C], edx
	movsx edx, word [ds:eax+0x4]
	mov dword [ds:edi+0x20], edx

	mov eax, dword [ds:edi+0xC]
	cmp eax, dword [ds:edi+0x18]
	jne @nodouble

	mov eax, dword [ds:edi+0x10]
	cmp eax, dword [ds:edi+0x1C]
	jne @nodouble
	jmp @con

	@nodouble:
	mov edx, edi
	add edx, 0xC
	push edx
	push edx
	push edi
	call absolute ]] .. MakeVec2D .. [[;
	add esp, 0xC

	mov edx, edi
	add edx, 0x18
	push edx
	push edx
	push edi
	call absolute ]] .. MakeVec2D .. [[;
	add esp, 0xC

	mov edx, edi
	add edx, 0xC
	push edx
	add edx, 0xC
	push edx
	call absolute ]] .. GetAngleVec .. [[;
	add esp, 0x8

	fldz
	fxch
	fst st1
	fsub st0, st3
	fabs
	push 100
	fild dword [ds:esp]
	fmul st0, st1
	frndint
	fist dword [ds:esp]
	fcompp
	pop eax
	cmp eax, 2
	;fcomi st2; compare angle in st0 with Pi in st2
	jle @atedge

	;check Z val of vector mul of V1 and V2
	mov eax, dword [ss:edi+0xC]
	mov edx, dword [ss:edi+0x1C]
	imul eax, edx
	xchg eax, ecx
	mov eax, dword [ss:edi+0x10]
	mov edx, dword [ss:edi+0x18]
	imul eax, edx
	xchg eax, ecx
	sub eax, ecx
	cmp eax, 0
	jle @neg
	faddp st1, st0
	jmp @con

	@neg:
	fsubp st1, st0

	@con:
	inc dword [ss:edi+0x24]
	mov ecx, dword [ss:edi+0x24]
	cmp ecx, dword [ss:ebp+0x18]
	jl @rep

	push 0
	fdiv st0, st1
	fistp dword [ds:esp]
	pop eax
	cmp eax, 2
	jge @inside
	fcomp
	xor eax, eax
	jmp @end

	@atedge:
	fcompp

	@inside:
	fcomp
	xor eax, eax
	inc eax

	@end:
	add esp, 0x28
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

Pathfinder.PointInProjection = PointInProjection

-- Takes FacetId, X, Y, returns ZLevel of point on plane defined by facet.
-- mem.call(Pathfinder.GetPlaneZLevel, 0, 280, Party.X, Party.Y)
local GetPlaneZLevel = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x34
	mov edi, esp

	mov esi, dword [ds:ebp+0x8]
	imul esi, esi, 96; Facet size
	add esi, dword [ds:0x6f3c84]; MapFacets ptr

	mov ecx, dword [ds:esi+0x30]; VertexIds
	movsx edx, word [ds:esi+0x5d]; VertexesCount

	; choose vertex ids

	;1: always first vertex
	movsx eax, word [ds:ecx]
	mov dword [ss:edi], eax

	;2: middle index
	mov eax, edx
	shr eax, 1
	shl eax, 1
	movsx edx, word [ds:ecx+eax]
	mov dword [ss:edi+0xC], edx

	;3: next one
	add eax, 0x2
	movsx edx, word [ds:ecx+eax]
	mov dword [ss:edi+0x18], edx

	; setup vertex coords
	xor ecx, ecx

	@rep1:
	mov eax, ecx
	imul eax, 0xC
	mov esi, dword [ss:edi+eax]; VertexId
	imul esi, esi, 0x6
	add esi, dword [ds:0x6f3c7c]; MapVertexes ptr

	add eax, edi

	movsx edx, word [ds:esi]
	mov dword [ss:eax], edx
	movsx edx, word [ds:esi+0x2]
	mov dword [ss:eax+0x4], edx
	movsx edx, word [ds:esi+0x4]
	mov dword [ss:eax+0x8], edx

	inc ecx
	cmp ecx, 3
	jl @rep1

	; calc vertex mul
	lea eax, dword [ds:edi+0xC]
	push eax
	push eax
	push edi
	call absolute ]] .. MakeVec3D .. [[;
	add esp, 0xC

	lea eax, dword [ds:edi+0x18]
	push eax
	push eax
	push edi
	call absolute ]] .. MakeVec3D .. [[;
	add esp, 0xC

	lea eax, dword [ds:edi+0x24]
	push eax
	lea eax, dword [ds:edi+0xC]
	push eax
	lea eax, dword [ds:edi+0x18]
	push eax
	call absolute ]] .. VectorMul .. [[;
	add esp, 0xC

	cmp dword [ss:edi+0x2c], 0
	je @flat

	mov eax, dword [ss:ebp+0xC]; X
	sub eax, dword [ds:edi]
	imul eax, dword [ds:edi+0x24]
	mov ecx, eax

	mov eax, dword [ss:ebp+0x10]; Y
	sub eax, dword [ds:edi+0x4]
	imul eax, dword [ds:edi+0x28]
	add eax, ecx

	mov ecx, dword [ss:edi+0x2c]
	xor edx, edx
	cmp eax, 0
	jge @positive
	dec edx
	@positive:
	idiv ecx
	mov ecx, eax
	mov eax, dword [ds:edi+0x8]
	sub eax, ecx
	jmp @end

	@flat:
	mov eax, dword [ss:edi+0x8]

	@end:
	add esp, 0x34
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

Pathfinder.GetPlaneZLevel = GetPlaneZLevel

-- takes X, Y, Z, returns floor level in eax, facetid in ecx
-- mem.call(Pathfinder.AltGetFloorLevelAsm, 0, Party.X, Party.Y, Party.Z)
local AltGetFloorLevelAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi

	xor eax, eax
	cmp dword [ds:0x6f39a0], 1; is indoor
	jne @end

	mov ecx, 0x6f3a08
	add dword [ss:ebp+0x10], 0xA
	push dword [ss:ebp+0x10]; Z
	add dword [ss:esp], 0x64
	push dword [ss:ebp+0xC]; Y
	push dword [ss:ebp+0x8]; X
	call absolute 0x4980ba
	test eax, eax
	push -1; facet ids list in stack border
	jne @con

	@fault:
	pop eax
	mov eax, -30000
	xor ecx, ecx
	jmp @end

	@con:
	imul eax, eax, 120; MapRoom size
	add eax, dword [ds:0x6f3c94]; contain Rooms ptr
	mov ecx, dword [ds:eax+0x8]; floors count
	mov eax, dword [ds:eax+0xC]; floors ptr
	mov esi, ecx
	imul esi, esi, 2
	add esi, eax

	@rep:
	sub esi, 2
	dec ecx
	cmp ecx, 0
	jl @con2

	movsx eax, word [ds:esi]; Facet id
	imul eax, eax, 96; Facet size
	add eax, dword [ds:0x6f3c84]; MapFacets ptr
	cmp byte [ds:eax+0x5d], 3; VertexesCount
	jl @rep

	mov edx, dword [ss:ebp+0x10]; Z
	cmp dx, word [ds:eax+0x58]; MinZ
	jl @rep

	mov edx, dword [ss:ebp+0x8]; X
	cmp dx, word [ds:eax+0x50]; MinX
	jl @rep

	cmp dx, word [ds:eax+0x52]; MaxX
	jg @rep

	mov edx, dword [ss:ebp+0xC]; Y
	cmp dx, word [ds:eax+0x54]; MinY
	jl @rep

	cmp dx, word [ds:eax+0x56]; MaxY
	jg @rep

	movsx edx, word [ds:eax+0x5d]; VertexesCount
	push ecx
	push edx
	push dword [ds:eax+0x30]; VertexIds array
	push dword [ss:ebp+0x10]
	push dword [ss:ebp+0xC]
	push dword [ss:ebp+0x8]; X,Y,Z
	call absolute ]] .. PointInProjection .. [[;
	add esp, 0x14
	pop ecx
	test eax, eax
	je @rep

	movsx eax, word [ds:esi]; Facet id
	push eax
	jmp @rep

	@con2:
	mov edi, esp
	mov eax, dword [ss:edi]
	cmp eax, -1
	je @fault

	mov esi, -30000
	push dword [ss:ebp+0xC]; Y
	push dword [ss:ebp+0x8]; X

	@rep2:
	push eax; Facet id
	call absolute ]] .. GetPlaneZLevel .. [[; returns ZLevel of X,Y point on plane defined by facet.
	mov dword [ss:edi], eax
	cmp eax, esi
	pop ecx
	jle @con3
	mov esi, eax
	mov dword [ss:ebp+0x10], ecx
	@con3:
	add edi, 0x4
	mov eax, dword [ss:edi]
	cmp eax, -1
	jne @rep2

	mov eax, esi
	mov ecx, dword [ss:ebp+0x10]
	mov esp, edi
	add esp, 0x4

	@end:
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

Pathfinder.AltGetFloorLevelAsm = AltGetFloorLevelAsm

------------------------------------------------------

-- Takes eax, returns |eax|
local absAsm = mem.asmproc([[
	cmp eax, 0
	jge @end
	neg eax
	@end:
	retn]])

-- Takes x1,y1,x2,y2, returns distance in eax and st0, x1-x2 and y1-y2 in edx and ecx
local GetDistXYAsm = mem.asmproc([[
	mov eax, dword [ss:esp+0x4]
	mov ecx, dword [ss:esp+0xc]
	sub eax, ecx
	push eax
	call absolute ]] .. absAsm .. [[;
	imul eax, eax
	mov edx, eax

	mov eax, dword [ss:esp+0xC]
	mov ecx, dword [ss:esp+0x14]
	sub eax, ecx
	push eax
	call absolute ]] .. absAsm .. [[;
	imul eax, eax

	add eax, edx
	push 0
	push eax
	fild qword [ss:esp]
	fsqrt
	fist dword [ss:esp]
	pop eax
	pop ecx
	pop ecx
	pop edx

	retn]])

-- Takes x1,y1,z1,x2,y2,z2 returns distance in eax.
local GetDistAsm = mem.asmproc([[
	push ebp
	mov ebp, esp

	mov eax, dword [ss:ebp+0x8]
	mov ecx, dword [ss:ebp+0x14]
	sub eax, ecx
	call absolute ]] .. absAsm .. [[;
	imul eax, eax
	push eax

	mov eax, dword [ss:ebp+0xC]
	mov ecx, dword [ss:ebp+0x18]
	sub eax, ecx
	call absolute ]] .. absAsm .. [[;
	imul eax, eax
	push eax

	mov eax, dword [ss:ebp+0x10]
	mov ecx, dword [ss:ebp+0x1c]
	sub eax, ecx
	call absolute ]] .. absAsm .. [[;
	imul eax, eax
	push eax

	pop eax
	pop ecx
	pop edx

	add eax, ecx
	add eax, edx

	push 0
	push eax
	fild qword [ss:esp]
	fsqrt
	fist dword [ss:esp]
	ffree st0
	pop eax
	pop ecx

	mov esp, ebp
	pop ebp
	retn]])

-- mem.call(DirectionToPointAsm, 0, -5456, 4981, -5456, 4981)
-- Takes x1,y1,x2,y2, returns direction (0-2048) in eax and distance in ecx
local DirectionToPointAsm = mem.asmproc([[
	push ebp
	mov ebp, esp

	; get X (edx), Y (ecx) and Hy (eax, st0)
	push dword [ss:ebp+0x14]
	push dword [ss:ebp+0x10]
	push dword [ss:ebp+0xc]
	push dword [ss:ebp+0x8]
	call absolute ]] .. GetDistXYAsm .. [[;
	mov esp, ebp
	push eax
	test eax, eax
	je @end

	; get Y
	mov eax, ecx
	call absolute ]] .. absAsm .. [[;

	; move Y to st0 (Hy to st1), divide.
	push 0
	push eax
	fild qword [ss:esp]
	fdiv st0, st1

	; get asin
	fst st1
	fmul st0, st0
	fld1
	fsub st0, st1
	fsqrt
	fstp st1
	fpatan

	; get raw angle
	fst st1
	push 0x3FF921FB; rad(90)
	push 0x54442D28
	fld qword [ss:esp]
	fdiv st1, st0
	fstp st2

	push 0
	push 0x200
	fild qword [ss:esp]
	fmul st1, st0
	fstp st2
	fist dword [ss:esp]
	ffree st0
	ffree st1
	pop eax

	; set phase
	cmp edx, 0
	jl @p23
	cmp ecx, 0
	jge @end
	jmp @IV

	@p23:
	cmp ecx, 0
	jl @III
	jmp @II

	@II:
	sub eax, 0x400
	neg eax
	jmp @end
	@III:
	add eax, 0x400
	jmp @end
	@IV:
	sub eax, 0x800
	neg eax

	@end:
	mov ecx, dword [ss:ebp-0x4]
	mov esp, ebp
	pop ebp
	retn]])

-- mem.call(TraceLoopAsm, 0, MonId, MonsterPtr, ToX, ToY, Radius, Limit)
-- Takes MonId, ptr to Monster struct, X and Y of destination, Radius of monster, Limit of steps to perform.
-- Returns 1 in eax if monster can reach point with X and Y, 0 - if he cannot.
local TraceLoopAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi

	mov edx, dword [ss:ebp+0x1c]

	@rep:
	push edx

	mov eax, dword [ss:ebp+0xC]
	add eax, 0x98
	movsx ecx, word [ds:eax]
	push ecx
	sub eax, 0x2
	movsx ecx, word [ds:eax]
	push ecx
	push dword [ss:ebp+0x14]
	push dword [ss:ebp+0x10]
	call absolute ]] .. DirectionToPointAsm .. [[;

	pop edx
	pop edx
	pop edx
	pop edx
	pop edx
	cmp ecx, edx
	jg @end
	jl @con
	cmp dword [ss:ebp+0x20], 0x10
	jge @end
	inc dword [ss:ebp+0x20]
	jmp @stuck

	@con:
	mov dword [ss:ebp+0x20], 0
	mov edx, ecx; save previous distance
	@stuck:
	push edx
	mov ecx, dword [ss:ebp+0xC]
	add ecx, 0xA2
	mov word [ds:ecx], ax
	push dword [ss:ebp+0x8]
	call absolute 0x46e3f0

	pop edx
	pop edx

	dec dword [ss:ebp+0x1c]
	jg @rep

	@end:
	xor eax, eax
	cmp edx, dword [ss:ebp+0x18]
	jg @exit
	inc eax

	@exit:
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

-- takes X, Y, Z, returns floor level in eax, facetid in ecx
local GetFloorLevelAsm = mem.asmproc([[
	push ebp
	mov ebp, esp

	xor eax, eax
	cmp dword [ds:0x6f39a0], 1; is indoor
	jne @end

	mov ecx, 0x6f3a08
	push dword [ss:ebp+0x10]; Z
	push dword [ss:ebp+0xC]; Y
	push dword [ss:ebp+0x8]; X
	call absolute 0x4980ba
	test eax, eax
	jne @con

	mov eax, -30000
	xor ecx, ecx
	jmp @end

	@con:
	push ]] .. AllCellsPtr .. [[;
	push eax
	push dword [ds:ebp+0x10]; Z
	mov edx, dword [ds:ebp+0xC]; Y
	mov ecx, dword [ds:ebp+0x8]; X
	call absolute 0x46b975
	mov ecx, dword [ds:]] .. AllCellsPtr .. [[]
	mov dword [ds:]] .. AllCellsPtr .. [[], 0

	@end:
	mov esp, ebp
	pop ebp
	retn]])

-- takes X, Y, Z, Radius, FromX, FromY, returns 1 in eax, if sphere does not intersect with walls at this point.
local CheckNeighboursAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	sub esp, 0x18
	mov edi, esp

	mov eax, dword [ss:ebp+0x8]
	mov dword [ds:edi], eax
	mov eax, dword [ss:ebp+0xC]
	mov dword [ds:edi+0x4], eax
	mov dword [ds:edi+0x8], 0

	mov eax, dword [ss:ebp+0x18]
	mov dword [ds:edi+0xC], eax
	mov eax, dword [ss:ebp+0x1C]
	mov dword [ds:edi+0x10], eax
	mov dword [ds:edi+0x14], 0

	push edi
	push edi
	lea eax, dword [ds:edi+0xC]
	push eax
	call absolute ]] .. MakeVec2D .. [[;
	add esp, 0xC

	cmp dword [ss:edi], 0
	je @OY
	cmp dword [ss:edi+0x4], 0
	je @OX

	mov dword [ds:edi+0xC], 0
	mov dword [ds:edi+0x10], 0x10
	mov dword [ds:edi+0x14], 0

	push edi
	lea eax, dword [ds:edi+0xC]
	push eax
	call absolute ]] .. GetCosVec .. [[;
	add esp, 0x8

	fldz
	fxch
	fst st1
	fmul st0, st0
	fld1
	fsub st0, st1
	fsqrt
	fstp st1
	push dword [ss:ebp+0x14]
	fild dword [ss:esp]
	fmul st0, st1
	fild dword [ss:esp]
	fmul st0, st3
	push 0
	fistp dword [ss:esp]
	fistp dword [ss:esp+0x4]
	fcompp
	pop eax
	pop ecx

	; set phase
	cmp dword [ss:edi], 0
	jl @IoII
	jmp @IIIoIV

	@IoII:
	cmp dword [ss:edi+0x4], 0
	jl @I
	jmp @II

	@IIIoIV:
	cmp dword [ss:edi+0x4], 0
	jl @IV
	jmp @III

	@I:
	nop
	jmp @startCheck

	@II:
	neg ecx
	jmp @startCheck

	@III:
	nop
	jmp @startCheck

	@IV:
	neg eax
	jmp @startCheck

	@OX:
	mov eax, dword [ss:ebp+0x14]
	xor ecx, ecx
	jmp @startCheck

	@OY:
	xor eax, eax
	mov ecx, dword [ss:ebp+0x14]
	jmp @startCheck

	@startCheck:
	mov edx, dword [ds:ebp+0x8]
	add edx, eax
	mov dword [ds:edi], edx
	shl eax, 1
	sub edx, eax
	mov dword [ds:edi+0xC], edx

	mov edx, dword [ds:ebp+0xC]
	add edx, ecx
	mov dword [ds:edi+0x4], edx
	shl ecx, 1
	sub edx, ecx
	mov dword [ds:edi+0x10], edx

	mov edx, dword [ss:ebp+0x10]
	add edx, 35
	mov dword [ds:edi+0x8], edx
	mov dword [ds:edi+0x14], edx

	push dword [ds:edi+0x8]
	push dword [ds:edi+0x4]
	push dword [ds:edi]
	call absolute ]] .. AltGetFloorLevelAsm .. [[;
	add esp, 0xC
	cmp eax, -29000
	jle @fault

	push dword [ds:edi+0x14]
	push dword [ds:edi+0x10]
	push dword [ds:edi+0xC]
	call absolute ]] .. AltGetFloorLevelAsm .. [[;
	add esp, 0xC
	cmp eax, -29000
	jle @fault

	mov ecx, 1
	jmp @end

	@fault:
	xor ecx, ecx
	jmp @end

	@end:
	add esp, 0x18
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x18]])

Pathfinder.CheckNeighboursAsm = CheckNeighboursAsm

-- Takes MonId, Radius, FromX, FromY, FromZ, ToX, ToY, ToZ
-- returns 1 in eax, if monster can reach point, 0 - otherwise

-- Uses approximation (faster, less accurate, does not use actual monster, does not crash game, when executed in separate thread).
-- mem.call(Pathfinder.TraceAsm, 0, 0, 30, Party.X, Party.Y, Party.Z, Party.X, Party.Y, Party.Z)
local TraceAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi

; calc limit
	push dword [ss:ebp + 0x10]
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x1c]
	push dword [ss:ebp + 0x20]
	call absolute ]] .. GetDistXYAsm .. [[;
	ffree st0
	mov esi, eax
	add esp, 0x10
	push esi
	fild dword [ss:esp]

; calc step offsets
	mov eax, dword [ss:ebp + 0x1c]
	sub eax, dword [ss:ebp + 0x10]
	push eax
	fild dword [ss:esp]

	mov eax, dword [ss:ebp + 0x20]
	sub eax, dword [ss:ebp + 0x14]
	push eax
	fild dword [ss:esp]
	add esp, 0xC

	fdiv st0, st2; y step offset
	fxch
	fdiv st0, st2; x step offset
	fxch

; Set can fly flag
	mov eax, dword [ss:ebp + 0x8]
	imul eax, 0x3cc; Monster size
	add eax, ]] .. Map.Monsters["?ptr"] .. [[;
	movsx eax, byte [ds:eax+0x3a]
	mov word [ss:ebp+0xE], ax

; trace loop
	mov dword [ss:ebp + 0x8], 6
	mov edi, dword [ss:ebp + 0x18]; previous Z

	@rep:
	; calc Y offset
		push dword [ss:ebp + 0x8]; steps count
		fild dword [ss:esp]
		fmul st0, st1
		fistp dword [ss:esp]
		pop eax; Y
	; calc X offset
		push dword [ss:ebp + 0x8]
		fild dword [ss:esp]
		fmul st0, st2
		fistp dword [ss:esp]
		pop edx; X
	; get new coordinates
		add edx, dword [ss:ebp + 0x10]; X
		add eax, dword [ss:ebp + 0x14]; Y
	; bake new coordinates
		mov dword [ss:ebp + 0x24], edi; Z
		mov dword [ss:ebp + 0x20], eax; Y
		mov dword [ss:ebp + 0x1c], edx; X
	; get floor level
		movsx eax, word [ss:ebp+0xC]
		push dword [ss:ebp+0x14]
		push dword [ss:ebp+0x10]
		push eax
		push dword [ss:ebp + 0x24]
		push dword [ss:ebp + 0x20]
		push dword [ss:ebp + 0x1c]
		call absolute ]] .. CheckNeighboursAsm .. [[;
		test ecx, ecx
		je @fault

		@con:
		mov dword [ss:ebp + 0x24], eax
		; if monster can fly, ignore height difference
		cmp word [ss:ebp+0xE], 1
		je @CanFly

		mov eax, edi
		sub eax, dword [ss:ebp + 0x24]
		call absolute ]] .. absAsm .. [[;
		cmp eax, 0x28
		jg @fault

		@CanFly:
		mov edi, dword [ss:ebp + 0x24]
		add dword [ss:ebp + 0x8], 0x6
		cmp dword [ss:ebp + 0x8], esi
	jle @rep

; result
	xor eax, eax
	inc eax
	mov ecx, edi
	jmp @end

	@fault:
	xor eax, eax

	@end:
	ffree st0
	ffree st1
	ffree st2
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

-- Uses engine tracer.
local TraceAsmNative = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi

; calc limit
	push dword [ss:ebp + 0x10]
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x18]
	push dword [ss:ebp + 0x1c]
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x24]
	call absolute ]] .. GetDistAsm .. [[;
	imul eax, 2
	mov esi, eax
	add esp, 0x18

; get monster ptr
	mov eax, dword [ss:ebp + 0x8]
	imul eax, 0x3cc
	add eax, ]] .. Map.Monsters["?ptr"] .. [[;
	mov edi, eax

; set up monster props
	; set CurrentActionLength
	lea eax, dword [ds:edi + 0xA8]
	mov word [ds:eax], 0x14

	; set AIState
	lea eax, dword [ds:edi + 0xB8]
	mov word [ds:eax], 6

	; set GraphicState
	lea eax, dword [ds:edi + 0xBA]
	mov word [ds:eax], 1

	; set CurrentActionStep
	lea eax, dword [ds:edi + 0xC0]
	mov dword [ds:eax], 1

	; set X, Y, Z
	lea eax, dword [ds:edi + 0x96]
	mov ecx, dword [ds:ebp + 0x10]
	mov word [ds:eax], cx

	mov ecx, dword [ds:ebp + 0x14]
	mov word [ds:eax + 0x2], cx

	mov ecx, dword [ds:ebp + 0x18]
	mov word [ds:eax + 0x4], cx

; trace with max velocity
	lea eax, dword [ds:edi + 0x94]
	mov ecx, ]] .. MAXTracingPrecision .. [[;
	mov word [ds:eax], cx

	push 0
	push esi
	push dword [ss:ebp + 0xC]
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1c]
	push edi
	push dword [ss:ebp + 0x8]
	call absolute ]] .. TraceLoopAsm .. [[;
	add esp, 0x1c

; if trace failed, trace with min velocity
	test eax, eax
	jne @end

	lea eax, dword [ds:edi + 0x94]
	mov ecx, ]] .. MINTracingPrecision .. [[;
	mov word [ds:eax], cx

	push 0
	push esi
	push dword [ss:ebp + 0xC]
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1c]
	push edi
	push dword [ss:ebp + 0x8]
	call absolute ]] .. TraceLoopAsm .. [[;
	add esp, 0x1c

; return result
	@end:
	movsx ecx, word [ds:edi+0x9A]
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

-- Takes id in eax, returns ptr in eax
local GetCellAsm = mem.asmproc([[
	imul eax, ]] .. CellItemSize .. [[;
	add eax, ]] .. AllCellsPtr .. [[;
	retn]])

-- Takes cell props (Id,X,Y,Z,StableZ,From,Cost,Length) and writes it into AllCells.
local SetCellAsm = mem.asmproc([[
	mov eax, dword [ss:esp+0x4]
	call absolute ]] .. GetCellAsm .. [[;

	; Id
	mov ecx, dword [ss:esp+0x4]
	mov word [ds:eax], cx

	; X
	mov ecx, dword [ss:esp+0x8]
	mov word [ds:eax+0x2], cx

	; Y
	mov ecx, dword [ss:esp+0xc]
	mov word [ds:eax+0x4], cx

	; Z
	mov ecx, dword [ss:esp+0x10]
	mov word [ds:eax+0x6], cx

	; StableZ
	mov ecx, dword [ss:esp+0x14]
	mov word [ds:eax+0x8], cx

	; From
	mov ecx, dword [ss:esp+0x18]
	mov word [ds:eax+0xA], cx

	; Cost
	mov ecx, dword [ss:esp+0x1C]
	mov dword [ds:eax+0xC], ecx

	; Length
	mov ecx, dword [ss:esp+0x20]
	mov dword [ds:eax+0x10], ecx

	retn]])

-- Takes x, y, z, returns 1 in eax if cell with same coordinates exist in AllCells, 0 - otherwise.
local CellExploredAsm = mem.asmproc([[
	xor eax, eax
	mov ecx, ]] .. AllCellsPtr .. [[;
	@rep:
	add ecx, ]] .. CellItemSize .. [[;
	cmp word [ds:ecx], 0
	je @end

	mov edx, dword [ss:esp+0x4]
	cmp word [ds:ecx+2], dx
	jne @rep
	mov edx, dword [ss:esp+0x8]
	cmp word [ds:ecx+4], dx
	jne @rep
	mov edx, dword [ss:esp+0xC]
	cmp word [ds:ecx+8], dx
	je @explored
	jmp @rep

	@explored:
	mov eax, 1
	@end:
	retn]])

-- Clears indexes of AllCells.
local ClearAllCellsAsm = mem.asmproc([[
	xor eax, eax
	xor ecx, ecx
	call absolute ]] .. GetCellAsm .. [[;
	@rep:
	mov word [ds:eax], 0
	add eax, ]] .. CellItemSize .. [[;
	inc ecx
	cmp ecx, ]] .. CellsAmount .. [[;
	jl @rep

	xor ecx, ecx
	mov eax, ]] .. ReachableAsm .. [[;
	@rep2:
	mov word [ds:eax], 0
	add eax, 2
	inc ecx
	cmp ecx, ]] .. CellsAmount .. [[;
	jl @rep2

	retn]])

-- takes cell id in eax, writes it into free slot of reachable cells table
local AddReachableAsm = mem.asmproc([[
	mov ecx, ]] .. ReachableAsm .. [[;
	@rep:
	cmp word [ds:ecx], 0
	je @end
	inc ecx
	inc ecx
	jmp @rep

	@end:
	mov word [ds:ecx], ax
	retn]])

-- takes id in eax, finds it in the reachable table and clears.
local RemoveReachableAsm = mem.asmproc([[
	mov ecx, ]] .. ReachableAsm .. [[;

	@rep:
	cmp word [ds:ecx], ax
	jne @con
	mov word [ds:ecx], 0
	@con:
	inc ecx
	inc ecx
	cmp ecx, ]] .. ReachableAsm + CellsAmount*2 .. [[;
	jl @rep

	retn]])

-- takes nothing, returns amount of items in reachable table in eax.
local ReachableSize = mem.asmproc([[
	mov ecx, ]] .. ReachableAsm .. [[;
	xor eax, eax

	@rep:
	cmp word [ds:ecx], 0
	je @con
	inc eax
	@con:
	inc ecx
	inc ecx
	cmp ecx, ]] .. ReachableAsm + CellsAmount*2 .. [[;
	jl @rep

	retn]])

-- takes nothing, returns cheapest reachable cell in eax.
local GetCheapestCell = mem.asmproc([[
	push esi
	push edi
	mov ecx, ]] .. ReachableAsm .. [[;
	mov esi, 1
	mov edi, 0x0fffffff

	@rep:
	movsx eax, word [ds:ecx]
	test eax, eax
	je @con
	mov edx, eax
	call absolute ]] .. GetCellAsm .. [[;
	mov eax, dword [ds:eax+0xC]; Cost
	cmp eax, edi
	jge @con
	mov edi, eax
	mov esi, edx

	@con:
	inc ecx
	inc ecx
	cmp ecx, ]] .. ReachableAsm + CellsAmount*2 .. [[;
	jl @rep

	mov eax, esi
	pop edi
	pop esi
	retn]])

-- takes facet id in eax, returns 1 in eax if facet is in allowed area, otherwise - 0.
local FacetInAllowedArea = mem.asmproc([[
	cmp eax, 0
	jl @nequ
	mov ecx, dword [ss:esp+0x4]
	test ecx, ecx
	je @end
	cmp word [ds:ecx], 0; if no AvAreas defined, just return 1
	je @end
	cmp dword [ds:]] .. FloorsPtr .. [[], 0; if floors have not been backed, just return 1
	je @end

	; get area
	imul eax, eax, 0x8
	add eax, dword [ds:]] .. FloorsPtr .. [[]
	mov eax, dword [ds:eax]
	mov ecx, dword [ss:esp+0x4]

	; check if area is in AvAreas
	@rep2:
	cmp word [ds:ecx], 0
	je @nequ
	cmp word [ds:ecx], ax
	je @end
	add ecx, 2
	jmp @rep2

	@nequ:
	xor eax, eax
	jmp @exit

	@end:
	xor eax, eax
	inc eax

	@exit:
	retn]])

local AllowedDirsAsm = mem.StaticAlloc(#AllowedDirections*3)
for i,v in ipairs(AllowedDirections) do
	mem.i1[AllowedDirsAsm+(i-1)*3]	 = v.X
	mem.i1[AllowedDirsAsm+(i-1)*3+1] = v.Y
	mem.i1[AllowedDirsAsm+(i-1)*3+2] = v.Z
end

local AStarWayParams = mem.StaticAlloc(44)

-- takes MonId, X, Y, Z of target, X, Y, Z of start, output ptr, returns ptr to way table in eax or 0 in eax if way have not been found.
local AStarWayAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi

	; clear cells table
	call absolute ]] .. ClearAllCellsAsm .. [[;

	; init params
	mov esi, 1; position in cells table
	mov eax, dword [ss:ebp+0x8]
	imul eax, 0x3cc
	add eax, ]] .. Map.Monsters["?ptr"] .. [[;
	mov edi, eax
	xor eax, eax

	; save monster props
	push dword [ds:edi+0x94]; Velocity, X
	push dword [ds:edi+0x98]; Y, Z
	push dword [ds:edi+0xa2]; Direction, LookAngle

	; write first cell
	push eax; Length
	push eax; Cost
	push eax; From
	push dword [ss:ebp+0x20];	StableZ
	push dword [ss:ebp+0x20];	Z
	push dword [ss:ebp+0x1c];	Y
	push dword [ss:ebp+0x18];	X
	push esi; cell id
	call absolute ]] .. SetCellAsm .. [[;
	add esp, 0x20
	mov eax, esi
	inc esi
	call absolute ]] .. AddReachableAsm .. [[;

	; start tracing
	@rep:
		; get next reachable cell
		call absolute ]] .. ReachableSize .. [[;
		test eax, eax
		je @endloop
		call absolute ]] .. GetCheapestCell .. [[;
		call absolute ]] .. RemoveReachableAsm .. [[;

		; check if it is close enough to target
		mov dword [ds:]] .. AStarWayParams .. [[], eax
		call absolute ]] .. GetCellAsm .. [[;
		mov dword [ds:]] .. AStarWayParams + 4 .. [[], eax
		push dword [ss:ebp+0xC];	X
		push dword [ss:ebp+0x10];	Y
		push dword [ss:ebp+0x14];	Z of target
		movsx ecx, word [ds:eax+0x2]
		push ecx
		movsx ecx, word [ds:eax+0x4]
		push ecx
		movsx ecx, word [ds:eax+0x6]
		push ecx; X,Y,Z of cell
		call absolute ]] .. GetDistAsm .. [[;
		add esp, 0x18
		movzx ecx, word [ds:edi+0x90]; monster body radius
		imul ecx, ecx, 0x2
		;add ecx, 0xc8
		cmp eax, ecx
		mov eax, 1
		jle @endloop

		; insert neighbour cells into AllCells and Reachable:
		; 1. bake current cell coords
		mov eax, dword [ds:]] .. AStarWayParams + 4 .. [[]
		movsx ecx, word [ds:eax+2]
		mov dword [ds:]] .. AStarWayParams + 8 .. [[], ecx
		movsx ecx, word [ds:eax+4]
		mov dword [ds:]] .. AStarWayParams + 12 .. [[], ecx
		movsx ecx, word [ds:eax+6]
		mov dword [ds:]] .. AStarWayParams + 16 .. [[], ecx

		mov dword [ds:]] .. AStarWayParams + 36 .. [[], ]] .. #AllowedDirections .. [[; dirs counter

		@repdirs:
			; 2. calc neighbour coords
			dec dword [ds:]] .. AStarWayParams + 36 .. [[]
			mov ecx, dword [ds:]] .. AStarWayParams + 36 .. [[]
			cmp ecx, 0
			jl @rep
			imul ecx, ecx, 3
			add ecx, ]] .. AllowedDirsAsm .. [[;

			; if monster can not fly, and Z ~= 0, skip step.
			cmp byte [ds:edi+0x3a], 1
			je @CanFly
			cmp byte [ds:ecx+0x2], 0
			jne @repdirs

			@CanFly:
			movzx eax, word [ds:edi+0x90]; monster body radius
			imul eax, 0x2
			movsx edx, byte [ds:ecx]
			imul eax, edx
			add eax, dword []] .. AStarWayParams + 8 .. [[]
			mov dword [ds:]] .. AStarWayParams + 20 .. [[], eax; Neighbour X

			movzx eax, word [ds:edi+0x90]; monster body radius
			imul eax, 0x2
			movsx edx, byte [ds:ecx+0x1]
			imul eax, edx
			add eax, dword []] .. AStarWayParams + 12 .. [[]
			mov dword [ds:]] .. AStarWayParams + 24  .. [[], eax; Neighbour Y

			movzx eax, word [ds:edi+0x90]; monster body radius
			imul eax, 0x2
			movsx edx, byte [ds:ecx+0x2]
			imul eax, edx
			add eax, dword []] .. AStarWayParams + 16 .. [[]
			mov dword [ds:]] .. AStarWayParams + 28  .. [[], eax; Neighbour Z

			; fix Z coordinate
			push dword [ds:]] .. AStarWayParams + 28  .. [[]
			add dword [ss:esp], 0x28
			push dword [ds:]] .. AStarWayParams + 24  .. [[]
			push dword [ds:]] .. AStarWayParams + 20  .. [[]
			call absolute ]] .. AltGetFloorLevelAsm .. [[;
			add esp, 0xC
			mov dword [ds:]] .. AStarWayParams + 28  .. [[], eax

			; make monsters prefer horizontal facets
			imul ecx, ecx, 96; Facet size
			add ecx, dword [ds:0x6f3c84]; MapFacets ptr
			movsx eax, word [ds:ecx+0x58]; MinZ
			movsx ecx, word [ds:ecx+0x5A]; MaxZ
			sub ecx, eax
			imul ecx, ecx
			mov dword [ds:]] .. AStarWayParams + 40  .. [[], ecx

			; check if area is allowed for tracing
			mov eax, ecx
			push dword [ss:ebp+0x28]
			call absolute ]] .. FacetInAllowedArea .. [[;
			pop ecx
			test eax, eax
			je @repdirs

			; 3. check if cell was explored before
			push dword [ds:]] .. AStarWayParams + 28  .. [[]
			push dword [ds:]] .. AStarWayParams + 24  .. [[]
			push dword [ds:]] .. AStarWayParams + 20  .. [[]
			call absolute ]] .. CellExploredAsm .. [[;
			add esp, 0xC
			test eax, eax
			jne @repdirs

			; 4. set cell and trace way to it
			push 0; Length
			push 0; Cost
			push dword [ds:]] .. AStarWayParams .. [[]; From
			push dword [ds:]] .. AStarWayParams + 28  .. [[]; StableZ
			push dword [ds:]] .. AStarWayParams + 28  .. [[]; Z
			push dword [ds:]] .. AStarWayParams + 24  .. [[]; Y
			push dword [ds:]] .. AStarWayParams + 20  .. [[]; X
			push esi; cell id
			call absolute ]] .. SetCellAsm .. [[;
			add esp, 0x20

			push dword [ds:]] .. AStarWayParams + 28  .. [[]; ToZ
			push dword [ds:]] .. AStarWayParams + 24  .. [[]; ToY
			push dword [ds:]] .. AStarWayParams + 20  .. [[]; ToX
			push dword [ds:]] .. AStarWayParams + 16  .. [[]; FromZ
			push dword [ds:]] .. AStarWayParams + 12  .. [[]; FromY
			push dword [ds:]] .. AStarWayParams + 8   .. [[]; FromX
			movzx eax, word [ds:edi+0x90]; monster body radius
			shr eax, 0x2
			push eax; Radius
			push dword [ss:ebp+0x8]; Mon Id
			call absolute ]] .. TraceAsm .. [[;
			add esp, 0x20
			test eax, eax
			je @repdirs

			; calculate length (distance from current cell to neighbour)
			mov eax, esi
			call absolute ]] .. GetCellAsm .. [[;
			mov word [eax+0x6], cx
			movsx ecx, word [ds:eax+0x2]
			push ecx
			movsx ecx, word [ds:eax+0x4]
			push ecx
			movsx ecx, word [ds:eax+0x6]
			push ecx
			mov eax, dword [ds:]] .. AStarWayParams + 4 .. [[]
			movsx ecx, word [ds:eax+0x2]
			push ecx
			movsx ecx, word [ds:eax+0x4]
			push ecx
			movsx ecx, word [ds:eax+0x6]
			push ecx
			call absolute ]] .. GetDistAsm .. [[;
			add esp, 0x18
			mov ecx, eax
			mov eax, dword [ds:]] .. AStarWayParams + 4 .. [[]
			add ecx, dword [ds:eax+0x10]
			push ecx
			mov eax, esi
			call absolute ]] .. GetCellAsm .. [[;
			pop ecx
			mov dword [ds:eax+0x10], ecx; length
			mov dword [ds:eax+0xC], ecx; cost

			; calculate cost (length + distance from neighbour to target)
			movsx ecx, word [ds:eax+0x2]
			push ecx
			movsx ecx, word [ds:eax+0x4]
			push ecx
			movsx ecx, word [ds:eax+0x6]
			push ecx
			push dword [ss:ebp+0xC]
			push dword [ss:ebp+0x10]
			push dword [ss:ebp+0x14]
			call absolute ]] .. GetDistAsm .. [[;
			add esp, 0x18
			push eax
			mov eax, esi
			call absolute ]] .. GetCellAsm .. [[;
			pop ecx
			add dword [ds:eax+0xC], ecx
			mov ecx, dword [ds:eax+0xC]
			add ecx, dword [ds:]] .. AStarWayParams + 40  .. [[]
			mov dword [ds:eax+0xC], ecx

			;5. if way traced successfuly, increment AllCells count (esi), otherwise - don't, let cell be overwritten.
			mov eax, esi
			call absolute ]] .. AddReachableAsm .. [[;
			inc esi
			cmp esi, ]] .. CellsAmount .. [[;
			jge @overflow
	jmp @repdirs

	@endloop:
	; if way found, build it
	test eax, eax
	je @end

	mov esi, ]] .. CellsAmount .. [[;
	mov eax, esi
	dec esi
	imul eax, eax, ]] .. CellItemSize .. [[;
	add eax, dword [ss:ebp+0x24]
	mov dword [ds:eax], 0
	add eax, 0x4
	mov dword [ds:eax], 0
	add eax, 0x4
	mov dword [ds:eax], 0
	add eax, 0x4
	mov dword [ds:eax], 0
	add eax, 0x4
	mov dword [ds:eax], 0
	mov eax, dword [ds:]] .. AStarWayParams + 4 .. [[]

	@repbuild:
	mov dword [ds:]] .. AStarWayParams + 36 .. [[], 0
	mov ecx, eax
	mov eax, esi
	imul eax, eax, ]] .. CellItemSize .. [[;
	add eax, dword [ss:ebp+0x24]
	xchg eax, ecx

	@copy:
	mov edx, eax
	add edx, dword [ds:]] .. AStarWayParams + 36 .. [[]
	mov edx, dword [edx]
	mov dword [ecx], edx
	add ecx, 0x4
	add dword [ds:]] .. AStarWayParams + 36 .. [[], 0x4
	cmp dword [ds:]] .. AStarWayParams + 36 .. [[], 0x14
	jl @copy

	@endcopy:
	cmp word [ds:eax+0xA], 0
	jne @conbuild

	mov eax, esi
	imul eax, eax, ]] .. CellItemSize .. [[;
	add eax, dword [ss:ebp+0x24]
	jmp @end

	@conbuild:
	dec esi
	test esi, esi
	je @overflow
	movzx eax, word [ds:eax+0xA]
	call absolute ]] .. GetCellAsm .. [[;
	jmp @repbuild

	@overflow:
	xor eax, eax

	@end:
	;pop dword [ds:edi+0xa2]
	;pop dword [ds:edi+0x98]
	;pop dword [ds:edi+0x94]
	add esp, 0xC
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

Pathfinder.absAsm = absAsm
Pathfinder.GetDistAsm = GetDistAsm
Pathfinder.GetDistXYAsm = GetDistXYAsm
Pathfinder.DirectionToPointAsm = DirectionToPointAsm
Pathfinder.TraceLoopAsm = TraceLoopAsm
Pathfinder.TraceAsm = TraceAsm
Pathfinder.TraceAsmNative = TraceAsmNative
Pathfinder.GetCellAsm = GetCellAsm
Pathfinder.SetCellAsm = SetCellAsm
Pathfinder.CellExploredAsm = CellExploredAsm
Pathfinder.ClearAllCellsAsm = ClearAllCellsAsm
Pathfinder.AddReachableAsm = AddReachableAsm
Pathfinder.RemoveReachableAsm = RemoveReachableAsm
Pathfinder.ReachableSize = ReachableSize
Pathfinder.GetCheapestCell = GetCheapestCell
Pathfinder.GetFloorLevelAsm = GetFloorLevelAsm
Pathfinder.AStarWayAsm = AStarWayAsm

ffi.cdef([[typedef struct {
	int Status;
	int MonId;
	int ToX;
	int ToY;
	int ToZ;
	int FromX;
	int FromY;
	int FromZ;
	int OutputPtr;
	int ResultPtr;
	int AvAreasPtr;} AStarQueue]])

local AStarQueueC = ffi.new("AStarQueue[?]", 50)

local u2, i2 = mem.u2, mem.i2
local function GetResult(ptr)
	local result = {}
	if ptr > 0 then
		for i = 0, CellsAmount do
			if u2[ptr+i*20] == 0 then
				break
			end
			result[i+1] = {X = i2[ptr+i*20+2], Y = i2[ptr+i*20+4], Z = i2[ptr+i*20+6]}
		end
	end
	return result
end

local function SetQueueItem(MonId, ToX, ToY, ToZ, FromX, FromY, FromZ, OutputPtr, AvAreasPtr)
	local QItemId
	for i = 0, 49 do
		if AStarQueueC[i].Status == 0 then
			QItemId = i
			break
		end
	end

	if not QItemId then
		return false
	end

	AStarQueueC[QItemId].MonId = MonId
	AStarQueueC[QItemId].ToX = ToX
	AStarQueueC[QItemId].ToY = ToY
	AStarQueueC[QItemId].ToZ = ToZ
	AStarQueueC[QItemId].FromX = FromX
	AStarQueueC[QItemId].FromY = FromY
	AStarQueueC[QItemId].FromZ = FromZ
	AStarQueueC[QItemId].OutputPtr = OutputPtr
	AStarQueueC[QItemId].AvAreasPtr = AvAreasPtr
	AStarQueueC[QItemId].Status = 1

	return QItemId
end
--~ require("PathfinderAsm")
--~ test = Pathfinder.AStarWay{MonId = 0, ToX = Party.X, ToY = Party.Y, ToZ = Party.Z}
local function AStarWay(t)
	local MonId, ToX, ToY, ToZ, AvAreas, FromX, FromY, FromZ = t.MonId, t.ToX, t.ToY, t.ToZ, t.AvAreas, t.FromX, t.FromY, t.FromZ

	if not ToX or not ToY or not ToZ then
		error("Attempt to make A* way without target coordinates.")
	end

	if not MonId then
		error("Attempt to make A* way without monster to trace with.")
	end

	local Monster = Map.Monsters[MonId]
	local OutputPtr = mem.malloc(CellItemSize*(CellsAmount + 2))
	FromX = FromX or Monster.X
	FromY = FromY or Monster.Y
	FromZ = FromZ or Monster.Z

	local AvAreasPtr = 0
	if AvAreas then
		AvAreasPtr = mem.malloc(20)
		local count = 1
		for k,v in pairs(AvAreas) do
			if v then
				u2[AvAreasPtr+(count-1)*2] = k
			end
			count = count + 1
			if count > 10 then
				break
			end
		end
	end

	local result
	if t.Async then
		local QItemId
		while not QItemId do
			QItemId = SetQueueItem(MonId, ToX, ToY, ToZ, FromX, FromY, FromZ, OutputPtr, AvAreasPtr)
			coroutine.yield()
		end

		while AStarQueueC[QItemId].Status < 3 do
			coroutine.yield()
		end
		if AStarQueueC[QItemId].Status == 3 then
			result = GetResult(AStarQueueC[QItemId].ResultPtr)
		else
			result = {}
		end
		AStarQueueC[QItemId].Status = 0
	else
		local resultPtr = mem.call(AStarWayAsm, 0, MonId, ToX, ToY, ToZ, FromX, FromY, FromZ, OutputPtr, AvAreasPtr)
		result = GetResult(resultPtr)
	end

	if AvAreasPtr > 0 then
		mem.free(AvAreasPtr)
	end
	mem.free(OutputPtr)
	return result
end
Pathfinder.AStarWayAsm = AStarWay

local function dumpAllCells()
	return GetResult(AllCellsPtr+CellItemSize)
end
Pathfinder.dumpAllCells = dumpAllCells

---------------------------------------------
-- A* queue - add task to queue to be processed by separate thread.

const.AStarQueueItemStatus = {}
const.AStarQueueItemStatus.NoItem = 0
const.AStarQueueItemStatus.WaitingForProcessing = 1
const.AStarQueueItemStatus.InProcess = 2
const.AStarQueueItemStatus.DonePathFound = 3
const.AStarQueueItemStatus.DonePathNotFound = 4
const.AStarQueueItemStatus.Error = 5

local QueuePtr = cdataPtr(AStarQueueC)
local QueueFlag = mem.StaticAlloc(4)
local ThreadHandler = 0

local HandlerAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi

	mov edi, ]] .. QueuePtr .. [[;
	xor ecx, ecx
	xor edx, edx

	@rep:
	cmp dword [ds:]] .. QueueFlag .. [[], 1
	jne @exit

	mov eax, ecx
	imul eax, eax, 0x2C
	add eax, edi
	cmp dword [ds:eax], 1
	je @start

	inc ecx
	cmp ecx, 0x32
	jl @rep
	xor ecx, ecx
	test edx, edx
	mov edx, 0
	je @Sleep
	jmp @rep

	@start:
	mov dword [ds:eax], 2
	push eax
	push dword [ds:eax+0x28]; AvAreasPtr
	push dword [ds:eax+0x20]; OutputPtr
	push dword [ds:eax+0x1C]; FromZ
	push dword [ds:eax+0x18]; FromY
	push dword [ds:eax+0x14]; FromX
	push dword [ds:eax+0x10]; ToZ
	push dword [ds:eax+0xC]; ToY
	push dword [ds:eax+0x8]; ToX
	push dword [ds:eax+0x4]; MonId
	call absolute ]] .. AStarWayAsm .. [[;
	add esp, 0x24
	mov edx, eax
	pop eax
	mov dword [ds:eax+0x24], edx
	test edx, edx
	jne @found
	mov dword [ds:eax], 4
	jmp @endTrace
	@found:
	mov dword [ds:eax], 3
	jmp @endTrace

	@endTrace:
	xor ecx, ecx
	xor edx, edx
	inc edx
	jmp @rep

	@Sleep:]]
	.. (debug.KernelSleep and ([[;
	push 0x20
	call absolute ]] .. debug.KernelSleep .. [[;]])
	or [[nop]])
	.. [[;
	;call dword [ds:0x4e8158]
	xor ecx, ecx
	xor edx, edx
	jmp @rep

	@exit:
	mov dword [ds:]] .. QueueFlag .. [[], 2
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

local function StartQueueHandler()
	mem.u4[QueueFlag] = 1
	if ThreadHandler == 0 then
		ThreadHandler = mem.dll["kernel32"].CreateThread(nil, 0, HandlerAsm, QueueFlag, 0, nil)
	end
	return ThreadHandler
end

local function StopQueueHandler()
	if ThreadHandler ~= 0 then
		if mem.u4[QueueFlag] == 1 then
			mem.u4[QueueFlag] = 0
			mem.dll["kernel32"].ResumeThread(ThreadHandler)
			while mem.u4[QueueFlag] ~= 2 do
				-- hold main thread, while handler finishes it's job
			end
			mem.dll["kernel32"].CloseHandle(ThreadHandler)
		elseif mem.u4[QueueFlag] == 2 then
			mem.dll["kernel32"].CloseHandle(ThreadHandler)
		end
		ThreadHandler = 0
	end
end

function events.AfterLoadMap()
	if Map.IsIndoor() then
		StartQueueHandler()
	end
end

function events.LeaveMap()
	if ThreadHandler ~= 0 then
		StopQueueHandler()
	end
end

function events.LeaveGame()
	if ThreadHandler ~= 0 then
		StopQueueHandler()
	end
end

Pathfinder.HandlerAsm = HandlerAsm
Pathfinder.StartQueueHandler = StartQueueHandler
Pathfinder.StopQueueHandler = StopQueueHandler
Pathfinder.AStarQueueC = AStarQueueC
