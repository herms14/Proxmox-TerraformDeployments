---
title: "How I Use Claude Code to Manage My Homelab: Context Persistence, Optimization, and Lessons Learned"
date: 2026-01-14
draft: false
tags: ["homelab", "claude", "ai", "automation", "proxmox", "infrastructure"]
categories: ["homelab", "ai"]
summary: "A deep dive into building a context persistence system for Claude Code that enables seamless multi-session infrastructure management across a 3-node Proxmox cluster with 40+ services."
cover:
  image: ""
  alt: "Claude Code Homelab Management"
  relative: false
---

Managing a homelab is complex. Managing it with an AI assistant that forgets everything after each conversation? That's a challenge I've spent months solving.

This post details how I've optimized Claude Code for infrastructure management, the context persistence system I built, and the lessons learned from deploying over 30 services across a 3-node Proxmox cluster with Claude as my primary engineering partner.

---

## The Problem: AI Amnesia

Claude is incredibly capable. It can write Terraform configs, debug Ansible playbooks, create Grafana dashboards, and architect entire systems. But it has one fundamental limitation: **it forgets everything between sessions**.

Every new conversation starts fresh. No memory of:
- What infrastructure exists
- What was deployed yesterday
- Which IP addresses are assigned
- What conventions we established
- What tasks are in progress

For simple questions, this doesn't matter. For managing a homelab with 18 VMs, 3 LXC containers, a Kubernetes cluster, a Proxmox Backup Server, and 40+ services? It's crippling.

I needed Claude to understand my infrastructure **instantly**, every single time.

---

## The Solution: A Multi-File Context System

Instead of fighting Claude's limitations, I built a system that works with them. The solution is a `.claude/` directory in my infrastructure repository containing structured context files that Claude reads at the start of every session.

### File Structure

```
homelab-infra-automation-project/
├── claude.md                    # Main instructions + infrastructure summary
├── .claude/
│   ├── context.md               # Stable infrastructure reference
│   ├── active-tasks.md          # Work in progress tracking
│   ├── session-log.md           # Chronological session history
│   └── conventions.md           # Standards and patterns
```

Each file serves a specific purpose, and together they give Claude complete situational awareness in under 30 seconds of reading.

---

## Breaking Down Each File

### 1. `claude.md` - The Entry Point

This is the main instructions file that Claude Code automatically reads. It contains:

**Infrastructure Context Summary** - A formatted ASCII box showing all critical infrastructure at a glance:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                        HOMELAB INFRASTRUCTURE CONTEXT                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ PROXMOX CLUSTER: MorpheusCluster (3-node + Qdevice)                          ║
║   • node01: 192.168.20.20 (Tailscale: 100.89.33.5)  - Primary VM Host        ║
║   • node02: 192.168.20.21 (Tailscale: 100.96.195.27) - Service Host          ║
║   • node03: 192.168.20.22 (Tailscale: 100.88.228.34) - Additional Node       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ KEY HOSTS                                                                     ║
║   • ansible:        192.168.20.30  - Ansible Controller + Packer             ║
║   • docker-media:   192.168.40.11  - Jellyfin, *arr stack                    ║
║   • docker-glance:  192.168.40.12  - Glance Dashboard, APIs                  ║
║   • traefik:        192.168.40.20  - Reverse Proxy                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

This box is displayed at every session start. Claude immediately knows:
- All node IPs (local and Tailscale)
- Network segmentation (which VLAN does what)
- Key service locations
- SSH credentials and key paths
- Azure hybrid cloud configuration

**Quick Reference Table** - Links to detailed documentation for each subsystem:

| Resource | Documentation |
|----------|---------------|
| Network | docs/NETWORKING.md |
| Terraform | docs/TERRAFORM.md |
| Services | docs/SERVICES.md |
| Discord Bots | docs/DISCORD_BOTS.md |

**Multi-Session Protocol** - Instructions for handling work-in-progress across sessions.

### 2. `.claude/context.md` - The Infrastructure Bible

This file contains stable, rarely-changing information:

- **Proxmox cluster configuration** - Node specs, storage pools, backup schedules
- **Network topology** - VLANs, IP ranges, DNS servers
- **Azure environment** - Subscription IDs, VM specs, VPN configuration
- **Service URLs** - Every deployed service with its endpoint
- **Authentication details** - SSH users, API token names (not values)
- **File locations** - Where configs live on each host

The key insight: **separate stable information from volatile information**. `context.md` rarely needs updates. Maybe once a month when I add a new service or change infrastructure.

Example section from `context.md`:

