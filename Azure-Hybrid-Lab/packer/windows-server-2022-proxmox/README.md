# Windows Server 2022 Packer Template for Proxmox VE

Automated Windows Server 2022 template creation for Proxmox VE with fully unattended installation and deployment.

## Overview

This Packer template creates a Windows Server 2022 Datacenter base image on Proxmox with:

- **Fully Automated Installation**: No manual intervention required during build
- **VirtIO Drivers**: Pre-installed for optimal disk and network performance
- **QEMU Guest Agent**: Installed for Proxmox integration
- **WinRM Enabled**: Ready for Ansible/Packer connectivity
- **Sysprep with Unattend**: Cloned VMs boot directly to desktop without OOBE prompts
- **UEFI Boot**: Modern boot configuration with Secure Boot support

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PACKER BUILD PROCESS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. CREATE VM          2. BOOT WINDOWS        3. UNATTENDED INSTALL     │
│  ┌──────────────┐      ┌──────────────┐       ┌──────────────┐          │
│  │ Proxmox API  │ ───► │ Windows ISO  │ ───► │autounattend  │          │
│  │ Creates VM   │      │ Boot from CD │       │.xml drives   │          │
│  │ ID: 9022     │      │              │       │installation  │          │
│  └──────────────┘      └──────────────┘       └──────────────┘          │
│                                                      │                   │
│  6. CONVERT TO         5. RUN SYSPREP         4. WINRM CONNECT         │
│     TEMPLATE                                                             │
│  ┌──────────────┐      ┌──────────────┐       ┌──────────────┐          │
│  │ VM becomes   │ ◄─── │ Generalize   │ ◄─── │ Packer runs  │          │
│  │ Template     │      │ with unattend│       │ provisioners │          │
│  │ Ready clone  │      │ for OOBE skip│       │ via WinRM    │          │
│  └──────────────┘      └──────────────┘       └──────────────┘          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Files Structure

```
packer/windows-server-2022-proxmox/
├── windows-server-2022.pkr.hcl    # Main Packer template
├── autounattend.xml               # Windows installation answer file
├── sysprep-unattend.xml           # Post-sysprep OOBE automation
├── variables.pkrvars.hcl          # Build variables (gitignored)
├── variables.pkrvars.hcl.example  # Variable template
├── README.md                      # This documentation
└── scripts/
    ├── setup-winrm.ps1            # WinRM configuration
    ├── enable-remoting.ps1        # PowerShell remoting setup
    └── install-virtio.ps1         # VirtIO driver installation
```

---

## Detailed File Explanations

### 1. windows-server-2022.pkr.hcl (Main Packer Template)

The main Packer template that orchestrates the entire build process.

#### Required Plugins

```hcl
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
    windows-update = {
      version = ">= 0.14.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}
```

- **proxmox**: Hashicorp's official Proxmox builder plugin
- **windows-update**: Optional plugin for installing Windows Updates during build

#### VM Hardware Configuration

```hcl
source "proxmox-iso" "ws2022" {
  # Hardware
  cores      = var.vm_cores       # Default: 2
  memory     = var.vm_memory      # Default: 4096 MB
  cpu_type   = "host"             # Pass-through host CPU features
  os         = "win10"            # Windows 10/Server 2019+ type
  bios       = "ovmf"             # UEFI boot (required for modern Windows)
  machine    = "q35"              # Modern chipset with PCIe support
  qemu_agent = true               # Enable QEMU guest agent channel

  # EFI Settings (required for UEFI)
  efi_config {
    efi_storage_pool  = var.proxmox_storage
    efi_type          = "4m"
    pre_enrolled_keys = true      # Secure Boot keys pre-enrolled
  }

  # Disk - VirtIO SCSI for best performance
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = "60G"
    storage_pool = var.proxmox_storage
    format       = "raw"          # Raw format for best performance
    io_thread    = true           # Enable IO threads
  }

  # Network - VirtIO on VLAN 80
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    vlan_tag = 80                 # Azure Hybrid Lab VLAN
  }
}
```

#### ISO Configuration

