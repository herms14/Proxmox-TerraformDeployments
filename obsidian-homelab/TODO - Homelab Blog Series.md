---
tags:
  - todo
  - homelab
  - blog
  - writing
created: 2025-12-23
status: in-progress
---

# TODO: Homelab Blog Series

> Document and share the homelab journey for technical audiences interested in homelabbing and containerization.

## Related Documents

- [[00 - Homelab Index]]
- [[TODO - Resume Homelab Experience]]

---

## Target Audience

- Technical people wanting to start a homelab
- Developers interested in Docker containerization
- Self-hosters looking for production-grade patterns

## Unique Angles

1. **Real infrastructure** - Not toy examples, actual production patterns
2. **Mistakes included** - Learning from path mismatches, config errors
3. **AI-assisted journey** - Novel angle most homelab blogs don't cover
4. **Three-tier documentation** - docs/, wiki, Obsidian sync process
5. **Discord integration** - Practical automation beyond just containers

---

## Blog Posts

### Published / In Progress

- [ ] **Post 1**: My Accidental Journey Into Homelabbing - From Trip Photos to Full-Blown Infrastructure
- [ ] **Post 2**: How AI Jumpstarted My Homelab Journey

### Foundation Layer (Posts 3-6)

| # | Title | Status | Key Topics |
|---|-------|--------|------------|
| 3 | Choosing Your Hypervisor: Why I Went With Proxmox | pending | Proxmox vs ESXi vs Hyper-V, cluster setup |
| 4 | Network Segmentation for Homelabs | pending | VLANs, OPNsense, isolation |
| 5 | Infrastructure as Code: Terraform for Homelab | pending | IaC, modules, reproducibility |
| 6 | Configuration Management with Ansible | pending | Playbooks, inventory, idempotency |

### Containerization Deep-Dives (Posts 7-10)

| # | Title | Status | Key Topics |
|---|-------|--------|------------|
| 7 | Docker Compose Patterns That Actually Work | pending | Volumes, networking, unified paths |
| 8 | Reverse Proxy Everything: Traefik Setup Guide | pending | SSL, dynamic config, middlewares |
| 9 | Single Sign-On for Self-Hosted Apps | pending | Authentik, ForwardAuth, outpost pattern |
| 10 | The Media Stack Nobody Talks About | pending | *arr apps, hardlinks, Jellyfin |

### Production-Grade Practices (Posts 11-14)

| # | Title | Status | Key Topics |
|---|-------|--------|------------|
| 11 | Monitoring Your Homelab Like a Pro | pending | Uptime Kuma, Prometheus, Grafana |
| 12 | Distributed Tracing in a Homelab | pending | OpenTelemetry, Jaeger |
| 13 | Automating Container Updates Without Breaking Things | pending | Watchtower, Discord approvals |
| 14 | Building Discord Bots for Homelab Management | pending | Argus, Update Manager |

### Advanced Topics (Posts 15-17)

| # | Title | Status | Key Topics |
|---|-------|--------|------------|
| 15 | Kubernetes at Home: Overkill or Opportunity? | pending | K8s vs Docker, 9-node cluster |
| 16 | Exposing Services Securely with Cloudflare Tunnel | pending | Zero-trust, no port forwarding |
| 17 | CI/CD for Homelab: GitLab Pipelines | pending | Automated deployments |

### Retrospectives (Posts 18-20)

| # | Title | Status | Key Topics |
|---|-------|--------|------------|
| 18 | Mistakes I Made So You Don't Have To | pending | Path mismatches, forgotten configs |
| 19 | The True Cost of Homelabbing | pending | Hardware, power, time, ROI |
| 20 | What I'd Do Differently Starting Over | pending | Lessons learned |

---

## Blog Post Template

```markdown
# [Title]

## TL;DR
- 3-4 bullet points of key takeaways
- What the reader will learn

## The Problem / Why This Matters
- Real scenario from your experience
- Pain point this solves

## Prerequisites
- What readers need before starting
- Links to previous posts in series

## The Solution
### Step 1: [Action]
- Explanation
- Code/config snippets
- Screenshots if applicable

### Step 2: [Action]
...

## Common Pitfalls
- Things that tripped you up
- How to avoid them

## Verification
- How to confirm it's working
- Expected output/behavior

## What's Next
- Teaser for next post
- Related topics to explore

## Resources
- Official docs
- Your GitHub repo
- Related posts
```

---

## Content Ideas for Post #2 (AI Jumpstart)

| Section | Content |
|---------|---------|
| **The Catalyst** | What made you try AI for homelab work |
| **Pair Programming** | How you use Claude for troubleshooting |
| **Documentation** | AI-assisted doc sync across 3 locations |
| **Learning Accelerator** | Concepts learned faster with AI explaining |
| **Limitations** | What AI can't do (manual UI config, external services) |
| **Workflow** | Your actual process - terminal + AI conversation |

### Real Examples to Include

From actual troubleshooting sessions:
- **Omada Exporter**: Site name mismatch (`Default` vs `Parang Marikina`)
- **Arr Stack Paths**: Unified `/data` mount for hardlinks
- **Jellyfin Empty Library**: Path mismatch between download clients and *arrs

---

## Publishing Checklist

For each post:
- [ ] Draft written
- [ ] Code snippets tested
- [ ] Screenshots captured
- [ ] Proofread
- [ ] Published to blog platform
- [ ] Shared on r/homelab, r/selfhosted
- [ ] Cross-linked from GitHub wiki

---

*Created: December 23, 2025*
