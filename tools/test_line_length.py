# Test Line Length
# Tool of csv2po.py
# By Tom CHEN <tomchen.org@gmail.com> (tomchen.org)

from pathlib import Path
from getfilepaths import getFilePaths

def testStrLineLengthInByte(inputPath, extension, maxLength, newline = '\n', encoding = 'UTF-8', encodingErrors = "strict"):
	for p in getFilePaths(inputPath, extension):
		f = p.open(mode = 'r', encoding = encoding, newline = newline, errors = encodingErrors)
		for n, line in enumerate(f):
			lineLen = len(line.encode(encoding))
			if lineLen > maxLength:
				print('Length of line ' + str(n+1) + ' in file ' + str(p) + ' is ' + str(lineLen) + ' and more than ' + str(maxLength))

testStrLineLengthInByte(Path('5_postprod'), 'str', 784, newline = '\r\n', encoding = 'gb2312')