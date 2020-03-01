
-- Modifying original SplitSkill to work without % division, since value with bonus should be able to go above 0x40.

SplitSkill = function(val)
	local n, mast
	if val >= 0x100 then
		mast = 4
		n = val - 0x100
	elseif val >= 0x80 then
		mast = 3
		n = val - 0x80
	elseif val >= 0x40 then
		mast = 2
		n = val - 0x40
	elseif val >= 1 then
		mast = 1
		n = val
	else
		n = 0
		mast = 0
	end
	return n, mast
end

-- Remove general bonus limit

mem.asmpatch(0x48f065, "jmp absolute 0x48f072")

-- Base functions

local getbonus = mem.asmproc([[
; ecx - base, eax - with bonus
test ch, ch
jnz @gm

cmp ecx, 0x80
jg @mm

cmp ecx, 0x40
jg @em

jmp @end

@gm:
sub eax, 0x100
jmp @end

@mm:
sub eax, 0x80
jmp @end

@em:
sub eax, 0x40

@end:
retn
]])

-- when ecx contain player ptr
getbonus3 = mem.asmproc([[
; eax - value with bonus
; ecx - player ptr
; esi - skill id

; 1. get raw skill

movzx ecx, word [ds:esi*2+ecx+0x378]

; 2. get bonus value

mov esi, eax
sub esi, ecx

; 3. split raw skill

and ecx, 0x3f

; 4. get bonus

add ecx, esi

retn
]])

-- Notifications

mem.asmpatch(0x417295, [[
mov cx, word [ds:ebx*2+esi+0x378]
jmp absolute 0x41729a]])
mem.asmpatch(0x41729a, "call absolute " .. getbonus)

mem.asmpatch(0x41741e, [[
mov cx, word [ds:edi]
call absolute ]] .. getbonus .. [[;
]])

mem.asmpatch(0x417463, [[
mov cx, word [ds:edi]
call absolute ]] .. getbonus .. [[;
]])

-- Alchemy
mem.asmpatch(0x4157b4, [[
push esi
mov esi, 0x25
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
]])

-- Magic
mem.asmpatch(0x42621f, [[
push esi
mov esi, dword [ss:ebp-0x20]
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
]])

-- ID mon
mem.asmpatch(0x41e07a, [[
push esi
mov esi, 0x22
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
]])

-- Weapons
mem.asmpatch(0x4371be, [[
push esi
mov esi, ebx
call absolute ]] .. getbonus3 .. [[;
pop esi

mov ebx, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:]])

mem.asmpatch(0x4371e9, [[
push esi
mov esi, 0x6
call absolute ]] .. getbonus3 .. [[;
pop esi

mov ebx, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:]])

mem.asmpatch(0x437215, [[
push esi
mov esi, 0x0
call absolute ]] .. getbonus3 .. [[;
pop esi

mov ebx, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:]])

-- Mace
mem.nop(0x4377b8, 3)
mem.asmpatch(0x4377af, [[
push esi
mov esi, 0x6
call absolute ]] .. getbonus3 .. [[;
pop esi

mov ebx, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
call absolute 0x455b09
]])

-- Unarmed
mem.nop(0x4380c4, 3)
mem.asmpatch(0x4380a7, [[
push esi
mov esi, 0x21
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
call absolute 0x455b09
]])

-- DragonAbility
mem.asmpatch(0x48cc26, [[
push esi
mov esi, 0x17
call absolute ]] .. getbonus3 .. [[;
pop esi

mov eax, ecx
lea edi, [eax+0xa]
]])

mem.asmpatch(0x48ccc3, [[
push esi
mov esi, 0x17
call absolute ]] .. getbonus3 .. [[;
pop esi

mov eax, ecx
lea edi, [eax+0xa]
]])

-- Armsmaster
mem.asmpatch(0x48d8fa, [[
push esi
mov esi, 0x23
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
]])

