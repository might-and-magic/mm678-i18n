
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

