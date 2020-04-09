
Pathfinder = {}

local CellItemSize = 20
local CellsAmount = 8000
local AllCellsPtr = mem.StaticAlloc(CellItemSize*(CellsAmount+2))
local ExploredCellsPtr = mem.StaticAlloc(CellsAmount*12*8)
local ReachableAsm = mem.StaticAlloc(CellsAmount*2)
local QueueFlag = mem.StaticAlloc(4)
local ThreadHandler = 0

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

-- {X =  0, 	Y =  0,		Z = -1},
-- {X =  0, 	Y =  0,		Z =  1}
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
--					Base funcions					--
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
	fcomp
	pop eax
	pop ecx

	mov esp, ebp
	pop ebp
	retn 0x18]])

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

	retn 0xC]])

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

	retn 0xC]])

-- takes X, Y, Z, VertexIds List, VertexesCount,
-- returns 1 in eax if point is in projection of polygon, defined by vertex list.
-- mem.call(Pathfinder.PointInProjection, 0, X, Y, Z, VertexIds, VertexesCount)
-- mem.call(Pathfinder.PointInProjection, 0, -32,	2214,	-26, Map.Facets[1411].VertexIds["?ptr"], Map.Facets[1411].VertexesCount)
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
	shl eax, 1
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
	shl eax, 1
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

	mov eax, dword [ds:edi+0x14]
	cmp eax, dword [ds:edi+0x20]
	jne @nodouble
	jmp @con

	@nodouble:
	mov edx, edi
	add edx, 0xC
	push edx
	push edx
	push edi
	call absolute ]] .. MakeVec3D .. [[;

	mov edx, edi
	add edx, 0x18
	push edx
	push edx
	push edi
	call absolute ]] .. MakeVec3D .. [[;

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

	fdiv st0, st1
	fabs
	push 0xA
	fild dword [ds:esp]
	fmul st0, st1
	fistp dword [ds:esp]
	fcomp
	pop eax
	cmp eax, 0x14
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
	retn 0x14]])

Pathfinder.PointInProjection = PointInProjection

-- takes three points, returns 1 in eax, if they are belong to same line.
local PointsOnLine = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	sub esp, 0x24
	mov edi, esp

	push edi
	push dword [ss:ebp+0xC]
	push dword [ss:ebp+0x8]
	call absolute ]] .. MakeVec3D ..[[;

	lea eax, dword [ds:edi+0xC]
	push eax
	push dword [ss:ebp+0x10]
	push dword [ss:ebp+0x8]
	call absolute ]] .. MakeVec3D ..[[;

	lea eax, dword [ds:edi+0x18]
	push eax
	lea eax, dword [ds:edi+0xC]
	push eax
	push edi
	call absolute ]] .. VectorMul .. [[;

	mov eax, dword [ds:edi+0x18]
	mov edx, dword [ds:edi+0x1C]
	mov ecx, dword [ds:edi+0x20]

	test eax, eax
	jne @nequ
	test ecx, ecx
	jne @nequ
	test edx, edx
	jne @nequ
	xor eax, eax
	inc eax
	jmp @end

	@nequ:
	xor eax, eax

	@end:
	add esp, 0x24
	pop edi
	mov esp, ebp
	pop ebp
	retn 0xC]])

-- takes vector, simplifies it
local SimplifyCoefficients = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	mov esi, dword [ss:ebp+0x8]

	;find lowest
	mov eax, dword [ds:esi]
	mov ecx, dword [ds:esi+0x4]
	mov edx, dword [ds:esi+0x8]

	call absolute ]] .. absAsm .. [[;
	xchg eax, ecx
	call absolute ]] .. absAsm .. [[;
	xchg eax, edx
	call absolute ]] .. absAsm .. [[;

	@I:
	mov edi, eax
	test edi, edi
	je @II
	test ecx, ecx
	je @Acon
	cmp eax, ecx
	ja @II
	@Acon:
	test edx, edx
	je @start
	cmp eax, edx
	jbe @start

	@II:
	mov edi, ecx
	test edi, edi
	je @III
	test edx, edx
	je @start
	cmp ecx, edx
	jbe @start

	@III:
	mov edi, edx

	@start:
	test edi, edi
	je @end

	@rep:
	mov eax, dword [ds:esi]
	cdq
	idiv edi
	test edx, edx
	jne @con

	mov eax, dword [ds:esi+0x4]
	cdq
	idiv edi
	test edx, edx
	jne @con

	mov eax, dword [ds:esi+0x8]
	cdq
	idiv edi
	test edx, edx
	jne @con

	jmp @found

	@con:
	dec edi
	cmp edi, 1
	jg @rep

	@found:
	mov eax, dword [ds:esi]
	cdq
	idiv edi
	mov dword [ds:esi], eax

	mov eax, dword [ds:esi+0x4]
	cdq
	idiv edi
	mov dword [ds:esi+0x4], eax

	mov eax, dword [ds:esi+0x8]
	cdq
	idiv edi
	mov dword [ds:esi+0x8], eax

	@end:
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x4]])

