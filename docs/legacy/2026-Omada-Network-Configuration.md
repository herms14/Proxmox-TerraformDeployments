---
banner: "[[999 Attachments/pixel-banner-images/Hermes Miraflor II Life Knowledge Database.jpg]]"
---
# Network Configuration



>[!Warning]
>Disable Global Secure Access on Kratos PC before accessing home lab, else you wont be able to connect.



## Network Topology



![[2026 Omada Network Configuration-6.png]]

## Device Inventory


![[2026 Homelab Configuration-2.png]]

	
|                   |                 |               |                     |                         |         |                   |
| ----------------- | --------------- | ------------- | ------------------- | ----------------------- | ------- | ----------------- |
| DEVICE NAME       | SITE NAME       | IP ADDRESS    | STATUS              | MODEL                   | VERSION | MAC Address       |
| Core Router       | Parang Marikina | 192.168.0.1   | Connected           | ER605 v2.20             | 2.3.3   | 8C-90-2D-4B-D9-6C |
| Core Switch       | Parang Marikina | 192.168.90.2  | Connected           | SG3210 v3.20            | 3.20.14 | 40-AE-30-B7-96-74 |
| Morpheus Switch   | Parang Marikina | 192.168.90.3  | Connected           | SG2210P v5.20           | 5.20.15 | DC-62-79-2A-0D-66 |
| Atreus Switch     | Parang Marikina | 192.168.90.51 | Connected           | ES20GPv1.0              | 1.0.2   | A8-29-48-96-C7-12 |
| Computer Room EAP | Parang Marikina | 192.168.90.12 | Connected           | EAP225(US) v4.0         | 5.1.11  | 0C-EF-15-50-39-52 |
| Living Room EAP   | Parang Marikina | 192.168.90.10 | Connected           | EAP610(US) v3.0         | 1.6.0   | 3C-64-CF-37-96-EC |
| Outdoor EAP       | Parang Marikina | 192.168.90.11 | Connected(Wireless) | EAP603-Outdoor(US) v1.0 | 1.0.1   | 78-20-51-C1-EA-A6 |


## Credentials

Cloud Controller Credentials:
Username: hermes-admin
Password: cK67hBQ4by#eTB3BhAH

Device Passwords for all routers and EAPs:
Username:  hermes-admin
Password: 
old: Zaq12wsxcde34rfv!!!0m@d@
new: o8kS&Dd9R0

