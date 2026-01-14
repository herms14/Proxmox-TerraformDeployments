---
title: "Reverse Engineering Learning: How I Use Claude Code to Turn Infrastructure Into Education"
date: 2026-01-14
draft: false
tags: ["learning", "claude", "ai", "homelab", "microsoft-fabric", "azure-sentinel", "documentation"]
categories: ["learning", "ai"]
summary: "A methodology for learning complex technologies by building first and having Claude create comprehensive, personalized documentation that teaches you what you built."
cover:
  image: ""
  alt: "Reverse Engineering Learning with Claude"
  relative: false
---

Most people learn by reading documentation, then building. I do the opposite.

I build first - deploy the infrastructure, configure the services, make it work. Then I have Claude Code create comprehensive documentation explaining what I built. The documentation becomes my learning material, tailored to my exact environment.

I call this **Reverse Engineering Learning**, and it's transformed how I master complex technologies.

---

## The Traditional Approach (And Why It Fails)

Traditional learning looks like this:

1. Read documentation
2. Watch tutorials
3. Try to replicate in your environment
4. Hit errors because your setup differs
5. Spend hours debugging mismatches
6. Finally get it working
7. Forget half of what you read

The problem? Generic documentation assumes a generic environment. Your homelab is unique. Your Azure setup is unique. The gaps between documentation and reality create friction that slows learning.

---

## The Reverse Engineering Approach

My approach flips this:

```
Traditional:  Docs → Build → Debug → Understanding (maybe)

Reverse:      Build → Claude Documents → Understand → Master
```

### The Process

1. **Build first**: Deploy the infrastructure, make it functional
2. **Claude documents**: Have Claude create comprehensive documentation of what exists
3. **Learn from your docs**: Study documentation tailored to YOUR environment
4. **Iterate**: Improve the system, update the docs, deepen understanding

The key insight: **Claude creates documentation that explains YOUR infrastructure, not some hypothetical generic setup**.

---

## Real Example: Microsoft Fabric Learning

I wanted to learn Microsoft Fabric - data lakehouses, medallion architecture, Delta tables, PySpark. Here's how I applied reverse engineering learning.

### Phase 1: Build First

I deployed without fully understanding:

```
Homelab                              Microsoft Fabric
────────────────────────             ─────────────────────
SQL Server VM (Proxmox)    ────────► Bronze Lakehouse
├── Customers (500K rows)   Gateway   ├── raw_customers
├── Products (10K rows)    ────────►  ├── raw_products
├── Orders (5M rows)                  └── raw_orders
└── Inventory (50K rows)
```

I set up:
- SQL Server VM on Proxmox with dummy data
- On-premises data gateway
- Fabric workspace with lakehouses
- Basic copy activities

It worked. Data flowed. But I didn't deeply understand *why* it worked or the concepts underneath.

### Phase 2: Claude Documents

Then I asked Claude to create learning documentation. Not generic Microsoft docs - documentation about MY setup.

**What I asked**: "Create a comprehensive glossary explaining all Fabric concepts, using my homelab as examples."

**What Claude created**: A 52KB glossary file with:

```markdown
### Data Lake

**What it is**: A centralized storage repository that holds vast
amounts of raw data in its native format until needed.

**Analogy**: Think of a data lake as a massive reservoir where you
dump all your data (structured, semi-structured, unstructured)
without worrying about format. You figure out how to use it later.

**In YOUR setup**: OneLake is Microsoft's data lake. Your raw_customers,
raw_products, and raw_orders tables in the Bronze lakehouse are
stored here as Delta files.

Traditional Database                    Data Lake
┌────────────────────┐                 ┌────────────────────┐
│ Structured data    │                 │ Anything goes:     │
│ Must define schema │                 │ - CSV files        │
│ before loading     │                 │ - JSON documents   │
└────────────────────┘                 └────────────────────┘
```

Every concept ties back to my actual infrastructure. Not hypothetical examples - MY examples.

### Phase 3: Structured Learning Path

Claude then created a numbered file structure:

| File | Content |
|------|---------|
| `00 - Learning Plan Overview.md` | Goals, architecture diagram, weekly plan |
| `00A - Glossary and Concepts.md` | 50+ concepts with analogies (52KB) |
| `01 - SQL Server Deployment Guide.md` | How I deployed the source database |
| `02 - Dummy Data Generation.md` | Scripts to create 500K customers, 5M orders |
| `03 - Data Gateway Setup.md` | Gateway installation and configuration |
| `04 - Lakehouse Implementation.md` | Bronze/Silver/Gold layer setup |

The architecture diagrams reference MY infrastructure:

```
┌──────────────────────────────────────────────────────────────────┐
│                           HOMELAB DATA SOURCE                     │
│                                                                   │
│  SQL Server on Proxmox (192.168.40.50)                           │
│  Database: HomelabAnalytics                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │ Customers   │  │ Products    │  │ Orders      │               │
│  │ (500K rows) │  │ (10K rows)  │  │ (5M rows)   │               │
│  └─────────────┘  └─────────────┘  └─────────────┘               │
└──────────────────────────────────────────────────────────────────┘
                                │
                    On-Premises Data Gateway
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                        MICROSOFT FABRIC                           │
│                                                                   │
│  Workspace: HomelabAnalytics                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │ lh_bronze   │─►│ lh_silver   │─►│ dw_gold     │               │
│  │ (Raw)       │  │ (Cleaned)   │  │ (Star)      │               │
│  └─────────────┘  └─────────────┘  └─────────────┘               │
└──────────────────────────────────────────────────────────────────┘
```

### The Result

After Claude created this documentation:

- **I understood medallion architecture** because I could see how it applied to my actual data
- **I grasped Delta tables** because I could query my own tables while reading the explanation
- **I learned PySpark** through notebooks that transformed my own data
- **I understood CDC** by watching real changes flow from my SQL Server

The learning stuck because it was grounded in reality I could touch and modify.

---

## Real Example: Azure Sentinel Learning

Same approach, different technology.

### Phase 1: Build the SIEM

I deployed Azure Sentinel connecting to my homelab:

| Source | Log Type | Integration |
|--------|----------|-------------|
| AZDC01-04 | Windows Security | AMA + DCR |
| linux-syslog-server01 | Syslog | Azure Arc + AMA |
| Proxmox nodes | System logs | rsyslog forwarding |
| OPNsense firewall | Firewall logs | Syslog |

Data was flowing. Alerts were firing. But I didn't deeply understand KQL, detection engineering, or SOAR.

### Phase 2: Claude Documents Everything

I asked Claude to create a comprehensive learning curriculum. What I got:

**Glossary and Concepts** (25KB):
- Every Sentinel concept explained with homelab context
- KQL explained through queries on my actual data
- Detection rules explained using my Windows DCs as examples

**KQL Query Reference**:
```markdown
### Finding Failed Logins on YOUR Domain Controllers

This query searches Windows Security logs from AZDC01-04:

SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4625  // Failed login
| where Computer startswith "AZDC"
| summarize FailedAttempts = count() by Computer, Account
| order by FailedAttempts desc

**Why this matters**: Your DCs (AZDC01-04) are the authentication
backbone. Failed logins could indicate:
- Brute force attacks
- Misconfigured service accounts
- Password expiration issues
```

**Detection Rules Library**:
```markdown
### Rule: Multiple Failed Logins from Same Source

**MITRE ATT&CK**: T1110 (Brute Force)

**Logic**: Alert when >10 failed logins from same IP within 5 minutes

**Applies to YOUR environment**:
- Monitors AZDC01 (192.168.80.2) - Primary DC
- Monitors AZDC02 (192.168.80.3) - Secondary DC
- Excludes known service accounts: svc_*, SYSTEM
```

### The Sentinel Bot Integration

I even had Claude build a Discord bot (`Sentinel Bot`) that interfaces with my Sentinel deployment:

```python
CONTAINER_HOSTS = {
    'grafana': '192.168.40.13',
    'prometheus': '192.168.40.13',
    'sentinel-bot': '192.168.40.13',
    'jellyfin': '192.168.40.11',
    # ... 30+ mappings
}
```

The bot became both:
1. **A tool**: Query alerts, check status, manage infrastructure
2. **Learning material**: Reading the code taught me how Sentinel APIs work

---

## The Documentation Style That Makes This Work

Over months, I developed a documentation style optimized for reverse engineering learning.

### 1. Numbered File Structure

```
Microsoft Fabric Learning/
├── 00 - Learning Plan Overview.md
├── 00A - Glossary and Concepts.md
├── 01 - SQL Server Deployment Guide.md
├── 02 - Dummy Data Generation.md
├── 03 - Data Gateway Setup.md
├── 04 - Lakehouse Implementation.md
```

Why it works:
- **Sequential**: Follow the numbers to build understanding
- **Modular**: Jump to specific topics as needed
- **Extensible**: Add new files without restructuring

### 2. Glossary-First Approach

Before diving into implementation, create a glossary that explains:
- **What it is**: Technical definition
- **Analogy**: Real-world comparison for intuition
- **In YOUR setup**: How it maps to your infrastructure
- **ASCII diagram**: Visual representation

Example:
```markdown
### Lakehouse

**What it is**: A modern architecture combining data lakes and
data warehouses.

**Analogy**: If a data lake is a reservoir (raw water storage)
and a data warehouse is a treatment plant (processed, clean),
a lakehouse is both - store raw, query clean.

**In YOUR setup**: Your lh_bronze lakehouse stores raw data
from SQL Server. lh_silver contains cleansed versions. Both
use Delta format on OneLake.

            LAKEHOUSE
┌───────────────────────────────────────┐
│  OneLake Storage (Delta Format)       │
│       │                               │
│       ├──► Spark Engine (PySpark)     │
│       │    ETL, ML, Data Engineering  │
│       │                               │
│       └──► SQL Engine (T-SQL)         │
│            BI Queries, Reporting      │
└───────────────────────────────────────┘
```

