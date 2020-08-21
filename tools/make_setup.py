from pathlib import Path
import shutil
import os
from distutils.dir_util import copy_tree
from getfilepaths import getFilePaths


# make_setup Step 1: copyfolders

# zh_CN/mmmerge
shutil.copy(Path('tools/mmarch.exe'), Path('6_setup/dev/zh_CN/mmmerge'))
shutil.copy(Path('6_setup/additional_files/icons/mmmerge.ico'), Path('6_setup/dev/zh_CN/mmmerge'))
os.rename('6_setup/dev/zh_CN/mmmerge/mmmerge.ico', '6_setup/dev/zh_CN/mmmerge/icon.ico')
shutil.copytree(Path('6_setup/additional_files/zh/mmmerge/zh'), Path('6_setup/dev/zh_CN/mmmerge/files'))
copy_tree('5_postprod/zh_CN/mmmerge', '6_setup/dev/zh_CN/mmmerge/files')
os.system('tools\\mmarch df2n "6_setup/dev/zh_CN/mmmerge/files" "6_setup/dev/zh_CN/mmmerge/script.nsi" "files"')
# manually update mm_i18n.nsi if necessary (i.e. if ;--FILE COPYING-- block changes)

# zh_CN/mm8
shutil.copy(Path('tools/mmarch.exe'), Path('6_setup/dev/zh_CN/mm8'))
shutil.copy(Path('6_setup/additional_files/icons/mm8.ico'), Path('6_setup/dev/zh_CN/mm8'))
os.rename('6_setup/dev/zh_CN/mm8/mm8.ico', '6_setup/dev/zh_CN/mm8/icon.ico')
shutil.copytree(Path('6_setup/additional_files/zh/mm8/zh'), Path('6_setup/dev/zh_CN/mm8/files'))
copy_tree('5_postprod/zh_CN/mm8', '6_setup/dev/zh_CN/mm8/files')
os.system('tools\\mmarch df2n "6_setup/dev/zh_CN/mm8/files" "6_setup/dev/zh_CN/mm8/script.nsi" "files"')
# manually update mm_i18n.nsi if necessary (i.e. if ;--FILE COPYING-- block changes)

# zh_CN/mm8_zh_update
shutil.copy(Path('tools/mmarch.exe'), Path('6_setup/dev/zh_CN/mm8_zh_update'))
shutil.copy(Path('6_setup/additional_files/icons/mm8.ico'), Path('6_setup/dev/zh_CN/mm8_zh_update'))
os.rename('6_setup/dev/zh_CN/mm8_zh_update/mm8.ico', '6_setup/dev/zh_CN/mm8_zh_update/icon.ico')
shutil.copytree(Path('6_setup/additional_files/zh/mm8/zh_update'), Path('6_setup/dev/zh_CN/mm8_zh_update/files'))
copy_tree('5_postprod/zh_CN/mm8', '6_setup/dev/zh_CN/mm8_zh_update/files')
os.system('tools\\mmarch df2n "6_setup/dev/zh_CN/mm8_zh_update/files" "6_setup/dev/zh_CN/mm8_zh_update/script.nsi" "files"')
# manually update mm_i18n.nsi if necessary (i.e. if ;--FILE COPYING-- block changes)


# zh_TW/mmmerge
shutil.copy(Path('tools/mmarch.exe'), Path('6_setup/dev/zh_TW/mmmerge'))
shutil.copy(Path('6_setup/additional_files/icons/mmmerge.ico'), Path('6_setup/dev/zh_TW/mmmerge'))
os.rename('6_setup/dev/zh_TW/mmmerge/mmmerge.ico', '6_setup/dev/zh_TW/mmmerge/icon.ico')
shutil.copytree(Path('6_setup/additional_files/zh/mmmerge/zh'), Path('6_setup/dev/zh_TW/mmmerge/files'))
copy_tree('5_postprod/zh_TW/mmmerge', '6_setup/dev/zh_TW/mmmerge/files')
os.system('tools\\mmarch df2n "6_setup/dev/zh_TW/mmmerge/files" "6_setup/dev/zh_TW/mmmerge/script.nsi" "files"')
# manually update mm_i18n.nsi if necessary (i.e. if ;--FILE COPYING-- block changes)