-- Takes three vertexes and destination ptr (16 bytes), returns A, B, C, D params of plane function (Ax + Bx + Cx + D = 0)
local GetPlaneDefiners = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	lea edi, dword [ss:ebp+0x8]

	; calc vertex mul
	mov eax, dword [ds:edi+0x4]
	push eax
	push eax
	push dword [ds:edi]
	call absolute ]] .. MakeVec3D .. [[;

	mov eax, dword [ds:edi+0x8]
	push eax
	push eax
	push dword [ds:edi]
	call absolute ]] .. MakeVec3D .. [[;

	push dword [ds:edi+0xC]
	push dword [ds:edi+0x4]
	push dword [ds:edi+0x8]
	call absolute ]] .. VectorMul .. [[;

	; simplify A, B, C
	;push dword [ds:edi+0xC]
	;call absolute ]] .. SimplifyCoefficients .. [[;

	; calc D
	; - V1.X*VV.X - V1.Y*VV.Y - V1.Z*VV.Z
	mov esi, dword [ds:edi+0xC]
	mov edi, dword [ds:edi]
	xor edx, edx

	mov eax, dword [ds:edi]
	mov ecx, dword [ds:esi]
	imul eax, ecx
	add edx, eax

	mov eax, dword [ds:edi+0x4]
	mov ecx, dword [ds:esi+0x4]
	imul eax, ecx
	add edx, eax

	mov eax, dword [ds:edi+0x8]
	mov ecx, dword [ds:esi+0x8]
	imul eax, ecx
	add edx, eax

	neg edx
	mov dword [ds:esi+0xC], edx
	mov eax, esi

	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x10]])

Pathfinder.GetPlaneDefiners = GetPlaneDefiners

-- takes Facet ptr, destination, return plane definers.
local GetFacetPlaneDefiners = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x24
	mov edi, esp

	mov eax, dword [ss:ebp+0x8]

	; choose vertexes
	mov ecx, dword [ds:eax+0x30]; VertexIds
	xor eax, eax

	;1 always first vertex
	movsx edx, word [ds:ecx]
	mov dword [ds:edi], edx

	@v2rep:
	;2 always second vertex
	add eax, 0x2
	movsx edx, word [ds:ecx+eax]
	cmp edx, dword [ds:edi]
	je @v2rep
	mov dword [ds:edi+0xC], edx

	;3 choose any not on line with previous two
	@rep:
	add eax, 0x2
	movsx edx, word [ds:ecx+eax]
	mov dword [ds:edi+0x18], edx
	push eax

	; setup vertex coords
	xor ecx, ecx
	@rep1:
		mov eax, ecx
		imul eax, 0xC
		lea eax, dword [ds:edi+eax]
		mov esi, dword [ds:eax]; VertexId
		imul esi, esi, 0x6
		add esi, dword [ds:0x6f3c7c]; MapVertexes ptr

		movsx edx, word [ds:esi]
		mov dword [ds:eax], edx
		movsx edx, word [ds:esi+0x2]
		mov dword [ds:eax+0x4], edx
		movsx edx, word [ds:esi+0x4]
		mov dword [ds:eax+0x8], edx

		inc ecx
		cmp ecx, 3
		jl @rep1

	lea eax, dword [ds:edi+0x18]
	push eax
	lea eax, dword [ds:edi+0xC]
	push eax
	push edi
	call absolute ]] .. PointsOnLine .. [[;
	test eax, eax
	je @con

	mov eax, dword [ss:ebp+0x8]
	movsx edx, word [ds:eax+0x5d]; VertexesCount
	mov ecx, dword [ds:eax+0x30]
	pop eax
	add eax, 2
	shl edx, 1
	cmp eax, edx
	jge @con2
	movsx edx, word [ds:ecx+eax]
	mov dword [ss:edi+0x18], edx
	mov ecx, 2
	push eax
	jmp @rep1

	@con:
	pop eax
	@con2:
	push dword [ss:ebp+0xC]
	lea eax, dword [ds:edi+0x18]
	push eax
	lea eax, dword [ds:edi+0xC]
	push eax
	push edi
	call absolute ]] .. GetPlaneDefiners .. [[;

	add esp, 0x24
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x8]])

Pathfinder.GetFacetPlaneDefiners = GetFacetPlaneDefiners

