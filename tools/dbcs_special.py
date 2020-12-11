# Double-byte character set (DBCS) support for Might and Magic 6/7/8 GrayFace Patch
# Use dbcs_special.py to transform DBCS text files to "special" text files first
# Then put FNT_DBCS.lua into \Scripts\General in GrayFace Patched MM6/7/8 with MMExtension (or MMMerge)
# By Tom CHEN (tomchen.org), MIT/Expat License

# This Python script will convert
# Double-byte characters
# BD A4 BD A5
# to
# [SO] [SP] BD A4 [BEL] [SP] BD A5 [BEL] [SI]

import re
from pathlib import Path
from getfilepaths import getFilePaths


# encoding could be set to "gb2312", "big5", "gbk", "euc_jp" and "euc_kr"

# inputStr is bytes
def encodeDbcsSpecial(inputStr, encoding):

	encodingRegex = {
		"gb2312": b"[\xA1-\xA9\xB0-\xF7][\xA0-\xFF]",
		"big5": b"[\xA1-\xC7\xC9-\xF9][\x40-\x7F\xA0-\xFF]",
		"gbk": b"[\x81-\xFE][\x40-\xFF]",
		"euc_jp": b"[\xA1-\xA8\xAD\xB0-\xF4][\xA0-\xFF]",
		"euc_kr": b"[\xA1-\xAC\xB0-\xC8\xCA-\xFD][\xA0-\xFF]"
	}
	def rpl(m):
		return b"\x0E\x20\x0E" + m.group(0) + b"\x07\x0F"

	inputStr = re.sub(encodingRegex[encoding] + b"(?!\x07)", rpl, inputStr)
	inputStr = re.sub(b"\x0F\x0E", b"", inputStr)

	return inputStr


# inputStr is locally encoded string
def decodeDbcsSpecial(inputStr):
	
	def rpl(m):
		return m.group(1)

	inputStr = re.sub(b"\x20\x0E(..)\x07", rpl, inputStr)
	inputStr = re.sub(b"\x0E([^\x0F]+)\x0F", rpl, inputStr)

	return inputStr


# encode a file or files in the path using DBCS Special encoding
def encodeDbcsSpecialFile(inputPath, outputPath, encoding):

	inputPathTemp = Path(inputPath)
	outputPathTemp = Path(outputPath)

	for p in getFilePaths(inputPathTemp, ['txt','str', 'ini']):

		f = p.open(mode = 'rb')
		content = f.read()
		f.close()

		pout = outputPathTemp.joinpath(p.relative_to(inputPathTemp))
		pout.parent.mkdir(parents = True, exist_ok = True)
		fout = pout.open(mode = 'wb')
		fout.write(encodeDbcsSpecial(content, encoding))
		fout.close()


# decode a file or files in the path using DBCS Special encoding
def decodeDbcsSpecialFile(inputPath, outputPath):

	inputPathTemp = Path(inputPath)
	outputPathTemp = Path(outputPath)

	for p in getFilePaths(inputPathTemp, ['txt','str', 'ini']):

		f = p.open(mode = 'rb')
		content = f.read()
		f.close()

		pout = outputPathTemp.joinpath(p.relative_to(inputPathTemp))
		pout.parent.mkdir(parents = True, exist_ok = True)
		fout = pout.open(mode = 'wb')
		fout.write(decodeDbcsSpecial(content))
		fout.close()


# encodeDbcsSpecialFile('4_prod/zh_CN', '5_postprod/zh_CN', "gb2312")

# decodeDbcsSpecialFile('5_postprod/zh_CN', 'temp_folder')
