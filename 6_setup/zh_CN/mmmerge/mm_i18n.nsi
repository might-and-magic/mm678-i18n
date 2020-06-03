; Might and Magic I18N (Localization) Patch Installer
; Written by Tom CHEN
; https://github.com/might-and-magic/mm678-i18n
; MIT License

;--------------------------------
;Include Modern UI
!include "MUI2.nsh"

;--------------------------------
;Variables and constants
!define OUTFILE "MM"

!define MMVERSION "Merge" ; 6 or 7 or 8 or Merge
!define MMLANG "Simplified Chinese"
!define MMLANGCODE "zh_CN"
!define VERSION "2020-05-26"

!define VERSIONDOT "4.0.0.0"

;--------------------------------
;General

;Name and file
Name "Might and Magic ${MMVERSION} ${MMLANG} Patch ${VERSION}"
OutFile "${OUTFILE}${MMVERSION}_${MMLANGCODE}_${VERSION}.exe"
Unicode True
; AutoCloseWindow true

VIProductVersion "${VERSIONDOT}"
VIAddVersionKey "ProductName" "Might and Magic ${MMVERSION} ${MMLANG} Patch ${VERSION}"
VIAddVersionKey "FileDescription" "Might and Magic ${MMVERSION} ${MMLANG} Patch ${VERSION}"
VIAddVersionKey "LegalTrademarks" "Might and Magic is a trademark of Ubisoft Entertainment SA"
VIAddVersionKey "LegalCopyright" "NWC/3DO; Ubisoft; MM I18N Team"
VIAddVersionKey "FileVersion" "${VERSIONDOT}"
VIAddVersionKey "ProductVersion" "${VERSIONDOT}"

BrandingText "NWC/3DO; Ubisoft; MM I18N Team"

!define MUI_ICON "icon.ico"

;--------------------------------
;Default installation folder
InstallDir $EXEDIR

;Request application privileges for Windows Vista
RequestExecutionLevel user

;--------------------------------
;Pages

!insertmacro MUI_PAGE_INSTFILES

;--------------------------------
;Languages

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section
; if this file exists, it will be safe to assume $EXEDIR is the correct MMVERSION game folder
	IfFileExists "$EXEDIR\Scripts\General\1_TownPortalSwitch.lua" is_correct_folder is_not_correct_folder

	is_correct_folder:

;-----FILE COPYING (MODIFYING, DELETING) STARTS HERE-----

		SetOutPath $INSTDIR
		File mmarch.exe

		RMDir /r /REBOOTOK "$INSTDIR\DataFiles"
		RMDir /r /REBOOTOK "$INSTDIR\Scripts\General\Misc"
		RMDir /r /REBOOTOK "$INSTDIR\Scripts\General\Obsolete"

		File /r /x *.todelete /x *.mmarchkeep files\*.*

		Delete "Data\breach.sprites.lod"
		Delete "Data\LocalizeTables.txt"
		Delete "Data\new.lod"
		Delete "Data\weather.icons.lod"
		Delete "Scripts\Modules\PathfinderAsmBroken.lua"
		Delete "Scripts\Modules\PathfinderAsmOld.lua"

		nsExec::Exec 'mmarch delete "Data\icons.lod" "cd1.evt"'
		nsExec::Exec 'mmarch delete "Data\icons.lod" "cd2.evt"'
		nsExec::Exec 'mmarch delete "Data\icons.lod" "cd3.evt"'
		nsExec::Exec 'mmarch delete "Data\icons.lod" "lwspiral.evt"'

		nsExec::Exec 'mmarch add "Data\EnglishT.lod" "Data\EnglishT.lod.mmarchive\*.*"'
		RMDir /r /REBOOTOK "$INSTDIR\Data\EnglishT.lod.mmarchive"
		nsExec::Exec 'mmarch add "Data\icons.lod" "Data\icons.lod.mmarchive\*.*"'
		RMDir /r /REBOOTOK "$INSTDIR\Data\icons.lod.mmarchive"
		nsExec::Exec 'mmarch add "Data\mm6.EnglishT.lod" "Data\mm6.EnglishT.lod.mmarchive\*.*"'
		RMDir /r /REBOOTOK "$INSTDIR\Data\mm6.EnglishT.lod.mmarchive"
		nsExec::Exec 'mmarch add "Data\patch.icons.lod" "Data\patch.icons.lod.mmarchive\*.*"'
		RMDir /r /REBOOTOK "$INSTDIR\Data\patch.icons.lod.mmarchive"
		nsExec::Exec 'mmarch add "Data\select.icons.lod" "Data\select.icons.lod.mmarchive\*.*"'
		RMDir /r /REBOOTOK "$INSTDIR\Data\select.icons.lod.mmarchive"

		Delete "mmarch.exe"

;-----FILE COPYING (MODIFYING, DELETING) ENDS HERE-----

		goto end_of_condition

	is_not_correct_folder:

		MessageBox MB_OK "Error: can't find the game folder. Please move ${OUTFILE}${MMVERSION}_${MMLANGCODE}_${VERSION}.exe to your game folder before executing it."

		Quit

	end_of_condition:

SectionEnd