-- takes point belonging to line, line's vector, plane definers, destination ptr, returns point of intersection.
local PlaneLineIntersect = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi

	; calc divisor
	;(PlaneV.X*lV.X + PlaneV.Y*lV.Y + PlaneV.Z*lV.Z)
	mov edi, dword [ss:ebp+0xC]
	mov esi, dword [ss:ebp+0x10]

	mov eax, dword [ds:edi]
	mov ecx, dword [ds:esi]
	imul eax, ecx
	mov edx, eax

	mov eax, dword [ds:edi+0x4]
	mov ecx, dword [ds:esi+0x4]
	imul eax, ecx
	add edx, eax

	mov eax, dword [ds:edi+0x8]
	mov ecx, dword [ds:esi+0x8]
	imul eax, ecx
	add edx, eax
	test edx, edx
	je @noint

	; calc divident
	; -1*(PlaneV.X*lV0.X + PlaneV.Y*lV0.Y + PlaneV.Z*lV0.Z + PlaneV.D)
	push edx
	mov edi, dword [ss:ebp+0x8]

	mov eax, dword [ds:edi]
	mov ecx, dword [ds:esi]
	imul eax, ecx
	mov edx, eax

	mov eax, dword [ds:edi+0x4]
	mov ecx, dword [ds:esi+0x4]
	imul eax, ecx
	add edx, eax

	mov eax, dword [ds:edi+0x8]
	mov ecx, dword [ds:esi+0x8]
	imul eax, ecx
	add edx, eax

	add edx, dword [ds:esi+0xC]
	neg edx

	; calc t
	push edx
	fild dword [ss:esp+0x4]
	fild dword [ss:esp]
	fdiv st0, st1
	fstp st1
	add esp, 0x8

	; calc new point
	mov esi, dword [ss:ebp+0xC]

	push dword [ds:esi]
	fild dword [ss:esp]
	fmul st0, st1
	fistp dword [ss:esp]
	mov eax, dword [ds:edi]
	add dword [ss:esp], eax

	push dword [ds:esi+0x4]
	fild dword [ss:esp]
	fmul st0, st1
	fistp dword [ss:esp]
	mov eax, dword [ds:edi+0x4]
	add dword [ss:esp], eax

	push dword [ds:esi+0x8]
	fild dword [ss:esp]
	fmul st0, st1
	fistp dword [ss:esp]
	mov eax, dword [ds:edi+0x8]
	add dword [ss:esp], eax

	pop eax; Z
	pop ecx; Y
	pop edx; X
	fcomp; get rid of t in fpu stack.

	mov esi, dword [ds:ebp+0x14]
	mov dword [ds:esi], edx
	mov dword [ds:esi+0x4], ecx
	mov dword [ds:esi+0x8], eax
	jmp @end

	@noint:
	mov esi, dword [ds:ebp+0x14]
	mov eax, -30000
	mov dword [ds:esi], eax
	mov dword [ds:esi+0x4], eax
	mov dword [ds:esi+0x8], eax

	@end:
	mov eax, esi
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x10]])

Pathfinder.PlaneLineIntersect = PlaneLineIntersect

--~ F = Map.Facets[123]
--~ V1 = Map.Vertexes[F.VertexIds[0]]
--~ V2 = Map.Vertexes[F.VertexIds[2]]
--~ V3 = Map.Vertexes[F.VertexIds[3]]
--~ print(dump(PlaneDefiners(V1, V2, V3)))

--~ TESTPTR = mem.StaticAlloc(52)

--~ mem.i4[TESTPTR] = V1.X
--~ mem.i4[TESTPTR+4] = V1.Y
--~ mem.i4[TESTPTR+8] = V1.Z

--~ mem.i4[TESTPTR+12] = V2.X
--~ mem.i4[TESTPTR+16] = V2.Y
--~ mem.i4[TESTPTR+20] = V2.Z

--~ mem.i4[TESTPTR+24] = V3.X
--~ mem.i4[TESTPTR+28] = V3.Y
--~ mem.i4[TESTPTR+32] = V3.Z

--~ mem.call(Pathfinder.GetPlaneDefiners, 0, TESTPTR, TESTPTR+12, TESTPTR+24, TESTPTR+36)
--~ print(mem.i4[TESTPTR+36],mem.i4[TESTPTR+40],mem.i4[TESTPTR+44],mem.i4[TESTPTR+48])

--~ lv0 = {X = Party.X, Y = Party.Y, Z = Party.Z + 35}
--~ lv1 = {X = Party.X + 20, Y = Party.Y, Z = Party.Z + 35}
--~ lv = MakeVec3D(lv0, lv1)
--~ print(dump(PlaneLineIntersection(PlaneDefiners(V1, V2, V3), lv0, lv)))

--~ TESTPTR2 = mem.StaticAlloc(52)
--~ for i = 0, 51 do
--~ 	mem.u1[TESTPTR2+i] = mem.u1[TESTPTR+i]
--~ end

--~ mem.i4[TESTPTR2] = lv0.X
--~ mem.i4[TESTPTR2+4] = lv0.Y
--~ mem.i4[TESTPTR2+8] = lv0.Z

--~ mem.i4[TESTPTR2+12] = lv.X
--~ mem.i4[TESTPTR2+16] = lv.Y
--~ mem.i4[TESTPTR2+20] = lv.Z

--~ mem.call(Pathfinder.PlaneLineIntersect, 0, TESTPTR2, TESTPTR2+12, TESTPTR+36, TESTPTR2+24)
--~ print(mem.i4[TESTPTR2+24],mem.i4[TESTPTR2+28],mem.i4[TESTPTR2+32])

------------------------------------------------------
--					Trace line  					--
------------------------------------------------------