```markdown
## Deployed Infrastructure

| Host | IP | Type | Services |
|------|-----|------|----------|
| docker-lxc-glance | 192.168.40.12 | LXC 200 | Glance, Media Stats API, Reddit Manager |
| docker-vm-core-utilities | 192.168.40.13 | VM 107 | Grafana, Prometheus, Sentinel Bot |
| traefik | 192.168.40.20 | VM | Reverse proxy |
```

### 3. `.claude/session-log.md` - The History Book

This is where the magic happens for **context continuity**. Every session logs:

- Date and time
- What was requested
- What was accomplished
- Files created or modified
- Current status (Completed/In Progress/Blocked)
- Next steps for future sessions

Example entry:

```markdown
## 2026-01-14

### Azure Hybrid Lab - Windows Template Builds & VM Deployment
**Status**: Completed
**Request**: Deploy 12 Windows Server VMs for Active Directory lab

**Work Completed**:
1. Rebuilt Packer template with WinRM fixes
2. Deployed 12 VMs via Terraform (DC01, DC02, FS01, FS02, SQL01, etc.)
3. Configured static IPs on all VMs
4. Created sysprep-unattend.xml for automated OOBE skip

**Files Modified**:
- Azure-Hybrid-Lab/packer/windows-server-2022-proxmox/autounattend.xml
- Azure-Hybrid-Lab/terraform/proxmox/main.tf

**Next Steps**:
1. Configure Active Directory forest
2. Promote secondary DCs
3. Deploy Azure Arc agents
```

When I start a new session, Claude reads this and immediately knows what happened recently, what's pending, and what conventions were established.

### 4. `.claude/active-tasks.md` - The Coordination Center

This file solves a specific problem: **multiple Claude sessions running simultaneously**.

I often have 2-3 Claude Code instances open - one researching, one coding, one deploying. Without coordination, they could conflict.

`active-tasks.md` tracks:
- Currently in-progress tasks (with instance identifier)
- Recently completed work
- Blocked tasks and why
- Resume instructions for interrupted work

```markdown
## Currently In Progress

### Instance A (This Session)
**Task**: Documentation Update - Technical Manual
**Status**: In Progress

### Instance B (Parallel Session)
**Task**: VM Static IP Configuration
**Status**: Completed

## Interrupted Tasks (Need Resumption)

### Windows 11 Packer Template Build
**Status**: Unknown (may have timed out)
**VM ID**: 9011 on node03

Check status:
```bash
ssh root@192.168.20.22 "qm list | grep 9011"
```
```

### 5. `.claude/conventions.md` - The Standards Guide

This file codifies how things should be done:

- **Adding new VMs** - Terraform patterns, variable conventions
- **Adding new services** - Checklist (Traefik route, DNS entry, Authentik, Discord bot, documentation)
- **Documentation format** - How to structure troubleshooting entries
- **Protected configurations** - Dashboards and pages not to modify without permission

Example convention:

```markdown
## Adding New Services Checklist

1. Deploy VM via Terraform
2. Create Ansible playbook in `ansible-playbooks/`
3. Add to Traefik dynamic config
4. Update DNS in OPNsense
5. Add Authentik protection (if needed)
6. Update Discord Bots (container list, VM mapping)
7. Update Documentation (Technical Manual AND Book)
```

---

## The Multi-Session Workflow Protocol

The context files only work if they're kept updated. I established a strict protocol that Claude follows:

### Before Starting ANY Work

1. **Check active tasks** - Read `.claude/active-tasks.md` for in-progress work
2. **Check session log** - Read `.claude/session-log.md` for recent history
3. **Avoid conflicts** - Don't work on something another session is handling

### During Work (Document As You Go)

1. **Log immediately** - Add entry to session-log.md when starting
2. **Mark active** - Update active-tasks.md with current task
3. **Update docs incrementally** - Don't wait until the end
4. **Update CHANGELOG.md** - For significant changes

### If Tokens Running Low

This is critical. Claude sessions have a context window limit. Before hitting it:

1. Update `active-tasks.md` with:
   - What's completed
   - What's remaining
   - Specific resume instructions
2. Commit changes so next session has context

### After Completing Work

1. Move task from "In Progress" to "Recently Completed"
2. Update session-log.md with final status
3. Clear entry from active tasks

---

## Optimizations and Tips

After months of iteration, here's what I've learned:

### 1. Use ASCII Art for Critical Information

The infrastructure context summary uses ASCII boxes because:
- It's visually distinct from prose
- Claude processes it as structured data
- It's scannable at a glance
- It survives copy-paste without formatting loss

### 2. Separate Stable vs. Volatile Information

