<#
    RSAT Dashboard Installer
    Version: 1.0
    Author: achermmi + ChatGPT
#>

Write-Host "==== RSAT Dashboard Installer ====" -ForegroundColor Cyan

# =============================================================
# PATHS
# =============================================================
$InstallPath = "C:\RSATDashboard"
$StartMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\RSAT Dashboard"
$DesktopLink = "$env:USERPROFILE\Desktop\RSAT Dashboard.lnk"
$ExePath = "$InstallPath\RSATDashboard.ps1"
$IconPath = "$InstallPath\rsat_ad_icon_multi.ico"

# =============================================================
# FUNCTIONS
# =============================================================

Function Create-Folder($path) {
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Function Copy-DashboardFiles {
    Write-Host "Copio i file della Dashboard..." -ForegroundColor Cyan

    Copy-Item ".\RSATDashboard.ps1"      -Destination $InstallPath -Force
    Copy-Item ".\RSATDashboard.xaml"     -Destination $InstallPath -Force
    Copy-Item ".\rsat_ad_icon_multi.ico" -Destination $InstallPath -Force

    # Copy Views Folder
    if (!(Test-Path ".\Views")) {
        Write-Host "La cartella Views non esiste!" -ForegroundColor Red
        exit
    }

    Copy-Item ".\Views" -Destination $InstallPath -Recurse -Force
}

Function New-Shortcut {
    param(
        [string]$Path,
        [string]$Target,
        [string]$Icon
    )

    $WS = New-Object -ComObject WScript.Shell
    $SC = $WS.CreateShortcut($Path)
    $SC.TargetPath = "powershell.exe"
    $SC.Arguments  = "-ExecutionPolicy Bypass -File `"$Target`""
    $SC.IconLocation = $Icon
    $SC.WorkingDirectory = $InstallPath
    $SC.Save()
}

Function Pin-Taskbar {
    Write-Host "Aggiungo RSAT Dashboard alla taskbar..."

    $lnk = $DesktopLink
    if (!(Test-Path $lnk)) { return }

    # Metodo moderno (Windows 11 compatibile)
    $verb = (New-Object -ComObject Shell.Application).
        NameSpace((Split-Path $lnk)).
        ParseName((Split-Path $lnk -Leaf)).
        Verbs() | Where-Object { $_.Name -match "pin to taskbar" }

    if ($verb) { $verb.DoIt() }
}

Function Check-RSATInstalled {
    Write-Host "Verifico la presenza dei componenti RSAT..."

    $capabilities = Get-WindowsCapability -Online | Where-Object Name -like "RSAT*"

    if ($capabilities.State -notcontains "Installed") {

        Write-Host ""
        Write-Host "⚠ ATTENZIONE: RSAT non risulta installato." -ForegroundColor Yellow
        Write-Host "Il tuo PC NON essendo nel dominio richiede RSAT + RUNAS." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Per installarlo manualmente da ISO:"
        Write-Host "  Settings → System → Optional Features → ADD → RSAT"
        Write-Host ""

        Pause
    }
}

# =============================================================
# INSTALLATION START
# =============================================================
Write-Host "`nInstallazione in corso..." -ForegroundColor Cyan

Create-Folder $InstallPath
Create-Folder $StartMenuPath

Copy-DashboardFiles

# =============================================================
# SHORTCUTS
# =============================================================
Write-Host "Creo scorciatoie..." -ForegroundColor Cyan

New-Shortcut -Path $DesktopLink    -Target $ExePath -Icon $IconPath
New-Shortcut -Path "$StartMenuPath\RSAT Dashboard.lnk" -Target $ExePath -Icon $IconPath

# =============================================================
# PIN TO TASKBAR
# =============================================================
Pin-Taskbar

# =============================================================
# CHECK RSAT
# =============================================================
Check-RSATInstalled

# =================================================