--~ FromX, FromY, FromZ = XYZ(Party)
--~ ToX, ToY, ToZ = XYZ(Map.Monsters[0])
--~ print(mem.call(Pathfinder.TraceLineAsm, 0, 0, 0, FromX, FromY, FromZ, ToX, ToY, ToZ))
local TraceLineAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x80
	mov edi, esp

	; Get room
	mov ecx, 0x6f3a08
	push dword [ss:ebp+0x18]; Z
	push dword [ss:ebp+0x14]; Y
	push dword [ss:ebp+0x10]; X
	call absolute 0x4980ba
	test eax, eax
	je @fault
	mov dword [ss:edi], eax

	; calc Dist
	push dword [ss:ebp+0x18]
	push dword [ss:ebp+0x14]
	push dword [ss:ebp+0x10]
	push dword [ss:ebp+0x24]
	push dword [ss:ebp+0x20]
	push dword [ss:ebp+0x1C]
	call absolute ]] .. GetDistAsm .. [[;
	mov dword [ss:edi+0x4], eax

	; calc bounding box
	mov eax, dword [ss:ebp+0x10]
	mov ecx, dword [ss:ebp+0x1c]
	cmp eax, ecx
	jl @con1
	xchg eax, ecx
	@con1:
	mov dword [ss:edi+0x8], eax; MinX
	mov dword [ss:edi+0xC], ecx; MaxX

	mov eax, dword [ss:ebp+0x14]
	mov ecx, dword [ss:ebp+0x20]
	cmp eax, ecx
	jl @con2
	xchg eax, ecx
	@con2:
	mov dword [ss:edi+0x10], eax; MinY
	mov dword [ss:edi+0x14], ecx; MaxY

	mov eax, dword [ss:ebp+0x18]
	mov ecx, dword [ss:ebp+0x24]
	cmp eax, ecx
	jl @con3
	xchg eax, ecx
	@con3:
	mov dword [ss:edi+0x18], eax; MinZ
	mov dword [ss:edi+0x1C], ecx; MaxZ

	; Get line vector
	lea eax, dword [ds:edi+0x28]
	push eax
	lea eax, dword [ss:ebp+0x10]
	push eax
	lea eax, dword [ss:ebp+0x1C]
	push eax
	call absolute ]] .. MakeVec3D .. [[;

	; Get walls list
	mov dword [ds:edi+0x7c], 0
	mov eax, dword [ss:edi]
	imul eax, eax, 120; MapRoom size
	add eax, dword [ds:0x6f3c94]; contain Rooms ptr
	mov ecx, dword [ds:eax+0x10]; walls count
	mov eax, dword [ds:eax+0x14]; walls ptr
	mov dword [ss:edi+0x20], eax
	mov dword [ss:edi+0x24], ecx
	jmp @rep

	; Get floors list
	@floorsCheck:
	inc dword [ds:edi+0x7c]
	mov eax, dword [ss:edi]
	imul eax, eax, 120; MapRoom size
	add eax, dword [ds:0x6f3c94]; contain Rooms ptr
	mov ecx, dword [ds:eax+0x8]; floors count
	mov eax, dword [ds:eax+0xC]; floors ptr
	mov dword [ss:edi+0x20], eax
	mov dword [ss:edi+0x24], ecx
	jmp @rep

	; Get ceils list
	@CeilsCheck:
	inc dword [ds:edi+0x7c]
	mov eax, dword [ss:edi]
	imul eax, eax, 120; MapRoom size
	add eax, dword [ds:0x6f3c94]; contain Rooms ptr
	mov ecx, dword [ds:eax+0x18]; ceils count
	mov eax, dword [ds:eax+0x1C]; ceils ptr
	mov dword [ss:edi+0x20], eax
	mov dword [ss:edi+0x24], ecx

	; check every item
	@rep:
		dec dword [ss:edi+0x24]
		jl @exitrep
		mov edx, dword [ss:edi+0x20]
		mov eax, dword [ss:edi+0x24]
		shl eax, 1
		movsx eax, word [ds:edx+eax]

		imul eax, eax, 96; Facet size
		add eax, dword [ds:0x6f3c84]; MapFacets ptr
		cmp byte [ds:eax+0x5d], 3; VertexesCount
		jl @rep

		mov edx, dword [ss:edi+0x1C]; MaxZ
		cmp dx, word [ds:eax+0x58]; MinZ
		jl @rep

		mov edx, dword [ss:edi+0x18]; MinZ
		cmp dx, word [ds:eax+0x5A]; MaxZ
		jg @rep

		mov edx, dword [ss:edi+0xC]; MaxX
		cmp dx, word [ds:eax+0x50]; MinX
		jl @rep

		mov edx, dword [ss:edi+0x8]; MinX
		cmp dx, word [ds:eax+0x52]; MaxX
		jg @rep

		mov edx, dword [ss:edi+0x14]; MaxY
		cmp dx, word [ds:eax+0x54]; MinY
		jl @rep

		mov edx, dword [ss:edi+0x10]; MinY
		cmp dx, word [ds:eax+0x56]; MaxY
		jg @rep

		; check for Invisible & Untouchable

		; choose vertexes
		mov edx, dword [ds:eax+0x30]
		mov dword [ds:edi+0x74], edx
		movsx edx, word [ds:eax+0x5d]
		mov dword [ds:edi+0x78], edx

		lea edx, dword [ds:edi+0x58]
		push edx
		push eax
		call absolute ]] .. GetFacetPlaneDefiners .. [[;

		lea eax, dword [ds:edi+0x68]; Destination
		push eax
		lea eax, dword [ds:edi+0x58]; Plane definers
		push eax
		lea eax, dword [ds:edi+0x28]; Line vector
		push eax
		lea eax, dword [ss:ebp+0x10]; From point
		push eax
		call absolute ]] .. PlaneLineIntersect .. [[;

		push dword [ds:edi+0x70]; Z
		push dword [ds:edi+0x6C]; Y
		push dword [ds:edi+0x68]; X
		push dword [ss:ebp+0x24]
		push dword [ss:ebp+0x20]
		push dword [ss:ebp+0x1C]
		call absolute ]] .. GetDistAsm .. [[;
		cmp eax, dword [ss:edi+0x4]
		jg @rep

		push dword [ds:edi+0x70]; Z
		push dword [ds:edi+0x6C]; Y
		push dword [ds:edi+0x68]; X
		push dword [ss:ebp+0x18]
		push dword [ss:ebp+0x14]
		push dword [ss:ebp+0x10]
		call absolute ]] .. GetDistAsm .. [[;
		cmp eax, dword [ss:edi+0x4]
		jg @rep

		push dword [ds:edi+0x78]; VertexesCount
		push dword [ds:edi+0x74]; VertexIds
		push dword [ds:edi+0x70]; Z
		push dword [ds:edi+0x6C]; Y
		push dword [ds:edi+0x68]; X
		call absolute ]] .. PointInProjection .. [[;
		test eax, eax
		je @rep

		jmp @fault

	@exitrep:
	cmp dword [ds:edi+0x7c], 1
	jl @floorsCheck
	cmp dword [ds:edi+0x7c], 2
	jl @CeilsCheck

	xor eax, eax
	inc eax
	jmp @end

	@fault:
	xor eax, eax

	@end:
	add esp, 0x80
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x20]])

