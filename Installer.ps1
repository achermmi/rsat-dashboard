# ============================
# RSAT Dashboard Installer
# ============================

Write-Host "Installazione RSAT Dashboard in corso..." -ForegroundColor Cyan

$Base = "C:\RSATDashboard"
$DesktopLnk = "$env:USERPROFILE\Desktop\RSAT Dashboard.lnk"
$StartMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\RSAT Dashboard.lnk"
$IconPath = "$Base\rsat_ad_icon_multi.ico"

# ============================
# CREA CARTELLA
# ============================
if (!(Test-Path $Base)) {
    Write-Host "Creo cartella $Base"
    New-Item -ItemType Directory $Base | Out-Null
}

# ============================
# COPIA FILE
# ============================
Write-Host "Copio file principali..."
Copy-Item ".\RSATDashboard.ps1" $Base -Force
Copy-Item ".\RSATDashboard.xaml" $Base -Force
Copy-Item ".\rsat_ad_icon_multi.ico" $Base -Force

# ============================
# CREA SHORTCUT FUNZIONALE
# ============================

Function Create-Shortcut($Path) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($Path)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments  = "-ExecutionPolicy Bypass -NoProfile -File `"$Base\RSATDashboard.ps1`""
    $Shortcut.IconLocation = $IconPath
    $Shortcut.WorkingDirectory = $Base
    $Shortcut.Save()
}

# Desktop
Create-Shortcut -Path $DesktopLnk

# Start Menu
Create-Shortcut -Path $StartMenu

Write-Host "Shortcut creati." -ForegroundColor Green


# ============================
# PIN ALLA TASKBAR
# ============================

Write-Host "Aggiungo RSAT Dashboard alla taskbar..."

$shell = New-Object -ComObject Shell.Application
$folder = $shell.Namespace((Split-Path $DesktopLnk))
$item   = $folder.ParseName((Split-Path $DesktopLnk -Leaf))

$pinVerb = $item.Verbs() | Where-Object { $_.Name -match "pin to taskbar|Barra delle applicazioni|An Taskleiste" }

if ($pinVerb) {
    $pinVerb.DoIt()
    Write-Host "Pinnato correttamente!" -ForegroundColor Green
} else {
    Write-Host "⚠ Non è stato possibile pinnare automaticamente. Fallo manualmente cliccando col destro sul collegamento." -ForegroundColor Yellow
}


# ============================
# FINE
# ============================

Write-Host "`nInstallazione completata!" -ForegroundColor Cyan
Write-Host "Puoi avviare la RSAT Dashboard dall'icona sul Desktop o dal menu Start." -ForegroundColor White
