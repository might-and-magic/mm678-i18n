
-- Script simply replaces text fields of tables with ones from "LocalizeTables.txt".
-- Sacrificing a bit of perfomance for a lot of conviniency of work with localizations.

function RelocalizeTables()

	for FilePath in path.find("Data/*LocalizeTables.*txt") do

		local TxtTable = io.open(FilePath, "r")

		if TxtTable then

			local Words
			local LineIt = TxtTable:lines()
			LineIt() -- skip header

			if string.find(FilePath, "ItemsTxt") then
				-- special behaivor for ItemsTxt
				local Items = Game.ItemsTxt
				for line in LineIt do
					Words = string.split(line, "\9")
					local Num = tonumber(Words[1])
					if Num then
						local Item = Items[Num]
						Item.Name 				= Words[2]
						Item.NotIdentifiedName	= Words[3]
						Item.Notes				= Words[4]
					end
				end
			elseif string.find(FilePath, "2DEvents") then
				-- special behaivor for 2DEvents
				local Houses = Game.Houses
				for line in LineIt do
					Words = string.split(line, "\9")
					local Num = tonumber(Words[1])
					if Num then
						local House = Houses[Num]
						House.Name = Words[2]
						House.OwnerName	= Words[3]
						House.OwnerTitle = Words[4]
						House.EnterText = Words[5]
					end
				end
			else
				local len = string.len
				for line in LineIt do
					Words = string.split(line, "\9")
					if Words[1] then
						local cTable	= Words[1]
						local cId		= tonumber(Words[2])
						local cField	= Words[3]
						local cText		= tonumber(Words[4]) or Words[4]

						if len(cTable) > 0 and cId then
							if len(cField) > 0 then
								Game[cTable][cId][cField] = cText
							else
								Game[cTable][cId]  = cText
							end
						end
					end
				end
			end

			io.close(TxtTable)
		end
	end

end

function events.GameInitialized2()
	RelocalizeTables()
end
