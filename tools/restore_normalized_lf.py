# Restore normalized LF

from pathlib import Path
import re

f = Path('NPCText.txt').open(mode = 'r', newline = '\r\n', encoding = 'cp1252')
lines = f.readlines()
lineNumber = 1
for n, l in enumerate(lines):
	if (re.match(str(lineNumber), l) == None):
		lines[n-1] = lines[n-1].replace('\r\n', '\n')
	else:
		lineNumber += 1

fo = Path('NPCText2.txt').open(mode = 'w', newline = '', encoding = 'cp1252')
fo.writelines(lines)