Pathfinder.TraceLineAsm = TraceLineAsm

------------------------------------------------------
--					GetFloorLevel					--
------------------------------------------------------
-- Unlike Map.GetFloorLevel, does not mess game data, when executed in separate thread

-- takes X, Y, Z, returns floor level in eax, facetid in ecx
-- mem.call(Pathfinder.AltGetFloorLevelAsm, 0, Party.X, Party.Y, Party.Z)
local AltGetFloorLevelAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x28
	mov edi, esp
	mov dword [ds:edi+0x10], 0x0
	mov dword [ds:edi+0x14], 0x0
	mov dword [ds:edi+0x18], 0x20

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

		push ecx
		push eax

		push edi
		push eax
		call absolute ]] .. GetFacetPlaneDefiners .. [[;

		lea eax, dword [ds:edi+0x1C]
		push eax
		push edi
		lea eax, dword [ds:edi+0x10]
		push eax
		lea eax, dword [ss:ebp+0x8]
		push eax
		call absolute ]] .. PlaneLineIntersect .. [[;

		pop eax
		movsx edx, word [ds:eax+0x5d]; VertexesCount
		push edx
		push dword [ds:eax+0x30]; VertexIds array
		push dword [ds:edi+0x24]
		push dword [ds:edi+0x20]
		push dword [ds:edi+0x1C]; X,Y,Z
		call absolute ]] .. PointInProjection .. [[;
		pop ecx
		test eax, eax
		je @rep

		mov eax, dword [ds:edi+0x24]; intersection Z
		push eax
		movsx eax, word [ds:esi]; FacetId
		push eax
		jmp @rep

	@con2:
	mov eax, dword [ss:esp]
	cmp eax, -1
	je @fault

	mov esi, -30000

	@rep2:
		pop ecx
		pop eax
		cmp eax, esi
		jle @con3
		mov esi, eax
		mov dword [ss:ebp+0x10], ecx
		@con3:
		mov eax, dword [ss:esp]
		cmp eax, -1
		jne @rep2

	mov eax, esi
	mov ecx, dword [ss:ebp+0x10]
	add esp, 0x4

	@end:
	add esp, 0x28
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

Pathfinder.AltGetFloorLevelAsm = AltGetFloorLevelAsm

------------------------------------------------------

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

-- takes X, Y, Z, Radius, FromX, FromY, returns side shifts in eax and ecx
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
	jmp @end

	@II:
	neg ecx
	jmp @end

	@III:
	nop
	jmp @end

	@IV:
	neg eax
	jmp @end

	@OX:
	mov eax, dword [ss:ebp+0x14]
	xor ecx, ecx
	jmp @end

	@OY:
	xor eax, eax
	mov ecx, dword [ss:ebp+0x14]

	@end:
	add esp, 0x18
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x18]])

