
;--------------------------------
;Include Modern UI
!include "MUI2.nsh"

;--------------------------------
;General

;Name and file
Name "Might and Magic Patch"
OutFile "patch.exe"
Unicode True
; AutoCloseWindow true

BrandingText "NWC/3DO; Ubisoft"

; !define MUI_ICON "icon.ico"

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

SectionEnd
