## To do

* 简中文字翻译
  * 单个魔法描述和其专家大师描述也要检查统一(DOING)
  * 魔法门8的“历史”里面有些原版没翻译完的，可以翻译完(DOING)
  * 药剂的描述快速检查一下
  * 神器物品描述中“(加X属性)”、喝泉水等加属性的，都统一成“某属性+阿拉伯数字”的形式（批量找(增加|提高|提升|加)(减少|降低|减低|减|降)。“完美版”MM6就是这么统一的）
  * 杀伤/伤害/攻击力；技术->技能 这些词的用法
* 简中包其他
  * 魔法门7、6的灰脸补丁的简体中文汉化
  * 怪物强化公式再换换？
  * 中文视频可能放进来？(DOING)
  * 指南针改中文的吧
* 他人反馈（与字串相关但并非仅简中）
  * 怎么穿越
  * MM6开头介绍
  * 方尖塔记录消失问题
* 其他
  * 自动化生成6_finalprod(DOING)
  * lod (DOING)
  * 全部的繁体汉化包自动生成
  * 其他语言的语言包自动生成
  * 其他语言的介绍文字
  * 写个作弊界面
  * `% escape？ i.e. #, python-format`

## i18n readiness

Localized string for "You found %lu gold (followers take %lu)!" must always end with "%lu)!"

In the localized string for "You win!  +3 Skill Points" (+3 can be +5 or +7 or +10), "+" must always be preceded by two spaces "  "

ugly name z10 LocZHCN.icons.lod

LocalizeTables.ZHCN_NPCNames.txt   +   Scripts/General/NPCNewsTopics.lua's ProcessNamesTXT()

News topics - area.txt last lines   +   Scripts/General/NPCNewsTopics.lua's ProcessMapNewsTXT()

OTHER: compare rodril and master branch

## Percent sign

* MM8 & MMMerge history:
  * %30: February 4, 1172 (date of the history article)
  * %31: your main character's name
  * %32: his/her (possessive case)
  * %33: he/she (subjective case)
  * %34: him/her (objective case)
* MM7 history:
  * %30: February 4, 1172 (date of the history article)
  * %31, %32, %33, %34: your four characters' name
* MM6 NPCbtb:
  * %01：NPC名字
  * %02：角色名字
  * %03：NPC的第三人称所有格
  * %04：贿赂的金币数量
  * %05：时间（“早晨”等）
  * %06：先生sir/女士lady
  * %07：爵士Sir/夫人Lady
  * %08：Award（完成的任务）之一
  * %09：NPC的第三人称所有格
  * %10：爵士Lord/夫人Lady
  * %11：声誉
  * %12：声誉
  * %13：随机的名字
  * %14：兄弟/姐妹 brother/sister（根据NPC的性别）
  * %15：女儿（哪怕角色是男的，bug！）
  * %16：兄弟/姐妹 brother/sister（根据NPC的性别）

## Other bugs

Noble Plate Armor no dressed status image `evt.GiveItem{1,0,880}`

幽灵沼泽门不对 mm6

阿拉莫斯城堡传送器 mm6

Weather effect can't switch off immediately

tools/add_context.py
csv2po.py exec()
tools/add_dbcs_special.py
tools/test_line_length.py

Useful or not?
DDB1.STR
intro.STR
INTRO.TXT
Lose.STR
LWSPIRAL.STR
NPCDATA.STR
SPIRAL.STR
Win.STR
NWC.STR
NPCGroup.txt
NPCDATA.STR
T1.STR - T8.STR
7Out09.STR - 7Out12.STR, 7Out14.STR
ZDDB02.STR - ZDDB10.STR, ZDTL01.STR, ZDTL02.STR, ZDWJ01.STR, ZDWJ1.STR, ZDWJ2.STR

yes, useful
roster.txt

above overwrites below:

2102	Path of Light
2103	Path of Dark
2104	Are you sure, you want to change your path? Dark spells will be vanished from your spellbook and dark magic will be erased from your mind. (Yes/No)
2105	Are you sure, you want to change your path? Light spells will be vanished from your spellbook and light magic will be erased from your mind. (Yes/No)
2106	It is never late to turn back to light, child. Choose light side.
2107	Darkness wait and it's patience is eternal. Choose dark side.
2108	yes
2109	Either you've already choosen your path, or you are not ready to do it.

2102	The barrel is empty
2103	+1 Might permanent
2104	+1 Accuracy permanent
2105	+1 Personality permanent
2106	+1 Intellect permanent
2107	+1 Endurance permanent
2108	+1 Speed permanent
2109	+1 Luck permanent