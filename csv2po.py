# CSV2PO Python (csv2po.py) v1.0.0
# By Tom CHEN <tomchen.org@gmail.com> (tomchen.org)
# MIT License
# Python 3.8+

import re
import glob
import os
import time
import random
import importlib.util
import gettext
import polib
from pathlib import Path

from pluralforms import pluralforms
import settings

__version__ = '1.0.0'

import sys
sys.setrecursionlimit(10000)

# ========== Settings init START ==========

def setDefaults(defaultsDict):
	for key in defaultsDict:
		if not hasattr(settings, key) or getattr(settings, key) == '':
			setattr(settings, key, defaultsDict[key])

setDefaults({
	'project_name'              : 'My Project',
	'author_name'               : 'John Doe',
	'author_email'              : 'johndoe@example.com',
	'team_name'                 : 'My Team',

	'source_folder'             : '0_source',
	'template_folder'           : '1_template',
	'dev_folder'                : '2_dev',
	'i18n_folder'               : '3_i18n',
	'prod_folder'               : '4_prod',

	'file_extensions'           : ['txt'],

	'template_repl'             : '_(TRANS)_',
	'template_repl_with_context': '_(TRANS_CONTEXT:<context>)_',
	'template_encoding'         : 'UTF-8',

	'first_language'            : 'en',
	'source_encoding'           : {},
	'encoding_errors_handling'  : 'ignore',

	'conflict_priority'         : {},

	'i18n_language_exclusion'   : [],
	'prod_language_exclusion'   : [],

	'separator'                 : '\t',
	'eol'                       : '\n',
	'lf_in_crlf_mode'           : False,

	'trim_whitespace'           : False,
	'trim_doublequote'          : True,
	'trim_singlequote'          : False,
	'convert_two_quotes_to_one' : True,

	'no_log'                    : True,
	'no_warning'                : False
})


# lang lists (global variables)
sourceLangs = list(map(lambda x: x.name, list(Path(settings.source_folder).glob('*'))))

cleanedI18nLangExcl = settings.i18n_language_exclusion
cleanedI18nLangExcl = [x for x in cleanedI18nLangExcl if x != settings.first_language] # cleanedI18nLangExcl can't have first language
setattr(settings, 'i18n_language_exclusion', cleanedI18nLangExcl)

langs = [x for x in sourceLangs if x not in cleanedI18nLangExcl] # i18n langs
nonFirstLangs = [x for x in langs if x != settings.first_language]

prodLangs = [x for x in langs if x not in settings.prod_language_exclusion] # prod langs


# defaults for settings.source_encoding[lang] and settings.conflict_priority[lang]
for lang in langs:
	if lang not in settings.source_encoding or settings.source_encoding[lang] == '':
		settings.source_encoding[lang] = 'UTF-8' # set default

for lang in nonFirstLangs:
	if lang not in settings.conflict_priority or settings.conflict_priority[lang] == '':
		settings.conflict_priority[lang] = [['MOSTFREQUENT']] # set default


# lf_in_crlf_mode is effective only when eol = '\r\n'
if settings.lf_in_crlf_mode and settings.eol != '\r\n':
	setattr(settings, 'lf_in_crlf_mode', False)


# ========== Settings init END ==========


# ========== Utility functions START ==========

def log(s, error = 'w'):
	if error == 'w':
		printHead = 'Warning: '
	elif error == 'e':
		printHead = 'Error: '
	elif error == 'n':
		printHead = 'Note: '
	if settings.no_log == False:
		f = Path('logfile.txt').open(mode = 'a+', newline = '\n', encoding = 'UTF-8')
		f.write(printHead + s + '\n')
		f.close()
	if error == 'e':
		raise ValueError(printHead + s)
	elif settings.no_warning == False:
		print(printHead + s)


def getFilePaths(pathObj, extension = 'txt', recursive = True):
	if recursive:
		pathPre = '**/'
	else:
		pathPre = ''
	if type(extension) is list:
		retList = []
		for thisExt in extension:
			retList += getFilePaths(pathObj, extension = thisExt, recursive = recursive)
		return retList
	else:
		return list(pathObj.glob(pathPre + '*.' + extension))

# ========== Utility functions END ==========


# ========== Functions START ==========

def encodingFix(s, encoding, decode = True):
	if encoding.lower() == 'gb2312':
		if decode: # read
			return s.replace(u'\u30FB', u'\u00B7').replace(u'\u2015', u'\u2014')
		else:
			return s.replace(u'\u00B7', u'\u30FB').replace(u'\u2014', u'\u2015').replace(u'\u2013', u'\u2015')
	return s

