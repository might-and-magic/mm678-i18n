# Small script to overwrite po entry with overwrite_in_po.txt table.

# For each line "msgctxt	msgid	msgstr" in overwrite_in_po.txt table,
# all .po entries that match msgctxt and msgid will change their msgstr to the specified one.

# There should not be duplicated lines (with same msgctxt and msgid) in overwrite_in_po.txt table


import pandas as pd
from pathlib import Path
import polib

df = pd.read_csv(Path('tools/overwrite_in_po.txt'), sep="\t", header=None)

po = polib.pofile(Path('3_i18n/zh_CN/LC_MESSAGES/mm678.po'))

for entry in po:

	target = df[(df[0] == entry.msgctxt) & (df[1] == entry.msgid)]
	if not target.empty:
		entry.msgstr = target[2].iloc[0]

po.save(Path('3_i18n/zh_CN/LC_MESSAGES/mm678.new.po'))
