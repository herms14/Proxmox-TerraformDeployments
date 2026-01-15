# =============================================================================
# Enable PowerShell Remoting
# =============================================================================
# This script enables and configures PowerShell remoting for Ansible management.
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Enabling PowerShell Remoting..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if PS Remoting is already enabled (avoid restarting WinRM if already configured)
$remotingEnabled = $false
try {
    $winrmService = Get-Service WinRM -ErrorAction Stop
    $listener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"} -ErrorAction SilentlyContinue
    if ($winrmService.Status -eq 'Running' -and $listener) {
        $remotingEnabled = $true
        Write-Host "PS Remoting is already enabled, skipping Enable-PSRemoting to avoid connection drop" -ForegroundColor Green
    }
} catch {
    Write-Host "WinRM not configured, will enable..." -ForegroundColor Yellow
}

# Enable PowerShell Remoting (only if not already enabled)
if (-not $remotingEnabled) {
    Write-Host "Enabling PS Remoting..." -ForegroundColor Yellow
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}

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

# Configure PSSessionConfiguration for remoting (skip if already running to avoid restart)
if (-not $remotingEnabled) {
    Write-Host "Configuring PSSessionConfiguration..." -ForegroundColor Yellow
    Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI:$false -Force
} else {
    Write-Host "Skipping PSSessionConfiguration (already configured)" -ForegroundColor Green
}

# Enable CredSSP for double-hop authentication (useful for domain environments)
Write-Host "Enabling CredSSP Server..." -ForegroundColor Yellow
Enable-WSManCredSSP -Role Server -Force

# Configure WinRM for Ansible
Write-Host "Additional WinRM configuration for Ansible..." -ForegroundColor Yellow

# Set MaxMemoryPerShellMB
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024

# Set MaxConcurrentOperationsPerUser
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 4294967295

# Note: Not restarting WinRM here to avoid breaking Packer connection
# WinRM will pick up changes on next connection
Write-Host "WinRM configuration updated (no restart needed)" -ForegroundColor Yellow

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