```hcl
# Primary ISO - Windows Server 2022 installation media
iso_file = "${var.proxmox_iso_storage}:iso/${var.ws2022_iso_file}"

# Additional ISO 1 - VirtIO drivers
additional_iso_files {
  device   = "sata1"
  iso_file = "${var.proxmox_iso_storage}:iso/${var.virtio_iso_file}"
}

# Additional ISO 2 - Custom CD with scripts
additional_iso_files {
  device   = "sata2"
  cd_files = [
    "${path.root}/autounattend.xml",
    "${path.root}/scripts/setup-winrm.ps1",
    "${path.root}/scripts/enable-remoting.ps1",
    "${path.root}/scripts/install-virtio.ps1",
    "${path.root}/sysprep-unattend.xml"
  ]
  cd_label = "OEMDRV"             # Windows looks for this label
}
```

The CD is labeled "OEMDRV" because Windows Setup automatically searches for `autounattend.xml` on drives with this label.

#### Boot Configuration

```hcl
boot         = "order=ide2"       # Boot from CD-ROM first (Windows ISO)
boot_wait    = "3s"               # Wait for UEFI to initialize
boot_command = ["<spacebar><spacebar><spacebar>"]  # "Press any key to boot from CD"
```

#### WinRM Communicator

```hcl
communicator   = "winrm"
winrm_username = var.admin_username    # "Administrator"
winrm_password = var.admin_password    # Set in variables
winrm_timeout  = "4h"                  # Long timeout for Windows install
winrm_use_ssl  = false                 # Use HTTP (port 5985)
winrm_insecure = true
winrm_port     = 5985
winrm_host     = "192.168.80.99"       # Static IP configured in autounattend.xml
```

The static IP `192.168.80.99` is configured during Windows installation via `autounattend.xml`, allowing Packer to connect reliably.

#### Provisioners (Build Steps)

```hcl
build {
  # 1. Verify WinRM connection
  provisioner "powershell" {
    inline = ["Write-Host 'WinRM is available!'"]
  }

  # 2. Install QEMU Guest Agent
  provisioner "powershell" {
    inline = [
      "$installer = Get-ChildItem -Path 'E:\\guest-agent\\' -Filter 'qemu-ga-x86_64.msi'",
      "Start-Process msiexec.exe -ArgumentList '/i', $installer.FullName, '/quiet' -Wait"
    ]
  }

  # 3. Configure PowerShell remoting (idempotent)
  provisioner "powershell" {
    script = "${path.root}/scripts/enable-remoting.ps1"
  }

  # 4. Windows Updates (optional)
  dynamic "provisioner" {
    labels   = ["windows-update"]
    for_each = var.skip_windows_updates ? [] : [1]
    content {
      search_criteria = "IsInstalled=0"
      update_limit    = 50
    }
  }

  # 5. Final configuration (firewall, RDP, power settings)
  provisioner "powershell" {
    inline = [
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'",
      "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",  # High Performance
      "powercfg /hibernate off"
    ]
  }

  # 6. Copy sysprep unattend file
  provisioner "powershell" {
    inline = [
      "$oem = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'OEMDRV' }",
      "$src = $oem.DriveLetter + ':\\sysprep-unattend.xml'",
      "Copy-Item -Path $src -Destination 'C:\\Windows\\System32\\Sysprep\\unattend.xml' -Force"
    ]
  }

  # 7. Run Sysprep to generalize the image
  provisioner "powershell" {
    inline = [
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /generalize /oobe /shutdown /quiet /unattend:C:\\Windows\\System32\\Sysprep\\unattend.xml"
    ]
  }
}
```

---

### 2. autounattend.xml (Windows Installation Answer File)

This XML file automates the entire Windows installation process without any user interaction.

#### Windows PE Phase (Initial Setup)

```xml
<settings pass="windowsPE">
    <!-- Regional Settings -->
    <component name="Microsoft-Windows-International-Core-WinPE">
        <SetupUILanguage>
            <UILanguage>en-US</UILanguage>
        </SetupUILanguage>
        <InputLocale>en-US</InputLocale>
        <SystemLocale>en-US</SystemLocale>
    </component>
```

#### VirtIO Driver Loading

Windows Setup cannot see VirtIO disks without loading drivers first. We specify multiple drive letters because the VirtIO ISO can be assigned different letters:

```xml
<component name="Microsoft-Windows-PnpCustomizationsWinPE">
    <DriverPaths>
        <!-- Drive D: paths -->
        <PathAndCredentials wcm:action="add" wcm:keyValue="1">
            <Path>D:\vioscsi\2k22\amd64</Path>
        </PathAndCredentials>
        <PathAndCredentials wcm:action="add" wcm:keyValue="2">
            <Path>D:\NetKVM\2k22\amd64</Path>
        </PathAndCredentials>
        <!-- Drive E: paths (fallback) -->
        <PathAndCredentials wcm:action="add" wcm:keyValue="4">
            <Path>E:\vioscsi\2k22\amd64</Path>
        </PathAndCredentials>
        <!-- Drive F: paths (fallback) -->
        <PathAndCredentials wcm:action="add" wcm:keyValue="7">
            <Path>F:\vioscsi\2k22\amd64</Path>
        </PathAndCredentials>
    </DriverPaths>
</component>
```

