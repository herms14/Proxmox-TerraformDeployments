# =============================================================================
# Setup WinRM for Packer/Ansible Connectivity - Windows 11
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setting up WinRM for Packer..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Ensure network is Private (required for WinRM)
Write-Host "Setting network profile to Private..." -ForegroundColor Yellow
try {
    $networkProfiles = Get-NetConnectionProfile
    foreach ($profile in $networkProfiles) {
        Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "Warning: Could not set network profile. Continuing..." -ForegroundColor Yellow
}

# Configure WinRM service
Write-Host "Configuring WinRM service..." -ForegroundColor Yellow
winrm quickconfig -quiet

Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

winrm set winrm/config '@{MaxTimeoutms="7200000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config '@{MaxEnvelopeSizekb="8192"}'

# Configure WinRM listener
Write-Host "Configuring WinRM HTTP listener..." -ForegroundColor Yellow
$selector_set = @{ Address = "*"; Transport = "HTTP" }

try { Remove-WSManInstance -ResourceURI 'winrm/config/listener' -SelectorSet $selector_set -ErrorAction SilentlyContinue } catch { }

New-WSManInstance -ResourceURI 'winrm/config/listener' -SelectorSet $selector_set -ValueSet @{ Port = 5985 }

# Configure Windows Firewall
Write-Host "Configuring Windows Firewall for WinRM..." -ForegroundColor Yellow
Remove-NetFirewallRule -DisplayName "WinRM HTTP" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 -Profile Any -Enabled True

# Set LocalAccountTokenFilterPolicy
Write-Host "Configuring LocalAccountTokenFilterPolicy..." -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
New-ItemProperty -Path $regPath -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWORD -Force | Out-Null

Restart-Service WinRM

Write-Host "========================================" -ForegroundColor Green
Write-Host "WinRM setup completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
