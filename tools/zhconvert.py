# ZhConvert

from pathlib import Path
from getfilepaths import getFilePaths
from opencc import OpenCC

quoteDict = {
'「': '“',
'」': '”',
'『': '‘',
'』': '’'
}

# hk2s: Traditional Chinese (Hong Kong standard) to Simplified Chinese
# s2hk: Simplified Chinese to Traditional Chinese (Hong Kong standard)
# s2t: Simplified Chinese to Traditional Chinese
# s2tw: Simplified Chinese to Traditional Chinese (Taiwan standard)
# s2twp: Simplified Chinese to Traditional Chinese (Taiwan standard, with phrases)
# t2hk: Traditional Chinese to Traditional Chinese (Hong Kong standard)
# t2s: Traditional Chinese to Simplified Chinese
# t2tw: Traditional Chinese to Traditional Chinese (Taiwan standard)
# tw2s: Traditional Chinese (Taiwan standard) to Simplified Chinese
# tw2sp: Traditional Chinese (Taiwan standard) to Simplified Chinese (with phrases)
def convertZhFile(inputPathObj, outputPathObj, method = 'tw2sp', convertQuote = True, inputEncoding = 'utf8', outputEncoding = 'utf8', replaceWords = []):
	f = inputPathObj.open(mode = 'r', newline = '', encoding = inputEncoding)
	content = f.read()
	f.close()

	for replaceWord in replaceWords:
		content = content.replace(replaceWord[0], replaceWord[1])

	cc = OpenCC(method)
	content = cc.convert(content)
	if method in ['hk2s', 't2s', 'tw2s', 'tw2sp']:
		QDict = quoteDict
	elif method in ['s2hk', 's2t', 's2tw', 's2twp']:
		QDict = dict([[v,k] for k,v in quoteDict.items()])
	else:
		QDict = {}
	for q in QDict:
		content = content.replace(q, QDict[q])
	outputPathObj.parent.mkdir(parents = True, exist_ok = True)
	fout = outputPathObj.open(mode = 'w', newline = '', encoding = outputEncoding)
	fout.write(content)
	fout.close()

def batchConvertZhFile(inputPath, outputPath, inputEncoding = 'utf8', outputEncoding = 'utf8', extension = 'txt', method = 'tw2sp', convertQuote = True, replaceWords = []):
	for p in getFilePaths(inputPath, extension = extension):
		pout = outputPath.joinpath(p.relative_to(inputPath))
		convertZhFile(p, pout, method = method, convertQuote = convertQuote, inputEncoding = 'utf8', outputEncoding = 'utf8', replaceWords = replaceWords)


batchConvertZhFile(inputPath = Path('3_i18n/zh_CN/LC_MESSAGES'), outputPath = Path('3_i18n/zh_TW/LC_MESSAGES'), extension = ['po'], method = 's2twp', replaceWords = [['Language: zh_CN', 'Language: zh_TW'], ['自由天堂', '自由港'], ['恩洛斯', '安罗斯'], ['贾丹姆', '贾达密'], ['咔', '咯'], ['～', '-']])