**Driver Paths Explained:**
- `vioscsi` - VirtIO SCSI controller driver (required to see the disk)
- `NetKVM` - VirtIO network driver (required for network connectivity)
- `Balloon` - Memory ballooning driver (dynamic memory management)
- `2k22` - Windows Server 2022 specific drivers
- `amd64` - 64-bit architecture

#### Disk Configuration (GPT/UEFI)

```xml
<DiskConfiguration>
    <Disk wcm:action="add">
        <DiskID>0</DiskID>
        <WillWipeDisk>true</WillWipeDisk>
        <CreatePartitions>
            <!-- EFI System Partition (260 MB) -->
            <CreatePartition wcm:action="add">
                <Order>1</Order>
                <Size>260</Size>
                <Type>EFI</Type>
            </CreatePartition>
            <!-- Microsoft Reserved Partition (16 MB) -->
            <CreatePartition wcm:action="add">
                <Order>2</Order>
                <Size>16</Size>
                <Type>MSR</Type>
            </CreatePartition>
            <!-- Windows Partition (rest of disk) -->
            <CreatePartition wcm:action="add">
                <Order>3</Order>
                <Extend>true</Extend>
                <Type>Primary</Type>
            </CreatePartition>
        </CreatePartitions>
        <ModifyPartitions>
            <ModifyPartition wcm:action="add">
                <Order>1</Order>
                <PartitionID>1</PartitionID>
                <Label>System</Label>
                <Format>FAT32</Format>
            </ModifyPartition>
            <ModifyPartition wcm:action="add">
                <Order>3</Order>
                <PartitionID>3</PartitionID>
                <Label>Windows</Label>
                <Letter>C</Letter>
                <Format>NTFS</Format>
            </ModifyPartition>
        </ModifyPartitions>
    </Disk>
</DiskConfiguration>
```

**Partition Layout:**
| Partition | Size | Type | Format | Purpose |
|-----------|------|------|--------|---------|
| 1 | 260 MB | EFI | FAT32 | UEFI boot loader |
| 2 | 16 MB | MSR | - | Microsoft Reserved |
| 3 | Remaining | Primary | NTFS | Windows OS |

#### Windows Edition Selection

```xml
<ImageInstall>
    <OSImage>
        <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
        </InstallTo>
        <InstallFrom>
            <MetaData wcm:action="add">
                <Key>/IMAGE/NAME</Key>
                <Value>Windows Server 2022 SERVERDATACENTER</Value>
            </MetaData>
        </InstallFrom>
        <WillShowUI>Never</WillShowUI>
    </OSImage>
</ImageInstall>
```

The `Value` must match exactly the image name in the ISO. Use `dism /Get-ImageInfo /ImageFile:sources\install.wim` to list available images.

#### Product Key

```xml
<UserData>
    <AcceptEula>true</AcceptEula>
    <ProductKey>
        <Key>NTRM9-VKKQQ-RDFG7-XYTMJ-GVM4V</Key>  <!-- Evaluation/KMS key -->
        <WillShowUI>OnError</WillShowUI>
    </ProductKey>
</UserData>
```

This is a KMS Generic Volume License Key (GVLK) for Windows Server 2022 Datacenter. It allows installation without activation prompts.

#### First Logon Commands

These commands run automatically after Windows installation completes:

```xml
<FirstLogonCommands>
    <!-- 1. Set PowerShell execution policy -->
    <SynchronousCommand wcm:action="add">
        <Order>1</Order>
        <CommandLine>powershell -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Unrestricted -Force"</CommandLine>
    </SynchronousCommand>

    <!-- 2. Disable Windows Defender real-time monitoring (for Packer) -->
    <SynchronousCommand wcm:action="add">
        <Order>2</Order>
        <CommandLine>powershell -ExecutionPolicy Bypass -Command "Set-MpPreference -DisableRealtimeMonitoring $true -EA 0; Add-MpPreference -ExclusionPath 'C:\Windows\Temp' -EA 0"</CommandLine>
    </SynchronousCommand>

    <!-- 3. Configure static IP for Packer connection -->
    <SynchronousCommand wcm:action="add">
        <Order>3</Order>
        <CommandLine>powershell -ExecutionPolicy Bypass -Command "$a=Get-NetAdapter|?{$_.Status -eq 'Up'}|Select -First 1; New-NetIPAddress -InterfaceIndex $a.ifIndex -IPAddress 192.168.80.99 -PrefixLength 24 -DefaultGateway 192.168.80.1; Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses 8.8.8.8"</CommandLine>
    </SynchronousCommand>

    <!-- 4. Install VirtIO drivers -->
    <SynchronousCommand wcm:action="add">
        <Order>4</Order>
        <CommandLine>powershell -ExecutionPolicy Bypass -Command "$drives = @('D','E','F','G'); foreach($d in $drives){$p=\"${d}:\install-virtio.ps1\"; if(Test-Path $p){&amp; $p; break}}"</CommandLine>
    </SynchronousCommand>

    <!-- 5. Setup WinRM for Packer -->
    <SynchronousCommand wcm:action="add">
        <Order>5</Order>
        <CommandLine>powershell -ExecutionPolicy Bypass -Command "$drives = @('D','E','F','G'); foreach($d in $drives){$p=\"${d}:\setup-winrm.ps1\"; if(Test-Path $p){&amp; $p; break}}"</CommandLine>
    </SynchronousCommand>

    <!-- 6. Enable PowerShell Remoting -->
    <SynchronousCommand wcm:action="add">
        <Order>6</Order>
        <CommandLine>powershell -ExecutionPolicy Bypass -Command "$drives = @('D','E','F','G'); foreach($d in $drives){$p=\"${d}:\enable-remoting.ps1\"; if(Test-Path $p){&amp; $p; break}}"</CommandLine>
    </SynchronousCommand>
</FirstLogonCommands>
```

**Command Execution Order:**
1. **Set-ExecutionPolicy**: Allows PowerShell scripts to run
2. **Disable Defender**: Prevents Defender from deleting Packer's temporary scripts
3. **Configure Network**: Sets static IP 192.168.80.99 so Packer can connect
4. **Install VirtIO**: Runs the VirtIO driver installation script
5. **Setup WinRM**: Configures WinRM for Packer communication
6. **Enable Remoting**: Configures PowerShell remoting for Ansible

---

### 3. sysprep-unattend.xml (Post-Clone OOBE Automation)

This file is copied to `C:\Windows\System32\Sysprep\unattend.xml` before running Sysprep. When cloned VMs boot, Windows uses this file to skip OOBE screens.

#### Specialize Phase

```xml
<settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup">
        <TimeZone>Singapore Standard Time</TimeZone>
        <RegisteredOwner>Administrator</RegisteredOwner>
        <RegisteredOrganization>Azure Hybrid Lab</RegisteredOrganization>
    </component>

    <!-- Disable Server Manager auto-open -->
    <component name="Microsoft-Windows-ServerManager-SvrMgrNc">
        <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
    </component>

    <!-- Enable Remote Desktop -->
    <component name="Microsoft-Windows-TerminalServices-LocalSessionManager">
        <fDenyTSConnections>false</fDenyTSConnections>
    </component>
</settings>
```

#### OOBE Phase (Skip All Prompts)

```xml
<settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup">
        <OOBE>
            <HideEULAPage>true</HideEULAPage>
            <HideLocalAccountScreen>true</HideLocalAccountScreen>
            <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
            <NetworkLocation>Work</NetworkLocation>
            <ProtectYourPC>3</ProtectYourPC>          <!-- Don't send data to Microsoft -->
            <SkipMachineOOBE>true</SkipMachineOOBE>
            <SkipUserOOBE>true</SkipUserOOBE>
        </OOBE>

        <!-- Set Administrator password -->
        <UserAccounts>
            <AdministratorPassword>
                <Value>c@llimachus14</Value>
                <PlainText>true</PlainText>
            </AdministratorPassword>
        </UserAccounts>

        <!-- Auto-login to desktop -->
        <AutoLogon>
            <Password>
                <Value>c@llimachus14</Value>
                <PlainText>true</PlainText>
            </Password>
            <Enabled>true</Enabled>
            <LogonCount>3</LogonCount>
            <Username>Administrator</Username>
        </AutoLogon>

        <!-- Re-enable WinRM on cloned VMs -->
        <FirstLogonCommands>
            <SynchronousCommand wcm:action="add">
                <Order>1</Order>
                <CommandLine>powershell -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Unrestricted -Force"</CommandLine>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
                <Order>2</Order>
                <CommandLine>powershell -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force -SkipNetworkProfileCheck"</CommandLine>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
                <Order>3</Order>
                <CommandLine>powershell -ExecutionPolicy Bypass -Command "winrm quickconfig -quiet"</CommandLine>
            </SynchronousCommand>
        </FirstLogonCommands>
    </component>
</settings>
```

