
-- Remove arcomage from Emerald Island's taverns

function events.DrawShopTopics(t)
	if t.HouseType == const.HouseType.Tavern then
		t.Handled = true
		t.NewTopics[1] = const.ShopTopics.RentRoom
		t.NewTopics[2] = const.ShopTopics.BuyFood
		t.NewTopics[3] = const.ShopTopics.Learn
	end
end
