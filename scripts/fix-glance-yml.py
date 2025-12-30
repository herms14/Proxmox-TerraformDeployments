#!/usr/bin/env python3
"""Fix Glance YAML configuration for Pi-hole entry."""

import re

with open("/opt/glance/config/glance.yml", "r") as f:
    content = f.read()

# Fix the messed up section around Paperless
# Find the pattern where Pi-hole was incorrectly inserted
old_pattern = """      - title: Paperless
        icon: si:paperlessngx
      - title: Pi-hole
        url: http://192.168.20.53/admin/
        icon: si:pihole
        url: http://192.168.40.13:8000"""

new_pattern = """      - title: Paperless
        url: http://192.168.40.13:8000
        icon: si:paperlessngx
      - title: Pi-hole
        url: http://192.168.20.53/admin/
        icon: si:pihole"""

content = content.replace(old_pattern, new_pattern)

with open("/opt/glance/config/glance.yml", "w") as f:
    f.write(content)

print("Fixed YAML structure")
