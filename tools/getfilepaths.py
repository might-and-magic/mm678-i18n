# getFilePaths
# Tool of csv2po.py
# By Tom CHEN <tomchen.org@gmail.com> (tomchen.org)

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
		fileName = '*.' + extension
		if extension == '':
			fileName = '*'
		return list(pathObj.glob(pathPre + fileName))
