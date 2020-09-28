# ZhConvert

from pathlib import Path
from opencc import OpenCC
import polib
import time


start = time.time()


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
method = 's2twp'
cc = OpenCC(method)
convertQuote = True
replaceWordList = [['自由天堂', '自由港'], ['恩洛斯', '安罗斯'], ['贾丹姆', '贾达密'], ['咔', '咯'], ['～', '-']]
replaceWordListAfter = [['心繫', '心系']]

po = polib.pofile(Path('3_i18n/zh_CN/LC_MESSAGES/mm678.po'))
for entry in po:

	outputContent = entry.msgstr

	for replaceWord in replaceWordList:
		outputContent = outputContent.replace(replaceWord[0], replaceWord[1])

	outputContent = cc.convert(outputContent)

	for replaceWordAfter in replaceWordListAfter:
		outputContent = outputContent.replace(replaceWordAfter[0], replaceWordAfter[1])

	if convertQuote:
		if method in ['hk2s', 't2s', 'tw2s', 'tw2sp']:
			QDict = quoteDict
		elif method in ['s2hk', 's2t', 's2tw', 's2twp']:
			QDict = dict([[v,k] for k,v in quoteDict.items()])
		else:
			QDict = {}
		for q in QDict:
			outputContent = outputContent.replace(q, QDict[q])

	entry.msgstr = outputContent


po.metadata['Language'] = 'zh_TW'
po.save(Path('3_i18n/zh_TW/LC_MESSAGES/mm678.po'))



end = time.time()
print('Execution time: ' + str(end - start) + ' second')
