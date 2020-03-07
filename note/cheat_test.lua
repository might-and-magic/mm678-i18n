-- By 1qwop0 and Tom CHEN

--MeetVerdant1
Party[0].Experience = 75001 evt.SpeakNPC{803}	--evt.SetNPCGreeting{803, 329}
--舒尔曼的信
evt.Add{"QBits", 1104} evt.Add{"QBits", 1105} evt.ForPlayer(0).Add{"Inventory", 2125} evt.SetNPCGreeting{803, 330} evt.SpeakNPC{803}
--ConnectorGem
vars.Quest_CrossContinents.GotConnectorStone = true evt.ForPlayer(0).Add{"Inventory", 624} evt.SetNPCGreeting{803, 331} evt.SpeakNPC{803}

--SavingGoobers1
evt.GiveItem{1,0,663}
evt.SpeakNPC{803}
--SavingGoobers2
evt.GiveItem{1,0,664}
evt.SpeakNPC{803}
--SavingGoobers3
evt.GiveItem{1,0,665}
evt.SpeakNPC{803}
--SavingGoobers4
for i = 177,186 do evt.GiveItem{1,0,i} end
evt.SpeakNPC{803}
--SavingGoobers5
for i = 9, 12 do vars.Quest_SavingGoobers.EnRodMapsVisited[i] = true end
evt.SpeakNPC{803}
--SavingGoobers6
Party[0].MightBase = 500
Party[0].IntellectBase = 500
Party[0].PersonalityBase = 500
Party[0].EnduranceBase = 500
Party[0].AccuracyBase = 500
Party[0].SpeedBase = 500
Party[0].LuckBase = 500
evt.SpeakNPC{803}
--
CastSpellDirect(88, 60, 3)	--普度众生
--SavingGoobers7
vars.Quest_SavingGoobers.PhilStonesLeft = 1
evt.GiveItem{1,0,219}
evt.SpeakNPC{803}
--SavingGoobers8
vars.Quest_SavingGoobers.ItemsForFinalLeft =  {[146] = 1}
evt.GiveItem{1,0,146}
evt.SpeakNPC{803}

--8代通关
Party.QBits[228] = true
vars.Quest_CrossContinents.ContinentFinished[1] = true
evt.SetNPCGreeting{803, 327}
vars.Quest_CrossContinents.GotReward[1] = true
evt.SpeakNPC{803}
--7代通关
Party.QBits[783] = true
vars.Quest_CrossContinents.ContinentFinished[2] = true
evt.SetNPCGreeting{803, 326}
vars.Quest_CrossContinents.GotReward[2] = true
evt.SpeakNPC{803}
--6代通关
Party.QBits[784] = true
vars.Quest_CrossContinents.ContinentFinished[3] = true
evt.SetNPCGreeting{803, 325}
vars.Quest_CrossContinents.GotReward[3] = true
vars.Quest_CrossContinents.ImporvedConnector = true
vars.Quest_CrossContinents.AllStoriesFinished = true
vars.Quest_CrossContinents.ShowInterlude = true
vars.Quest_CrossContinents.FQCatchTime = Game.Time
vars.Quest_CrossContinents.MeetTime = Game.Time
evt.SpeakNPC{803}
--最终任务
evt.MoveToMap{14658, -10598, 320, 0, 0, 0, 0, 8, "out02.odm"}	--休息1小时
--
Party[0].HP = 9999
Party[0].SP = 9999
Party[0].ArmorClassBonus = 9999
CastSpellDirect(1, 60, 3)	--火把
--
CastSpellDirect(12, 60, 3)	--魔力神眼
--
CastSpellDirect(21, 60, 3)	--飞行
--
CastSpellDirect(75, 60, 3)	--抗魔
--
Party.SpellBuffs[const.PartyBuff.Invisibility].ExpireTime = Game.Time + 30000*100	--隐身19/存档

--跳到Breach
evt.MoveToMap{-20475,388,938,500,0,0,0,0, "BrAlvar.odm"}	--队友1
--
evt.MoveToMap{-20983,-14853,4864,90,0,0,0,0, "BrAlvar.odm"}	--队友2?
--
evt.MoveToMap{15897,-17178,2049,2000,0,0,0,0, "BrAlvar.odm"}	--队友3
--
Party.SpellBuffs[const.PartyBuff.Invisibility].ExpireTime = Game.Time + 30000*100
evt.MoveToMap{7564,19904,289,500,0,0,0,0, "BrAlvar.odm"}	--队友4/谜语

-- 埃斯里克
evt.MoveToMap{-217,8990,769,2000,0,0,0,0, "6d14.blv"}

-- 杀
for i,v in Map.Monsters do v.HP=0 end



-- 在MM6、7、8的三个大陆之间传送，需要在特定的传送点施展时空之门魔法，以开启大陆间传送模式。每个大陆都有一些特定的传送点，需要找找。
-- 不想找，或是没有时空之门魔法，想作弊的话，可以按CTRL+F1打开控制台，然后输入某些代码，然后CTRL+回车键执行代码：


-- 1、来到特定的传送点，没有时空之门魔法，那就CTRL+F1开启控制台，输入
CastSpellScroll(31)
-- 然后CTRL+回车键执行，即凭空施展时空之门魔法。改变代码中的数字，就可以施展其他魔法


-- 2、不知道特定的传送点在哪里，在任意的地点，CTRL+F1开启控制台，输入
TownPortalControls.GenDimDoor()
TownPortalControls.SwitchTo(4)
Game.GlobalTxt[10] = " "
ExitCurrentScreen(false, true)
CastSpellDirect(31, 10, 4)
Mouse.Item.Number = 0
Timer(TownPortalControls.RevertTPSwitch, const.Minute, false)
-- 然后CTRL+回车键执行，即开启大陆间传送模式


-- 3、想使用类似简体中文版魔法门6的J键作弊，直接跳到某一地图上的话，那么，CTRL+F1开启控制台，输入
evt.MoveToMap{Name = "7d25.blv"}
-- 然后CTRL+回车键执行，即直接跳到魔法门7的塞莱斯特，其中7d25.blv是塞莱斯特的地图文件名。具体的地区和该地区地图文件名的对应关系，见楼上《整合版地图一览表》。把7d25.blv换成其他地图文件名，就可以跳到其他任何地区。