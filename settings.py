project_name = 'Might and Magic 6 7 8 Translation'
author_name  = 'Tom Chen'
author_email = 'tomchen.org@gmail.com'
team_name    = 'Might and Magic Unofficial Translation Team'
textdomain = 'mm678'

# folders have no slash
source_folder   = '0_source'
template_folder = '1_template'
dev_folder      = '2_dev'
i18n_folder     = '3_i18n'
prod_folder     = '4_prod'

file_extensions = ['txt', 'str', 'ini']

# source files offer translatable strings but not the format
# all text to the right of the rightmost template_repl tag won't be taken into consideration
template_repl = "_(TRANS)_"
template_repl_with_context = "_(TRANS_CONTEXT:'<context>')_" # translatable text with context
template_encoding = 'UTF-8' # default is 'UTF-8'

first_language = 'en'

source_encoding = { # defaults are 'UTF-8'
	'en': 'cp1252',
	'zh_CN': 'gb2312',
	'zh_TW': 'big5'
}

encoding_errors_handling = 'strict' # could be 'strict', 'ignore' (default), 'replace', 'backslashreplace', etc. see https://docs.python.org/3/library/io.html#io.TextIOWrapper

custom_list = {
	'zh_CN': {
		# 'my_translation_zh_0': [
		# 	# ['pet', '家养动物'],
		# 	[('cat', 'abbr for category'), '类别']
		# ], # can also be a string indicating the path to a tab-seperated file
		'customlist_zh_longstrfix': {
			'file': '0_source/zh_CN/customlist/longstrfix.list',
			# 'encoding': 'UTF-8'
		},
		'customlist_zh_globalfix': {
			'file': '0_source/zh_CN/customlist/globalfix.list',
			# 'encoding': 'UTF-8'
		},
		'customlist_zh_riddle': {
			'file': '0_source/zh_CN/customlist/riddle.list',
			# 'encoding': 'UTF-8'
		},
		'customlist_zh_customlist': {
			'file': '0_source/zh_CN/customlist/customlist.list',
			# 'encoding': 'UTF-8'
		},
		'customlist_zh_untrans': {
			'file': '0_source/zh_CN/customlist/untrans.list',
			# 'encoding': 'UTF-8'
		},
		'customlist_zh_npctextnew': {
			'file': '0_source/zh_CN/customlist/npctextnew.list',
			# 'encoding': 'UTF-8'
		}
	}
}

conflict_priority = {
	'zh_CN': [
		['CUSTOMLIST:customlist_zh_longstrfix'],
		['CUSTOMLIST:customlist_zh_globalfix'],
		['CUSTOMLIST:customlist_zh_riddle'],
		['CUSTOMLIST:customlist_zh_customlist'],
		['CUSTOMLIST:customlist_zh_untrans'],
		['CUSTOMLIST:customlist_zh_npctextnew'],
		['L1FOLDER:mmmerge', 'L1FOLDER:mm6', 'L1FOLDER:mm7', 'L1FOLDER:mm8'],
		['MOSTFREQUENT']
	]
}

# Language exclusion list containing languages present in the source folder, but do not need to proceed and generate i18n files
# default is []
# the first language cannot be excluded even if you put it in the list
i18n_language_exclusion = []

# Language exclusion list containing languages present in the i18n folder, but do not need to proceed and generate prod files
# default is []
# the first language could be excluded
prod_language_exclusion = []

separator = '\t'
eol = '\r\n'

# The following mode read non CRLF ('\r\n') LF ('\n') in translatable strings as `Slash N` ('\\n') at the beginning
# and convert them back at the end when generating prod files
# default is False
# effective only when eol = '\r\n'
lf_in_crlf_mode = True

# For every separator-separated value, you could do following trim, sanitization works
trim_whitespace = False
trim_doublequote = True
trim_singlequote = False
convert_two_quotes_to_one = True # convert "" (or '') to " (or ')

no_log = True
no_warning = True