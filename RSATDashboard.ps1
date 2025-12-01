Add-Type -AssemblyName PresentationFramework, PresentationCore

# ============================
# LOAD XAML UI
# ============================
[xml]$xaml = Get-Content "$PSScriptRoot\RSATDashboard.xaml"
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# ============================
# BIND CONTROLS
# ============================
$CloseBtn    = $Window.FindName("CloseBtn")

$BtnDashboard = $Window.FindName("BtnDashboard")
$BtnAD        = $Window.FindName("BtnAD")
$BtnDNS       = $Window.FindName("BtnDNS")
$BtnCluster   = $Window.FindName("BtnCluster")
$BtnRunAs     = $Window.FindName("BtnRunAs")
$BtnSearch    = $Window.FindName("BtnSearch")

$MainContent = $Window.FindName("MainContent")

# ============================
# LOG DIRECTORY
# ============================
$LogPath = "$env:LOCALAPPDATA\RSATDashboard\logs"
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory $LogPath | Out-Null
}

Function Write-Log($msg) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path "$LogPath\dashboard.log" -Value "$timestamp - $msg"
}

# ============================
# RSAT TOOL MAP
# ============================
$RSATTools = @{
    "ADUC"        = "dsa.msc"
    "ADSites"     = "dssite.msc"
    "ADDomains"   = "domain.msc"
    "DNS"         = "dnsmgmt.msc"
    "DHCP"        = "dhcpmgmt.msc"
    "GPMC"        = "gpmc.msc"
    "Cluster"     = "cluadmin.msc"
    "CertSrv"     = "certsrv.msc"
    "VolumeAct"   = "vmw.exe"
    "ServerMgr"   = "ServerManager.exe"
}

Function Launch-RSATTool($toolKey) {
    if ($RSATTools.ContainsKey($toolKey)) {
        Write-Log "Launching RSAT tool: $toolKey"
        Start-Process $RSATTools[$toolKey]
    } else {
        Show-AzureMessage "Strumento RSAT non trovato: $toolKey"
    }
}

# ============================
# CUSTOM AZURE MESSAGE BOX
# ============================
Function Show-AzureMessage {
param(
    $Message,
    $Title = "RSAT Dashboard"
)

$MsgXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Width="380" Height="170" Background="#0F172A"
        WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen">
    <Border Background="#1E293B" BorderBrush="#3B82F6" BorderThickness="2" CornerRadius="8">
        <StackPanel Margin="15">
            <TextBlock Text="$Title" Foreground="#60A5FA" FontSize="18" Margin="0,0,0,10"/>
            <TextBlock Text="$Message" TextWrapping="Wrap" Foreground="#E2E8F0" FontSize="15"/>
            <Button Width="90" Height="30" Margin="0,20,0,0"
                    Background="#3B82F6" Foreground="White"
                    HorizontalAlignment="Right" Content="OK"
                    Click="Close" />
        </StackPanel>
    </Border>
</Window>
"@

    [xml]$xml = $MsgXAML
    $reader = New-Object System.Xml.XmlNodeReader $xml
    $msgWindow = [Windows.Markup.XamlReader]::Load($reader)
    $msgWindow.ShowDialog() | Out-Null
}

# ============================
# DPAPI CREDENTIAL STORAGE
# ============================
$CredPath = "$env:LOCALAPPDATA\RSATDashboard\cred.bin"

Function Save-Creds($username, $password) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$username`n$password")
    $enc   = [System.Security.Cryptography.ProtectedData]::Protect(
                $bytes,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    
    Set-Content -Path $CredPath -Value $enc -Encoding Byte
    Show-AzureMessage "Credenziali salvate correttamente."
}

Function Load-Creds {
    if (!(Test-Path $CredPath)) { return $null }
    $enc = Get-Content -Path $CredPath -Encoding Byte
    $dec = [System.Security.Cryptography.ProtectedData]::Unprotect(
                $enc,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $str = [System.Text.Encoding]::UTF8.GetString($dec)
    $parts = $str -split "`n"
    return @{ User=$parts[0]; Pass=$parts[1] }
}

Function RunAs-ADUC {
    $creds = Load-Creds
    if ($null -eq $creds) {
        Show-AzureMessage "Nessuna credenziale salvata."
        return
    }

    $secure = ConvertTo-SecureString $creds.Pass -AsPlainText -Force
    $cred   = New-Object System.Management.Automation.PSCredential($creds.User,$secure)

    Write-Log "Running ADUC as $($creds.User)"
    Start-Process "mmc.exe" "dsa.msc" -Credential $cred
}

