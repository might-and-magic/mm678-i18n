local u1, u2, u4, mstr, mcopy, mptr = mem.u1, mem.u2, mem.u4, mem.string, mem.copy, mem.topointer
local NewCode

local function GetPlayer(p)
	local i = (p - Party.PlayersArray["?ptr"]) / Party.PlayersArray[0]["?size"]
	return Party.PlayersArray[i], i
end

local function GetMonster(p)
	if p < Map.Monsters["?ptr"] then
		return
	end
	local i = (p - Map.Monsters["?ptr"]) / Map.Monsters[0]["?size"]
	return Map.Monsters[i], i
end

---------------------------------------
-- Set outdoor light event

mem.autohook2(0x4886e5, function(d)
	local t = {Minute = Game.Minute, Hour = d.eax}
	events.call("SetOutdoorLight", t)
	d.eax = t.Hour
end)

mem.autohook2(0x4886f4, function(d)
	local t = {Minute = d.ecx, Hour = Game.Hour}
	events.call("SetOutdoorLight", t)
	d.ecx = t.Minute
end)

mem.autohook2(0x488731, function(d)
	local t = {Minute = d.ecx, Hour = Game.Hour}
	events.call("SetOutdoorLight", t)
	d.ecx = t.Minute
end)

mem.autohook2(0x488be7, function(d)
	local t = {Minute = Game.Minute, Hour = d.eax}
	events.call("SetOutdoorLight", t)
	d.eax = t.Hour
end)

mem.autohook2(0x488CAE, function(d)
	local t = {Minute = d.eax, Hour = Game.Hour}
	events.call("SetOutdoorLight", t)
	d.eax = t.Minute
end)

mem.autohook2(0x488C0E, function(d)
	local t = {Minute = d.edi, Hour = Game.Hour}
	events.call("SetOutdoorLight", t)
	d.edi = t.Minute
end)

---------------------------------------
-- Sounds for extra tilesets
-- allows to change sounds of step or execute event based on tile coordinates;
-- only outdoors.

local TileSoundData = {}
mem.autohook2(0x473cf0, function(d) TileSoundData = {Y = d.eax, X = mem.u4[d.esp], Run = mem.u4[d.esp+4]} end)
mem.autohook2(0x473cf8, function(d)
	TileSoundData.Sound = d.eax
	events.call("TileSound", TileSoundData)
	d.eax = TileSoundData.Sound
end)

---------------------------------------
-- Step sounds
-- allows to change sound of step
-- indoors and outdoors.

mem.autohook(0x4724f4, function(d)
	if d.edx >= 0 then
		local t = {Sound = u4[d.esp], Run = u4[d.ebp - 0x34] == 0 and 1 or 0, Facet = Map.Facets[d.edx]}
		events.call("StepSound", t)
		u4[d.esp] = t.Sound
	end
end)
mem.autohook(0x473d02, function(d)
	if d.ecx > 0xffff then
		local t = {Sound = u4[d.esp], Run = u4[d.esp] == 0x40 and 1 or 0, Facet = structs.ModelFacet:new(d.ecx + d.eax)}
		events.call("StepSound", t)
		u4[d.esp] = t.Sound
	end
end)


---------------------------------------
-- Got item

mem.autohook2(0x421244, function(d)
	events.call("GotItem", Mouse.Item.Number)
end)
mem.autohook2(0x491a4b, function(d)
	events.call("GotItem", Mouse.Item.Number)
end)


---------------------------------------
-- Regen tick event
-- Standart regen ticks, - unlike timers, continues to tick during party rest.

mem.autohook2(0x491f58, function(d)
	events.cocall("RegenTick", GetPlayer(d.eax))
end)


---------------------------------------
-- Party rest events

local function CalcRestFoodCost()
	local t = {Amount = mem.u1[0x518570]}
	events.call("CalcRestFoodCost", t)
	mem.u1[0x518570] = t.Amount
end

mem.autohook2(0x41ebff, CalcRestFoodCost)
mem.autohook2(0x41ec24, CalcRestFoodCost)
mem.autohook2(0x41ec2b, CalcRestFoodCost)
mem.autohook2(0x41ec36, CalcRestFoodCost)

---------------------------------------
-- Calc jump height event

mem.autohook2(0x473164, function(d)
	local t = {Height = d.eax}
	events.call("CalcJumpHeight", t)
	d.eax = t.Height
end)

function events.CalcJumpHeight(t)
	t.Height = math.min(t.Height, 420)
end

---------------------------------------
-- Can cast town portal
NewCode = mem.asmproc([[
nop
nop
nop
nop
nop
jnz absolute 0x42735b
idiv ecx
cmp edx, dword [ss:ebp-4]
jmp absolute 0x4296a3]])
mem.asmpatch(0x42969e, "jmp absolute " .. NewCode)