**Key Settings:**
- `SkipMachineOOBE`/`SkipUserOOBE`: Skip all OOBE screens
- `AutoLogon`: Automatically logs in as Administrator (3 times)
- `FirstLogonCommands`: Re-enables WinRM for Ansible connectivity

---

### 4. scripts/setup-winrm.ps1

Configures WinRM for Packer connectivity during the build process.

```powershell
# Set network to Private (required for WinRM)
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# Enable and configure WinRM
winrm quickconfig -quiet
Set-Service -Name WinRM -StartupType Automatic

# Configure WinRM settings
winrm set winrm/config '@{MaxTimeoutms="7200000"}'      # 2 hour timeout
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config '@{MaxEnvelopeSizekb="8192"}'    # Large payload support

# Create HTTP listener on port 5985
$selector = @{Address="*"; Transport="HTTP"}
New-WSManInstance -ResourceURI 'winrm/config/listener' -SelectorSet $selector -ValueSet @{Port=5985}

# Configure firewall
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985

# Enable remote admin access
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name LocalAccountTokenFilterPolicy -Value 1
```

---

### 5. scripts/enable-remoting.ps1

Configures PowerShell remoting for Ansible. **Designed to be idempotent** - checks if remoting is already enabled before making changes that could restart WinRM.

```powershell
# Check if PS Remoting is already enabled (avoid restarting WinRM)
$remotingEnabled = $false
$winrmService = Get-Service WinRM
$listener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"}
if ($winrmService.Status -eq 'Running' -and $listener) {
    $remotingEnabled = $true
    Write-Host "PS Remoting already enabled, skipping Enable-PSRemoting"
}

# Only enable if not already configured (Enable-PSRemoting restarts WinRM)
if (-not $remotingEnabled) {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
}

# Configure TrustedHosts (safe to run multiple times)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Configure PSSessionConfiguration (only if not already enabled)
if (-not $remotingEnabled) {
    Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI:$false -Force
}

# Enable CredSSP for double-hop authentication
Enable-WSManCredSSP -Role Server -Force

# Configure WinRM settings for Ansible
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 4294967295
```

**Why Idempotent?**
This script runs twice:
1. During initial Windows setup (FirstLogonCommands)
2. As a Packer provisioner

If `Enable-PSRemoting` runs during the Packer provisioner, it restarts WinRM and drops the connection. The idempotent check prevents this.

---

### 6. scripts/install-virtio.ps1

Installs VirtIO drivers and QEMU Guest Agent from the mounted ISO.

```powershell
# Find VirtIO ISO (could be D:, E:, or F:)
$virtIODrive = $null
Get-Volume | ForEach-Object {
    $testPath = "$($_.DriveLetter):\guest-agent"
    if (Test-Path $testPath) {
        $virtIODrive = "$($_.DriveLetter):"
    }
}

# Install QEMU Guest Agent
$guestAgentMsi = Get-ChildItem -Path "${virtIODrive}\guest-agent\" -Filter "qemu-ga-x86_64.msi"
Start-Process msiexec.exe -ArgumentList "/i", $guestAgentMsi.FullName, "/quiet", "/norestart" -Wait

# Install VirtIO drivers using pnputil
$driverPaths = @(
    "${virtIODrive}\vioscsi\2k22\amd64",    # SCSI controller
    "${virtIODrive}\NetKVM\2k22\amd64",      # Network
    "${virtIODrive}\Balloon\2k22\amd64",     # Memory balloon
    "${virtIODrive}\qxldod\2k22\amd64",      # Display
    "${virtIODrive}\viorng\2k22\amd64",      # Random number generator
    "${virtIODrive}\vioserial\2k22\amd64",   # Serial port
    "${virtIODrive}\pvpanic\2k22\amd64"      # Panic device
)

foreach ($driverPath in $driverPaths) {
    if (Test-Path $driverPath) {
        $infFiles = Get-ChildItem -Path $driverPath -Filter "*.inf"
        foreach ($inf in $infFiles) {
            pnputil.exe /add-driver $inf.FullName /install
        }
    }
}

# Configure QEMU Guest Agent service
Set-Service -Name "QEMU-GA" -StartupType Automatic
Start-Service -Name "QEMU-GA"
```