Pathfinder.CheckNeighboursAsm = CheckNeighboursAsm

-- takes shiftX, shiftY, FromX, FromY, FromZ, ToX, ToY, ToZ, returns 1 in eax, if there's no obstacles on the way
local TraceMonWayLines = mem.asmproc([[
	push ebp
	mov ebp, esp

	push dword [ss:ebp + 0x24]
	add dword [ss:esp], 0x28
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1c]
	push dword [ss:ebp + 0x18]
	add dword [ss:esp], 0x28
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x10]
	push 0
	push 0
	call absolute ]] .. TraceLineAsm .. [[;
	test eax, eax
	je @end

	mov eax, dword [ss:ebp + 0x8]
	mov ecx, dword [ss:ebp + 0xC]
	push dword [ss:ebp + 0x24]
	add dword [ss:esp], 0x64
	push dword [ss:ebp + 0x20]
	add dword [ss:esp], ecx
	push dword [ss:ebp + 0x1c]
	add dword [ss:esp], eax
	push dword [ss:ebp + 0x18]
	add dword [ss:esp], 0x28
	push dword [ss:ebp + 0x14]
	add dword [ss:esp], ecx
	push dword [ss:ebp + 0x10]
	add dword [ss:esp], eax
	push 0
	push 0
	call absolute ]] .. TraceLineAsm .. [[;
	test eax, eax
	je @end

	mov eax, dword [ss:ebp + 0x8]
	mov ecx, dword [ss:ebp + 0xC]
	push dword [ss:ebp + 0x24]
	add dword [ss:esp], 0x64
	push dword [ss:ebp + 0x20]
	sub dword [ss:esp], ecx
	push dword [ss:ebp + 0x1c]
	sub dword [ss:esp], eax
	push dword [ss:ebp + 0x18]
	add dword [ss:esp], 0x28
	push dword [ss:ebp + 0x14]
	sub dword [ss:esp], ecx
	push dword [ss:ebp + 0x10]
	sub dword [ss:esp], eax
	push 0
	push 0
	call absolute ]] .. TraceLineAsm .. [[;
	test eax, eax
	je @end

	@end:
	mov esp, ebp
	pop ebp
	retn 0x20]])

Pathfinder.TraceMonWayLines = TraceMonWayLines

-- Takes MonId, Radius, FromX, FromY, FromZ, ToX, ToY, ToZ
-- returns 1 in eax, if monster can reach point, 0 - otherwise

-- Uses approximation (faster, less accurate, does not use actual monster, does not crash game, when executed in separate thread).
-- mem.call(Pathfinder.TraceAsm, 0, 0, 30, Party.X, Party.Y, Party.Z, Party.X, Party.Y, Party.Z)
local TraceAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x18