# zh_TW/mm8
shutil.copy(Path('tools/mmarch.exe'), Path('6_setup/dev/zh_TW/mm8'))
shutil.copy(Path('6_setup/additional_files/icons/mm8.ico'), Path('6_setup/dev/zh_TW/mm8'))
os.rename('6_setup/dev/zh_TW/mm8/mm8.ico', '6_setup/dev/zh_TW/mm8/icon.ico')
shutil.copytree(Path('6_setup/additional_files/zh/mm8/zh'), Path('6_setup/dev/zh_TW/mm8/files'))
copy_tree('5_postprod/zh_TW/mm8', '6_setup/dev/zh_TW/mm8/files')
os.system('tools\\mmarch df2n "6_setup/dev/zh_TW/mm8/files" "6_setup/dev/zh_TW/mm8/script.nsi" "files"')
# manually update mm_i18n.nsi if necessary (i.e. if ;--FILE COPYING-- block changes)

# zh_TW/mm8_zh_update
shutil.copy(Path('tools/mmarch.exe'), Path('6_setup/dev/zh_TW/mm8_zh_update'))
shutil.copy(Path('6_setup/additional_files/icons/mm8.ico'), Path('6_setup/dev/zh_TW/mm8_zh_update'))
os.rename('6_setup/dev/zh_TW/mm8_zh_update/mm8.ico', '6_setup/dev/zh_TW/mm8_zh_update/icon.ico')
shutil.copytree(Path('6_setup/additional_files/zh/mm8/zh_update'), Path('6_setup/dev/zh_TW/mm8_zh_update/files'))
copy_tree('5_postprod/zh_TW/mm8', '6_setup/dev/zh_TW/mm8_zh_update/files')
os.system('tools\\mmarch df2n "6_setup/dev/zh_TW/mm8_zh_update/files" "6_setup/dev/zh_TW/mm8_zh_update/script.nsi" "files"')
# manually update mm_i18n.nsi if necessary (i.e. if ;--FILE COPYING-- block changes)



# make_setup Step 2: makensis (use /SOLID lzma for all), in cmd (C:\Users\Chen\githubprojects\might-and-magic\mm678-i18n>), type:

# "C:\Program Files (x86)\NSIS\makensis" /X"SetCompressor /SOLID lzma" "6_setup/dev/zh_CN/mmmerge/mm_i18n.nsi"
# "C:\Program Files (x86)\NSIS\makensis" /X"SetCompressor /SOLID lzma" "6_setup/dev/zh_CN/mm8/mm_i18n.nsi"
# "C:\Program Files (x86)\NSIS\makensis" /X"SetCompressor /SOLID lzma" "6_setup/dev/zh_CN/mm8_zh_update/mm_i18n.nsi"

# "C:\Program Files (x86)\NSIS\makensis" /X"SetCompressor /SOLID lzma" "6_setup/dev/zh_TW/mmmerge/mm_i18n.nsi"
# "C:\Program Files (x86)\NSIS\makensis" /X"SetCompressor /SOLID lzma" "6_setup/dev/zh_TW/mm8/mm_i18n.nsi"
# "C:\Program Files (x86)\NSIS\makensis" /X"SetCompressor /SOLID lzma" "6_setup/dev/zh_TW/mm8_zh_update/mm_i18n.nsi"



# make_setup Step 3: Clean Up and Move Out installation .exe files

# Path('6_setup/prod/').mkdir(exist_ok=True)
# for fLang in getFilePaths(Path('6_setup/dev'), '', False):
# 	for fVer in getFilePaths(fLang, '', False):
# 		fTemp = fVer.joinpath('files')
# 		if fTemp.exists():
# 			shutil.rmtree(str(fTemp))
# 		fTemp = fVer.joinpath('mmarch.exe')
# 		if fTemp.exists():
# 			os.remove(str(fTemp))
# 		fTemp = fVer.joinpath('script.nsi')
# 		if fTemp.exists():
# 			os.remove(str(fTemp))
# 		fTemp = fVer.joinpath('icon.ico')
# 		if fTemp.exists():
# 			os.remove(str(fTemp))

# 		fTempList = getFilePaths(fVer, 'exe', False)
# 		if len(fTempList) > 0:
# 			fTemp = fTempList[0]
# 			shutil.move(str(fTemp), '6_setup/prod/' + fTemp.name)



# make_setup Step 4: exes to 7-zip archives, in cmd, type:

# cd 6_setup\prod
# for /r %f in (*) do "C:\Program Files\7-Zip\7z.exe" a -t7z "%~nf.7z" "%~nf.exe" -m0=lzma2 -mx=9 -aoa && del "%~nf.exe"
