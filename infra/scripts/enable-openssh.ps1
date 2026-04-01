# ──────────────────────────────────────────────────────────────
# Enable OpenSSH Server on Windows 11
# Runs as a Custom Script Extension at VM provisioning time.
#
# What it does:
#   1. Installs the OpenSSH.Server Windows capability
#   2. Starts and enables the sshd service
#   3. Sets the default SSH shell to powershell.exe
#   4. Ensures the Windows Firewall allows inbound SSH (port 22)
#
# After bootstrap-copilot.ps1 runs and installs PowerShell 7,
# the default shell can be updated to pwsh.exe if desired.
# ──────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Stop'

Write-Output '=== OpenSSH Setup: Starting ==='

# 1. Install OpenSSH Server capability
$sshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshServer.State -ne 'Installed') {
    Write-Output 'Installing OpenSSH.Server capability...'
    Add-WindowsCapability -Online -Name $sshServer.Name
    Write-Output '✅ OpenSSH.Server installed'
}
else {
    Write-Output '✅ OpenSSH.Server already installed'
}

# 2. Start and enable the sshd service
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
Write-Output '✅ sshd service started and set to Automatic'

# 3. Set default shell to PowerShell (Windows PowerShell 5.1)
#    This ensures SSH sessions land in a PowerShell prompt.
$regPath = 'HKLM:\SOFTWARE\OpenSSH'
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
New-ItemProperty -Path $regPath `
    -Name 'DefaultShell' `
    -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -PropertyType String -Force | Out-Null
Write-Output '✅ Default SSH shell set to powershell.exe'

# 4. Ensure Windows Firewall allows SSH inbound
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $rule) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP `
        -Action Allow -LocalPort 22
    Write-Output '✅ Firewall rule created for SSH (port 22)'
}
else {
    Write-Output '✅ Firewall rule for SSH already exists'
}

# 5. Restart sshd to apply DefaultShell change
Restart-Service sshd
Write-Output '✅ sshd restarted with new default shell'

Write-Output '=== OpenSSH Setup: Complete ==='
