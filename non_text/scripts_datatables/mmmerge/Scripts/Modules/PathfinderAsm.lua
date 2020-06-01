
Pathfinder = {}

local u1, i1, u2, i2, u4, i4 = mem.u1, mem.i1, mem.u2, mem.i2, mem.u4, mem.i4
local QueueSize = 50
local CellItemSize = 20
local CellsAmount = 8000
local AllCellsPtr = mem.StaticAlloc(CellItemSize*(CellsAmount+2))
local ReachableAsm = mem.StaticAlloc(CellsAmount*2)
local QueueFlag = mem.StaticAlloc(4)
local ThreadHandler = 0
local DataPointers = mem.StaticAlloc(20)
local MapVertexesPtr, MapFacetsPtr, MapRoomsPtr, SpacePtr, SpaceSizePtr = DataPointers, DataPointers + 4, DataPointers + 8, DataPointers + 12, DataPointers + 16
local OutdoorBoundaries = {MinX = -27648, MaxX = 27648, MinY = -27648, MaxY = 27648, AreaSize = 1024} -- Z is fixed: 0 - 4096
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
{X =  1, 	Y =  1,		Z = -1}}

local AllowedDirsAsm = mem.StaticAlloc(#AllowedDirections*3)
for i,v in ipairs(AllowedDirections) do
	i1[AllowedDirsAsm+(i-1)*3]	 = v.X
	i1[AllowedDirsAsm+(i-1)*3+1] = v.Y
	i1[AllowedDirsAsm+(i-1)*3+2] = v.Z
end

local function cdataPtr(obj)
	return tonumber(string.sub(tostring(obj), -10))
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

-- takes amount of integers, num1, num2, num3 ... Returns greatest common divisor.
local GetGCD = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	push esi
	sub esp, 0x4

	mov dword [ss:esp], 1;
	mov edi, dword [ss:ebp+0x8]; amount of input
	lea esi, dword [ss:ebp+0xC]; input ptr

	xor ecx, ecx
	@abs_input:
	mov eax, dword [ds:esi+ecx]
	call absolute ]] .. absAsm .. [[;
	mov dword [ds:esi+ecx], eax
	add ecx, 0x4
	dec edi
	jne @abs_input

	@loop_start:

	mov edi, dword [ss:ebp+0x8]; amount of input
	xor ecx, ecx
	xor eax, eax
	@sum_input:
	add eax, dword [ds:esi+ecx]
	add ecx, 0x4
	dec edi
	jne @sum_input

	test eax, eax
	je @one

	; check input for 1 anywhere and for zeros everywhere, except one value
	mov edi, dword [ss:ebp+0x8]; amount of input
	xor ecx, ecx

	@find_zeros:
	cmp eax, dword [ds:esi+ecx]
	je @end
	cmp dword [ds:esi+ecx], 1
	je @one
	add ecx, 0x4
	dec edi
	jne @find_zeros

	; check if entire input became equal
	mov edi, dword [ss:ebp+0x8]; amount of input
	xor ecx, ecx

	@equality_check:
	dec edi
	je @end; all equal
	mov eax, dword [ds:esi+ecx]
	add ecx, 0x4
	cmp eax, dword [ds:esi+ecx]
	je @equality_check

	; check if all are even
	mov edi, dword [ss:ebp+0x8]; amount of input
	xor ecx, ecx
	xor edx, edx; count even numbers

	@all_even:
	mov eax, dword [ds:esi+ecx]
	add ecx, 0x4
	test eax, eax
	je @con_all_even
	and eax, 1
	test eax, eax
	jne @con_all_even
	inc edx
	@con_all_even:
	dec edi
	jne @all_even

	test edx, edx
	je @process_uneven
	cmp edx, dword [ss:ebp+0x8]
	jl @process_even

	shl dword [ss:esp], 1; increase multiplier if all numbers are even

	@process_even:

	; halfen ever even input
	mov edi, dword [ss:ebp+0x8]; amount of input
	xor ecx, ecx
	sub ecx, 4

	@halfen_even:
	add ecx, 0x4
	dec edi
	jl @loop_start
	mov eax, dword [ds:esi+ecx]
	and eax, 1
	test eax, eax
	jne @halfen_even
	shr dword [ds:esi+ecx], 1
	jmp @halfen_even

	; if all numbers are uneven

	; find MinNum, MaxNum, MaxOffset
	; calculate (MaxNum - MinNum)/2
	; update value by MaxOffset

	@process_uneven:
	mov edi, dword [ss:ebp+0x8]; amount of input
	xor ecx, ecx
	mov eax, 0xfffffff

	@find_max_min:
	dec edi
	jl @update_max_num
	cmp dword [esi+edi*4], 0
	je @find_max_min
	cmp eax, dword [esi+edi*4]
	jl @con_seek1
	mov eax, dword [esi+edi*4]
	@con_seek1:
	cmp ecx, dword [esi+edi*4]
	jg @find_max_min
	mov ecx, dword [esi+edi*4]
	lea edx, dword [esi+edi*4]
	jmp @find_max_min

	@update_max_num:
	sub ecx, eax
	shr ecx, 1
	mov dword [edx], ecx
	jmp @loop_start

	@one:
	xor eax, eax
	inc eax
	jmp @end

	@end:
	mov ecx, dword [ss:esp]
	imul eax, ecx
	add esp, 0x4
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

Pathfinder.GetGCD = GetGCD

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

	; simplify vector to avoid integer overflow
	push dword [ds:edi+0x8]
	push dword [ds:edi+0x4]
	push dword [ds:edi]
	push 3
	call absolute ]] .. GetGCD .. [[;
	add esp, 0x10
	mov ecx, eax

	mov eax, dword [ds:edi]
	cdq
	idiv ecx
	mov dword [ds:edi], eax

	mov eax, dword [ds:edi+0x4]
	cdq
	idiv ecx
	mov dword [ds:edi+0x4], eax

	mov eax, dword [ds:edi+0x8]
	cdq
	idiv ecx
	mov dword [ds:edi+0x8], eax

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
	movzx eax, word [ds:eax]; Vertex Id
	imul eax, eax, 0x6
	add eax, dword [ds:]] .. MapVertexesPtr .. [[]; MapVertexes ptr - 0x6f3c7c for indoor, custom - for outdoor

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
	movzx eax, word [ds:eax]; Vertex Id
	imul eax, eax, 0x6
	add eax, dword [ds:]] .. MapVertexesPtr .. [[]; MapVertexes ptr - 0x6f3c7c for indoor, custom - for outdoor

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
	movzx edx, word [ds:ecx]
	mov dword [ds:edi], edx

	@v2rep:
	;2 always second vertex
	add eax, 0x2
	movzx edx, word [ds:ecx+eax]
	cmp edx, dword [ds:edi]
	je @v2rep
	mov dword [ds:edi+0xC], edx

	;3 choose any not on line with previous two
	add eax, 0x2
	movzx edx, word [ds:ecx+eax]
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
		add esi, dword [ds:]] .. MapVertexesPtr .. [[]; MapVertexes ptr - 0x6f3c7c for indoor, custom - for outdoor

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
	movzx edx, word [ds:eax+0x5d]; VertexesCount
	mov ecx, dword [ds:eax+0x30]
	pop eax
	add eax, 2
	shl edx, 1
	cmp eax, edx
	jge @con2
	movzx edx, word [ds:ecx+eax]
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

------------------------------------------------------
--					Trace line  					--
------------------------------------------------------

-- mem.call(Pathfinder.AreaFromPoint, 0, Party.X, Party.Y, Party.Z)
-- takes X, Y, Z, returns area id (in indoor maps - room id)
local AreaFromPoint = mem.asmproc([[
	push ebp
	mov ebp, esp
	cmp dword [ds:0x6f39a0], 1; is indoor
	je @indoor

	; floor(ceil((Party.X + 27648)/1024)*55 + (Party.Y + 27648)/1024) - 54
	mov eax, dword [ds:]] .. MapVertexesPtr .. [[]
	test eax, eax
	je @end

	mov eax, dword [ss:ebp+0x8]
	add eax, ]] .. OutdoorBoundaries.MaxX .. [[;
	sar eax, 10
	imul eax, 55

	mov ecx, dword [ss:ebp+0xC]
	add ecx, ]] .. OutdoorBoundaries.MaxY .. [[;
	sar ecx, 10

	add eax, ecx
	inc eax

	test eax, eax
	jle @fault

	@con1:
	cmp eax, ]] .. math.floor((OutdoorBoundaries.MaxX/512))^2 .. [[;
	jle @end

	@fault:
	xor eax,eax
	jmp @end

	@indoor:
	mov ecx, 0x6f3a08
	push dword [ss:ebp+0x10]; Z
	push dword [ss:ebp+0xC]; Y
	push dword [ss:ebp+0x8]; X
	call absolute 0x4980ba
	jmp @end

	@end:
	mov esp, ebp
	pop ebp
	retn 0xC]])

Pathfinder.AreaFromPoint = AreaFromPoint

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
	call absolute ]] .. AreaFromPoint .. [[; room from point - 0x4980ba
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

	; calc line bounding box
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
	add eax, dword [ds:]] .. MapRoomsPtr .. [[]; contain Rooms ptr, indoor - 0x6f3c94, outdoor - custom
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
	add eax, dword [ds:]] .. MapRoomsPtr .. [[]; contain Rooms ptr, indoor - 0x6f3c94, outdoor - custom
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
	add eax, dword [ds:]] .. MapRoomsPtr .. [[]; contain Rooms ptr, indoor - 0x6f3c94, outdoor - custom
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
		movzx eax, word [ds:edx+eax]

		imul eax, eax, 96; Facet size
		add eax, dword [ds:]] .. MapFacetsPtr .. [[]; MapFacets ptr, indoor - 0x6f3c84, outdoor - custom
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

	mov ecx, 0x6f3a08
	add dword [ss:ebp+0x10], 0xA
	push dword [ss:ebp+0x10]; Z
	add dword [ss:esp], 0x64
	push dword [ss:ebp+0xC]; Y
	push dword [ss:ebp+0x8]; X
	call absolute ]] .. AreaFromPoint .. [[; room from point - 0x4980ba
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
	add eax, dword [ds:]] .. MapRoomsPtr .. [[]; contain Rooms ptr, indoor - 0x6f3c94, outdoor - custom
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

		movzx eax, word [ds:esi]; Facet id
		imul eax, eax, 96; Facet size
		add eax, dword [ds:]] .. MapFacetsPtr .. [[]; MapFacets ptr, indoor - 0x6f3c84, outdoor - custom
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
		movzx edx, word [ds:eax+0x5d]; VertexesCount
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
		movzx eax, word [ds:esi]; FacetId
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
-- gives correct shifts only for 45 degrees based angles.
local CheckNeighboursAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi
	sub esp, 0x24
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

	mov eax, dword [ds:edi]
	mov dword [ds:edi+0xC], eax
	mov eax, dword [ds:edi+0x4]
	mov dword [ds:edi+0x10], eax
	mov dword [ds:edi+0x14], 1

	push edi
	lea eax, dword [ds:edi+0xC]
	push eax
	lea eax, dword [ds:edi+0x18]
	push eax
	call absolute ]] .. VectorMul .. [[;

	mov eax, dword [ds:edi+0x18]
	mov ecx, dword [ds:edi+0x1C]

	test eax, eax
	je @SetY
	mov eax, dword [ss:ebp+0x14]
	jg @SetY
	neg eax

	@SetY:
	test ecx, ecx
	je @end
	mov ecx, dword [ss:ebp+0x14]
	jg @end
	neg ecx

	@end:
	add esp, 0x24
	pop edi
	mov esp, ebp
	pop ebp
	retn 0x18]])

