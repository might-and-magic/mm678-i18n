# ZhConvert

from pathlib import Path
from opencc import OpenCC
cc = OpenCC('tw2sp')

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
def convertZhFile(inputPathObj, outputPathObj, method = 'tw2sp', convertQuote = True):
	f = inputPathObj.open(mode = 'r', newline = '', encoding = None)
	content = f.read()
	f.close()
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
	fout = outputPathObj.open(mode = 'w', newline = '')
	fout.write(content)
	fout.close()

def batchConvertZhFile(inputPath, outputPath, extension = 'txt', method = 'tw2sp', convertQuote = True):
	for p in getFilePaths(inputPath, extension = extension):
		pout = outputPath.joinpath(p.relative_to(inputPath))
		convertZhFile(p, pout, method = method, convertQuote = convertQuote)

batchConvertZhFile(Path('input'), Path('output'), extension = ['txt'])
