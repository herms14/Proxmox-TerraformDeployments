# =============================================================================
# Enable PowerShell Remoting for Windows Server 2025
# =============================================================================
# This script enables and configures PowerShell remoting for Ansible management.
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Enabling PowerShell Remoting..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Enable PowerShell Remoting
Write-Host "Enabling PS Remoting..." -ForegroundColor Yellow
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure TrustedHosts to allow all hosts (for lab environment)
Write-Host "Configuring TrustedHosts..." -ForegroundColor Yellow
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Configure execution policy (ignore errors if already set at higher scope)
Write-Host "Setting execution policy..." -ForegroundColor Yellow
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
} catch {
    Write-Host "Execution policy note: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Configure PSSessionConfiguration for remoting
Write-Host "Configuring PSSessionConfiguration..." -ForegroundColor Yellow
Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI:$false -Force

# Enable CredSSP for double-hop authentication (useful for domain environments)
Write-Host "Enabling CredSSP Server..." -ForegroundColor Yellow
Enable-WSManCredSSP -Role Server -Force

# Configure WinRM for Ansible
Write-Host "Additional WinRM configuration for Ansible..." -ForegroundColor Yellow

# Set MaxMemoryPerShellMB (increased for WS2025)
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 2048

# Set MaxConcurrentOperationsPerUser
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 4294967295

# Disable UAC remote restrictions (lab environment only)
Write-Host "Disabling UAC remote restrictions..." -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $regPath -Name EnableLUA -Value 0 -ErrorAction SilentlyContinue

# Enable Remote Registry service
Write-Host "Enabling Remote Registry service..." -ForegroundColor Yellow
Set-Service -Name RemoteRegistry -StartupType Automatic
Start-Service -Name RemoteRegistry -ErrorAction SilentlyContinue

# Restart WinRM to apply all changes
Write-Host "Restarting WinRM..." -ForegroundColor Yellow
Restart-Service WinRM

# Test local PSSession
Write-Host "Testing local PSSession..." -ForegroundColor Yellow
try {
    $session = New-PSSession -ComputerName localhost -ErrorAction Stop
    Remove-PSSession $session
    Write-Host "Local PSSession test: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "Local PSSession test: FAILED - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "PowerShell Remoting enabled successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