Don't mix rarely-changing infrastructure details with frequently-changing task status. My split:
- `context.md` - Changes monthly
- `session-log.md` - Changes every session
- `active-tasks.md` - Changes during sessions

### 3. Include Resume Instructions

Every in-progress task includes explicit commands to resume:

```markdown
**Resume Instructions**:
```bash
ssh hermes-admin@192.168.20.30
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox
packer build -var-file='variables.pkrvars.hcl' .
```
```

Future sessions don't need to figure out where we left off.

### 4. Protect Working Configurations

I mark certain dashboards and pages as "protected" with explicit warnings:

```markdown
### Protected Grafana Dashboards (DO NOT MODIFY)

- **Container Status History** (`container-status`)
- **Synology NAS Storage** (`synology-nas-modern`)
- **Omada Network Overview** (`omada-network`)
```

Claude respects these boundaries and asks before modifying.

### 5. Document the "Why", Not Just the "What"

Session logs include context:

```markdown
**Root Cause**: Using Display Name instead of internal WIM image name
**Changed from**: `Windows Server 2022 Datacenter (Desktop Experience)`
**Changed to**: `Windows Server 2022 SERVERDATACENTER`
```

Future sessions (or future me) understand not just what changed, but why.

### 6. Use Tables Liberally

Tables are information-dense and easy for Claude to parse:

```markdown
| VM | VMID | Static IP | Status |
|----|------|-----------|--------|
| DC01 | 300 | 192.168.80.2 | Configured |
| DC02 | 301 | 192.168.80.3 | Configured |
```

### 7. Version Your Documentation

My Technical Manual has version numbers (v5.8 as of writing). When Claude makes updates, it increments the version. This creates an audit trail.

---

## The Value of Persistence: Real Examples

Here's what this system enabled - three detailed examples from my actual infrastructure:

---

### Example 1: Building a Complete Timeline App (60+ Files in One Session)

**The Request**: "Create a timeline app to document my homelab journey, like Immich's timeline view."

**What Claude Built**: A complete Next.js 14 application called **Homelab Chronicle** with:

| Component | Files | Description |
|-----------|-------|-------------|
| API Routes | 18 | Events CRUD, webhooks, sync endpoints |
| Pages | 10 | Timeline, admin, search, stats, infrastructure map |
| Components | 15 | TipTap editor, timeline views, UI components |
| Integrations | 5 | GitHub, GitLab, Prometheus, Watchtower, Ansible |
| Config | 12 | Prisma schema, Docker, Traefik, environment |

**Total**: 60+ TypeScript files, Dockerfile, docker-compose.yml, Prisma schema, and deployment playbooks.

The session log entry captures the scope:

```markdown
### Homelab Chronicle Timeline App Created
**Status**: Completed
**Request**: Create a timeline visualization app for documenting homelab changes

**Features**:
- Immich-style vertical timeline with events grouped by year/month
- TipTap rich text editor with formatting, code blocks, images
- Image upload with drag-drop support
- Category filtering and search
- Admin panel for CRUD operations
- Authentik SSO authentication

**Files Created**:
- Core app files (50+ files in `apps/homelab-chronicle/`)
- `scripts/seed.ts` - Seeds 23 historical events
- `scripts/import-git.ts` - Import from git commits
- `Dockerfile` + `docker-compose.yml`
- `terraform/homelab-chronicle/main.tf` - LXC provisioning
- `ansible-playbooks/services/deploy-homelab-chronicle.yml`
```

This was possible because Claude knew:
- My Traefik configuration patterns (from `context.md`)
- My Authentik OAuth setup (from session history)
- My Ansible playbook conventions (from `conventions.md`)
- Where to deploy (LXC 203 on node01, from infrastructure map)

Without context persistence, I'd have spent hours explaining all of this. Instead, Claude just built it correctly the first time.

---

### Example 2: Multi-Session Debugging of Windows Packer Templates

**The Problem**: Building Windows Server 2022 templates for an Azure Hybrid Lab. What should have been straightforward became a multi-session debugging saga.

**Session 1 (January 2, 2026)** - Initial attempt fails:
```markdown
### Azure Hybrid Lab Packer Build - autounattend.xml Fixes
**Status**: In Progress (Session Ended)

**Issue**: Windows installer kept showing OS selection screen
**Root Cause**: Using Display Name instead of internal WIM image name

Used `wimlib-imagex info` on Proxmox to discover correct image names:
| Index | Internal Name | Display Name |
|-------|---------------|--------------|
| 4 | Windows Server 2022 SERVERDATACENTER | Datacenter (Desktop Experience) |

**Changed from**: `Windows Server 2022 Datacenter (Desktop Experience)`
**Changed to**: `Windows Server 2022 SERVERDATACENTER`

**Resume Instructions**:
ssh hermes-admin@192.168.20.30
cd ~/azure-hybrid-lab/packer/windows-server-2022-proxmox
packer build -var-file='variables.pkrvars.hcl' .
```