# ============================
# RENDER CARDS (2×N Azure style)
# ============================
Function Show-Cards($title, $cards) {

    $MainContent.Content = $null

    $ui = @"
<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
    <StackPanel Margin='20'>

        <TextBlock Text='$title'
                   Foreground='#60A5FA'
                   FontSize='26'
                   Margin='0,0,0,20'
                   HorizontalAlignment='Center'/>

        <UniformGrid Columns='2' Rows='0'>
"@

    foreach ($card in $cards.Keys) {
        $ui += "<Button Style='{StaticResource AzureCard}' Tag='$($cards[$card])' Margin='10'>$card</Button>"
    }

    $ui += @"
        </UniformGrid>
    </StackPanel>
</Grid>
"@

    [xml]$xmlUI = $ui
    $readerUI = New-Object System.Xml.XmlNodeReader $xmlUI
    $panel = [Windows.Markup.XamlReader]::Load($readerUI)

    # Add handlers
    $buttons = $panel.FindName("Content").Parent.FindName("*")
    foreach ($b in $panel.FindAll("Button")) {
        $b.Add_Click({
            Launch-RSATTool ($this.Tag)
        })
    }

    $MainContent.Content = $panel
}

# ============================
# AD SEARCH
# ============================
Function Search-ADUser {
    param($query)

    try { Import-Module ActiveDirectory -ErrorAction Stop } 
    catch { Show-AzureMessage "Modulo ActiveDirectory non installato."; return }

    try {
        $user = Get-ADUser -Filter "Name -like '*$query*'" `
            -Properties DistinguishedName | Select -First 1
    }
    catch {
        Show-AzureMessage "Errore durante la query AD."
        return
    }

    if ($null -eq $user) {
        Show-AzureMessage "Nessun utente trovato."
        return
    }

    Start-Process "mmc.exe" "dsa.msc /select=`"$($user.DistinguishedName)`""
}

# ============================
# SIDEBAR EVENTS
# ============================
$CloseBtn.Add_Click({ $Window.Close() })

$BtnDashboard.Add_Click({
    Show-Cards "Dashboard" @{
        "Active Directory Users" = "ADUC"
        "Group Policy Manager"   = "GPMC"
        "DNS Manager"            = "DNS"
        "DHCP Manager"           = "DHCP"
        "Cluster Manager"        = "Cluster"
        "Certificate Authority"  = "CertSrv"
        "Volume Activation"      = "VolumeAct"
        "Server Manager"         = "ServerMgr"
    }
})

$BtnAD.Add_Click({
    Show-Cards "Active Directory" @{
        "AD Users and Computers" = "ADUC"
        "AD Sites and Services"  = "ADSites"
        "AD Domains and Trusts"  = "ADDomains"
        "Group Policy Manager"   = "GPMC"
    }
})

$BtnDNS.Add_Click({
    Show-Cards "DNS / DHCP" @{
        "DNS Manager" = "DNS"
        "DHCP Manager" = "DHCP"
        "Server Manager" = "ServerMgr"
    }
})

$BtnCluster.Add_Click({
    Show-Cards "Failover Cluster" @{
        "Cluster Manager" = "Cluster"
        "Server Manager" = "ServerMgr"
    }
})

$BtnRunAs.Add_Click({
    $MainContent.Content = $null

    $ui = @"
<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
    <StackPanel Margin='30'>

        <TextBlock Text='RunAs Domain Admin'
                   Foreground='#60A5FA'
                   FontSize='26'
                   Margin='0,0,0,20'/>

        <TextBlock Text='Username (fsi.local\admin)' Foreground='#E2E8F0'/>
        <TextBox x:Name='TBUser' Margin='0,5,0,15'/>

        <TextBlock Text='Password' Foreground='#E2E8F0'/>
        <PasswordBox x:Name='TBPass' Margin='0,5,0,15'/>

        <Button x:Name='SaveCredsBtn' Style='{StaticResource AzureCard}' 
                Margin='0,20,0,10'>Salva Credenziali</Button>

        <Button x:Name='RunAsBtn' Style='{StaticResource AzureCard}'>Avvia ADUC come Admin</Button>
    </StackPanel>
</Grid>
"@

    [xml]$xmlUI = $ui
    $readerUI = New-Object System.Xml.XmlNodeReader $xmlUI
    $panel = [Windows.Markup.XamlReader]::Load($readerUI)

    $panel.FindName("SaveCredsBtn").Add_Click({
        Save-Creds ($panel.FindName("TBUser").Text) ($panel.FindName("TBPass").Password)
    })

    $panel.FindName("RunAsBtn").Add_Click({
        RunAs-ADUC
    })

    $MainContent.Content = $panel
})

$BtnSearch.Add_Click({
    $query = Read-Host "Inserisci il nome utente da cercare"
    Search-ADUser $query
})

# ============================
# RUN APP
# ============================
$Window.ShowDialog()