# use all files in /<template>/ to generate globalLineDict[filePath]
def template2GlobalLineDict():
	globalLineDict = {}
	for filePathComplete in getFilePaths(Path(settings.template_folder), settings.file_extensions):
		f = filePathComplete.open(mode = 'r', newline = settings.eol, encoding = settings.template_encoding, errors = settings.encoding_errors_handling)
		filePath = filePathComplete.relative_to(settings.template_folder)
		globalLineDict[filePath] = []
		for line in f:
			line = encodingFix(line, settings.template_encoding)
			lineMatches = re.findall('(' + re.escape(settings.template_repl) + ')|' + re.escape(settings.template_repl_with_context).replace('<context>', '(.*?)'), line)
			lineSplitList = re.compile(re.escape(settings.template_repl) + '|' + re.escape(settings.template_repl_with_context).replace('<context>', '.*?')).split(line)
			transCount = len(lineMatches)
			msgctxtDict = {}
			for i, tu in enumerate(lineMatches):
				if tu[0] == '':
					msgctxtDict[i] = tu[1]
			regex = ''
			lslLen = len(lineSplitList)
			if lslLen > 1:
				for i in range(lslLen - 1):
					regex += re.escape(lineSplitList[i])
					if settings.eol != '\r\n':
						regex += '([^' + settings.separator + '^' + settings.eol + ']*)'
					else:
						regex += '((?:[^' + settings.separator + '^\r]|\r(?!\n))*)'
				lslLastMatchObj = re.match('(.*?)(?:\t|\r\n)', lineSplitList[lslLen - 1])
				if lslLastMatchObj != None:
					regex += re.escape(lslLastMatchObj.group(1))
			globalLineDict[filePath].append({
				'transCount': transCount,
				'regex': regex,
				'lineSplitList': lineSplitList.copy(),
				'msgctxtDict': msgctxtDict.copy(),
			})
	return globalLineDict


# convert LF ('\n') (non CRLF ('\r\n')) in a string to `Slash N` ('\\n')
def lf2SlashN(s):
	return re.sub('(?<!\r)\n', r'\\n', s)

# convert `Slash N` ('\\n') back to LF ('\n') [don't care about CRLF]
def slashN2Lf(s):
	return re.sub(r'\\n', '\n', s)

def escapeTab(s):
	return re.sub('\t', r'\\t', s)

def sanitizeDoubleQuote(s):
	return s.replace('"', r'\"')

def cleanString(s):
	if settings.trim_whitespace:
		s = s.strip()
	if settings.trim_doublequote:
		s = re.sub('^"|"$', '', s)
		if settings.convert_two_quotes_to_one:
			s = s.replace('""', '"')
	if settings.trim_singlequote:
		s = re.sub('^\'|\'$', '', s)
		if settings.convert_two_quotes_to_one:
			s = s.replace('\'\'', '\'')
	if settings.lf_in_crlf_mode:
		s = lf2SlashN(s)
	s = sanitizeDoubleQuote(s)
	return s

def cleanStringList(l):
	return list(map(lambda s: cleanString(s), l))


# use globalLineDict[filePath] to match all files in /<source>/<first_language>/ to get msgidList in globalLineDict[filePath]
def source1stLang2MsgidList(globalLineDict):
	for filePath in globalLineDict:
		p0 = Path(settings.source_folder).joinpath(settings.first_language).joinpath(filePath)
		if p0.is_file():
			f0 = p0.open(mode = 'r', newline = settings.eol, encoding = settings.source_encoding[settings.first_language], errors = settings.encoding_errors_handling)
			for i, line in enumerate(f0):
				line = encodingFix(line, settings.source_encoding[settings.first_language])
				lineDict = globalLineDict[filePath][i]
				matchObj = re.match(lineDict['regex'], line)
				if matchObj:
					msgidList = matchObj.groups()
					msgidList = cleanStringList(msgidList)
					lineDict['msgidList'] = msgidList
					for msgid in lineDict['msgidList']:
						if msgid == '':
							log('At least one of msgids in line ' + str(i + 1) + ' in first-language file ' + str(p0) + ' is an empty string. It may cause problem in later process.')
				else:
					log('Line ' + str(i + 1) + ' in first-language file ' + str(p0) + ' doesn\'t correspond to its template. First language file must be well present and correspond to the template file.', 'e')
			f0.close()
		else:
			log('Can\'t find first-language file ' + str(p0) + '. First language file must be well present and correspond to the template file.', 'e')

