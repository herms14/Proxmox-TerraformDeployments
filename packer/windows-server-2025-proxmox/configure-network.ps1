# configure-network.ps1
# Configures static IP for VirtIO network adapter

$maxRetries = 10
$retryCount = 0

# Wait for VirtIO network adapter to appear
while ($retryCount -lt $maxRetries) {
    $adapter = Get-NetAdapter | Where-Object {
        ($_.InterfaceDescription -like '*VirtIO*') -or
        ($_.InterfaceDescription -like '*Red Hat*')
    } | Select-Object -First 1

    if ($adapter) {
        Write-Host "Found VirtIO adapter: $($adapter.Name)"
        break
    }

    Write-Host "Waiting for VirtIO adapter... (attempt $($retryCount + 1)/$maxRetries)"
    Start-Sleep -Seconds 3
    $retryCount++
}

if (-not $adapter) {
    Write-Host "VirtIO adapter not found, trying any available adapter"
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
}

if ($adapter) {
    Write-Host "Configuring IP on adapter: $($adapter.Name)"

    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue

    # Set static IP
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
        -IPAddress 192.168.20.99 `
        -PrefixLength 24 `
        -DefaultGateway 192.168.20.1 `
        -ErrorAction Stop

    # Set DNS
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
        -ServerAddresses 192.168.90.53

    Write-Host "Network configuration complete"
    Write-Host "IP: 192.168.20.99/24"
    Write-Host "Gateway: 192.168.20.1"
    Write-Host "DNS: 192.168.90.53"
} else {
    Write-Host "ERROR: No network adapter found"
    exit 1
}
