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

!define MMVERSION "8" ; 6 or 7 or 8 or Merge
!define MMLANG "Simplified Chinese"
!define MMLANGCODE "zh_CN"
!define FileNameStr "Update"
!define VERSION "2020-08-01"

!define VERSIONDOT "4.0.0.0"

;--------------------------------
;General

;Name and file
Name "Might and Magic ${MMVERSION} ${MMLANG} ${FileNameStr} Patch ${VERSION}"
OutFile "${OUTFILE}${MMVERSION}_${MMLANGCODE}_${FileNameStr}_${VERSION}.exe"
Unicode True
; AutoCloseWindow true

VIProductVersion "${VERSIONDOT}"
VIAddVersionKey "ProductName" "Might and Magic ${MMVERSION} ${MMLANG} ${FileNameStr} Patch ${VERSION}"
VIAddVersionKey "FileDescription" "Might and Magic ${MMVERSION} ${MMLANG} ${FileNameStr} Patch ${VERSION}"
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
	IfFileExists "$EXEDIR\mm8.exe" is_correct_folder is_not_correct_folder

	is_correct_folder:

;-----FILE COPYING (MODIFYING, DELETING) STARTS HERE-----

		SetOutPath $INSTDIR

		File /r /x *.todelete /x *.mmarchkeep files\*.*

;-----FILE COPYING (MODIFYING, DELETING) ENDS HERE-----

		goto end_of_condition

	is_not_correct_folder:

		MessageBox MB_OK "Error: can't find the game folder. Please move ${OUTFILE}${MMVERSION}_${MMLANGCODE}_${FileNameStr}_${VERSION}.exe to your game folder before executing it."

		Quit

	end_of_condition:

SectionEnd
