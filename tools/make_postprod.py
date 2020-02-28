
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

