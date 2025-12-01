🔵 RSAT Dashboard — Modern Azure Edition

Windows RSAT administration dashboard with auto-update, Azure-styled UI, and WPF interface.

✨ Features

Modern Azure UI

WPF engine

RSAT tool launcher

AD search (Live LDAP query)

RunAs with DPAPI-encrypted credentials

Auto-Update system (GitHub versioning)

Azure “Card” layout (dashboard style)

Sidebar compact navigation

Error logging & safe fallback

📦 Included Tools

Active Directory Users & Computers

AD Sites & Services

AD Domains & Trusts

GPMC

DNS Manager

DHCP Manager

Failover Cluster Manager

Certificate Authority

Volume Activation

Server Manager

🔄 Auto-Update System

The dashboard checks:

version.txt
update.zip


from GitHub using raw URLs:

https://raw.githubusercontent.com/<username>/rsat-dashboard/main/version.txt
https://raw.githubusercontent.com/<username>/rsat-dashboard/main/update.zip


If the version is newer, it automatically:

✔ downloads update.zip
✔ extracts it into C:\RSATDashboard
✔ relaunches the dashboard

🛠 How to Build Updates

Run:

BuildUpdate.ps1 -push


This will:

✔ auto-increment version
✔ create update.zip
✔ commit & push to GitHub (if git is configured)

📂 Folder Structure
C:\RSATDashboard\
    RSATDashboard.ps1
    RSATDashboard.xaml
    rsat_ad_icon_multi.ico
    logs\

⚙ Requirements

Windows 10/11

RSAT Installed

PowerShell 5.1+

📝 License

MIT License (optional)