---

## Build Process Timeline

| Time | Phase | Actions |
|------|-------|---------|
| 0:00 | VM Creation | Proxmox API creates VM with disks, ISOs |
| 0:01 | Boot | VM boots from Windows ISO |
| 0:02 | Windows PE | `autounattend.xml` loads VirtIO drivers |
| 0:03 | Disk Setup | Creates GPT partitions |
| 0:04-0:08 | Install | Windows copies files, configures system |
| 0:09 | First Boot | Windows completes setup, auto-logs in |
| 0:10 | Scripts | FirstLogonCommands configure network, WinRM |
| 0:11 | WinRM | Packer connects via WinRM |
| 0:12 | Provisioners | Guest agent, remoting, final config |
| 0:13 | Sysprep | Generalizes image with unattend.xml |
| 0:14 | Complete | VM shuts down, converts to template |

**Total Build Time: ~7 minutes** (without Windows Updates)

---

## Prerequisites

### 1. Upload ISOs to Proxmox

| ISO | Purpose | Storage Path |
|-----|---------|--------------|
| Windows Server 2022 | Installation media | `local:iso/ws2022.iso` |
| VirtIO Drivers | Disk/network drivers | `local:iso/virtio-win.iso` |

### 2. Install Packer

```bash
# On Ansible Controller (Ubuntu)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

packer version
```

### 3. Create API Token

On Proxmox:
1. Datacenter → Permissions → API Tokens
2. Add token for `terraform-deployment-user@pve`
3. Note the token ID and secret

### 4. Configure Variables

```bash
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

Edit `variables.pkrvars.hcl`:
```hcl
proxmox_api_url          = "https://192.168.20.22:8006/api2/json"
proxmox_api_token_id     = "terraform-deployment-user@pve!tf"
proxmox_api_token_secret = "your-token-secret"
proxmox_node             = "node03"
ws2022_iso_file          = "ws2022.iso"
virtio_iso_file          = "virtio-win.iso"
admin_password           = "your-password"
vlan_tag                 = 80
```

---

## Building the Template

```bash
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox

# Initialize plugins
packer init .

# Validate configuration
packer validate -var-file="variables.pkrvars.hcl" .

# Build template
packer build -var-file="variables.pkrvars.hcl" .
```

### Force Rebuild

```bash
packer build -force -var-file="variables.pkrvars.hcl" .
```

---

## Template Contents

After successful build, template 9022 includes:

| Component | Status |
|-----------|--------|
| Windows Server 2022 Datacenter | Installed |
| VirtIO SCSI Driver | Installed |
| VirtIO Network Driver | Installed |
| VirtIO Balloon Driver | Installed |
| QEMU Guest Agent | Installed & Running |
| WinRM HTTP (5985) | Enabled |
| PowerShell Remoting | Enabled |
| Remote Desktop | Enabled |
| High Performance Power Plan | Active |

---

## Troubleshooting

### WinRM Connection Timeout

**Symptom**: Packer waits forever for WinRM

**Solutions**:
1. Verify VM has IP 192.168.80.99 (check Proxmox console)
2. Ensure VLAN 80 is configured on switch
3. Check firewall allows WinRM traffic
4. Increase `winrm_timeout` in template

### VirtIO Drivers Not Loading

**Symptom**: "No drives found" during Windows setup

**Solutions**:
1. Verify VirtIO ISO is mounted as SATA1
2. Check driver paths match ISO structure
3. Use correct Windows version folder (`2k22` not `2k19`)

### Script Files Deleted

**Symptom**: "Script file not found" errors

**Cause**: Windows Defender deleting Packer's temp scripts

**Solution**: The `autounattend.xml` now includes:
```xml
<CommandLine>powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true; Add-MpPreference -ExclusionPath 'C:\Windows\Temp'"</CommandLine>
```

### WinRM Connection Drops During Build

**Symptom**: Build fails mid-provisioner with "connection reset"

**Cause**: `Enable-PSRemoting` restarts WinRM service

**Solution**: The `enable-remoting.ps1` is now idempotent - it checks if remoting is already enabled before running `Enable-PSRemoting`.
