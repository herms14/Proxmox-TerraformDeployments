# ==============================================================================
# Check Windows VM Internet Connectivity
# ==============================================================================
# Run this script on Azure Domain Controllers to verify internet connectivity
# and prepare for Azure Monitor Agent installation.
#
# Usage:
#   1. RDP to AZDC01 (10.10.4.4)
#   2. Open PowerShell as Administrator
#   3. Run: .\check-windows-vm-internet.ps1
#
# ==============================================================================

param(
    [switch]$Fix
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Windows VM Internet Connectivity Checker" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Store results
$results = @{
    Hostname = $env:COMPUTERNAME
    DNS = $false
    Internet = $false
    AzureMonitor = $false
    AzureLogin = $false
    Proxy = $null
}

# -----------------------------------------------------------------------------
# Check 1: DNS Resolution
# -----------------------------------------------------------------------------
Write-Host "[1/5] Checking DNS resolution..." -ForegroundColor Yellow

try {
    $dnsTest = Resolve-DnsName "management.azure.com" -ErrorAction Stop
    if ($dnsTest) {
        Write-Host "  [OK] DNS resolution working" -ForegroundColor Green
        $results.DNS = $true
    }
} catch {
    Write-Host "  [FAIL] DNS resolution failed" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# Check 2: General Internet Connectivity
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/5] Checking general internet connectivity..." -ForegroundColor Yellow

$internetEndpoints = @(
    @{Name = "Microsoft"; URL = "https://www.microsoft.com"},
    @{Name = "Google"; URL = "https://www.google.com"}
)

foreach ($endpoint in $internetEndpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.URL -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  [OK] $($endpoint.Name) reachable" -ForegroundColor Green
            $results.Internet = $true
        }
    } catch {
        Write-Host "  [FAIL] $($endpoint.Name) not reachable" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Check 3: Azure Monitor Agent Endpoints
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/5] Checking Azure Monitor Agent endpoints..." -ForegroundColor Yellow

$azureEndpoints = @(
    @{Name = "Azure Management"; URL = "https://management.azure.com"; Port = 443},
    @{Name = "Azure Monitor"; URL = "https://global.handler.control.monitor.azure.com"; Port = 443},
    @{Name = "Azure Login"; URL = "https://login.microsoftonline.com"; Port = 443},
    @{Name = "Azure Monitor Ingest"; URL = "https://southeastasia.handler.control.monitor.azure.com"; Port = 443}
)

foreach ($endpoint in $azureEndpoints) {
    try {
        $tcpTest = Test-NetConnection -ComputerName ([System.Uri]$endpoint.URL).Host -Port $endpoint.Port -WarningAction SilentlyContinue
        if ($tcpTest.TcpTestSucceeded) {
            Write-Host "  [OK] $($endpoint.Name) ($($endpoint.Port))" -ForegroundColor Green
            if ($endpoint.Name -eq "Azure Monitor") { $results.AzureMonitor = $true }
            if ($endpoint.Name -eq "Azure Login") { $results.AzureLogin = $true }
        } else {
            Write-Host "  [FAIL] $($endpoint.Name)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [FAIL] $($endpoint.Name) - Error: $_" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# Check 4: Proxy Settings
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/5] Checking proxy configuration..." -ForegroundColor Yellow

$proxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
if ($proxySettings.ProxyEnable -eq 1) {
    Write-Host "  [INFO] Proxy enabled: $($proxySettings.ProxyServer)" -ForegroundColor Yellow
    $results.Proxy = $proxySettings.ProxyServer
} else {
    Write-Host "  [OK] No proxy configured" -ForegroundColor Green
}

# Check system proxy
$envProxy = $env:HTTP_PROXY, $env:HTTPS_PROXY | Where-Object { $_ }
if ($envProxy) {
    Write-Host "  [INFO] Environment proxy: $envProxy" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Check 5: Network Configuration
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/5] Checking network configuration..." -ForegroundColor Yellow

$ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }
foreach ($adapter in $ipConfig) {
    Write-Host "  Interface: $($adapter.InterfaceAlias)" -ForegroundColor Cyan
    Write-Host "    IP Address: $($adapter.IPv4Address.IPAddress)" -ForegroundColor White
    Write-Host "    Gateway:    $($adapter.IPv4DefaultGateway.NextHop)" -ForegroundColor White
    Write-Host "    DNS:        $($adapter.DNSServer.ServerAddresses -join ', ')" -ForegroundColor White
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Summary for $($results.Hostname)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$overall = $results.DNS -and $results.Internet -and $results.AzureMonitor -and $results.AzureLogin

if ($overall) {
    Write-Host "  [SUCCESS] All connectivity checks passed!" -ForegroundColor Green
    Write-Host "  Ready for Azure Monitor Agent installation." -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Some checks failed:" -ForegroundColor Yellow
    if (-not $results.DNS) { Write-Host "    - DNS resolution" -ForegroundColor Red }
    if (-not $results.Internet) { Write-Host "    - Internet connectivity" -ForegroundColor Red }
    if (-not $results.AzureMonitor) { Write-Host "    - Azure Monitor endpoints" -ForegroundColor Red }
    if (-not $results.AzureLogin) { Write-Host "    - Azure Login endpoints" -ForegroundColor Red }
}

# -----------------------------------------------------------------------------
# Fix Suggestions
# -----------------------------------------------------------------------------
if (-not $overall) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "  Troubleshooting Steps" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow

    if (-not $results.DNS) {
        Write-Host "  DNS Issues:" -ForegroundColor Yellow
        Write-Host "    1. Check DNS server settings in network adapter" -ForegroundColor White
        Write-Host "    2. Verify DNS server is reachable" -ForegroundColor White
        Write-Host "    3. Try using Azure DNS: 168.63.129.16" -ForegroundColor White
    }

    if (-not $results.Internet) {
        Write-Host "  Internet Issues:" -ForegroundColor Yellow
        Write-Host "    1. Check NSG rules allow outbound traffic" -ForegroundColor White
        Write-Host "    2. Verify NAT gateway or public IP is configured" -ForegroundColor White
        Write-Host "    3. Check routing table for default route" -ForegroundColor White
    }

    if ($Fix) {
        Write-Host ""
        Write-Host "  Attempting automatic fixes..." -ForegroundColor Cyan

        # Try to fix DNS by adding Azure DNS
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($adapter) {
            Write-Host "  Adding Azure DNS (168.63.129.16) as secondary DNS..." -ForegroundColor White
            $currentDNS = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4).ServerAddresses
            $newDNS = $currentDNS + "168.63.129.16" | Select-Object -Unique
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $newDNS
            Write-Host "  DNS updated. Please re-run this script to verify." -ForegroundColor Green
        }
    }
}

Write-Host ""
return $results
