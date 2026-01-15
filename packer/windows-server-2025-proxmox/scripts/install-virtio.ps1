# =============================================================================
# Install VirtIO Drivers and QEMU Guest Agent for Windows Server 2025
# =============================================================================
# This script installs VirtIO drivers from the mounted ISO and the QEMU
# Guest Agent for better Proxmox integration.
# Supports both 2k25 (if available) and 2k22 driver versions.
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installing VirtIO Drivers (WS2025)..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Find the VirtIO ISO drive letter
$virtIODrive = $null
Get-Volume | ForEach-Object {
    $driveLetter = $_.DriveLetter
    if ($driveLetter) {
        $testPath = "${driveLetter}:\guest-agent"
        if (Test-Path $testPath) {
            $virtIODrive = "${driveLetter}:"
            Write-Host "Found VirtIO ISO at $virtIODrive" -ForegroundColor Green
        }
    }
}

if (-not $virtIODrive) {
    Write-Host "VirtIO ISO not found, checking default locations..." -ForegroundColor Yellow
    $defaultDrives = @("E:", "D:", "F:")
    foreach ($drive in $defaultDrives) {
        if (Test-Path "${drive}\vioscsi") {
            $virtIODrive = $drive
            Write-Host "Found VirtIO ISO at $virtIODrive" -ForegroundColor Green
            break
        }
    }
}

if (-not $virtIODrive) {
    Write-Host "VirtIO ISO not found! Skipping driver installation." -ForegroundColor Red
    exit 0
}

# Install QEMU Guest Agent
Write-Host "Installing QEMU Guest Agent..." -ForegroundColor Yellow
$guestAgentMsi = Get-ChildItem -Path "${virtIODrive}\guest-agent\" -Filter "qemu-ga-x86_64.msi" -ErrorAction SilentlyContinue

if ($guestAgentMsi) {
    Write-Host "Installing $($guestAgentMsi.Name)..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/i", $guestAgentMsi.FullName, "/quiet", "/norestart" -Wait -NoNewWindow
    Write-Host "QEMU Guest Agent installed" -ForegroundColor Green
} else {
    Write-Host "QEMU Guest Agent MSI not found, skipping..." -ForegroundColor Yellow
}

# Determine which driver version to use (2k25 if available, else 2k22)
$driverVersion = "2k22"
if (Test-Path "${virtIODrive}\vioscsi\2k25\amd64") {
    $driverVersion = "2k25"
    Write-Host "Using Windows Server 2025 specific drivers (2k25)" -ForegroundColor Green
} else {
    Write-Host "2k25 drivers not found, using 2k22 drivers (compatible)" -ForegroundColor Yellow
}

# Install VirtIO drivers using pnputil
Write-Host "Installing VirtIO drivers via pnputil (version: $driverVersion)..." -ForegroundColor Yellow

$driverFolders = @(
    "vioscsi",
    "NetKVM",
    "Balloon",
    "qxldod",
    "viorng",
    "vioserial",
    "pvpanic",
    "qemupciserial"
)

foreach ($folder in $driverFolders) {
    # Try 2k25 first, then 2k22
    $driverPath = "${virtIODrive}\${folder}\2k25\amd64"
    if (-not (Test-Path $driverPath)) {
        $driverPath = "${virtIODrive}\${folder}\2k22\amd64"
    }

    if (Test-Path $driverPath) {
        $infFiles = Get-ChildItem -Path $driverPath -Filter "*.inf"
        foreach ($inf in $infFiles) {
            Write-Host "Installing driver: $folder - $($inf.Name)" -ForegroundColor Yellow
            pnputil.exe /add-driver $inf.FullName /install 2>&1 | Out-Null
        }
    } else {
        Write-Host "Driver not found: $folder" -ForegroundColor DarkGray
    }
}

# Set QEMU Guest Agent service to auto-start
Write-Host "Configuring QEMU Guest Agent service..." -ForegroundColor Yellow
$qemuService = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
if ($qemuService) {
    Set-Service -Name "QEMU-GA" -StartupType Automatic
    Start-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
    Write-Host "QEMU Guest Agent service configured" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "VirtIO driver installation completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