**Session 2 (January 13, 2026)** - More issues discovered:
```markdown
### Fixed - Windows Server 2025 Packer Autounattend Issues
**Identified and fixed multiple autounattend.xml issues**:
  - **Missing wcm namespace**: Added xmlns:wcm to root element
  - **8.3 filename truncation**: ISO creation truncated `autounattend.xml` to `AUTOUNAT.XML`
  - **SATA CD-ROM not detected**: Windows PE doesn't enumerate SATA; switched to IDE
  - **Missing product key**: Added ProductKey element to skip licensing screen

**ISO creation command** (must use Joliet flags):
xorriso -as mkisofs -J -joliet-long -V "OEMDRV" -o autounattend.iso ./dir/
```

**Session 3 (January 14, 2026)** - Final breakthrough:
```markdown
### Azure Hybrid Lab - Full Deployment Complete
**Status**: ✅ SUCCESS

**Key Technical Fixes Applied**:
1. **WinRM Connection Drops** - `enable-remoting.ps1` now checks if remoting
   is already enabled before calling `Enable-PSRemoting` (which restarts WinRM)
2. **Script File Deletion** - Added Windows Defender exclusion in autounattend.xml
3. **Post-Sysprep OOBE** - Created sysprep-unattend.xml for fully automated boot

**Deployed VMs**: 12 Windows Server VMs in ~30 minutes
| VM | VMID | Role | Status |
|----|------|------|--------|
| DC01 | 300 | Primary Domain Controller | Running |
| DC02 | 301 | Secondary Domain Controller | Running |
| FS01-02, SQL01, AADCON01, AADPP01-02, IIS01-02, CLIENT01-02 | ... | Various | Running |
```

**Why This Worked**: Each session started by reading the previous session's findings. Claude didn't re-discover that WIM names differ from display names - it knew that from Session 1. It didn't retry SATA CD-ROM - it knew from Session 2 that IDE was required. By Session 3, all the learned context accumulated into a working solution.

The git commits tell the story:
```
b3a3df5 feat(azure-hybrid-lab): Add Windows Server 2022 Packer template for Proxmox
220d0af docs: Expand Technical Manual V5.4 with credentials and tutorials
```

---

### Example 3: Building a 700-Line Discord Bot Power Management System

**The Request**: "Add commands to safely shutdown and startup the entire Proxmox cluster via Discord."

**What Claude Built**: A complete power management cog for my Sentinel Discord bot.

From the CHANGELOG:
```markdown
### Added - Sentinel Bot Power Management Commands (January 13, 2026)
- `/shutdownall` - Gracefully shutdown ALL VMs, LXCs, and Proxmox nodes
- `/shutdown-nodns` - Shutdown all except Pi-hole (LXC 202) to keep DNS available
- `/startall` - Wake all nodes via Wake-on-LAN and start all VMs/LXCs

**Wake-on-LAN support** for all three Proxmox nodes:
  - node01: `38:05:25:32:82:76`
  - node02: `84:47:09:4d:7a:ca`
  - node03: `d8:43:ae:a8:4c:a7`

**Safe shutdown/startup order**:
  - Shutdown: VMs → LXCs → Nodes (node03 → node02 → node01)
  - Startup: WoL → Wait for nodes → LXCs (Pi-hole first for DNS) → VMs
```

The code Claude generated (`cogs/power.py`) includes:

```python
@dataclass
class PowerOperationReport:
    """Tracks results of power operations."""
    operation: str  # 'shutdown' or 'startup'

    nodes_total: int = 0
    nodes_success: int = 0
    nodes_failures: List[str] = field(default_factory=list)
    nodes_skipped: List[str] = field(default_factory=list)

    vms_total: int = 0
    vms_success: int = 0
    # ... tracking for all resource types

    def to_embed(self) -> discord.Embed:
        """Generate summary embed with color-coded results."""
```

And in `config.py`, all my infrastructure IPs are mapped:

```python
CONTAINER_HOSTS = {
    # docker-vm-core-utilities01 (192.168.40.13)
    'grafana': '192.168.40.13',
    'prometheus': '192.168.40.13',
    'sentinel-bot': '192.168.40.13',

    # docker-vm-media01 (192.168.40.11)
    'jellyfin': '192.168.40.11',
    'radarr': '192.168.40.11',
    'sonarr': '192.168.40.11',
    # ... 30+ container mappings
}

PROXMOX_NODES = {
    'node01': '192.168.20.20',
    'node02': '192.168.20.21',
    'node03': '192.168.20.22',
}
```