# use globalLineDict[filePath] to generate all files in /<dev>/
def source1stLang2Dev(globalLineDict):
	for filePath in globalLineDict:
		p = Path(settings.dev_folder).joinpath(filePath)
		p = p.with_suffix(p.suffix + '.py')
		p.parent.mkdir(parents = True, exist_ok = True)
		fDev = p.open(mode = 'w', newline = '\n', encoding = 'UTF-8')
		fDev.write('def t(_, _x): return (')
		for lineDict in globalLineDict[filePath]:
			lem1 = len(lineDict['lineSplitList']) - 1
			splitListStr = ''
			for j in range(lem1): # lem1 could be 0 in which case the following `for` block is skipped
				if j in lineDict['msgctxtDict']:
					splitListStr += repr(lineDict['lineSplitList'][j]) + ' + _x("' + lineDict['msgctxtDict'][j] + '", "' + (lineDict['msgidList'][j]) + '") + '
				else:
					splitListStr += repr(lineDict['lineSplitList'][j]) + ' + _("' + (lineDict['msgidList'][j]) + '") + '
			splitListStr += repr(lineDict['lineSplitList'][lem1]) + '\n'
			fDev.write(splitListStr)
		fDev.write(')')
		fDev.close()


# use globalLineDict[filePath] to match all files in /<source>/<first_language>/ to generate potDict without msgstr
def globalLineDict2PotDict(globalLineDict):
	potDict = {}
	for filePath in globalLineDict:
		for lineIndex, lineDict in enumerate(globalLineDict[filePath]):
			if 'msgidList' in lineDict:
				for i, msgid in enumerate(lineDict['msgidList']):
					if i in lineDict['msgctxtDict']:
						msgctxt = lineDict['msgctxtDict'][i]
					else:
						msgctxt = None
					msgTuple = (msgid, msgctxt)
					if msgTuple in potDict:
						loc = potDict[(msgid, msgctxt)]['locations']
						pathLineTuple = (filePath.with_suffix(filePath.suffix + '.py'), lineIndex + 1)
						if pathLineTuple not in loc:
							loc.append(pathLineTuple)
					else:
						potDict[(msgid, msgctxt)] = {
							'locations': [
								(filePath.with_suffix(filePath.suffix + '.py'), lineIndex + 1)
							]
						}
	return potDict


# get a language's plural form. Plural form is like 'nplurals=2; plural=(n != 1);', 'nplurals=1; plural=0;', etc.
# uses pluralforms.py. If not in the dict, returns None
def getPluralForm(lang):
	if lang in pluralforms:
		return pluralforms['en']
	else:
		return pluralforms.get(lang.split('_')[0], None)


# use potDict to generate first language's .pot or non-first language's .po file
# .pot, .po files are ALWAYS encoded in UTF-8 with LF as EOL
def generatePoFile(potDict, isPot = True, lang = settings.first_language):
	p = Path(settings.i18n_folder)
	if not isPot:
		p = p.joinpath(lang).joinpath('LC_MESSAGES')
	p = p.joinpath(settings.textdomain + ('.pot' if isPot else '.po'))
	p.parent.mkdir(parents = True, exist_ok = True)
	f = p.open(mode = 'w', newline = '\n', encoding = 'UTF-8')

	pluralform = getPluralForm(lang)
	currentTime = time.strftime("%Y-%m-%d %H:%M%z", time.localtime())

	lineStr = '''#, fuzzy
''' if isPot else ''

	lineStr += '''msgid ""
msgstr ""
"Project-Id-Version: ''' + settings.project_name + '''\\n"
"POT-Creation-Date: ''' + currentTime + '''\\n"
"PO-Revision-Date: ''' + currentTime + '''\\n"
"Last-Translator: ''' + settings.author_name + ''' <''' + settings.author_email + '''>\\n"
"Language-Team: ''' + settings.team_name + '''\\n"
"Language: ''' + lang + '''\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"X-Generator: CSV2PO Python Script ''' + __version__ + '''\\n"
"X-Poedit-Basepath: ''' + Path(os.path.relpath(settings.dev_folder, p.parent)).as_posix() + '''\\n"
''' + ('"Plural-Forms: ' + pluralform + '''\\n"
''' if pluralform != None else '') + '''"X-Poedit-SourceCharset: UTF-8\\n"
"X-Poedit-KeywordsList: pgettext:1c,2;_x:1c,2\\n"
"X-Poedit-SearchPath-0: .\\n"

'''
	for msgTuple in potDict:
		msgInfo = potDict[msgTuple]
		locMap = map(lambda tu: tu[0].as_posix() + ':' + str(tu[1]), msgInfo['locations'])
		lineStr += '#: ' + ' '.join(locMap) + '\n'
		if msgTuple[1] != None:
			lineStr += 'msgctxt "' + msgTuple[1] + '"\n'
		lineStr += 'msgid "' + msgTuple[0] + '"\n'
		# print(msgInfo)
		if not isPot and 'msgstr' in msgInfo and lang in msgInfo['msgstr']:
			msgstr = msgInfo['msgstr'][lang]
		else:
			msgstr = ''
		lineStr += 'msgstr "' + msgstr + '"\n'
		lineStr += '\n'
	f.write(lineStr)
	f.close()


