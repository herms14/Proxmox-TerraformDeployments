---
tags:
  - homelab
  - gitops
  - gitlab
  - cicd
  - architecture
created: 2025-12-30
updated: 2025-12-30
status: active
---

# GitOps Architecture for Homelab Services

## Overview

This document describes the GitOps architecture implemented for managing homelab services. The system enables declarative infrastructure management where:

- **Git is the single source of truth** - All service configurations are stored as YAML files
- **Changes are applied automatically** - Pushing to the main/master branch triggers deployment
- **The system is self-documenting** - Service YAML files describe the complete deployment

### What is GitOps?

GitOps is an operational framework that applies DevOps best practices used for application development (version control, collaboration, compliance) to infrastructure automation.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitOps Workflow                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Developer          GitLab              Runner              Infrastructure │
│   ─────────          ──────              ──────              ────────────── │
│                                                                              │
│   1. Edit YAML ───────►                                                      │
│                                                                              │
│   2. git push  ──────────► 3. Webhook                                       │
│                            triggers                                          │
│                            pipeline ─────► 4. Runner                         │
│                                            picks up job                      │
│                                                   │                          │
│                                                   ▼                          │
│                                            5. Execute ─────► 6. Deploy      │
│                                               scripts        containers      │
│                                                   │          Configure       │
│                                                   │          Traefik         │
│                                                   │          Update DNS      │
│                                                   │          Setup SSO       │
│                                                   │          Update Glance   │
│                                                   ▼                          │
│                                            7. Verify & Notify               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HOMELAB GITOPS ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────────┐ │
│  │   Developer  │     │    GitLab    │     │      GitLab Runner           │ │
│  │   Workstation│────►│    Server    │────►│      (192.168.40.24)         │ │
│  │              │     │(192.168.40.23│     │                              │ │
│  │  - Edit YAML │     │              │     │  - Shell Executor            │ │
│  │  - git push  │     │  - Webhook   │     │  - Python Scripts            │ │
│  └──────────────┘     │  - Pipeline  │     │  - SSH Access                │ │
│                       │  - Artifacts │     └──────────────────────────────┘ │
│                       └──────────────┘                  │                    │
│                                                         │                    │
│                                    ┌────────────────────┼────────────────┐   │
│                                    │                    │                │   │
│                                    ▼                    ▼                ▼   │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                        TARGET INFRASTRUCTURE                              ││
│  ├──────────────────────────────────────────────────────────────────────────┤│
│  │                                                                           ││
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          ││
│  │  │  docker-media   │  │ docker-core-    │  │  docker-lxc-    │          ││
│  │  │  192.168.40.11  │  │ utilities01     │  │  glance         │          ││
│  │  │                 │  │ 192.168.40.13   │  │  192.168.40.12  │          ││
│  │  │ - Jellyfin      │  │                 │  │                 │          ││
│  │  │ - *arr stack    │  │ - Grafana       │  │ - Glance        │          ││
│  │  │ - MeTube        │  │ - Prometheus    │  │   Dashboard     │          ││
│  │  │ - Downloads     │  │ - n8n           │  │                 │          ││
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘          ││
│  │                                                                           ││
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          ││
│  │  │    Traefik      │  │    Authentik    │  │    Pi-hole      │          ││
│  │  │  192.168.40.20  │  │  192.168.40.21  │  │  192.168.90.53  │          ││
│  │  │                 │  │                 │  │                 │          ││
│  │  │ - Reverse Proxy │  │ - SSO/Auth      │  │ - DNS Records   │          ││
│  │  │ - TLS Certs     │  │ - OIDC/SAML     │  │ - Local DNS     │          ││
│  │  │ - Routing       │  │ - Forward Auth  │  │                 │          ││
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘          ││
│  │                                                                           ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
homelab-services/
├── .gitlab-ci.yml              # CI/CD Pipeline Definition
│                               # - 10 stages
│                               # - 13 jobs
│                               # - Artifact passing between stages
│
├── schema/
│   └── service-schema.json     # JSON Schema for YAML Validation
│
├── scripts/                    # Automation Scripts (Python)
│   ├── detect_changes.py       # Git diff analysis
│   ├── validate_service.py     # Schema validation
│   ├── show_plan.py            # Deployment planning
│   ├── deploy_container.py     # Docker deployment
│   ├── configure_traefik.py    # Reverse proxy config
│   ├── configure_dns.py        # Pi-hole DNS records
│   ├── configure_authentik.py  # SSO provisioning
│   ├── update_glance.py        # Dashboard updates
│   ├── verify_deployment.py    # Health checks
│   ├── rollback.py             # Unified rollback
│   └── notify_discord.py       # Notifications
│
├── services/                   # Service Definitions (YAML)
│   ├── media/
│   ├── downloads/
│   ├── productivity/
│   └── monitoring/
│
└── docs/
    ├── GITOPS_ARCHITECTURE.md
    ├── PIPELINE_WALKTHROUGH.md
    ├── DEPLOYMENT_TUTORIAL.md
    └── TROUBLESHOOTING.md
```

---

## Design Decisions

### 1. Single YAML File Per Service

**Decision**: Each service is defined in a single, self-contained YAML file.

**Rationale**:
- **Simplicity**: One file = one service = one deployment unit
- **Discoverability**: Easy to find and understand any service
- **Atomicity**: Changes to one service don't affect others
- **Git History**: Clear commit history per service

### 2. Schema-First Validation

**Decision**: Use JSON Schema for validating service YAML files.

**Rationale**:
- **Fail Fast**: Invalid configurations caught before deployment
- **Documentation**: Schema doubles as documentation
- **IDE Support**: Enables autocomplete in VSCode/IDE
- **Consistency**: Enforces naming conventions and required fields

### 3. Incremental Deployments

**Decision**: Only deploy services that changed in the commit.

**Rationale**:
- **Speed**: Don't redeploy unchanged services
- **Safety**: Minimize blast radius of changes
- **Efficiency**: Save resources and time

### 4. Shell Executor (Not Docker)

**Decision**: Use GitLab Runner with Shell executor instead of Docker executor.

**Rationale**:
- **SSH Access**: Direct SSH to target hosts without network complexity
- **Simplicity**: No Docker-in-Docker issues
- **Speed**: No container startup overhead
- **Host Tools**: Access to system Python, git, ssh

### 5. Python for Automation Scripts

**Decision**: Use Python 3 for all automation scripts.

**Rationale**:
- **Readability**: Clear, maintainable code
- **Libraries**: Rich ecosystem (pyyaml, requests, jsonschema)
- **Error Handling**: Better than bash for complex logic
- **Cross-Platform**: Works on any runner

---

## Component Details

### GitLab Server (192.168.40.23)

| Component | Description |
|-----------|-------------|
| **GitLab CE** | Self-hosted GitLab instance |
| **Repository** | `root/homelab-services` |
| **Webhooks** | Trigger pipeline on push |
| **Artifact Storage** | Store pipeline artifacts |

### GitLab Runner (192.168.40.24)

| Component | Description |
|-----------|-------------|
| **Executor** | Shell (bash) |
| **User** | `gitlab-runner` |
| **SSH Key** | `/home/gitlab-runner/.ssh/homelab_ed25519` |
| **Python** | Python 3.x with pip |

### Target Hosts

| Host | IP | User | Purpose |
|------|-----|------|---------|
| docker-media | 192.168.40.11 | hermes-admin | Media services |
| docker-core-utils | 192.168.40.13 | hermes-admin | Core utilities |
| docker-lxc-glance | 192.168.40.12 | root | Glance dashboard |
| traefik | 192.168.40.20 | hermes-admin | Reverse proxy |
| authentik | 192.168.40.21 | hermes-admin | SSO |
| pihole | 192.168.90.53 | N/A (API) | DNS |

---

## Security Considerations

### SSH Key Management

```
┌─────────────────────────────────────────────────────────────────┐
│                      SSH Key Distribution                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  GitLab Runner                    Target Hosts                   │
│  ─────────────                    ────────────                   │
│                                                                  │
│  /home/gitlab-runner/.ssh/        ~/.ssh/authorized_keys         │
│  └── homelab_ed25519  ──────────► hermes-admin@docker-media     │
│      (private key)                hermes-admin@docker-core-utils │
│                                   hermes-admin@traefik           │
│                                   root@docker-lxc-glance         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Secrets Management

| Secret | Storage | Usage |
|--------|---------|-------|
| SSH Private Key | Runner filesystem | SSH to hosts |
| Pi-hole Password | GitLab CI Variable | DNS API auth |
| Authentik Token | GitLab CI Variable | SSO API auth |
| Discord Webhook | GitLab CI Variable | Notifications |

---

## Related Documents

- [[33 - GitOps Pipeline Walkthrough]] - Detailed pipeline explanation
- [[34 - GitOps Deployment Tutorial]] - Step-by-step deployment guide
- [[35 - GitOps Troubleshooting]] - Common issues and solutions
- [[20 - GitLab CI-CD Automation]] - Original CI/CD setup

---

*Last updated: December 30, 2025*
