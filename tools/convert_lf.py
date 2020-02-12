# Batch convert LF to '\n' and vice versa
# Tool of csv2po.py
# By Tom CHEN <tomchen.org@gmail.com> (tomchen.org)

import re
from pathlib import Path

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

def convertLf(inputPath, outputPath, encoding = None, SlashNTolf = True): # check LF (non CRLF)
	f = inputPath.open(mode = 'r', newline = '\r\n', encoding = encoding)
	content = f.read()
	f.close()
	if SlashNTolf:
		content = re.sub(r'\\n', '\n', content)
	else:
		content = re.sub('(?<!\r)\n', r'\\n', content)
	outputPath.parent.mkdir(parents = True, exist_ok = True)
	fo = outputPath.open(mode = 'w', newline = '', encoding = encoding)
	fo.write(content)
	fo.close()

def batchConvertLf(inputPath, outputPath, SlashNTolf = True, extension = 'txt', encoding = 'UTF-8'):
	for p in getFilePaths(inputPath, extension = extension):
		convertLf(p, outputPath.joinpath(p.relative_to(inputPath)), encoding, SlashNTolf)

# batchConvertLf(inputPath = Path('0_source/zh_CN/customlist/t'), outputPath = Path('0_source/zh_CN/customlist/t2'), SlashNTolf = False, extension = 'list', encoding = 'UTF-8')
batchConvertLf(inputPath = Path('0_source/zh_CN/customlist/t2'), outputPath = Path('0_source/zh_CN/customlist/t3'), SlashNTolf = True, extension = 'list', encoding = 'UTF-8')
