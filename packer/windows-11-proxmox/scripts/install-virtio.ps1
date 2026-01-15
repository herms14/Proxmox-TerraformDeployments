# =============================================================================
# Install VirtIO Drivers and QEMU Guest Agent for Windows 11
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installing VirtIO Drivers (Win11)..." -ForegroundColor Cyan
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
    Start-Process msiexec.exe -ArgumentList "/i", $guestAgentMsi.FullName, "/quiet", "/norestart" -Wait -NoNewWindow
    Write-Host "QEMU Guest Agent installed" -ForegroundColor Green
}

# Install VirtIO drivers (w11 folder for Windows 11)
Write-Host "Installing VirtIO drivers via pnputil (w11)..." -ForegroundColor Yellow

$driverFolders = @("vioscsi", "NetKVM", "Balloon", "qxldod", "viorng", "vioserial", "pvpanic")

foreach ($folder in $driverFolders) {
    $driverPath = "${virtIODrive}\${folder}\w11\amd64"
    if (Test-Path $driverPath) {
        $infFiles = Get-ChildItem -Path $driverPath -Filter "*.inf"
        foreach ($inf in $infFiles) {
            Write-Host "Installing driver: $folder - $($inf.Name)" -ForegroundColor Yellow
            pnputil.exe /add-driver $inf.FullName /install 2>&1 | Out-Null
        }
    }
}

# Configure QEMU Guest Agent service
$qemuService = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
if ($qemuService) {
    Set-Service -Name "QEMU-GA" -StartupType Automatic
    Start-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "VirtIO driver installation completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
