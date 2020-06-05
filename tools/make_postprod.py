from versions import versions, langEncDict, dbcsLangs, dbcsEncs
import re
from pathlib import Path
from getfilepaths import getFilePaths
from dbcs_special import encodeDbcsSpecialFile, decodeDbcsSpecial
import shutil
import configparser
import os
from distutils.dir_util import copy_tree



def copyFonts(d, pTemp, mmVersion, pNameCondensed):
	if mmVersion == '6':
		targetLod = 'icons'
	elif mmVersion == '7':
		targetLod = 'events'
	else: # 8 or merge
		targetLod = 'EnglishT'
	for fnt in getFilePaths(Path('non_text/font/' + d), 'fnt', False):
		shutil.copy(fnt, pTemp.joinpath('Data/10 Loc' + pNameCondensed + '.' + targetLod))


if Path('5_postprod').exists():
	shutil.rmtree('5_postprod')

for p in getFilePaths(Path('4_prod'), '', True):
	if p.name == 'nonprod' and p.exists():
		shutil.rmtree(p)

for p in getFilePaths(Path('4_prod'), '', False):
	if p.name in dbcsLangs:
		encodeDbcsSpecialFile(p, Path('5_postprod').joinpath(p.name), langEncDict[p.name])
	else:
		shutil.copytree(p, Path('5_postprod').joinpath(p.name))

# os.system('tools\\mmarch k non_text\scripts_datatables\mmmerge_rodril non_text\scripts_datatables\mmmerge filesonly non_text\scripts_datatables\difftemp')
# scriptDiffPath = Path('non_text/scripts_datatables/difftemp')

for p in getFilePaths(Path('5_postprod'), '', False):
	pTemp = p.joinpath('mm6/data/10LocLANG.icons')
	pNameCondensed = p.name.upper().replace('_', '') # e.g. ZHCN
	if pTemp.exists():
		pTemp.rename(pTemp.parent.joinpath('10 Loc' + pNameCondensed + '.icons'))

	pTemp = p.joinpath('mm7/DATA/10LocLANG.events')
	if pTemp.exists():
		pTemp.rename(pTemp.parent.joinpath('10 Loc' + pNameCondensed + '.events'))

	pTemp = p.joinpath('mm8/Data/10LocLANG.EnglishT')
	if pTemp.exists():
		pTemp.rename(pTemp.parent.joinpath('10 Loc' + pNameCondensed + '.EnglishT'))

	pTemp = p.joinpath('mmmerge/Data/10LocLANG.EnglishT')
	if pTemp.exists():
		pTemp.rename(pTemp.parent.joinpath('10 Loc' + pNameCondensed + '.EnglishT'))

	for pTemp in getFilePaths(p.joinpath('mmmerge/Data/Text localization'), 'txt', True):
		if pTemp.name[:4] == 'LANG':
			pTemp.rename(pTemp.parent.joinpath(pNameCondensed + pTemp.name[4:]))

	for versionNum in ['6', '7', '8', 'merge']:
		pTemp = p.joinpath('mm' + versionNum + '/Data/LocalizeConf.ini')
		config = configparser.ConfigParser()
		config.read(pTemp, encoding = langEncDict[p.name])
		if p.name in dbcsLangs:
			config['Settings']['program_name'] = decodeDbcsSpecial(config['Settings']['program_name'])

		config['Settings']['game_version']     = versionNum                          # 6/7/8/merge

		if versionNum == 'merge':
			config['Settings']['grayface_version'] = versions['grayface']['8']           # GrayFace Patch's version
			config['Settings']['merge_version']    = versions['merge']                   # 0 (not mmmerge)/YYYY-MM-DD
		else:
			config['Settings']['grayface_version'] = versions['grayface'][versionNum]
			config['Settings']['merge_version']    = '0'

		config['Settings']['lang']             = p.name
		config['Settings']['i18n_version']     = versions['i18n'][p.name]
		config['Settings']['encoding']         = langEncDict[p.name]

		with open(pTemp, mode = 'w', encoding = langEncDict[p.name]) as configfile:
			config.write(configfile, False)

	if p.name in dbcsLangs:
		for versionNum in ['6', '7', '8', 'merge']:
			versionNum2 = versionNum
			if versionNum2 == 'merge':
				versionNum2 = '8'
			pTemp = p.joinpath('mm' + versionNum + '/mm' + versionNum2 + 'lang.ini')
			config = configparser.RawConfigParser()
			config.optionxform = str
			config.read(pTemp, encoding = langEncDict[p.name])

			for opt in ['RecoveryTimeInfo', 'PlayerNotActive', 'DoubleSpeed', 'NormalSpeed', 'GameSavedText', 'ArmorHalved']:
				if config.has_option('Settings', opt):
					config['Settings'][opt] = '.' + config['Settings'][opt]

			with open(pTemp, mode = 'w', encoding = langEncDict[p.name]) as configfile:
				config.write(configfile, False)

	for versionNum in ['6', '7', '8', 'merge']:
		pTemp = p.joinpath('mm' + versionNum)
		pNameCondensed = p.name.upper().replace('_', '') # e.g. ZHCN
		encoding = langEncDict[p.name]

		# if scriptDiffPath.joinpath('Data').exists():
		# 	shutil.copytree(scriptDiffPath.joinpath('Data'), pTemp.joinpath('Data'))
		# if scriptDiffPath.joinpath('Scripts').exists():
		# 	shutil.copytree(scriptDiffPath.joinpath('Scripts'), pTemp.joinpath('Scripts'))
		# if p.name not in dbcsLangs:
		# 	os.remove(pTemp.joinpath('Scripts/General/FNT_DBCS.lua'))

		copyFonts(encoding, pTemp, versionNum, pNameCondensed)
		if encoding in dbcsEncs:
			copyFonts('cp1252', pTemp, versionNum, pNameCondensed)
		if encoding == 'cp1252' or encoding in dbcsEncs:
			if versionNum == '6' or versionNum == '7':
				versionNumFont = '67'
			else: # versionNum == '8' or versionNum == 'merge'
				versionNumFont = '8'
			copyFonts('cp1252/' + versionNumFont, pTemp, versionNum, pNameCondensed)