--
mem.asmpatch(0x48f1e2, [[
push esi
mov esi, 0x21
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
test edi, edi
je absolute 0x48f50f]])

mem.asmpatch(0x48f1ec, [[
mov ecx, eax
xor esi, esi
call absolute 0x455b09]])
mem.nop(0x48f1b8, 3)

--
mem.asmpatch(0x48f259, [[
push esi
mov esi, edi
call absolute ]] .. getbonus3 .. [[;
pop esi

mov esi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
call absolute 0x455b09]])
mem.nop(0x48f290, 3)
mem.nop(0x48f27f, 2)

-- Unarmed
mem.asmpatch(0x48f2b3, [[
push esi
mov esi, 0x21
call absolute ]] .. getbonus3 .. [[;
pop esi

mov esi, ecx
test esi, esi
je absolute 0x48f50f]])
mem.asmpatch(0x48f2bd, [[
mov ecx, eax]])
mem.nop(0x48f2ce, 3)

mem.asmpatch(0x48f3af, [[
push esi
mov esi, 0x21
call absolute ]] .. getbonus3 .. [[;
pop esi

mov esi, ecx
test esi, esi
je absolute 0x48f3cd]])

mem.asmpatch(0x48f3b5, [[
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
call absolute 0x455b09]])
mem.nop(0x48f3c4, 3)

--
mem.asmpatch(0x48f49b, [[
push esi
mov esi, edx
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
call absolute 0x455b09]])
mem.nop(0x48f4a4, 3)

--
mem.asmpatch(0x48f4e0, [[
push esi
mov esi, 0x20
call absolute ]] .. getbonus3 .. [[;
pop esi

mov esi, ecx
cmp eax, 0x13c
jle @end
mov eax, 0x13c
@end:
mov ecx, eax
call absolute 0x455b09]])
mem.nop(0x48f4f8, 3)

-- Perception
mem.asmpatch(0x4901bf, [[
push esi
mov esi, 0x1b
call absolute ]] .. getbonus3 .. [[;
pop esi

push ecx
mov ecx, eax
call absolute 0x49019c
pop ecx
jmp absolute 0x4901c9]])

-- Meditation
mem.asmpatch(0x4901d4, [[
push esi
mov esi, 0x1c
call absolute ]] .. getbonus3 .. [[;
pop esi

push ecx
mov ecx, eax
call absolute 0x49019c
pop ecx
jmp absolute 0x4901de]])

--
mem.asmpatch(0x4901ff, [[
push esi
mov esi, 0x18
call absolute ]] .. getbonus3 .. [[;
pop esi

push ecx
mov ecx, eax
call absolute 0x49019c
pop ecx
mov edi, eax
mov eax, ecx
jmp absolute 0x49020d]])

--
mem.asmpatch(0x49024c, [[
push esi
mov esi, 0x1a
call absolute ]] .. getbonus3 .. [[;
pop esi

push ecx
mov ecx, eax
call absolute 0x49019c
pop ecx
mov edi, eax
mov eax, ecx
jmp absolute 0x49025a]])
--
mem.asmpatch(0x4902a1, [[
push esi
mov esi, 0x19
call absolute ]] .. getbonus3 .. [[;
pop esi

mov esi, ecx
mov ecx, eax]])

--
mem.asmpatch(0x4902f1, [[
push esi
mov esi, 0x1d
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edi, ecx
mov ecx, eax
call absolute 0x455b09]])
mem.nop(0x490314, 3)
--
mem.asmpatch(0x490330, [[
push esi
mov esi, 0x1f
call absolute ]] .. getbonus3 .. [[;
pop esi

mov esi, ecx
mov edi, ebp
mov ecx, eax]])
mem.nop(0x490336, 3)
--
mem.nop(0x490378, 7)
mem.asmpatch(0x49037f, [[
push esi
mov esi, 0x26
call absolute ]] .. getbonus3 .. [[;
pop esi

mov edx, ecx
test edx, edx
pop esi]])
mem.nop(0x490393, 3)
