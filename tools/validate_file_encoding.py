# Batch validate file encoding
# Tool of csv2po.py
# By Tom CHEN <tomchen.org@gmail.com> (tomchen.org)

import re
from pathlib import Path
from getfilepaths import getFilePaths

def validateFileEncoding(pathObj, inputEncoding, outputEncoding = None):
	f = pathObj.open(mode = 'r', encoding = inputEncoding, errors = "strict")
	content = f.read()
	f.close()
	if outputEncoding != None:
		pout = pathObj.with_suffix('.temp2del')
		fout = pout.open(mode = 'w', encoding = outputEncoding, newline = '', errors = "strict")
		fout.write(content)
		fout.close()
		pout.unlink()

def batchValidateFilesEncoding(inputEncoding = None, pathObj = Path('.'), extension = 'txt', outputEncoding = None):
	for p in getFilePaths(pathObj, extension = extension):
		print(p)
		validateFileEncoding(p, inputEncoding, outputEncoding)

def checkLfLine(path, lineNumber, line):
	LfFound = re.findall('(?<!\r)\n', line)
	LfFoundNumber = len(LfFound)
	if LfFoundNumber != 0:
		print(str(LfFoundNumber) + ' LF found in line ' + str(lineNumber) + ' of file ' + str(path))

def checkLf(path, encoding = None): # check LF (non CRLF)
	f = path.open(mode = 'r', newline = '\r\n', encoding = encoding)
	for i, line in enumerate(f):
		checkLfLine(path, i+1, line)
	f.close()

def batchCheckLf(encoding = None, pathObj = Path('.'), extension = 'txt'):
	for p in getFilePaths(pathObj, extension = extension):
		checkLf(p, encoding)

# batchValidateFilesEncoding(inputEncoding = 'GB2312', pathObj = Path('0_source/zh_CN'), extension = ['txt', 'str', 'ini'])
batchValidateFilesEncoding(inputEncoding = 'UTF-8', pathObj = Path('template_without_context'), extension = ['txt', 'str', 'ini'])

# batchCheckLf(encoding = 'cp1252', pathObj = Path('0_source/en'), extension = ['txt', 'str'])
# batchCheckLf(encoding = 'gb2312', pathObj = Path('0_source/zh_CN'), extension = ['txt', 'str'])
# batchCheckLf(encoding = 'UTF-8', pathObj = Path('0_source/zh_CN/customlist'), extension = 'list')