# shutil.rmtree(scriptDiffPath)
print('Main process is done.')


for pntLang in getFilePaths(Path('non_text/scripts_datatables/'), '', False):
	pntLangName = pntLang.name
	# pntLangNameCondensed = pntLangName.upper().replace('_', '') # e.g. ZHCN
	for pntVer in getFilePaths(pntLang, '', False):
		pTemp = Path('5_postprod').joinpath(pntLangName).joinpath(pntVer.name)
		copy_tree(str(pntVer), str(pTemp))
print('Script, datatable process is done.')


for pntLang in getFilePaths(Path('non_text/img/prod/'), '', False):
	pntLangName = pntLang.name
	pntLangNameCondensed = pntLangName.upper().replace('_', '') # e.g. ZHCN
	for pntVer in getFilePaths(pntLang, '', False):
		# next(pntVer.iterdir()) is the first child dir of pntVer, it is assumed the only child dir pntVer is /Data/ folder since images store only in /Data/
		dataFolder = next(pntVer.iterdir())
		for dirTemp in getFilePaths(dataFolder, '', False):
			folderNameTemp = '10 Loc' + pntLangNameCondensed + '.' + dirTemp.name
			if dirTemp.name == 'icons' and pntVer.name == 'mmmerge':
				folderNameTemp = 'z' + folderNameTemp
			pTemp = Path('5_postprod').joinpath(pntLangName).joinpath(pntVer.name).joinpath(dataFolder.name).joinpath(folderNameTemp)
			copy_tree(str(dirTemp), str(pTemp))
print('Image process is done.')


for pntLang in getFilePaths(Path('non_text/MM8Setup/prod/'), '', False):
	for pntVer in getFilePaths(pntLang, '', False):
		shutil.copy(pntVer.joinpath('MM8Setup.Exe'), Path('5_postprod').joinpath(pntLang.name).joinpath(pntVer.name))
print('MM8Setup process is done.')


for pntLang in getFilePaths(Path('non_text/sound/prod/'), '', False):
	pntLangName = pntLang.name
	pntLangNameCondensed = pntLangName.upper().replace('_', '') # e.g. ZHCN
	for pntVer in getFilePaths(pntLang, '', False):
		soundParentFolder = next(pntVer.iterdir())
		soundFolder = next(soundParentFolder.iterdir())

		folderNameTemp = soundFolder.name
		folderNameTemp = '10 Loc' + pntLangNameCondensed + '.' + soundFolder.name
		pTemp = Path('5_postprod').joinpath(pntLangName).joinpath(pntVer.name).joinpath(soundParentFolder.name).joinpath(folderNameTemp)
		copy_tree(str(soundFolder), str(pTemp))

		if pntLangName == 'zh_CN':
			folderNameTempZHTW = soundFolder.name
			folderNameTempZHTW = '10 LocZHTW.' + soundFolder.name
			pTempZHTW = Path('5_postprod').joinpath('zh_TW').joinpath(pntVer.name).joinpath(soundParentFolder.name).joinpath(folderNameTempZHTW)
			copy_tree(str(soundFolder), str(pTempZHTW))

print('Sound process is done.')


for pntLang in getFilePaths(Path('5_postprod'), '', False):
	for pntVer in getFilePaths(pntLang, '', False):
		dataFolder = pntVer.joinpath('Data')
		soundFolder = pntVer.joinpath('Sounds')
		fInFolder = []
		if dataFolder.exists():
			fInFolder = fInFolder + getFilePaths(dataFolder, '', False)
		if soundFolder.exists():
			fInFolder = fInFolder + getFilePaths(soundFolder, '', False)
		for fInDataFolder in fInFolder:
			if fInDataFolder.name[0:6] == '10 Loc' or fInDataFolder.name[0:7] == 'z10 Loc':
				stemTemp = fInDataFolder.name.split('.')[-1].lower()
				if stemTemp == 'audio':
					archiveType = 'mmsnd'
					archiveExt = 'snd'
				elif stemTemp == 'icons' or stemTemp == 'events':
					archiveType = 'mmiconslod'
					archiveExt = 'lod'
				elif stemTemp == 'englishd' or stemTemp == 'englisht':
					archiveType = 'mm8loclod'
					archiveExt = 'lod'
				os.system('tools\\mmarch c "' + fInDataFolder.name + '.' + archiveExt + '" ' + archiveType + ' "' + str(fInDataFolder.parent) + '" "' + str(fInDataFolder) + '\\*"')
				os.system('tools\\mmarch o "' + str(fInDataFolder.parent.joinpath(fInDataFolder.name + '.' + archiveExt)) + '"')
				shutil.rmtree(str(fInDataFolder))
				print(str(fInDataFolder.parent.joinpath(fInDataFolder.name + '.' + archiveExt)) + ' is made.')



# TODO: non_text/video/zh_CN -> Anims/10 LocZHCN.Magicdod.vid
