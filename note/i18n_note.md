## To do

弓箭BTU
chaos bug？

torch、tree的鼠标悬停标签不知怎么没翻译。硬3D高清就不显示标签，软3D低清就会显示出无法汉化的标签。。应该算是原版就有（原版硬3D就不显示标签），GrayFace补丁也一直没修复的问题（硬3D搞了高清模式还是有这个问题）。。
维兰坟墓“What is the Captain's code?”/“船长的密码是什么？”的字样没显示出来。英文版不知道有没有这个问题。“答案是？”显示出来了，输入答案也没有问题
道标的字体
高级议会 “Enter”不知怎么没翻译
时空之门切换大陆，大陆名称没翻译？
通关后的白房子 “Uneasy origin matter”不知怎么没翻译

这2-3条是翡翠岛NPC的对话的几个条目，好像是标题为龙蝇，火焰抗性这几个，若楼主有时间跑趟翡翠岛随便找几个npc对话就能看到，包括对话条目和对话内容都是英文。

盗窃术对应为空手搏斗术，交际术对应为炼金术，这个错误出现在一些对话条目，以及以下神器（我自己已改过）

有几个属性，好像是神器，写着提高灵魂抗性实际上是提高心系抗性，（因为没有灵魂抗性）。

施放备用魔法 检查

* 简中文字翻译
  * 单个魔法描述和其专家大师描述也要检查统一(DOING)
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
  * 方尖塔记录消失问题 *
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

最后是记录文档里的方尖碑信息，当初在8代是正常的，但在67代访问方尖碑后，似乎文档起了冲突，8代少了两条，分别是3#和4#。不过这事似乎英文版也发生过。7代倒是一条没少。我看6代翻译了，但是没找几个，还不清楚有没有问题。
6代正常
7代找完之后去埃弗蒙岛左下的石圈，中间没有白色的花啊，在旁边一顿乱按也不管用
8代更坑爹了，3#、4#方尖碑没有啊，不是在残破镇和铁荒沙漠么？

Noble Plate Armor no dressed status image `evt.GiveItem{1,0,880}`

幽灵沼泽门不对 mm6

阿拉莫斯城堡传送器 mm6

Weather effect can't switch off immediately

tools/context.py
csv2po.py exec()
tools/dbcs_special.py
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