Converge ISP Gateway
[EG8245H5](http://192.168.100.1/)
Username: telcoadmin
Password: Converge@huawei123

## VLAN Configuration

![[2026 Omada Network Configuration.png]]

| VLAN Name       | VLAN ID | Use Case                              |   Gateway    | DHCP Enabled | DHCP Address Range            | DNS Servers            |
| --------------- | :-----: | ------------------------------------- | :----------: | :----------: | ----------------------------- | ---------------------- |
| Default VLAN    |    1    | Management (temporary)                | 192.168.0.1  |     YES      | 192.168.0.100 - 192.168.0.199 | Google Default 8.8.8.8 |
| Internal VLAN   |   10    | Main LAN (Kratos PC, Internal NAS)    | 192.168.10.1 |     YES      | 192.168.10.50-192.168.10.254  | Google Default 8.8.8.8 |
| Homelab VLAN    |   20    | Proxmox Nodes, Homelab NAS            | 192.168.20.1 |     YES      | 192.168.20.50-192.168.20.254  | Google Default 8.8.8.8 |
| IoT VLAN        |   30    | IoT WiFi Devices                      | 192.168.30.1 |     YES      | 192.168.30.50-192.168.30.254  | Google Default 8.8.8.8 |
| Production VLAN |   40    | Future workloads                      | 192.168.40.1 |     YES      | 192.168.40.50-192.168.40.254  | Google Default 8.8.8.8 |
| Guest VLAN      |   50    | Guest WiFi                            | 192.168.50.1 |     YES      | 192.168.50.50-192.168.50.254  | Google Default 8.8.8.8 |
| Sonos VLAN      |   60    | For SONOS Speakers                    | 192.168.60.1 |     YES      | 192.168.60.50-192.168.50.100  | Google Default 8.8.8.8 |
| Management VLAN |   90    | Device management (planned migration) | 192.168.90.1 |     YES      | 192.168.90.50-192.168.90.254  | Google Default 8.8.8.8 |


>[!Information]
>For Sonos speakers, devices prefer 2.4GHz


### VLAN 10 Port Configuration
![[2026 Omada Network Configuration-7.png]]



### VLAN 20 Port Configuration

![[2026 Omada Network Configuration-8.png]]

### VLAN 30 Port Configuration

![[2026 Omada Network Configuration-9.png]]

### VLAN 40 Port Configuration

![[2026 Omada Network Configuration-10.png]]


### VLAN 50 Port Configuration

![[2026 Omada Network Configuration-11.png]]

### VLAN 90 Port Configuration

![[2026 Omada Network Configuration-12.png]]

### Sonos VLAN

![[2026 Omada Network Configuration-13.png]]

### Firewall VLAN

![[2026 Omada Network Configuration-14.png]]
## SSID Configuration

![[2026 Omada Network Configuration-4.png]]

>[!Information]
>Disable MLO, Enable 802.11k for SSID where phones and older devices will be connecting.
>- PMF = **security**  
>- 802.11k = **better roaming decisions**
> - MLO = **raw performance at the cost of mobility**

#### Good to know for WiFi Optimization

**PMF (Protected Management Frames – 802.11w)**  
**Purpose:**  
Protects Wi-Fi management frames (deauth, disassoc, action frames) from spoofing and trivial attacks. Without PMF, anyone can kick clients off your network with forged packets.

**Enable when:**  
Internal or trusted SSIDs with modern devices (phones, laptops).  
You want protection against deauth/disruption attacks.

**Mode guidance:**

- **Capable** → Best default (secure + compatible)
    
- **Mandatory** → Only for modern-only networks
    
- **Disable** → Legacy or problematic IoT only
    

---

**MLO (Multi-Link Operation – Wi-Fi 7 / 802.11be)**  
**Purpose:**  
Allows a single client to use multiple radios (e.g., 5 GHz + 6 GHz) simultaneously for higher throughput and lower latency.

**Enable when:**  
You have Wi-Fi 7 APs and Wi-Fi 7 clients.  
Devices are mostly stationary and performance-focused.

**Disable when:**  
SSIDs are used by roaming devices (phones, laptops).  
You rely on fast roaming (802.11k/v/r).

**Key trade-off:**  
MLO improves speed but currently **breaks fast roaming**.

---

**802.11k (Radio Resource Management)**  
**Purpose:**  
Helps clients learn about nearby APs so they can roam intelligently instead of blindly scanning.

**Enable when:**  
Multi-AP environments.  
User devices move around.

**Disable when:**  
Almost never. Safe and beneficial in most deployments.



### SSID Names

NKD5380-Internal
VLAN: 10
Security Key: Zaq12wsxcde34rfv!!!Internal

NHN7476-Homelab
VLAN: 20
Security Key: Zaq12wsxcde34rfv!!!HomeLab

WOC321-IoT
VLAN: 30
Security Key: Zaq12wsxcde34rfv!!!IOT

NAZ9229-Production
VLAN: 40
Security Key: Zaq12wsxcde34rfv!!!Production

EAD6167-Guest
VLAN: 50
Security Key: Zaq12wsxcde34rfv!!!Guest

NCP5653-Management
VLAN: 90
Security Key: Zaq12wsxcde34rfv!!!Management

NAZ9229 - Sonos Wifi Network
VLAN: 60
Security Key: Zaq12wsxcde34rfv!!!Sonos

**Backup WiFI SSID
In case Omada Network goes does due to Tinkering, use these backup SSIDs

ARA2802
Security Key : Zaq12wsxcde34rfv!!!Backup

NIR7714-MLO-Backup
Security Key: Zaq12wsxcde34rfv!!!Backup
## Gateway Configurations

![[2026 Omada Network Configuration-16.png]]
>[!TODO]
>OPNSense will soon be the main gateway / firewall and DNS Resolver


## Switch Port Configurations


>[!TIP]
>Core Switch and Morpheus Switch should have TRUNK Ports for all its Uplink ports with the management port as the native port and  all VLANS as Tagged traffic.


### Core Switch

![[2026 Omada Network Configuration-18.png]]


####  **Core Switch (SG3210 v3.20) – Port Configuration Table**

| Port  | Device               | Trunk or Access | Native VLAN               | Tagged VLANs                    | Untagged VLAN |
| ----- | -------------------- | --------------- | ------------------------- | ------------------------------- | ------------- |
| **1** | OC300 Controller     | **Trunk**       | 1 (Default)               | 1,10,20,30,40,50,90 (All VLANs) | None          |
| **2** | Opensense Port       | **Access**      | 90 (Management)           | None                            | None          |
| **5** | Zephyrus Port        | **Access        | 10 (Internal VLAN)        | None                            | None          |
| **6** | Morpheus Rack Uplink | **Trunk**       | 1 (Default)               | 10, 20, 30, 40, 50, 90          | None          |
| **7** | Kratos PC            | **Trunk**       | 10 (Internal) 20(Homelab) | None                            | 10            |
| **8** | Atreus Switch Uplink | **Trunk**       | 1 (Default)               | All VLANs                       | None          |

>[!Informational]
>Kratos PC is on Trunk mode on VLAN20 inorder for the Hyper VMs to be connected on VLAN 20



### Morpheus Switch

![[2026 Homelab Configuration-16.png]]
####  **Morpheus Switch (SG2210P v5.20) – Port Configuration Table**


| Port   | Device                         | Trunk or Access | Native VLAN        | Tagged VLANs                       | Untagged VLAN |
| ------ | ------------------------------ | --------------- | ------------------ | ---------------------------------- | ------------- |
| **1**  | Core Switch Uplink             | Trunk           | VLAN 1 (Default)   | All VLANs (1,10,20,30,40,50,90)    | None          |
| **2**  | Proxmox Node 01                | Trunk           | VLAN 20 (Homelab)  | 10,40                              | 20            |
| **3**  | Port3 (unused)                 | Trunk           | VLAN 1             | None / Default                     | 1             |
| **4**  | Port4 (unused)                 | Trunk           | VLAN 1             | None / Default                     | 1             |
| **5**  | Computer Room EAP (EAP225)     | Trunk           | VLAN 1 (Default)   | ALL SSID VLANs (10,20,30,40,50,90) | 1             |
| **6**  | Proxmox Node 02                | Trunk           | VLAN 20 (Homelab)  | 10,40                              | 20            |
| **7**  | CallimachusNAS Internal (eth0) | Access          | VLAN 10 (Internal) | None                               | 10            |
| **8**  | CallimachusNAS Homelab (eth1)  | Access          | VLAN 20 (Homelab)  | None                               | 20            |
| **9**  | Port9 (unused)                 | Trunk           | VLAN 1             | None / Default                     | 1             |
| **10** | Port10 (unused)                | Trunk           | VLAN 1             | None / Default                     | 1             |


#### Atreus Switch (ES206GP v1.0) – Port Configuration Table

![[2026 Omada Network Configuration-15.png]]



| Port  | Device               | Trunk or Access | Native VLAN | Tagged VLANs                       | Untagged VLAN |
| ----- | -------------------- | --------------- | ----------- | ---------------------------------- | ------------- |
| **1** | First Floor EAP Port | Trunk           | VLAN 1      | ALL SSID VLANs (10,20,30,40,50,90) | 1             |
| **2** | EMPTY                | EMPTY           | EMPTY       | EMPTY                              | EMPTY         |
| **3** | EMPTY                | EMPTY           | EMPTY       | EMPTY                              | EMPTY         |
| **4** | EMPTY                | EMPTY           | EMPTY       | EMPTY                              | EMPTY         |
| **5** | Core Router Port     | TRUNK           | VLAN 1      | ALL VLANS (1,10,20,30,40,50,90)    | 1             |
| **6** | Core Switch          | TRUNK           | VLAN 1      | ALL VLANS (1,10,20,30,40,50,90)    | 1             |


## ACLS

## Maintenance


Omada Configuration is backed up to NAS via FTP with the below configurations

FTP Username : omada-log-admin
Password : Vm8WRjgeg!&J3klc
File Path : /OmadaConfigBackup

![[2026 Homelab Configuration-17.png]]