
local OldGame = structs.f.GameStructure
function structs.f.GameStructure(define)
   OldGame(define)
   define
	[0x6f3784].array(4).r4 'SpeedModifiers'
	[0x4e87b0].struct(structs.PartyLight) 'PartyLight'

	if not define.members.GlobalTxt then
		define
		[0x601448].array(751).EditPChar 'GlobalTxt'
	end

	if not define.members.TransTxt then
		define
		[0x4fade4].array(500).EditPChar 'TransTxt'
	end

end

local function EditPLight(o, obj, Name, val)
	local Adr = Name == "Radius" and 0x4e87b0 or 0x4e87b4
	if val == nil then
		return mem.r4[Adr]
	else
		mem.IgnoreProtection(true)
		mem.r4[Adr] = val
		mem.IgnoreProtection(false)
	end
end

function structs.f.PartyLight(define)
   define
   .CustomType('Radius', 0, EditPLight)
   .CustomType('Falloff', 0, EditPLight)
end

---- Service functions ----

function FloatToHEX(n)
    if n == 0.0 then return 0.0 end

    local sign = 0
    if n < 0.0 then
        sign = 0x80
        n = -n
    end

    local mant, expo = math.frexp(n)
    local hext = {}

    if mant ~= mant then
        hext[#hext+1] = string.char(0xFF, 0x88, 0x00, 0x00)

    elseif mant == math.huge or expo > 0x80 then
        if sign == 0 then
            hext[#hext+1] = string.char(0x7F, 0x80, 0x00, 0x00)
        else
            hext[#hext+1] = string.char(0xFF, 0x80, 0x00, 0x00)
        end

    elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
        hext[#hext+1] = string.char(sign, 0x00, 0x00, 0x00)

    else
        expo = expo + 0x7E
        mant = (mant * 2.0 - 1.0) * math.ldexp(0.5, 24)
        hext[#hext+1] = string.char(sign + math.floor(expo / 0x2),
                                    (expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
                                    math.floor(mant / 0x100) % 0x100,
                                    mant % 0x100)
    end

    return tonumber(string.gsub(table.concat(hext),"(.)",
                                function (c) return string.format("%02X%s",string.byte(c),"") end), 16)
end


function HEXToFloat(c)

    if c == 0 then return 0.0 end

    local c = string.gsub(string.format("%X", c),"(..)",function (x) return string.char(tonumber(x, 16)) end)
    local b1,b2,b3,b4 = string.byte(c, 1, 4)
    local sign = b1 > 0x7F
    local expo = (b1 % 0x80) * 0x2 + math.floor(b2 / 0x80)
    local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4

    if sign then
        sign = -1
    else
        sign = 1
    end

    local n

    if mant == 0 and expo == 0 then
        n = sign * 0.0
    elseif expo == 0xFF then
        if mant == 0 then
            n = sign * math.huge
        else
            n = 0.0/0.0
        end
    else
        n = sign * math.ldexp(1.0 + mant / 0x800000, expo - 0x7F)
    end

    return n
end
