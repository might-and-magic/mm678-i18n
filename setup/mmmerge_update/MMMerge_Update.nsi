; Might and Magic 678 Merge Update Patch Installer
; Written by Tom CHEN
; https://github.com/might-and-magic/mm678-i18n/tree/master/setup/mmmerge_update
; MIT License

;--------------------------------
;Include Modern UI
!include "MUI2.nsh"

;--------------------------------
;Variables and constants

!define OUTFILE "MMMerge_Update"
!define VERSION "2020-03-22"

!define VERSIONDOT "2.0.0.0"

;--------------------------------
;General

;Name and file
Name "Might and Magic 678 Merge ${VERSION} Update Patch"
OutFile "${OUTFILE}_${VERSION}.exe"
Unicode True
; AutoCloseWindow true

VIProductVersion "${VERSIONDOT}"
VIAddVersionKey "ProductName" "Might and Magic 678 Merge ${VERSION} Update Patch"
VIAddVersionKey "FileDescription" "Might and Magic 678 Merge ${VERSION} Update Patch"
VIAddVersionKey "LegalTrademarks" "Might and Magic is a trademark of Ubisoft Entertainment SA"
VIAddVersionKey "LegalCopyright" "NWC/3DO; Ubisoft; MMMerge Team"
VIAddVersionKey "FileVersion" "${VERSIONDOT}"
VIAddVersionKey "ProductVersion" "${VERSIONDOT}"

BrandingText "NWC/3DO; Ubisoft; MMMerge Team"

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
; if $EXEDIR\Scripts\General\1_TownPortalSwitch.lua exists,
; it will be safe to assume $EXEDIR is MMMerge folder,
; otherwise, user should select the MMMerge folder
	IfFileExists "$EXEDIR\Scripts\General\1_TownPortalSwitch.lua" is_mmmerge_folder is_not_mmmerge_folder

	is_mmmerge_folder:

;-----FILE COPYING (MODIFYING, DELETING) STARTS HERE-----

		SetOutPath $INSTDIR

		File /r /x *.todelete files\*.*

		Delete "$INSTDIR\Data\breach.sprites.lod"
		Delete "$INSTDIR\Data\LocalizeTables.txt"
		Delete "$INSTDIR\Data\weather.icons.lod"

		; RMDir /r /REBOOTOK $INSTDIR\hg
		
		File mmarch.exe
		nsExec::Exec 'mmarch add "Data\EnglishT.lod" "Data\EnglishT.lod.mmarchive\*.*"'
		; nsExec::Exec "mmarch delete Data/EnglishT.lod ???"
		Delete $INSTDIR\mmarch.exe

		RMDir /r /REBOOTOK $INSTDIR\Data\EnglishT.lod.mmarchive


;-----FILE COPYING (MODIFYING, DELETING) ENDS HERE-----

		goto end_of_condition

	is_not_mmmerge_folder:

		MessageBox MB_OK "Error: can't find the game folder. Please move ${OUTFILE}_${VERSION}.exe to your game folder before executing it."

		Quit

	end_of_condition:



SectionEnd



; Delete "$INSTDIR\silent.nsi"


; Section "Test CopyFiles"

;   SectionIn 1 2 3

;   SetOutPath $INSTDIR\cpdest
;   CopyFiles "$WINDIR\*.ini" "$INSTDIR\cpdest" 0

; SectionEnd


; Section "Test Exec functions" TESTIDX

;   SectionIn 1 2 3
  
;   SearchPath $1 notepad.exe

;   MessageBox MB_OK "notepad.exe=$1"
;   Exec '"$1"'
;   ExecShell "open" '"$INSTDIR"'
;   Sleep 500
;   BringToFront

; SectionEnd
