# Double-byte character set (DBCS) support for Might and Magic 6/7/8 GrayFace Patch
# Use convert_dbcs_special.py to transform DBCS text files to "special" text files first
# Then put FNT_DBCS.lua into \Scripts\General in GrayFace Patched MM6/7/8 with MMExtension (or MMMerge)
# By Tom CHEN <tomchen.org>, MIT/Expat License

# This Python script will convert
# Double-byte characters
# BD A4 BD A5
# to
# [SO] [SP] BD A4 [BEL] [SP] BD A5 [BEL] [SI]

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


# encoding could be set to "gb2312", "big5", "gbk", "euc_jp" and "euc_kr"
def addDbcsSpecial(inputPath, outputPath, encoding):

	encodingRegex = {
		"gb2312": b"[\xA1-\xA9\xB0-\xF7][\xA0-\xFF]",
		"big5": b"[\xA1-\xC7\xC9-\xF9][\x40-\x7F\xA0-\xFF]",
		"gbk": b"[\x81-\xFE][\x40-\xFF]",
		"euc_jp": b"[\xA1-\xA8\xAD\xB0-\xF4][\xA0-\xFF]",
		"euc_kr": b"[\xA1-\xAC\xB0-\xC8\xCA-\xFD][\xA0-\xFF]"
	}
	def rpl(m):
		return b"\x0E\x20\x0E" + m.group(0) + b"\x07\x0F"

	for p in getFilePaths(inputPath, ['txt','str', 'ini']):

		f = p.open(mode = 'rb')
		content = f.read()
		f.close()

		content = re.sub(encodingRegex[encoding] + b"(?!\x07)", rpl, content)
		content = re.sub(b"\x0F\x0E", b"", content)

		pout = outputPath.joinpath(p.relative_to(inputPath))
		pout.parent.mkdir(parents = True, exist_ok = True)
		fout = pout.open(mode = 'wb')
		fout.write(content)
		fout.close()


addDbcsSpecial(Path('4_prod/zh_CN'), Path('5_postprod/zh_CN'), "gb2312")