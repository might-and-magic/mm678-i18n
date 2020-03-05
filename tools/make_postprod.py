
# copy

# dbcs

# delete all nonprod/ folders

# rename [all lang]/mmmerge/Data/'01LocLANG.EnglishT' to '10 Loc[LANG].EnglishT'

# [DBCS lang]/[mmmerge|mm8|mm7|mm6]/Data/LocalizeConf.ini convert back program_name

# [all lang]/[mmmerge|mm8|mm7|mm6]/Data/LocalizeConf.ini:
# version=2.4.1[merge190922]|2.4.1|2.4|2.4
# lang=zh_CN
# i18n_version=1.3.3
# encoding=gb2312

# [DBCS lang]/[mmmerge|mm8|mm7|mm6]/mm[8|8|7|6]lang.ini + '.'
# RecoveryTimeInfo=. ÂťĂ Â¸Â´ ĂÂą ÂźĂ¤ ÂŁÂş%d
# PlayerNotActive=. ĂĂ ĂÂˇ ĂĂ ÂąÂŁ Â´ĂŚ!
# DoubleSpeed=. ĂÂŤ ÂąÂś ĂĂ ÂśĂ
# NormalSpeed=. ĂĂ˝ ÂłÂŁ ĂĂ ÂśĂ

# [all lang]/[mmmerge|mm8|mm7|mm6]/Data/LocalizeTables.LANG_*.txt
# rename to LocalizeTables.[LANG]*.txt

# non_text/scripts_datatables
# diff copy to [all lang]/mmmerge/

# non_text/font/zh_CN/*.fnt
# copy to zh_CN/[mmmerge|mm8|mm7|mm6]/Data/10 LocZHCN.EnglishT
# see other langs

# non_text/MM8Setup/zh_CN/prod/[mmmerge|mm8]

# non_text/sound/zh_CN -> Data/10 LocZHCN.EnglishD

# non_text/video/zh_CN -> Anims/10 LocZHCN.Magicdod.vid

# non_text/img/zh_CN/prod -> Data/10 LocZHCN.EnglishD  Data/z10 LocZHCN.icons



import re
from pathlib import Path
from getfilepaths import getFilePaths
from add_dbcs_special import addDbcsSpecial
import shutil

def copyDirectory(src, dest):
	try:
		shutil.copytree(src, dest)
	except shutil.Error as e:
		print('Directory not copied. Error: %s' % e)
	except OSError as e:
		print('Directory not copied. Error: %s' % e)

langEncDict = {
	"zh_CN": "gb2312",
	"zh_TW": "big5",
	"kr": "euc_kr",
	"jp": "euc_jp"
}

for p in getFilePaths(Path('4_prod'), '', False):
	if p.name in langEncDict.keys():
		addDbcsSpecial(p, Path('5_postprod/' + p.name), langEncDict[p.name])
	else:
		copyDirectory(p, Path('5_postprod/' + p.name))