; get shifts
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x10]
	push dword [ss:ebp + 0xC]
	push dword [ss:ebp + 0x24]
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1c]
	call absolute ]] .. CheckNeighboursAsm .. [[;
	mov dword [ss:ebp - 0xC], eax
	mov dword [ss:ebp - 0x10], ecx

; Set can fly flag
	mov eax, dword [ss:ebp + 0x8]
	imul eax, 0x3cc; Monster size
	add eax, ]] .. Map.Monsters["?ptr"] .. [[;
	movsx eax, byte [ds:eax+0x3a]
	mov dword [ss:ebp-0x20], eax

; if monster can fly, just trace lines
	cmp dword [ss:ebp-0x20], 1
	jne @CantFly

	push dword [ss:ebp + 0x24]
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1C]
	push dword [ss:ebp + 0x18]
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x10]
	push dword [ss:ebp - 0x10]
	push dword [ss:ebp - 0xC]
	call absolute ]] .. TraceMonWayLines .. [[;
	test eax, eax
	je @fault
	jmp @TLsuccess

	@CantFly:
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

; trace loop
	mov dword [ss:ebp + 0x8], 6
	mov edi, dword [ss:ebp + 0x18]; previous Z

	mov eax, dword [ss:ebp + 0x10]; X
	mov ecx, dword [ss:ebp + 0x14]; Y
	mov edx, dword [ss:ebp + 0x18]; Z
	mov dword [ss:ebp + 0x1c], eax
	mov dword [ss:ebp + 0x20], ecx
	mov dword [ss:ebp + 0x24], edx

	@rep:
	; save previous point
		mov eax, dword [ss:ebp + 0x1c]; X
		mov ecx, dword [ss:ebp + 0x20]; Y
		mov edx, dword [ss:ebp + 0x24]; Z
		mov dword [ss:ebp - 0x14], eax
		mov dword [ss:ebp - 0x18], ecx
		mov dword [ss:ebp - 0x1C], edx

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
		push dword [ss:ebp + 0x24]
		add dword [ss:esp], 0x28
		push dword [ss:ebp + 0x20]
		push dword [ss:ebp + 0x1c]
		call absolute ]] .. AltGetFloorLevelAsm .. [[;
		add esp, 0xC
		cmp eax, -29000
		jle @fault

		mov dword [ss:ebp + 0x24], eax
		mov eax, edi
		sub eax, dword [ss:ebp + 0x24]
		call absolute ]] .. absAsm .. [[;
		cmp eax, 0x28
		jg @fault

	; trace lines
		push dword [ss:ebp + 0x24]
		push dword [ss:ebp + 0x20]
		push dword [ss:ebp + 0x1c]
		push dword [ss:ebp - 0x1C]
		push dword [ss:ebp - 0x18]
		push dword [ss:ebp - 0x14]
		push dword [ss:ebp - 0x10]
		push dword [ss:ebp - 0xC]
		call absolute ]] .. TraceMonWayLines .. [[;
		test eax, eax
		je @fault

	; end loop
		mov edi, dword [ss:ebp + 0x24]
		add dword [ss:ebp + 0x8], 0x18
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

	@TLsuccess:
	add esp, 0x18
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

local SimpleTraceAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x18

; get shifts
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x10]
	push dword [ss:ebp + 0xC]
	push dword [ss:ebp + 0x24]
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1c]
	call absolute ]] .. CheckNeighboursAsm .. [[;
	mov dword [ss:ebp - 0xC], eax
	mov dword [ss:ebp - 0x10], ecx

; trace lines
	push dword [ss:ebp + 0x24]
	add dword [ss:esp], 0x32
	push dword [ss:ebp + 0x20]
	push dword [ss:ebp + 0x1C]
	push dword [ss:ebp + 0x18]
	add dword [ss:esp], 0x32
	push dword [ss:ebp + 0x14]
	push dword [ss:ebp + 0x10]
	push dword [ss:ebp - 0x10]
	push dword [ss:ebp - 0xC]
	call absolute ]] .. TraceMonWayLines .. [[;

	add esp, 0x18
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

	; mark as explored
	add dword [ds:]] .. ExploredCellsPtr .. [[], 0xC;
	mov edx, dword [ds:]] .. ExploredCellsPtr .. [[];

	; Id
	mov ecx, dword [ss:esp+0x4]
	mov word [ds:eax], cx

	; X
	mov ecx, dword [ss:esp+0x8]
	mov word [ds:eax+0x2], cx
	mov word [ds:edx], cx

	; Y
	mov ecx, dword [ss:esp+0xc]
	mov word [ds:eax+0x4], cx
	mov word [ds:edx+0x2], cx

	; Z
	mov ecx, dword [ss:esp+0x10]
	mov word [ds:eax+0x6], cx

	; StableZ
	mov ecx, dword [ss:esp+0x14]
	mov word [ds:eax+0x8], cx
	mov word [ds:edx+0x4], cx

	; From
	mov ecx, dword [ss:esp+0x18]
	mov word [ds:eax+0xA], cx

	; Cost
	mov ecx, dword [ss:esp+0x1C]
	mov dword [ds:eax+0xC], ecx

	; Length
	mov ecx, dword [ss:esp+0x20]
	mov dword [ds:eax+0x10], ecx

	; write FromX, FromY, FromZ of explored cell
	mov eax, dword [ss:esp+0x18]
	call absolute ]] .. GetCellAsm .. [[;

	mov cx, word [ds:eax+2]
	mov word [ds:edx+0x6], cx
	mov cx, word [ds:eax+4]
	mov word [ds:edx+0x8], cx
	mov cx, word [ds:eax+8]
	mov word [ds:edx+0xA], cx

	retn]])

-- Takes x, y, z, returns 1 in eax if cell with same coordinates exist in AllCells, 0 - otherwise.
local CellExploredAsm2 = mem.asmproc([[
	xor eax, eax
	mov ecx, ]] .. ExploredCellsPtr .. [[;
	add ecx, 0xC; skip first cell
	@rep:
	add ecx, 0xC;
	cmp ecx, ]] .. ExploredCellsPtr + 12*8*CellsAmount .. [[;
	jge @end

	cmp word [ds:ecx], 0
	je @end

	mov edx, dword [ss:esp+0x4]
	cmp word [ds:ecx+2], dx
	jne @rep
	mov edx, dword [ss:esp+0x8]
	cmp word [ds:ecx+4], dx
	jne @rep
	mov edx, dword [ss:esp+0xC]
	cmp word [ds:ecx+6], dx
	je @explored
	jmp @rep

	@explored:
	mov eax, 1
	@end:
	retn]])

