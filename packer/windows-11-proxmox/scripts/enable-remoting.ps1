# =============================================================================
# Enable PowerShell Remoting for Windows 11
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Enabling PowerShell Remoting..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
} catch {
    Write-Host "Execution policy note: $($_.Exception.Message)" -ForegroundColor Yellow
}

Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI:$false -Force
Enable-WSManCredSSP -Role Server -Force

Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 2048
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 4294967295

# Disable UAC remote restrictions (lab environment)
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $regPath -Name EnableLUA -Value 0 -ErrorAction SilentlyContinue

# Enable Remote Registry
Set-Service -Name RemoteRegistry -StartupType Automatic
Start-Service -Name RemoteRegistry -ErrorAction SilentlyContinue

Restart-Service WinRM

Write-Host "========================================" -ForegroundColor Green
Write-Host "PowerShell Remoting enabled successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