# remove duplicates and set MOSTFREQUENT in a wordList
def removeDuplicatesAndSetMostfrequent(wordList):
	for lang in wordList:
		li = wordList[lang]
		for msgTuple in li:
			wordDicts = li[msgTuple]
			m = max([wordDicts[key]['count'] for key in wordDicts])
			for word in wordDicts:
				wordDict = wordDicts[word]
				if wordDict['count'] == m:
					wordDict['categories'].append('MOSTFREQUENT')
				wordDict['categories'] = list(set(wordDict['categories']))


def addCustomList(wordList):

	if settings.eol != '\r\n':
		singleRegex = '([^' + settings.separator + '^' + settings.eol + ']*)'
	else:
		singleRegex = '((?:[^' + settings.separator + '^\r]|\r(?!\n))*)'
	regex = singleRegex + '\t' + singleRegex + '\t' + singleRegex

	if hasattr(settings, 'custom_list'):
		for lang in settings.custom_list:
			wLLang = wordList[lang]
			lCurrentLang = settings.custom_list[lang]
			for lName in lCurrentLang:
				lNList = lCurrentLang[lName]
				lNListEnc = 'UTF-8'
				if 'encoding' in lNList:
					lNListEnc = lNList['encoding']
				if type(lNList) == dict:
					f = Path(lNList['file']).open(mode = 'r', newline = settings.eol, encoding = lNListEnc, errors = settings.encoding_errors_handling)
					lNList = []
					for line in f:
						line = encodingFix(line, lNListEnc)
						matches = re.match(regex, line).groups()
						if matches:
							if matches[0] == '':
								lNList.append([cleanString(matches[1]), cleanString(matches[2])])
							else:
								lNList.append([(cleanString(matches[1]), cleanString(matches[0])), cleanString(matches[2])])
				for item in lNList:
					if type(item[0]) is tuple:
						msgid = item[0][0]
						msgctxt = item[0][1]
						msgstr = item[1]
					else: # item[0] is str
						msgid = item[0]
						msgctxt = None
						msgstr = item[1]
					if (msgid, msgctxt) not in wLLang:
						wLLang[(msgid, msgctxt)] = {}
					wordListItemCurrent = wLLang[(msgid, msgctxt)]
					if msgstr not in wordListItemCurrent:
						wordListItemCurrent[msgstr] = {'categories': ['CUSTOMLIST:' + lName], 'count': 1}
					else:
						wordListItemCurrent[msgstr]['categories'].append('CUSTOMLIST:' + lName)
						wordListItemCurrent[msgstr]['count'] += 1