-- takes X, Y, Z, Radius, FromX, FromY, returns side shifts in eax and ecx
local CheckNeighboursAsm2 = mem.asmproc([[
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
	sub esp, 0x14

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
	add esp, 0x14
	pop esi
	pop edi
	mov esp, ebp
	pop ebp
	retn]])


-- Takes X, Y, returns absolute TileId
local GetTileIdAsm = mem.asmproc([[
	push ebp
	mov ebp, esp

	; calc Tile X
	mov eax, dword [ss:ebp+0x8]
	sar eax, 9
	add eax, 0x40

	; calc Tile Y
	mov ecx, dword [ss:ebp+0xC]
	sar ecx, 9
	mov edx, 0x40
	sub edx, ecx
	mov ecx, edx
	dec ecx

	; get relative TileId
	xchg eax, ecx
	shl eax, 7
	add eax, ecx
	mov ecx, 0x6CEBD0
	mov ecx, dword [ds:ecx+0xBC]
	movzx eax, byte [ds:eax+ecx]

	cmp eax, 0x5a
	jl @end

	; calc tileset id and offset
	sub eax, 0x5a
	cdq
	mov ecx, 0x24
	idiv ecx

	; get tileset offset
	mov ecx, 0x6CEBD0
	add ecx, 0xa2
	movsx eax, word [ecx+eax*4]
	add eax, edx

	@end:
	mov esp, ebp
	pop ebp
	retn 0x8]])