-- Takes x, y, z, FromId returns 1 in eax if cell with same coordinates exist in AllCells, 0 - otherwise.
local CellExploredAsm = mem.asmproc([[
	push ebp
	mov ebp, esp

	mov eax, dword [ss:ebp+0x14]
	call absolute ]] .. GetCellAsm .. [[;

	;XY
	mov ecx, dword [ds:ebp+0xC]
	shl ecx, 0x10
	mov cx, word [ds:ebp+0x8]
	push ecx

	;ZX
	mov ecx, dword [ds:ebp+0x10]
	shl ecx, 0x10
	mov cx, word [ds:eax+0x2]
	push ecx

	;YZ
	movsx ecx, word [ds:eax+0x8]
	shl ecx, 0x10
	mov cx, word [ds:eax+0x4]
	push ecx


	mov ecx, ]] .. ExploredCellsPtr .. [[;
	@rep:
	add ecx, 0xC;
	cmp ecx, ]] .. ExploredCellsPtr + 12*8*CellsAmount .. [[;
	jge @neq

	mov eax, dword [ds:ecx]
	cmp eax, dword [ss:esp]
	jne @rep
	mov eax, dword [ds:ecx+0x4]
	cmp eax, dword [ss:esp+0x4]
	jne @rep
	mov eax, dword [ds:ecx+0x8]
	cmp eax, dword [ss:esp+0x8]
	jne @rep

	mov eax, 1
	jmp @end

	@neq:
	xor eax, eax

	@end:
	mov esp, ebp
	pop ebp
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

	mov edx, ]] .. ExploredCellsPtr .. [[;
	mov dword [ds:]] .. ExploredCellsPtr .. [[], edx;
	@rep3:
	add edx, 0xC
	mov dword [ds:edx], 0
	mov dword [ds:edx+0x4], 0
	mov dword [ds:edx+0x8], 0
	cmp edx, ]] .. ExploredCellsPtr+CellsAmount*12*8 .. [[;
	jl @rep3

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

-- takes facet id in eax, returns 1 in eax if facet is in allowed room, otherwise - 0.
local FacetInAllowedRoom = mem.asmproc([[
	cmp eax, 0
	jl @nequ
	mov ecx, dword [ss:esp+0x4]
	test ecx, ecx
	je @end
	cmp word [ds:ecx], 0; if no AvAreas defined, just return 1
	je @end

	; get facet
	imul eax, eax, 96; Facet size
	add eax, dword [ds:0x6f3c84]; MapFacets ptr
	movsx eax, word [ds:eax+0x4c]

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

local AStarWayParams = mem.StaticAlloc(48)

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
	;push dword [ds:edi+0x94]; Velocity, X
	;push dword [ds:edi+0x98]; Y, Z
	;push dword [ds:edi+0xa2]; Direction, LookAngle

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
			; check if handler have to be stopped
			cmp dword [ds:]] .. QueueFlag .. [[], 1
			jne @overflow

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

			; fix Z level
			push dword [ds:]] .. AStarWayParams + 28  .. [[]
			;movzx eax, word [ds:edi+0x92]; monster body height
			add dword [ss:esp], 0x64
			push dword [ds:]] .. AStarWayParams + 24  .. [[]
			push dword [ds:]] .. AStarWayParams + 20  .. [[]
			call absolute ]] .. AltGetFloorLevelAsm .. [[;
			add esp, 0xC
			cmp eax, -29000
			jle @repdirs

			cmp byte [ds:edi+0x3a], 1
			je @CanFlyZCon
			mov dword [ds:]] .. AStarWayParams + 28  .. [[], eax
			@CanFlyZCon:

			; check if area is allowed for tracing
			mov eax, ecx
			push ecx
			push dword [ss:ebp+0x28]
			call absolute ]] .. FacetInAllowedRoom .. [[;
			pop ecx
			pop ecx
			test eax, eax
			je @repdirs

			cmp byte [ds:edi+0x3a], 1
			je @fixZfault

			; make monsters prefer horizontal facets
			imul ecx, ecx, 96; Facet size
			add ecx, dword [ds:0x6f3c84]; MapFacets ptr
			movsx eax, word [ds:ecx+0x58]; MinZ
			movsx ecx, word [ds:ecx+0x5A]; MaxZ
			sub ecx, eax
			mov dword [ds:]] .. AStarWayParams + 40  .. [[], ecx

			@fixZfault:

			; 3. check if cell was explored before
			push dword [ds:]] .. AStarWayParams   .. [[]
			push dword [ds:]] .. AStarWayParams + 28  .. [[]
			push dword [ds:]] .. AStarWayParams + 24  .. [[]
			push dword [ds:]] .. AStarWayParams + 20  .. [[]
			call absolute ]] .. CellExploredAsm .. [[;
			add esp, 0x10
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
			shr eax, 4
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
			cmp esi, ]] .. CellsAmount-2 .. [[;
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
			result[i+1] = {X = i2[ptr+i*20+2], Y = i2[ptr+i*20+4], Z = i2[ptr+i*20+6], From = i2[ptr+i*20+10]}
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
--~ test = Pathfinder.AStarWayAsm{MonId = 0, ToX = Party.X, ToY = Party.Y, ToZ = Party.Z}
--~ print(#test)
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
		AvAreasPtr = mem.malloc(24)
		local count = 1
		u2[AvAreasPtr] = 0
		for k,v in pairs(AvAreas) do
			if v then
				u2[AvAreasPtr+(count-1)*2] = k
			end
			count = count + 1
			if count > 10 then
				break
			end
		end
		u2[AvAreasPtr+(count-1)*2] = 0
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

function events.BeforeLeaveGame()
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
