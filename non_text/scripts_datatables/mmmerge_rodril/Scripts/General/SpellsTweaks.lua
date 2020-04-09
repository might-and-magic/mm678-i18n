local ceil = math.ceil

local function GetPlayer(ptr)
	local PLId = (ptr - Party.PlayersArray[0]["?ptr"]) / Party.PlayersArray[0]["?size"]
	local PL = Party.PlayersArray[PLId]
	return PL, PlId
end

local function GetMonster(ptr)
	local MonId = (ptr - Map.Monsters[0]["?ptr"]) / Map.Monsters[0]["?size"]
	local Mon = Map.Monsters[MonId]
	return Mon, MonId
end

-- Change chance calculation for "slow" and "mass distortion" spells to be applied.
local function CanApplySpell(Skill, Mastery, Resistance)
	if Resistance == const.MonsterImmune then
		return false
	else
		return (math.random(5, 100) + Skill + Mastery*2.5) > Resistance
	end
end

local function CanApplySlowMassDistort(d)
	local PL = GetPlayer(mem.u4[d.ebp-0x1c])
	local Skill, Mastery = SplitSkill(PL:GetSkill(const.Skills.Earth))

	local Mon = GetMonster(d.eax)
	local Res = Mon.Resistances[const.Damage.Earth]

	if CanApplySpell(Skill, Mastery, Res) then
		d.eax = 1
	else
		d.eax = 0
	end
end

mem.nop(0x426f97, 3)
mem.hook(0x426fa2, CanApplySlowMassDistort)
mem.nop(0x426910, 2)
mem.nop(0x426918, 1)
mem.hook(0x42691e, CanApplySlowMassDistort)

-- Make Stun paralyze target for small duration
mem.autohook2(0x437751, function(d)
	local Player = GetPlayer(d.ebx)
	local Skill, Mas = SplitSkill(Player:GetSkill(const.Skills.Earth))
	local mon = GetMonster(d.ecx)

	local Buff = mon.SpellBuffs[const.MonsterBuff.Paralyze]
	Buff.ExpireTime = math.max(Game.Time + const.Minute + Skill*Mas, Buff.ExpireTime)
end)

-- Change chance of monster being stunned
mem.autohook2(0x437713, function(d)
	local Player = GetPlayer(d.ebx)
	local Mon = GetMonster(d.esi)
	local Skill, Mastery = SplitSkill(Player:GetSkill(const.Skills.Earth))

	if CanApplySpell(Skill, Mastery, Mon.Resistances[const.Damage.Earth]) then
		d.eax = 1
	else
		d.eax = 0
	end
end)

-- Change chance calculation for Control Undead
mem.nop(0x42c3aa, 6)
mem.nop(0x42c413, 6)
mem.nop(0x42c41c, 2)
mem.nop(0x42c424, 1)
mem.hook(0x42c42a, function(d)
	local mon = GetMonster(d.eax)

	if mon.DarkResistance == const.MonsterImmune or Game.IsMonsterOfKind(mon.Id, const.MonsterKind.Undead) == 0 then
		d.eax = 0
		return
	end

	local Player = GetPlayer(mem.u4[d.ebp-0x1c])
	local Skill, Mas = SplitSkill(Player:GetSkill(const.Skills.Dark))

	if mon.DarkResistance > Skill*Mas then
		d.eax = 0
		return
	end

	if Mas > 3 then
		mon.Group = 0
		mon.Ally = 9999 -- Same as reanimated monster's ally.
	end
	mon.Hostile = false
	mon.ShowAsHostile = false
	d.eax = 1
end)

-- Make monsters' power cure heal nearby monsters

local function GetDist(t,x,y,z)
	local px, py, pz  = XYZ(t)
	return math.sqrt((px-x)^2 + (py-y)^2 + (pz-z)^2)
end

function events.MonsterCastSpell(t)
	if t.Spell == 77 then
		local Skill, Mas = SplitSkill(t.Monster.Spell == t.Spell and t.Monster.SpellSkill or t.Monster.Spell2Skill)
		local Heal = 10 + 5 *Skill
		local x,y,z = XYZ(t.Monster)
		local Mon = t.Monster
		local count = 0
		for i,v in Map.Monsters do
			if (v.Group == Mon.Group or v.Ally == Mon.Ally or Game.HostileTxt[ceil(v.Id/3)][ceil(Mon.Id/3)] == 0) and GetDist(v,x,y,z) < 2000 then
				v.HP = math.min(v.HP + Heal, v.FullHP)
				Game.ShowMonsterBuffAnim(i)
				count = count + 1
				if count >= 5 then
					break
				end
			end
		end
	end
end

function events.MonsterCanCastSpell(t)
	if t.Spell == 77 then
		local x,y,z = XYZ(t.Monster)
		local Mon = t.Monster
		for i,v in Map.Monsters do
			if (v.Group == Mon.Group or v.Ally == Mon.Ally or Game.HostileTxt[ceil(v.Id/3)][ceil(Mon.Id/3)] == 0) and GetDist(v,x,y,z) < 2000 and v.HP < v.FullHP then
				t.Result = 1
				break
			end
		end
	end
end

-- Monsters can cast neither flying fist or paralyze, replace these spells:
local SpellReplace = {[76] = 70, [81] = 87}
function events.MonsterCastSpell(t)
	t.Spell = SpellReplace[t.Spell] or t.Spell
end