# use globalLineDict[filePath] to match all files in /<source>/<nonFirstLangs>/ to get wordList
def getWordList(globalLineDict, nonFirstLangs):

	wordList = {}

	for currentLang in nonFirstLangs:

		wordList[currentLang] = {}
		wordListCurrent = wordList[currentLang]

		for filePath in globalLineDict:
			currentCatList = list(filePath.parts)
			l = len(currentCatList)
			for n in range(l):
				if n == (l - 1):
					itemType = 'FILE'
				else:
					itemType = 'FOLDER'
				currentCatList[n] = itemType + ':' + currentCatList[n]
				currentCatList.append('L' + str(n+1) + currentCatList[n])

			glen = len(globalLineDict[filePath])
			p0 = Path(settings.source_folder).joinpath(currentLang).joinpath(filePath)
			if p0.is_file():
				f0 = p0.open(mode = 'r', newline = settings.eol, encoding = settings.source_encoding[currentLang], errors = settings.encoding_errors_handling)

				for i, line in enumerate(f0):
					line = encodingFix(line, settings.source_encoding[currentLang])
					if i < glen:
						lineDict = globalLineDict[filePath][i]
						matchObj = re.match(lineDict['regex'], line)
						if matchObj:
							msgstrList = matchObj.groups()
							msgstrList = cleanStringList(msgstrList)
							if 'msgidList' in lineDict:
								for j, msgid in enumerate(lineDict['msgidList']):
									if j in lineDict['msgctxtDict']:
										msgctxt = lineDict['msgctxtDict'][j]
									else:
										msgctxt = None
									msgTuple = (msgid, msgctxt)
									msgstr = msgstrList[j]
									if msgTuple not in wordListCurrent:
										wordListCurrent[msgTuple] = {}
									wordListItemCurrent = wordListCurrent[msgTuple]
									if msgstr in wordListItemCurrent:
										wordListItemCurrent[msgstr]['categories'] += currentCatList
										wordListItemCurrent[msgstr]['count'] += 1
									else:
										wordListItemCurrent[msgstr] = {'categories': currentCatList.copy(), 'count': 1}
						else:
							log('Line ' + str(i + 1) + ' in non first-language file ' + str(p0) + ' is skipped because source and template seem to be different.')
					else:
						log('Line ' + str(i + 1) + ' in non first-language file ' + str(p0) + ' is skipped because it doesn\'t exist in the template.')
				f0.close()
			else:
				log('Can\'t find non first-language file ' + str(p0) + '.')

	removeDuplicatesAndSetMostfrequent(wordList)
	addCustomList(wordList)

	return wordList


def filterDict(dictObj, callback):
	filteredDict = {}
	for (key, value) in dictObj.items():
		if callback((key, value)):
			filteredDict[key] = value
	return filteredDict


# conflict priority list explanation:
# Use the first rule in the highest level priority sublist (sublist is a non-nested list like ['FOLDER:a', 'L1FOLDER:b', 'L1FOLDER:c']) to check a group of words
# if only one word meets the rule, then returns this one
# if no word meets the rule, then use next rule in the same level priority sublist to check the current group of words
# if no word meets the rule and this is the last rule in the current priority sublist, then use lower level priority sublist to check the current group of words
# if more than one words meet the rule, then use lower level priority sublist to check the new group of words meeting the current rule
# if more than one words meet the rule and this is the lowest level priority sublist, then use next rule in the same level priority sublist to check the new group of words meeting the current rule
# if no word or more than one words meet the rule and this is the last rule in the lowest level priority sublist, then returns a random one in the current/new group of words

# find a single msgstr using priority list and wordDicts
def findMsgstr(priorityList, wordDicts):
	filteredWordDicts = wordDicts.copy()
	l = len(priorityList)
	for i, prioritySublist in enumerate(priorityList):
		for priority in prioritySublist:
			filteredWordDictsTemp = filterDict(filteredWordDicts, lambda wordTuple : priority in wordTuple[1]['categories'])
			lf = len(filteredWordDictsTemp)
			if lf == 1:
				return next(iter(filteredWordDictsTemp.keys()))
			elif lf == 0:
				continue
			else: # lf > 1
				filteredWordDicts = filteredWordDictsTemp.copy()
				if i == l - 1:
					continue
				else:
					break
	return random.choice(list(filteredWordDicts.keys()))


# use wordList to WRITE ALL msgstr in potDict
def writeMsgstrInPotDict(wordList, potDict, nonFirstLangs):
	for currentLang in nonFirstLangs:
		wordListCurrent = wordList[currentLang]
		for msgTuple in potDict:
			if msgTuple in wordListCurrent:
				if 'msgstr' not in potDict[msgTuple]:
					potDict[msgTuple]['msgstr'] = {}
				potDict[msgTuple]['msgstr'][currentLang] = findMsgstr(settings.conflict_priority[currentLang], wordListCurrent[msgTuple])
			else:
				log('Can\'t find ' + currentLang + ' language translation of the word "' + msgTuple[0] + '"' + (' (context: ' + msgTuple[1] + ')' if msgTuple[1] != None else '') + '.')


# use wordList to WRITE ALL msgstr in potDict
def generateAllPoFiles(potDict):
	generatePoFile(potDict)
	for currentLang in nonFirstLangs:
		generatePoFile(potDict, False, currentLang)