mem.hook(NewCode, function(d)
	local t = {CanCast = true, Handled = false, Mastery = mem.u4[d.ebp-0xC]}
	events.call("CanCastTownPortal", t)
	d.ZF = t.CanCast
	if t.Handled then
		d.ecx = 1
	end
end)

---------------------------------------
-- Open chest
-- Supposed to be used to tweak list of items.

NewCode = mem.asmpatch(0x4451c1, [[
nop
nop
nop
nop
nop
call absolute 0x41f8b8]])

mem.hook(NewCode, function(d)
	events.call("OpenChest", d.ecx)
end)

---------------------------------------
-- Get gold
-- Triggers when party finds gold (monster's corpses or gold items)

mem.autohook2(0x42013a, function(d)
	local t = {Amount = d.esi}
	events.call("BeforeGotGold", t)
	d.esi = t.Amount
end)

---------------------------------------
-- Click shop topic
-- Triggers when player clicks topic in shop
-- (list of topics provided by RemoveHouseRulesLimits.lua in const.ShopTopics)

mem.autohook2(0x4baa76, function(d)
	local t = {Handled = false, Topic = d.ecx}
	events.call("ClickShopTopic", t)

	d.ecx = t.Topic -- topic id change is allowed, but most probably will lead to game crash.

	if t.Handled then
		d.ZF = true
	end
end)

---------------------------------------
-- Calculate fame
-- Allows to change calculation base or overhaul counting.
--

NewCode = mem.asmpatch(0x4903a2, [[
call absolute 0x4026f4
nop; mem hook here
nop
nop
nop
nop

je @over

push 0
push 0xfa
push ecx
push eax
call absolute 0x4dac60

@over:
jmp absolute 0x4903bf]])

mem.hook(NewCode + 5, function(d)
	local t = {Handled = false, Result = 0, Base = Party[0].Experience}
	events.call("GetFameBase", t)

	if t.Handled then
		d.eax = t.Result
	else
		d.ecx = mem.u4[d.eax + 0xa4]
		d.eax = t.Base
	end
	d.ZF = t.Handled
end)

---------------------------------------
-- Get loading screen pic
-- Allows to change loading screen picture.
--
local strlen = string.len
mem.autohook2(0x44031d, function(d)
	local ptr = u4[d.esp]
	local t = {Pic = mstr(ptr)}
	events.call("GetLoadingPic", t)

	mcopy(ptr, t.Pic)
	u1[ptr + strlen(t.Pic)] = 0
end)

---------------------------------------
-- Can show "Heal" topic
--
local function CanShowHealTopic(d)
	local t = {CanShow = d.eax}
	events.call("CanShowHealTopic", t)
	d.eax = t.CanShow
end

mem.autohook2(0x4b5c3b, CanShowHealTopic)
mem.autohook2(0x4b5cd7, CanShowHealTopic)
mem.autohook2(0x4bacdd, CanShowHealTopic)

---------------------------------------
-- Get travel days cost
--
function events.GameInitialized2()

	NewCode = mem.asmpatch(0x4b5626, [[
	nop; mem hook
	nop
	nop
	nop
	nop
	cmp eax, 1
	jge absolute 0x4b562e]])

	mem.hook(NewCode, function(d)
		local t = {Days = d.eax, House = mem.u4[0x518678]}
		events.call("GetTravelDaysCost", t)

		d.eax = t.Days
	end)

	mem.autohook(0x4b51b8, function(d)
		local t = {Days = d.ecx, House = mem.u4[0x518678]}
		events.call("GetTravelDaysCost", t)

		d.ecx = t.Days
	end)

end

---------------------------------------
-- Can repair item
--
NewCode = mem.asmpatch(0x41cfdd, [[
mov ecx, dword [ss:esp-4];
nop; mem hook
nop
nop
nop
nop
cmp eax, 1
mov eax, dword [ss:ebp-4];]])

mem.hook(NewCode + 4, function(d)
	local t = {CanRepair = d.eax == 1, Player = Party[math.max(0, Game.CurrentPlayer)], Item = structs.Item:new(d.ecx)}
	events.call("CanRepairItem", t)

	d.ecx = 0
	d.eax = t.CanRepair and 1 or 0
end)

---------------------------------------
-- Artifact generated
--
local function ArtifactGenerated(d)
	local t = {ItemId = d.eax}
	events.call("ArtifactGenerated", t)

	d.eax = t.ItemId
end

mem.autohook2(0x44dd8d, ArtifactGenerated)
mem.autohook2(0x4541bf, ArtifactGenerated)

---------------------------------------
-- Arrow projectile
--
mem.autohook(0x42636c, function(d)
	local t = {ObjId = u4[d.ebp-0xac], PlayerIndex = u2[0x51d822]}
	events.call("ArrowProjectile", t)

	u4[d.ebp-0xac] = t.ObjId
end)

---------------------------------------
-- Dragon breath projectile
--
mem.autohook(0x4264ef, function(d)
	local t = {ObjId = u4[d.ebp-0xac], PlayerIndex = u2[0x51d822]}
	events.call("DragonBreathProjectile", t)

	u4[d.ebp-0xac] = t.ObjId
end)

---------------------------------------
-- Get spell skill
-- Supposed to modify skill level for default attacks of players (for example, dragon breath)
--
function events.GetSkill(t)
	if u2[0x51d820] > 0 then
		t.Spell = u2[0x51d820]
		events.call("GetSpellSkill", t)
	end
end

---------------------------------------
-- BeforeLeaveGame
-- called before LeaveGame event, at the moment, when player click "Quit" button second time.
-- Supposed to be used, when player leaving game, but map data still necessary.
mem.autohook2(0x433b0d, function() events.call("BeforeLeaveGame") end)

---------------------------------------
-- MonsterCastSpell
--
--
function events.GameInitialized2()

	local TargetBuf = mem.StaticAlloc(Map.Monsters.limit*4)

	mem.asmpatch(0x404638, [[
	mov eax, dword [ss:esp+8]
	cmp eax, dword [ds:0x40123F]
	jl @end

	push edx
	push ecx

	mov ecx, 0x3cc
	sub eax, dword [ds:0x40123F]
	cdq
	idiv ecx

	pop ecx
	pop edx

	mov word [ds:]] .. TargetBuf+2 .. [[+eax*4], 0;
	mov word [ds:]] .. TargetBuf   .. [[+eax*4], 4; -- target is party (const.ObjectRefKind)

	@end:
	mov eax, dword [ss:ebp+0xc]
	cmp eax, edi]])

	mem.asmpatch(0x404650, [[
	mov eax, dword [ss:esp+8]
	cmp eax, dword [ds:0x40123F]
	jl @end

	push edx
	push ecx

	mov ecx, 0x3cc
	sub eax, dword [ds:0x40123F]
	cdq
	idiv ecx

	pop ecx
	pop edx

	mov word [ds:]] .. TargetBuf+2 .. [[+eax*4], si;
	mov word [ds:]] .. TargetBuf   .. [[+eax*4], 3; -- target is monster (const.ObjectRefKind)

	@end:
	imul esi, esi, 0x3cc]])

	-- attack target selection

--~ 	mem.asmpatch(0x403f02, [[
--~ 	mov eax, dword [ss:esp+0x4]
--~ 	mov word [ds:]] .. TargetBuf+2 .. [[+eax*4], 0;
--~ 	mov word [ds:]] .. TargetBuf   .. [[+eax*4], 4; -- target is party (const.ObjectRefKind)
--~ 	mov eax, dword [ds:0xb2155c];]])

--~ 	mem.asmpatch(0x403f25, [[
--~ 	mov ecx, dword [ss:esp+0x4]
--~ 	mov word [ds:]] .. TargetBuf+2 .. [[+ecx*4], ax;
--~ 	mov word [ds:]] .. TargetBuf   .. [[+ecx*4], 3; -- target is monster (const.ObjectRefKind)
--~ 	imul eax, eax, 0x3cc;]])

	function GetMonsterTarget(i)
		return u2[TargetBuf+i*4], u2[TargetBuf+i*4+2]
	end

	local function MonsterCanCastSpellHook(d)
		local Mon, MonId = GetMonster(d.esi)
		if Mon then
			local TargetRef, TargetId = GetMonsterTarget(MonId)
			local t = {Spell = u4[d.ebp-0x8], Monster = Mon, Target = 0, Distance = u4[d.ebp-0xC], Result = d.eax, TargetRef = TargetRef}
			if TargetRef == 4 then
				t.Target = Party
			elseif TargetRef == 3 then
				t.Target = Map.Monsters[TargetId]
			end
			events.call("MonsterCanCastSpell", t)
			d.eax = t.Result
		end
	end

	NewCode = mem.asmhook(0x42543c, [[
	cmp dword [ss:ebp-0x8], 0
	je @end
	nop
	nop
	nop
	nop
	nop
	@end:]])
	mem.hook(NewCode+6, MonsterCanCastSpellHook)

	NewCode = mem.asmhook(0x42544f, [[
	cmp dword [ss:ebp-0x8], 0
	je @end
	nop
	nop
	nop
	nop
	nop
	@end:]])
	mem.hook(NewCode+6, MonsterCanCastSpellHook)

	mem.autohook(0x404d9f, function(d)
		local Mon, MonId = GetMonster(d.esi)
		if Mon then
			local TargetRef, TargetId = GetMonsterTarget(MonId)
			local t = {Spell = d.ecx, Monster = Mon, Target = 0, TargetRef = TargetRef, Handled = false}

			if TargetRef == 4 then
				t.Target = Party
			elseif TargetRef == 3 then
				t.Target = Map.Monsters[TargetId]
			end

			events.call("MonsterCastSpell", t)
			if t.Handled then
				d.ecx = 0xffff
			else
				d.ecx = t.Spell
			end
		end
	end)

end