### 3. Architecture Diagrams With YOUR IPs

Generic docs show `<your-server>`. My docs show `192.168.40.50`.

```
SQL Server (192.168.40.50)        Microsoft Fabric
═══════════════════════           ═════════════════
HomelabAnalytics DB    ─────────► lh_bronze (Lakehouse)
├── Customers (500K)    Gateway   ├── raw_customers
├── Products (10K)     ─────────► ├── raw_products
└── Orders (5M)                   └── raw_orders
```

When I look at my diagram, I can SSH to that exact IP and verify what I'm reading.

### 4. Certification Alignment

Every learning module maps to exam objectives:

```markdown
## Certification Alignment

### DP-600: Microsoft Fabric Analytics Engineer

| Exam Domain | Learning Coverage |
|-------------|-------------------|
| Plan and implement a solution | Week 7-8 |
| Prepare and serve data | Week 9-12 |
| Implement semantic models | Week 13-14 |
```

This ensures I'm not just learning randomly - I'm building toward recognized credentials.

### 5. Deliverables Checklist

Each module ends with concrete deliverables:

```markdown
### Key Deliverables

- [ ] SQL Server VM with 500K+ customers
- [ ] On-premises data gateway connected
- [ ] Bronze Lakehouse with all tables loaded
- [ ] Silver Lakehouse with cleansed data
- [ ] Gold Data Warehouse with star schema
- [ ] At least 1 Power BI report
```

I can verify my learning by checking boxes.

---

## Why This Works: The Psychology

### 1. Active Learning > Passive Reading

Building forces engagement. You can't skim infrastructure deployment.

### 2. Personalized Context Sticks

When every example uses YOUR infrastructure, there's no translation gap. The concepts are immediately applicable.

### 3. Teaching Deepens Understanding

Having Claude explain your infrastructure back to you is like teaching someone else. You catch gaps in your own understanding.

### 4. Documentation as Artifact

The docs you create become:
- Future reference material
- Onboarding guides for others
- Evidence of competence

### 5. Iteration is Built In

When you improve the infrastructure, you update the docs. Learning compounds.

---

## How to Implement This Yourself

### Step 1: Build Something Real

Don't follow tutorials exactly. Build something that solves YOUR problem:
- Your homelab, not a demo environment
- Your cloud subscription, not a sandbox
- Your data, not sample datasets

### Step 2: Ask Claude to Document It

Prompt template:
```
Create comprehensive learning documentation for [TECHNOLOGY]
based on my deployment:

My infrastructure:
- [List your components]
- [Include IP addresses, versions, configurations]

Include:
1. A glossary of all concepts with analogies
2. Architecture diagrams showing MY setup
3. Step-by-step guides referencing MY infrastructure
4. Certification alignment (if applicable)
5. Deliverables checklist
```

### Step 3: Use the Numbered File Structure

```
[Topic] Learning/
├── 00 - Learning Plan Overview.md
├── 00A - Glossary and Concepts.md
├── 01 - First Component Guide.md
├── 02 - Second Component Guide.md
└── ...
```

### Step 4: Include These Elements

Every document should have:
- **Tables**: Structured, scannable information
- **ASCII diagrams**: Visual architecture
- **YOUR IPs/names**: Real infrastructure references
- **Code blocks**: Actual commands you ran
- **Analogies**: Intuition builders

### Step 5: Iterate

As you learn more:
- Update the docs with new understanding
- Add troubleshooting sections when you hit issues
- Expand the glossary with new terms

---

## The Compound Effect

This approach compounds over time. My Obsidian vault now contains:

| Topic | Files | Total Size |
|-------|-------|------------|
| Microsoft Fabric Learning | 6 | ~150KB |
| Azure Sentinel Learning | 6 | ~130KB |
| Homelab Documentation | 41+ | ~500KB |

Each new technology builds on the documentation style. Each new project adds to the knowledge base. The learning accelerates because the infrastructure for learning already exists.

---

## Conclusion

Reverse engineering learning works because it grounds abstract concepts in concrete reality.

When Claude explains that "a lakehouse combines data lake flexibility with warehouse query performance," and your documentation shows YOUR `lh_bronze` lakehouse containing YOUR `raw_customers` table from YOUR SQL Server at `192.168.40.50` - the concept isn't abstract anymore. It's real. It's tangible. It's something you can query, modify, and understand.

The traditional approach asks: "How do I learn this technology?"

The reverse engineering approach asks: "How do I understand what I already built?"

The second question is easier to answer. And the answer teaches you more.

---

*This blog post was written by Claude Code, which also created the learning documentation it describes. The meta-layers continue to stack.*