**Why Context Mattered**: Claude knew:
- All my container-to-host mappings (from `context.md`)
- That Pi-hole on LXC 202 is critical for DNS (from infrastructure knowledge)
- My SSH key path and user conventions (from authentication section)
- The MAC addresses of my nodes (from previous Wake-on-LAN documentation)
- That reaction-based confirmation is my pattern for dangerous operations (from other bot commands)

The result: a feature that safely orchestrates shutdown/startup of 18 VMs, 3 LXCs, and 3 Proxmox nodes, with proper ordering, progress tracking, and Discord embeds - all generated correctly because Claude understood my complete infrastructure.

---

### Parallel Operations in Action

From `active-tasks.md` on January 14, 2026:

```markdown
## Currently In Progress

### Instance A (This Session) - COMPLETED
**Task**: Documentation Update - Technical Manual & Book
**Status**: ✅ DONE
- Updated Technical Manual to v5.8 (Azure Hybrid Lab section ~600 lines)
- Updated Book Chapter 25 with Packer/Terraform narrative

### Instance B (This Session) - COMPLETED
**Task**: VM Static IP Configuration
**Status**: ✅ DONE

| VM | VMID | Static IP | Status |
|----|------|-----------|--------|
| DC01 | 300 | 192.168.80.2 | ✅ Configured |
| DC02 | 301 | 192.168.80.3 | ✅ Configured |
... (12 VMs total)
```

Two Claude instances, working simultaneously:
- **Instance A**: Writing documentation in Obsidian
- **Instance B**: SSHing into VMs and configuring network settings

Neither stepped on the other's work. Both updated their respective sections of `active-tasks.md`. When Instance B finished, Instance A saw the completion and could reference the new IP assignments in the documentation.

---

## The Complete File Template

For anyone wanting to implement this, here's the minimal template:

**`claude.md`**:
```markdown
# Project Name

## Infrastructure Context Summary
[ASCII box with critical IPs, services, credentials]

## Multi-Session Workflow
[Before/During/After protocols]

## Context Files
| File | Purpose |
|------|---------|
| .claude/context.md | Infrastructure reference |
| .claude/active-tasks.md | Work in progress |
| .claude/session-log.md | Session history |
```

**`.claude/context.md`**:
```markdown
# Infrastructure Context

## Servers
[Table of all hosts with IPs and purposes]

## Services
[Table of all services with URLs]

## Authentication
[SSH users, key locations, API credentials]
```

**`.claude/active-tasks.md`**:
```markdown
# Active Tasks

## Currently In Progress
[Current task with status]

## Recently Completed
[Last 3-5 completed tasks]

## Interrupted Tasks
[Tasks needing resumption with instructions]
```

**`.claude/session-log.md`**:
```markdown
# Session Log

## [Date]
### [Task Name]
**Status**: In Progress/Completed/Blocked
**Request**: [What was asked]
**Work Completed**: [What was done]
**Files Modified**: [List of files]
**Next Steps**: [What comes next]
```

---

## Results

With this system in place:

- **Setup time per session**: ~30 seconds (Claude reads context files)
- **Context accuracy**: 100% - Claude knows my infrastructure immediately
- **Multi-session continuity**: Seamless - no information loss between sessions
- **Parallel work**: Coordinated - multiple instances don't conflict
- **Documentation**: Always current - updated as part of the workflow

My homelab now has:
- 3-node Proxmox cluster
- 18 VMs + 3 LXC containers
- 40+ services (Jellyfin, *arr stack, Grafana, Traefik, Authentik, etc.)
- Azure hybrid cloud with AD, Sentinel SIEM, and site-to-site VPN
- Kubernetes cluster (9 nodes)
- Comprehensive monitoring with custom Grafana dashboards

All deployed and managed with Claude Code as the primary engineering assistant, with full context persistence across hundreds of sessions.

---

## Conclusion

The key insight is simple: **Claude doesn't need memory if you give it perfect notes**.

By structuring context into purpose-specific files, establishing strict documentation protocols, and building coordination mechanisms for parallel work, Claude becomes an incredibly effective infrastructure management partner.

The overhead is minimal - updating a few markdown files as part of normal workflow. The payoff is massive - an AI assistant that understands your entire infrastructure, every single time.

If you're using Claude Code for any complex, ongoing project, I highly recommend implementing something similar. The initial setup takes an afternoon. The productivity gains compound forever.

---

*This blog post was written with Claude Code, using the exact context persistence system it describes. The irony is not lost on me.*