Pathfinder.GetTileIdAsm = GetTileIdAsm

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

-- takes facet id in eax, returns 1 in eax if facet is in allowed room, otherwise - 0.
local FacetInAllowedRoom = mem.asmproc([[
	mov ecx, dword [ss:esp+0x4]
	test ecx, ecx
	je @end

	imul eax, eax, 96; Facet size
	add eax, dword [ds:]] .. MapFacetsPtr .. [[]; MapFacets ptr, indoor - 0x6f3c84, outdoor - custom
	movsx eax, word [ds:eax+0x4c]
	cmp byte [ecx+eax], 1
	je @end

	@nequ:
	xor eax, eax
	jmp @exit

	@end:
	xor eax, eax
	inc eax

	@exit:
	retn]])

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
		shl ecx, 1
		add ecx, 0x64
		cmp eax, ecx
		jg @monster_far_or_not_in_sight

		mov eax, dword [ds:]] .. AStarWayParams + 4 .. [[]
		movsx ecx, word [ds:eax+0x6]; Z of cell
		add ecx, 0x28
		push ecx
		movsx ecx, word [ds:eax+0x4]; Y
		push ecx
		movsx ecx, word [ds:eax+0x2]; X
		push ecx
		push dword [ss:ebp+0x14];	Z of target
		add dword [ss:esp], 0x28
		push dword [ss:ebp+0x10];	Y
		push dword [ss:ebp+0xC];	X
		push 0
		push 0
		call absolute ]] .. TraceLineAsm .. [[;
		test eax, eax
		jne @endloop

		@monster_far_or_not_in_sight:
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
			cmp dword [ds:0x6F39A0], 2
			;je @DecreaseOutdoorRad
			shl eax, 1
			;@DecreaseOutdoorRad:
			movsx edx, byte [ds:ecx]
			imul eax, edx
			add eax, dword []] .. AStarWayParams + 8 .. [[]
			mov dword [ds:]] .. AStarWayParams + 20 .. [[], eax; Neighbour X

			movzx eax, word [ds:edi+0x90]; monster body radius
			shl eax, 1
			movsx edx, byte [ds:ecx+0x1]
			imul eax, edx
			add eax, dword []] .. AStarWayParams + 12 .. [[]
			mov dword [ds:]] .. AStarWayParams + 24  .. [[], eax; Neighbour Y

			movzx eax, word [ds:edi+0x90]; monster body radius
			shl eax, 1
			movsx edx, byte [ds:ecx+0x2]
			imul eax, edx
			add eax, dword []] .. AStarWayParams + 16 .. [[]
			mov dword [ds:]] .. AStarWayParams + 28  .. [[], eax; Neighbour Z

			; fix Z level
			push dword [ds:]] .. AStarWayParams + 28  .. [[]
			add dword [ss:esp], 0x64
			push dword [ds:]] .. AStarWayParams + 24  .. [[]
			push dword [ds:]] .. AStarWayParams + 20  .. [[]
			call absolute ]] .. AltGetFloorLevelAsm .. [[;
			add esp, 0xC
			cmp eax, -29000
			jle @fixZfault
			mov dword [ds:]] .. AStarWayParams + 28  .. [[], eax
			@fixZfault:

			; check if area is allowed for tracing
			mov eax, ecx
			push ecx
			push dword [ss:ebp+0x28]
			call absolute ]] .. FacetInAllowedRoom .. [[;
			pop ecx
			pop ecx
			test eax, eax
			je @repdirs

			; make monsters prefer horizontal facets
			imul ecx, ecx, 96; Facet size
			add ecx, dword [ds:]] .. MapFacetsPtr .. [[]; MapFacets ptr, indoor - 0x6f3c84, outdoor - custom
			movsx eax, word [ds:ecx+0x58]; MinZ
			movsx ecx, word [ds:ecx+0x5A]; MaxZ
			sub ecx, eax
			mov dword [ds:]] .. AStarWayParams + 40  .. [[], ecx

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
			shr eax, 1
			push eax; Radius
			push dword [ss:ebp+0x8]; Mon Id
			call absolute ]] .. TraceAsm .. [[;
			add esp, 0x20
			test eax, eax
			je @repdirs

			; calculate length (distance from current cell to neighbour)
			mov eax, esi
			call absolute ]] .. GetCellAsm .. [[;

			cmp byte [ds:edi+0x3a], 1
			je @dont_ground_flying_monsters
			mov word [eax+0x6], cx
			jmp @con_cell_setup

			@dont_ground_flying_monsters:
			movsx edx, word [eax+0x6]
			mov word [eax+0x6], cx
			sub edx, 0x32
			cmp edx, ecx
			jl @con_cell_setup
			mov word [eax+0x6], dx

			@con_cell_setup:
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

			cmp dword [ds:0x6F39A0], 2
			je @OutdoorLength
			shr eax, 1
			@OutdoorLength:

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

local AStarQueueC = ffi.new("AStarQueue[?]", QueueSize)

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
		AvAreasPtr = mem.malloc(Map.Rooms.count)
		for i,v in Map.Rooms do
			u1[AvAreasPtr+i] = AvAreas[i] and 1 or 0
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

const.AStarQueueStatus = {}
const.AStarQueueStatus.NoHandler = 0
const.AStarQueueStatus.Working = 1
const.AStarQueueStatus.Stopped = 2
const.AStarQueueStatus.StopRequested = 3
const.AStarQueueStatus.PauseRequested = 4
const.AStarQueueStatus.Paused = 5

local QueuePtr = cdataPtr(AStarQueueC)
local HandlerAsm = mem.asmproc([[
	push ebp
	mov ebp, esp
	push edi

	mov edi, ]] .. QueuePtr .. [[;
	xor ecx, ecx
	xor edx, edx

	@rep:
	mov eax, dword [ds:]] .. QueueFlag .. [[]
	cmp eax, 3
	je @exit

	cmp eax, 4
	je @PauseRequest

	cmp eax, 5
	je @Sleep

	mov eax, ecx
	imul eax, eax, 0x2C
	add eax, edi
	cmp dword [ds:eax], 1
	je @start

	inc ecx
	cmp ecx, ]] .. QueueSize  .. [[;
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

	@PauseRequest:
	mov dword [ds:]] .. QueueFlag .. [[], 5

	@Sleep:
	push 0x20
	call absolute ]] .. mem.GetProcAddress(mem.dll["kernel32"]["?ptr"], "Sleep") .. [[;
	xor ecx, ecx
	xor edx, edx
	jmp @rep

	@exit:
	mov dword [ds:]] .. QueueFlag .. [[], 2
	pop edi
	mov esp, ebp
	pop ebp
	retn]])

local function UpdatePointers()
	if Map.IsIndoor() then
		u4[MapVertexesPtr], u4[MapFacetsPtr], u4[MapRoomsPtr] = u4[0x6f3c7c], u4[0x6f3c84], u4[0x6f3c94]
	else
		u4[MapVertexesPtr], u4[MapFacetsPtr], u4[MapRoomsPtr] = Pathfinder.LoadMapDataBin()
	end
	return u4[MapVertexesPtr] ~= 0
end

local function ClearQueue()
	for i = 0, QueueSize  do
		AStarQueueC[i].Status = 0
	end
end
Pathfinder.ClearQueue = ClearQueue

local function StartQueueHandler()
	if u4[QueueFlag] == 1 and ThreadHandler ~= 0 then -- handler already working
		return ThreadHandler
	end

	UpdatePointers()
	if Map.IsOutdoor() and u4[MapVertexesPtr] == 0 then
		return 0
	end

	u4[QueueFlag] = 1
	if ThreadHandler == 0 then
		ThreadHandler = mem.dll["kernel32"].CreateThread(nil, 0, HandlerAsm, QueueFlag, 0, nil)
	end
	return ThreadHandler
end

local function QueueStatus()
	return u1[QueueFlag]
end

local function PauseQueueHandler()
	if ThreadHandler ~= 0 then
		if mem.u4[QueueFlag] == const.AStarQueueStatus.Working then
			mem.u4[QueueFlag] = const.AStarQueueStatus.PauseRequested
			mem.dll["kernel32"].ResumeThread(ThreadHandler)
			while mem.u4[QueueFlag] ~= const.AStarQueueStatus.Paused do
				-- hold main thread, while handler finishes it's job
			end
		end
	end
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
	ClearQueue()
end

Pathfinder.HandlerAsm = HandlerAsm
Pathfinder.StartQueueHandler = StartQueueHandler
Pathfinder.StopQueueHandler = StopQueueHandler
Pathfinder.PauseQueueHandler = PauseQueueHandler
Pathfinder.AStarQueueC = AStarQueueC
Pathfinder.QueueStatus = QueueStatus

------------------------------------------------------
--						Events						--
------------------------------------------------------

function events.AfterLoadMap()
	StartQueueHandler()
end

function events.LeaveMap()
	if ThreadHandler ~= 0 then
		ClearQueue()
		PauseQueueHandler()
	end
end

function events.BeforeLeaveGame()
	if ThreadHandler ~= 0 then
		PauseQueueHandler()
	end
end

function events.LeaveGame()
	if ThreadHandler ~= 0 then
		PauseQueueHandler()
	end
end

------------------------------------------------------
--				Outdoor maps support				--
------------------------------------------------------

local MonstersMovementHook = mem.asmpatch(0x4026ef, [[
	nop
	nop
	nop
	nop
	nop
	pop edi
	pop esi
	pop ebx
	leave
	retn]])

mem.hook(MonstersMovementHook, function()
	events.call("MonstersChooseDirection")
end)

local function TileAbsoluteId(X, Y)
	X = (64 + X / 0x200):floor()
	Y = (64 - Y / 0x200):floor()

	local TileId = Map.TileMap[Y][X]
	if TileId >= 90 then
		TileId = TileId - 90
		TileId = Map.Tilesets[(TileId/36):floor()].Offset + TileId % 36
	end
	return TileId
end

local function ConvertOutdoorData()
	if not Map.IsOutdoor() then
		return false
	end

	local MapVertexes = {}
	local MapFacets = {}
	local MapRooms = {}
	local Val

	local AreaBoxExtraSize = 64 -- used for detecting neighbour facets to increase tracing precision
	local AreaSize = OutdoorBoundaries.AreaSize

	-- set empty default room
	MapRooms[1] = {
		MinX = -30000 - AreaBoxExtraSize,
		MaxX = -30000 + AreaBoxExtraSize,
		MinY = -30000 - AreaBoxExtraSize,
		MaxY = -30000 + AreaBoxExtraSize,
		MinZ = -30000,
		MaxZ = -30000,
		FloorsCount = 0,
		Floors = {},
		WallsCount = 0,
		Walls = {},
		CeilsCount = 0,
		Ceils = {}
	}

	-- Init areas
	for X = OutdoorBoundaries.MinX, OutdoorBoundaries.MaxX, AreaSize do
		for Y = OutdoorBoundaries.MinY, OutdoorBoundaries.MaxY, AreaSize do
			MapRooms[#MapRooms + 1] = {
				MinX = X - AreaBoxExtraSize,
				MaxX = X + AreaBoxExtraSize + AreaSize,
				MinY = Y - AreaBoxExtraSize,
				MaxY = Y + AreaBoxExtraSize + AreaSize,
				MinZ = -1,
				MaxZ = 4096,
				FloorsCount = 0,
				Floors = {},
				WallsCount = 0,
				Walls = {},
				CeilsCount = 0,
				Ceils = {}
			}
		end
	end

	-- Interpret ground as vertexes and facets
	local GroundVertexes = {}
	local aX, aY, TileId
	for Y, Yt in Map.HeightMap do
		aY = (64 - Y)*512
		GroundVertexes[Y] = {}
		for X, Height in Yt do
			aX = (X - 64)*512
			Val = {Id = #MapVertexes + 1, X = aX, Y = aY, Z = Height*32}
			MapVertexes[Val.Id] = Val
			GroundVertexes[Y][X] = Val
		end
	end

	local V1, V2, V3, V4, TileId
	for X, Yt in pairs(GroundVertexes) do
		for Y, Vertex in pairs(Yt) do
			if GroundVertexes[X+1] and GroundVertexes[X+1][Y+1] then
				V1, V2, V3, V4 = Vertex, GroundVertexes[X][Y+1], GroundVertexes[X+1][Y+1], GroundVertexes[X+1][Y]

				TileId = TileAbsoluteId((V1.X + V3.X)/2, (V1.Y + V3.Y)/2)
				if Game.CurrentTileBin[TileId].Water then
					-- skip water facets as impassable

				-- triangulate non-horizontal facets
				elseif V1.Z == V2.Z == V3.Z == V4.Z then
					Val = {
						VertexIds = {V1.Id, V2.Id, V3.Id, V4.Id},
						Room = 0,
						MinX = math.min(V1.X, V2.X, V3.X, V4.X),
						MaxX = math.max(V1.X, V2.X, V3.X, V4.X),
						MinY = math.min(V1.Y, V2.Y, V3.Y, V4.Y),
						MaxY = math.max(V1.Y, V2.Y, V3.Y, V4.Y),
						MinZ = V1.Z,
						MaxZ = V1.Z,
						-- 3 - horizontal floor, 4 - non-horizontal floor
						PolygonType = 3}

					MapFacets[#MapFacets + 1] = Val
				else
					Val = {
						VertexIds = {V1.Id, V2.Id, V3.Id},
						Room = 0,
						MinX = math.min(V1.X, V2.X, V3.X),
						MaxX = math.max(V1.X, V2.X, V3.X),
						MinY = math.min(V1.Y, V2.Y, V3.Y),
						MaxY = math.max(V1.Y, V2.Y, V3.Y),
						MinZ = math.min(V1.Z, V2.Z, V3.Z),
						MaxZ = math.max(V1.Z, V2.Z, V3.Z),
						PolygonType = 4}

					MapFacets[#MapFacets + 1] = Val

					Val = {
						VertexIds = {V1.Id, V3.Id, V4.Id},
						Room = 0,
						MinX = math.min(V1.X, V3.X, V4.X),
						MaxX = math.max(V1.X, V3.X, V4.X),
						MinY = math.min(V1.Y, V3.Y, V4.Y),
						MaxY = math.max(V1.Y, V3.Y, V4.Y),
						MinZ = math.min(V1.Z, V3.Z, V4.Z),
						MaxZ = math.max(V1.Z, V3.Z, V4.Z),
						PolygonType = 4}

					MapFacets[#MapFacets + 1] = Val
				end

			end
		end
	end

	-- Process models
	for ModelId, Model in Map.Models do
		local CurVertexList = {}
		for VertexId, Vertex in Model.Vertexes do
			CurVertexList[VertexId] = #MapVertexes + 1
			MapVertexes[#MapVertexes + 1] = {X = Vertex.X, Y = Vertex.Y, Z = Vertex.Z}
		end

		for FacetId, Facet in Model.Facets do
			Val = {
				VertexIds = {},
				Room = 0,
				MinX = Facet.MinX,
				MaxX = Facet.MaxX,
				MinY = Facet.MinY,
				MaxY = Facet.MaxY,
				MinZ = Facet.MinZ,
				MaxZ = Facet.MaxZ,
				PolygonType = Facet.PolygonType}

			if Val.PolygonType ~= 3 then -- horizontal floor
				-- increase Z bounds to force small facets detection.
				Val.MinZ = Val.MinZ - 50
				Val.MaxZ = Val.MaxZ + 50
			end

			for _, VertexId in Facet.VertexIds do
				table.insert(Val.VertexIds, CurVertexList[VertexId])
			end
			MapFacets[#MapFacets + 1] = Val
		end
	end

	-- Interpret sprites as X facets pairs
	local DecListItem
	local GrowBoundsVal = 50
	local SpriteFacets, SpriteVertexes = {}, {}
	local SminX, SmaxX, SminY, SmaxY, Radius, BaseId
	for SpriteId, Sprite in Map.Sprites do
		DecListItem = Game.DecListBin[Sprite.DecListId]
		if not DecListItem.NoBlockMovement and not DecListItem.NoDraw
			and DecListItem.Radius > 30 and DecListItem.Height > 30 then -- sprites with sizes less than 30 do not block movement

			Radius = DecListItem.Radius + GrowBoundsVal
			BaseId = #MapVertexes

			SpriteVertexes[1] = {Id = BaseId + 1, X = Sprite.X + Radius, Y = Sprite.Y + Radius, Z = Sprite.Z} -- >^
			SpriteVertexes[2] = {Id = BaseId + 2, X = Sprite.X - Radius, Y = Sprite.Y + Radius, Z = Sprite.Z} -- <^
			SpriteVertexes[3] = {Id = BaseId + 3, X = Sprite.X + Radius, Y = Sprite.Y - Radius, Z = Sprite.Z} -- >
			SpriteVertexes[4] = {Id = BaseId + 4, X = Sprite.X - Radius, Y = Sprite.Y - Radius, Z = Sprite.Z} -- <

			SpriteVertexes[5] = {Id = BaseId + 5, X = Sprite.X + Radius, Y = Sprite.Y + Radius, Z = Sprite.Z + DecListItem.Height}
			SpriteVertexes[6] = {Id = BaseId + 6, X = Sprite.X - Radius, Y = Sprite.Y + Radius, Z = Sprite.Z + DecListItem.Height}
			SpriteVertexes[7] = {Id = BaseId + 7, X = Sprite.X + Radius, Y = Sprite.Y - Radius, Z = Sprite.Z + DecListItem.Height}
			SpriteVertexes[8] = {Id = BaseId + 8, X = Sprite.X - Radius, Y = Sprite.Y - Radius, Z = Sprite.Z + DecListItem.Height}

			-- register vertexes
			for _, Vertex in ipairs(SpriteVertexes) do
				MapVertexes[Vertex.Id] = Vertex
			end

			SminX, SmaxX, SminY, SmaxY = Sprite.X - Radius, Sprite.X + Radius, Sprite.Y - Radius, Sprite.Y + Radius

			-- X

			SpriteFacets[1] = {VertexIds = {SpriteVertexes[1].Id, SpriteVertexes[5].Id, SpriteVertexes[8].Id, SpriteVertexes[4].Id},
				MinX = SminX, MaxX = SmaxX, MinY = SminY, MaxY = SmaxY}

			SpriteFacets[2] = {VertexIds = {SpriteVertexes[2].Id, SpriteVertexes[6].Id, SpriteVertexes[7].Id, SpriteVertexes[3].Id},
				MinX = SminX, MaxX = SmaxX, MinY = SminY, MaxY = SmaxY}

			-- Cube

			SpriteFacets[3] = {VertexIds = {SpriteVertexes[1].Id, SpriteVertexes[5].Id, SpriteVertexes[6].Id, SpriteVertexes[2].Id},
				MinX = SminX, MaxX = SmaxX, MinY = SminY, MaxY = SmaxY}

			SpriteFacets[4] = {VertexIds = {SpriteVertexes[3].Id, SpriteVertexes[7].Id, SpriteVertexes[8].Id, SpriteVertexes[4].Id},
				MinX = SminX, MaxX = SmaxX, MinY = SminY, MaxY = SmaxY}

			SpriteFacets[5] = {VertexIds = {SpriteVertexes[1].Id, SpriteVertexes[5].Id, SpriteVertexes[7].Id, SpriteVertexes[3].Id},
				MinX = SminX, MaxX = SmaxX, MinY = SminY, MaxY = SmaxY}

			SpriteFacets[6] = {VertexIds = {SpriteVertexes[3].Id, SpriteVertexes[7].Id, SpriteVertexes[8].Id, SpriteVertexes[6].Id},
				MinX = SminX, MaxX = SmaxX, MinY = SminY, MaxY = SmaxY}

			-- set rest facet props and register facets
			for _, Facet in pairs(SpriteFacets) do
				MapFacets[#MapFacets+1] = Facet
				Facet.Room = 0
				Facet.PolygonType = 1 -- wall
				Facet.MinZ = Sprite.Z - DecListItem.Height - GrowBoundsVal
				Facet.MaxZ = Sprite.Z + DecListItem.Height + GrowBoundsVal
			end
		end
	end

	-- Assign facets to "rooms":
	-- slow, but obvious method
	local function BBoxesIntersect(A, B)
		return	A.MinX <= B.MaxX and A.MaxX >= B.MinX
			and	A.MinY <= B.MaxY and A.MaxY >= B.MinY
	end

	for RoomId, Room in pairs(MapRooms) do
		for FacetId, Facet in pairs(MapFacets) do
			if BBoxesIntersect(Room, Facet) then
				if Facet.PolygonType == 1 then -- wall
					table.insert(Room.Walls, FacetId)
				elseif Facet.PolygonType == 3 or Facet.PolygonType == 4 then -- floor
					table.insert(Room.Floors, FacetId)
				else -- ceiling
					table.insert(Room.Ceils, FacetId)
				end
				Facet.Room = RoomId
			end
		end
	end

	-- set "count" fields, cut extra size, calc bin size
	local extraSize = 0
	local binSize = #MapVertexes*6 + #MapFacets*96 + #MapRooms*120
	for FacetId, Facet  in pairs(MapFacets) do
		Facet.VertexesCount = #Facet.VertexIds
		extraSize = extraSize + Facet.VertexesCount*2 + 2
	end

	for RoomId, Room in pairs(MapRooms) do
		Room.FloorsCount = #Room.Floors
		Room.WallsCount = #Room.Walls
		Room.CeilsCount = #Room.Ceils

		extraSize = extraSize + (Room.FloorsCount + Room.WallsCount + Room.CeilsCount + 3)*4

		Room.MinX = Room.MinX + AreaBoxExtraSize
		Room.MaxX = Room.MaxX - AreaBoxExtraSize
		Room.MinY = Room.MinY + AreaBoxExtraSize
		Room.MaxY = Room.MaxY - AreaBoxExtraSize
		Room.MinZ = Room.MinZ + 1
	end

	return {Rooms = MapRooms, Facets = MapFacets, Vertexes = MapVertexes, binSize = binSize, extraSize = extraSize}
end

local BinVersion = 1
local BinMapDataProps = {
	sizes = 		{R = 120, F = 96, V = 6},
	packedsizes = 	{R = 24, F = 96, V = 6},

	fields = {
		R = {
			FloorsCount	= {m = u4, offset = 0x8,  packed = 0},
			WallsCount	= {m = u4, offset = 0x10, packed = 4},
			CeilsCount	= {m = u4, offset = 0x18, packed = 8},
			MinX		= {m = i2, offset = 0x6C, packed = 12},
			MaxX		= {m = i2, offset = 0x6E, packed = 14},
			MinY		= {m = i2, offset = 0x70, packed = 16},
			MaxY		= {m = i2, offset = 0x72, packed = 18},
			MinZ		= {m = i2, offset = 0x74, packed = 20},
			MaxZ		= {m = i2, offset = 0x76, packed = 22}},

		F = {
			Room = {m = u2, offset = 0x4c, packed = 0x4c},
			MinX = {m = i2, offset = 0x50, packed = 0x50},
			MaxX = {m = i2, offset = 0x52, packed = 0x52},
			MinY = {m = i2, offset = 0x54, packed = 0x54},
			MaxY = {m = i2, offset = 0x56, packed = 0x56},
			MinZ = {m = i2, offset = 0x58, packed = 0x58},
			MaxZ = {m = i2, offset = 0x5a, packed = 0x5a},
			PolygonType = 	{m = u1, offset = 0x5c, packed = 0x5c},
			VertexesCount = {m = u1, offset = 0x5d, packed = 0x5d}},

		V = {
			X = {m = i2, offset = 0, packed = 0},
			Y = {m = i2, offset = 2, packed = 2},
			Z = {m = i2, offset = 4, packed = 4}}},

	tables = {
		R = {
			Floors	= {m = u2, offset = 0xC,  convId = 4},
			Walls	= {m = u2, offset = 0x14, convId = 5},
			Ceils	= {m = u2, offset = 0x1C, convId = 6}},

		F = {
			VertexIds = {m = u2, offset = 0x30, convId = 3}},

		V = {}}
	}

local function ExportMapDataBin(MapData)
	local output = {}
	local tinsert = table.insert
	local MapRooms, MapFacets, MapVertexes = MapData.Rooms, MapData.Facets, MapData.Vertexes
	local bin = io.open("Data/BlockMaps/" .. string.replace(Map.Name, ".odm", ".bin"), "wb")
	local memstr = mem.string
	local Props = BinMapDataProps
	local buff = mem.malloc(120)--mem.StaticAlloc(120)
	local function ClearBuff()
		for i = buff, buff+120, 4 do
			u4[i] = 0
		end
	end

	local function SetSplitter()
		u4[buff] = 0xffffffff
		tinsert(output, memstr(buff, 4, true))
	end

	local function SetElemHeader(Size, Type)
		u4[buff] = Size
		u1[buff+4] = Type
		tinsert(output, memstr(buff, 5, true))
	end

	bin:setvbuf("no")

	-- write header: version, general size, size of subtables
	u4[buff  ] = BinVersion
	u4[buff+4] = MapData.binSize
	u4[buff+8] = MapData.extraSize
	tinsert(output, memstr(buff, 12, true))
	SetSplitter()
	ClearBuff()

	SetElemHeader((#MapVertexes + 1)*Props.packedsizes.V, 0)
	ClearBuff()
	tinsert(output, memstr(buff, Props.packedsizes.V, true)) -- empty vertex to align lua (1-based) and asm (0-based) indexation.
	for i,v in ipairs(MapVertexes) do
		--SetElemHeader(Props.packedsizes.V, 0)
		for field, prop in pairs(Props.fields.V) do
			prop.m[buff + prop.packed] = v[field]
		end
		tinsert(output, memstr(buff, Props.packedsizes.V, true))
	end
	ClearBuff()

	-- Export facets block
	-- empty facet to align lua (1-based) and asm (0-based) indexation.
	SetElemHeader((#MapFacets + 1)*Props.packedsizes.F, 1)
	tinsert(output, memstr(buff, Props.packedsizes.F, true))

	for i,v in ipairs(MapFacets) do
		ClearBuff()
		for field, prop in pairs(Props.fields.F) do
			prop.m[buff + prop.packed] = v[field]
		end

		for id, item in ipairs(v.VertexIds) do
			u2[buff+(id-1)*2] = item
		end
		tinsert(output, memstr(buff, Props.packedsizes.F, true))
	end
	ClearBuff()

	-- Export rooms block
	for i,v in ipairs(MapRooms) do
		SetElemHeader(Props.packedsizes.R, 2)
		for field, prop in pairs(Props.fields.R) do
			prop.m[buff + prop.packed] = v[field]
		end
		tinsert(output, memstr(buff, Props.packedsizes.R, true))

		for t, prop in pairs(Props.tables.R) do
			SetElemHeader(#v[t]*2, prop.convId)
			for id, item in ipairs(v[t]) do
				u2[buff] = item
				tinsert(output, memstr(buff, 2, true))
			end
		end
	end
	mem.free(buff)

	bin:write(table.concat(output, ""))
	bin:close()
end

local function LoadMapDataBin()
	local Path = "Data/BlockMaps/" .. string.replace(Map.Name, ".odm", ".bin")
	local bin = io.open(Path, "r")
	if not bin then
		return 0,0,0
	end

	bin:close()
	bin = io.LoadString(Path)
	local readpos = 0
	local readend = 0
	local readsize = #bin
	local min = math.min
	local memstr = mem.string
	local binptr = mem.topointer(bin)
	local Props = BinMapDataProps
	local buff = binptr

	local function ReadNext(num, doread)
		if readend == readsize then
			return nil
		end
		readpos = readend
		buff = binptr + readpos
		readend = min(readend + num, readsize)
		if doread then
			return memstr(binptr + readpos, num, true)
		end
		return true
	end

	ReadNext(16) -- header
	local FileBinVersion = u4[buff]
	if FileBinVersion ~= BinVersion then
		return 0,0,0
	end

	local GeneralSize	= u4[buff+4]
	local ExtraSize		= u4[buff+8]
	local NewSpaceSize	= GeneralSize + ExtraSize
	local GeneralPtr = mem.malloc(NewSpaceSize)
	u4[SpaceSizePtr] = NewSpaceSize
	if u4[SpacePtr] ~= 0 then
		mem.free(u4[SpacePtr])
	end
	u4[SpacePtr] = GeneralPtr

	local ExtraPtr = GeneralPtr + GeneralSize
	local Pointers = {}
	local DataType = {[0] = "V", [1] = "F", [2] = "R"}
	local pos = GeneralPtr
	local ItemType, CurSize, CurConverter, CurItemPtr, prop

	local subTProps = {
		[3] = Props.tables.F.VertexIds,
		[4] = Props.tables.R.Floors,
		[5] = Props.tables.R.Walls,
		[6] = Props.tables.R.Ceils}

	while ReadNext(5) do
		CurSize, CurConverter = u4[buff], u1[buff+4]
		ItemType = DataType[CurConverter] or "Z"
		Pointers[ItemType] = Pointers[ItemType] or pos

		if CurConverter == 0 then -- straight copy
			mem.copy(pos, ReadNext(CurSize, true))
			pos = pos + CurSize

		elseif CurConverter == 1 then -- facet
			mem.copy(pos, ReadNext(CurSize, true))
			for i = pos, pos+CurSize, Props.sizes.F do
				u4[i+0x30] = i
			end
			pos = pos + CurSize

		elseif CurConverter == 2 then -- rooms
			CurItemPtr = pos
			ReadNext(CurSize)
			for k,v in pairs(Props.fields.R) do
				v.m[pos + v.offset] = v.m[buff + v.packed]
			end
			pos = pos + Props.sizes.R

		elseif CurConverter >= 3 and CurConverter <= 6 then -- subtables
			prop = subTProps[CurConverter]
			u4[CurItemPtr + prop.offset] = ExtraPtr
			prop = ReadNext(CurSize, true)
			if prop then
				mem.copy(ExtraPtr, prop)
				ExtraPtr = ExtraPtr + CurSize
			end

		else
			error("Wrong format of pathfinder data in " .. string.replace(Map.Name, ".odm", ".bin") .. ".")
		end
	end

	return Pointers.V, Pointers.F, Pointers.R

end

Pathfinder.TileAbsoluteId		= TileAbsoluteId
Pathfinder.ConvertOutdoorData	= ConvertOutdoorData
Pathfinder.ExportMapDataBin		= ExportMapDataBin
Pathfinder.LoadMapDataBin		= LoadMapDataBin
-- Pathfinder.ExportMapDataBin(Pathfinder.ConvertOutdoorData())