# compile all .po to .mo files
def po2Mo():
	for currentLang in nonFirstLangs:
		p = Path(settings.i18n_folder).joinpath(currentLang).joinpath('LC_MESSAGES').joinpath(settings.textdomain + '.po')
		polib.pofile(p).save_as_mofile(p.with_suffix('.mo'))

# get dev text functions from all dev modules
def getDevTextDict():
	devTextDict = {}
	for p in getFilePaths(Path(settings.dev_folder), 'py'):
		filePath = p.relative_to(settings.dev_folder).with_suffix('')
		spec = importlib.util.spec_from_file_location(p.name, p)
		module = importlib.util.module_from_spec(spec)
		spec.loader.exec_module(module)
		devTextDict[filePath] = module.t
	return devTextDict

# generate prod files for a single language
def generateProdForLang(lang, devTextDict):
	localedir = Path.cwd().joinpath(settings.i18n_folder)
	trans = gettext.translation(settings.textdomain, localedir, languages = [lang], fallback = True)

	def _(message):
		ret = trans.gettext(message)
		if settings.lf_in_crlf_mode:
			ret = slashN2Lf(ret)
		ret = escapeTab(ret)
		return ret

	def _x(context, message):
		ret = trans.pgettext(context, message)
		if settings.lf_in_crlf_mode:
			ret = slashN2Lf(ret)
		ret = escapeTab(ret)
		return ret

	for path in devTextDict:
		devText = devTextDict[path]
		p = Path(settings.prod_folder).joinpath(lang).joinpath(path)
		p.parent.mkdir(parents = True, exist_ok = True)
		f = p.open(mode = 'w', newline = '', encoding = settings.source_encoding[lang], errors = settings.encoding_errors_handling)
		f.write(encodingFix(devText(_, _x), settings.source_encoding[lang], False))
		f.close()

# generate prod files for all languages
def generateProdForAllLang(langs, devTextDict):
	for lang in langs:
		generateProdForLang(lang, devTextDict)

# generate prod files from .mo files
def mo2Prod(langs):
	devTextDict = getDevTextDict()
	generateProdForAllLang(langs, devTextDict)


# ========== Functions END ==========



# ========== Procedural START ==========

def generateDevOnly():
	globalLineDict = template2GlobalLineDict()
	source1stLang2MsgidList(globalLineDict)
	source1stLang2Dev(globalLineDict)


def generateDevAndI18n():
	globalLineDict = template2GlobalLineDict()
	source1stLang2MsgidList(globalLineDict)
	source1stLang2Dev(globalLineDict)
	potDict = globalLineDict2PotDict(globalLineDict)
	wordList = getWordList(globalLineDict, nonFirstLangs)
	writeMsgstrInPotDict(wordList, potDict, nonFirstLangs)
	# print(globalLineDict)
	# print(wordList)
	# print(potDict)
	generateAllPoFiles(potDict)
	po2Mo()


def generateProd():
	mo2Prod(prodLangs)


def exec():
	generateDevAndI18n()
	generateProd()
	log('End.', 'n')


# ========== Procedural END ==========



if __name__ == "__main__":
	exec()
	# generateDevAndI18n()
	# generateProd()
	# generateDevOnly()


# custom_list = {
# 	'zh_CN': {
# 		'my_translation_zh_1': [
# 			['first language name', 'this language name'],
# 			['first language name', 'this language name']
# 		] # can also be a string indicating the path to a tab-separated file
# 	}
# }

# potDict = {
# 	('msgid', 'msgctxt'): { # 'msgctxt' could be None or ''
# 		'locations': [
# 			(Path1, 21), # Path line tuple
# 			(Path2, 34)
# 		],
# 		'msgstr': {
# 			'zh_CN': '??',
# 			'fr': '??'
# 		}
# 	},
# 	...
# }

# wordList = {
# 	'zh_CN': {
# 		('aabb', context): {
# 			'????': {
# 				'categories': [],
# 				'count': 3
# 			}
# 		},
# 		...
# 	},
# 	...
# }

# globalLineDict = {
# 	'filePath': [
# 		{ # each line
# 			'transCount': 2,
# 			'regex': r'',
# 			'lineSplitList': ['23'],
# 			'msgctxtDict': {0: 'abbr for category'},
# 			'msgidList': ['cat', 'dog']
# 		},
# 		...
# 	]
# }