"""
Configuration for Blog Image Generator

Paths and settings for generating images for homelab blog posts.
"""

import os
from pathlib import Path

# ============================================================================
# PATHS
# ============================================================================

# Blog posts location (Obsidian vault)
BLOG_POSTS_PATH = Path(
    "C:/Users/herms/OneDrive/Obsidian Vault/Hermes's Life Knowledge Base/"
    "07 HomeLab Things/Homelab Blog Posts"
)

# Images output - stored in BOTH locations
OBSIDIAN_IMAGES_PATH = BLOG_POSTS_PATH / "images"

# Hugo repo for GitHub Pages deployment (clone this repo locally)
HUGO_REPO_PATH = Path("C:/Users/herms/Documents/GitHub/Clustered-Thoughts")
HUGO_IMAGES_PATH = HUGO_REPO_PATH / "static" / "images" / "blog"

# ============================================================================
# PROCESSING OPTIONS
# ============================================================================

# Sync images to Hugo repo automatically
SYNC_TO_HUGO = True

# Processing mode
PROCESS_ALL = False  # True = all posts, False = single post
DRY_RUN = False      # True = preview only, no file changes
OVERWRITE_EXISTING = False  # Skip posts that already have images

# ============================================================================
# GEMINI CLI SETTINGS
# ============================================================================

# Gemini model to use (via CLI)
GEMINI_MODEL = "gemini-2.5-pro"

# Timeout for Gemini CLI calls (seconds)
GEMINI_TIMEOUT = 120

# ============================================================================
# IMAGE GENERATION SETTINGS
# ============================================================================

# Image naming pattern: {post_number}-{section_index}-{type}.png
# Example: 03-02-architecture.png

# Supported visual types
VISUAL_TYPES = ["mermaid_diagram", "ai_image", "none"]

# Mermaid diagram types
MERMAID_TYPES = ["flowchart", "sequence", "graph", "stateDiagram", "classDiagram"]

# ============================================================================
# HOMELAB CONTEXT (for accurate diagram generation)
# ============================================================================

HOMELAB_CONTEXT = """
Homelab Infrastructure Context:
- Proxmox Cluster: MorpheusCluster (3-node + Qdevice)
  - node01: 192.168.20.20 (Primary VM Host)
  - node02: 192.168.20.21 (Service Host)
  - node03: 192.168.20.22 (Desktop Node, Azure Hybrid Lab)
- Networks:
  - VLAN 20: 192.168.20.0/24 (Infrastructure)
  - VLAN 40: 192.168.40.0/24 (Services/Docker)
  - VLAN 90: 192.168.90.0/24 (Management)
- Key Services:
  - Traefik (192.168.40.20): Reverse proxy
  - Authentik (192.168.40.21): SSO/Identity
  - Glance (192.168.40.12): Dashboard
  - Grafana (192.168.40.13): Monitoring
  - Synology NAS (192.168.20.31): Storage
- Technologies: Docker Compose, Kubernetes (9-node), Terraform, Ansible, PBS
"""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def ensure_directories():
    """Create output directories if they don't exist."""
    OBSIDIAN_IMAGES_PATH.mkdir(parents=True, exist_ok=True)
    if SYNC_TO_HUGO and HUGO_REPO_PATH.exists():
        HUGO_IMAGES_PATH.mkdir(parents=True, exist_ok=True)


def get_post_files():
    """Get all blog post markdown files."""
    return sorted(BLOG_POSTS_PATH.glob("Blog Post *.md"))
