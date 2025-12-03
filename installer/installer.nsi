!include "MUI2.nsh"

Name "RSAT Dashboard"
OutFile "RSATDashboard_Setup.exe"
InstallDir "C:\RSATDashboard"
Icon "rsat_ad_icon_multi.ico"
RequestExecutionLevel admin

!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

Section "Install"

  SetOutPath "$INSTDIR"

  File "RSATDashboard.ps1"
  File "RSATDashboard.xaml"
  File "rsat_ad_icon_multi.ico"
  File "Installer.ps1"

  SetOutPath "$INSTDIR\Views"
  File /r "Views\*.xaml"

  ; Shortcut Desktop
  CreateShortcut "$DESKTOP\RSAT Dashboard.lnk" "powershell.exe" "-ExecutionPolicy Bypass -File `"$INSTDIR\RSATDashboard.ps1`"" "$INSTDIR\rsat_ad_icon_multi.ico"

  ; Start Menu folder
  CreateDirectory "$SMPROGRAMS\RSAT Dashboard"
  CreateShortcut "$SMPROGRAMS\RSAT Dashboard\RSAT Dashboard.lnk" "powershell.exe" "-ExecutionPolicy Bypass -File `"$INSTDIR\RSATDashboard.ps1`"" "$INSTDIR\rsat_ad_icon_multi.ico"

SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\RSAT Dashboard.lnk"
  Delete "$SMPROGRAMS\RSAT Dashboard\RSAT Dashboard.lnk"
  RMDir  "$SMPROGRAMS\RSAT Dashboard"
  RMDir /r "$INSTDIR"
SectionEnd
