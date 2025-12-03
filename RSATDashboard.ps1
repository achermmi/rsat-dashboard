Add-Type -AssemblyName PresentationFramework, PresentationCore

# =============================================================
# AUTO-UPDATE (GitHub: achermmi/rsat-dashboard)
# =============================================================

$CurrentVersion = "1.0.0"
$BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

$VersionURL   = "https://raw.githubusercontent.com/achermmi/rsat-dashboard/main/version.txt"
$UpdateZipURL = "https://raw.githubusercontent.com/achermmi/rsat-dashboard/main/update.zip"

Function Check-ForUpdate {
    Write-Host "Controllo aggiornamenti RSAT Dashboard..."

    try {
        $Latest = Invoke-WebRequest -Uri $VersionURL -UseBasicParsing -ErrorAction Stop
        $LatestVersion = $Latest.Content.Trim()
    } catch {
        return
    }

    if ($LatestVersion -ne $CurrentVersion) {

        $ZipPath = "$BasePath\update.zip"
        Invoke-WebRequest -Uri $UpdateZipURL -OutFile $ZipPath -UseBasicParsing
        Expand-Archive $ZipPath -DestinationPath $BasePath -Force
        Remove-Item $ZipPath -Force

        Start-Process "powershell.exe" "-ExecutionPolicy Bypass -File `"$BasePath\RSATDashboard.ps1`""
        exit
    }
}

Check-ForUpdate

# =============================================================
# LOAD XAML VIEW FUNCTION
# =============================================================

Function Load-XamlView {
    param([string]$path)

    $xaml = Get-Content $path -Raw
    $xmlReader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    return [Windows.Markup.XamlReader]::Load($xmlReader)
}

# Load Main Window
$MainWindow = Load-XamlView "$BasePath\RSATDashboard.xaml"
$MainContent = $MainWindow.FindName("MainContent")

# Menu buttons
$BtnDashboard = $MainWindow.FindName("BtnDashboard")
$BtnAD        = $MainWindow.FindName("BtnAD")
$BtnDNS       = $MainWindow.FindName("BtnDNS")
$BtnCluster   = $MainWindow.FindName("BtnCluster")
$BtnRunAs     = $MainWindow.FindName("BtnRunAs")
$BtnSearch    = $MainWindow.FindName("BtnSearch")
$CloseBtn     = $MainWindow.FindName("CloseBtn")

# =============================================================
# RSAT TOOLS (RunAs-only)
# =============================================================

$RSAT = @{
    "ADUC"      = "dsa.msc"
    "ADSites"   = "dssite.msc"
    "ADDomains" = "domain.msc"
    "DNS"       = "dnsmgmt.msc"
    "DHCP"      = "dhcpmgmt.msc"
    "GPMC"      = "gpmc.msc"
    "Cluster"   = "cluadmin.msc"
}

Function Open-RSATTool {
    param([string]$tool)

    # Load DPAPI credentials
    $c = Load-Creds
    if ($null -eq $c) {
        [System.Windows.MessageBox]::Show("Nessuna credenziale salvata. Apri RunAs e salvale.")
        return
    }

    $sec = ConvertTo-SecureString $c.Pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($c.User, $sec)

    if ($RSAT.ContainsKey($tool)) {

        $exe = $RSAT[$tool]

        if ($exe -like "*.msc") {
            Start-Process -Credential $cred "mmc.exe" $exe
        } else {
            Start-Process -Credential $cred $exe
        }

    } else {
        [System.Windows.MessageBox]::Show("Tool RSAT non trovato: $tool")
    }
}

# =============================================================
# LOAD VIEWS
# =============================================================

Function Load-View {
    param([string]$name)
    $viewPath = "$BasePath\Views\$name.xaml"
    $MainContent.Content = Load-XamlView $viewPath
}

# =============================================================
# DPAPI CREDENTIALS
# =============================================================

$CredPath = "$env:LOCALAPPDATA\RSATDashboard\cred.bin"
New-Item -ItemType Directory -Path "$env:LOCALAPPDATA\RSATDashboard" -Force | Out-Null

Function Save-Creds($user,$pass) {
    $bytes = [Text.Encoding]::UTF8.GetBytes("$user`n$pass")
    $enc = [Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    Set-Content -Path $CredPath -Encoding Byte -Value $enc
}

Function Load-Creds {
    if (!(Test-Path $CredPath)) { return $null }
    $enc = Get-Content -Path $CredPath -Encoding Byte
    $dec = [Security.Cryptography.ProtectedData]::Unprotect($enc,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    $str = [Text.Encoding]::UTF8.GetString($dec)
    $parts = $str -split "`n"
    return @{ User=$parts[0]; Pass=$parts[1] }
}

# =============================================================
# AD SEARCH
# =============================================================

Function Search-AD {
    param([string]$text)

    try { Import-Module ActiveDirectory -ErrorAction Stop }
    catch { [System.Windows.MessageBox]::Show("Modulo AD non installato."); return }

    $u = Get-ADUser -Filter "Name -like '*$text*'" -Properties DistinguishedName | Select -First 1
    if ($null -eq $u) {
        [System.Windows.MessageBox]::Show("Nessun utente trovato.")
        return
    }

    Start-Process "mmc.exe" "dsa.msc /select=`"$($u.DistinguishedName)`""
}

# =============================================================
# BUTTON EVENTS
# =============================================================

$CloseBtn.Add_Click({ $MainWindow.Close() })

$BtnDashboard.Add_Click({ Load-View "Dashboard" })
$BtnAD.Add_Click({ Load-View "ActiveDirectory" })
$BtnDNS.Add_Click({ Load-View "DNS" })
$BtnCluster.Add_Click({ Load-View "Cluster" })
$BtnRunAs.Add_Click({ Load-View "RunAs" })

$BtnSearch.Add_Click({
    $query = [Microsoft.VisualBasic.Interaction]::InputBox("Inserisci nome utente:")
    if ($query -ne "") { Search-AD $query }
})

# Load dashboard at start
Load-View "Dashboard"

$MainWindow.ShowDialog() | Out-Null
