# =========================================
# RSAT Dashboard Auto-Build System
# =========================================

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$ZipPath = Join-Path $Base "update.zip"
$VersionFile = Join-Path $Base "version.txt"

# --- 1) Incrementa versione ---
if (!(Test-Path $VersionFile)) {
    "1.0.0" | Out-File $VersionFile
}

$Version = Get-Content $VersionFile
$Parts = $Version.Split('.')
$Parts[2] = [int]$Parts[2] + 1
$NewVersion = "$($Parts[0]).$($Parts[1]).$($Parts[2])"

$NewVersion | Out-File $VersionFile

Write-Host "Nuova versione generata: $NewVersion" -ForegroundColor Green

# --- 2) Crea ZIP ---
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Write-Host "Creo update.zip..." -ForegroundColor Cyan

$Files = @(
    "RSATDashboard.ps1",
    "RSATDashboard.xaml",
    "rsat_ad_icon_multi.ico"
)

Compress-Archive -Path $Files -DestinationPath $ZipPath -Force

Write-Host "update.zip creato con successo!" -ForegroundColor Green

# --- 3) Push automatico su GitHub (opzionale) ---
if ($args -contains "-push") {
    Write-Host "Eseguo git add/commit/push..." -ForegroundColor Yellow

    git add RSATDashboard.ps1 RSATDashboard.xaml rsat_ad_icon_multi.ico update.zip version.txt
    git commit -m "Update $NewVersion"
    git push

    Write-Host "Push completato!" -ForegroundColor Green
}
