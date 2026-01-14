---
tags:
  - context
  - claude-code
  - life-progress
  - glance
created: 2025-12-22
purpose: Provide context to other Claude Code instances about the Life Progress implementation
---

# Life Progress Widget Implementation Context

> **Purpose**: Copy this entire document as a prompt to another Claude Code instance to provide full context about the Life Progress widget implementation.

---

## PROMPT START

The Life Progress widget has been implemented on the homelab. Here is the complete context:

### What Was Built

A Life Progress widget on the Glance dashboard that displays horizontal progress bars showing:
- **Year progress** (red gradient) - How much of the current year has passed
- **Month progress** (yellow gradient) - How much of the current month has passed
- **Day progress** (green gradient) - How much of the current day has passed
- **Life progress** (green gradient) - How much of a 75-year lifespan has passed (based on birth date Feb 14, 1989)
- **Daily motivational quote** - Rotates through 30 quotes about time/mortality

### Architecture

Two components work together:

1. **Flask API** (`life-progress` container on docker-vm-core-utilities01:5051)
   - Calculates all progress percentages
   - Serves daily quote based on day of year
   - Returns JSON response

2. **Glance Widget** (in Glance dashboard config)
   - Calls the Flask API
   - Renders HTML progress bars with inline CSS
   - Uses gjson template syntax

### File Locations

All on **docker-vm-core-utilities01 (192.168.40.13)**:

| File | Path | Purpose |
|------|------|---------|
| Flask App | `/opt/life-progress/app.py` | Python API with progress calculations and quotes |
| Dockerfile | `/opt/life-progress/Dockerfile` | Container build config |
| Docker Compose | `/opt/life-progress/docker-compose.yml` | Container deployment |
| Glance Config | `/opt/glance/config/glance.yml` (on docker-lxc-glance 192.168.40.12) | Widget template with HTML/CSS |

### Flask API Code (`/opt/life-progress/app.py`)

```python
from flask import Flask, jsonify
from datetime import datetime, date
import calendar

app = Flask(__name__)

# Configuration - MODIFY THESE VALUES TO CUSTOMIZE
BIRTH_DATE = date(1989, 2, 14)  # Birth date (YYYY, MM, DD)
TARGET_AGE = 75                  # Target lifespan in years

# 30 motivational quotes about time and mortality
QUOTES = [
    "Time is the most valuable thing a man can spend. - Theophrastus",
    "Lost time is never found again. - Benjamin Franklin",
    "The trouble is, you think you have time. - Buddha",
    # ... 27 more quotes in the actual file
]

def get_daily_quote():
    today = date.today()
    day_of_year = today.timetuple().tm_yday
    return QUOTES[day_of_year % len(QUOTES)]

def calculate_progress():
    now = datetime.now()
    today = date.today()

    # Year progress
    year_start = datetime(now.year, 1, 1)
    year_end = datetime(now.year + 1, 1, 1)
    year_progress = ((now - year_start).total_seconds() / (year_end - year_start).total_seconds()) * 100

    # Month progress
    days_in_month = calendar.monthrange(now.year, now.month)[1]
    month_progress = ((now.day - 1 + now.hour/24 + now.minute/1440) / days_in_month) * 100

    # Day progress
    day_progress = ((now.hour * 3600 + now.minute * 60 + now.second) / 86400) * 100

    # Life progress
    target_date = date(BIRTH_DATE.year + TARGET_AGE, BIRTH_DATE.month, BIRTH_DATE.day)
    total_life_days = (target_date - BIRTH_DATE).days
    days_lived = (today - BIRTH_DATE).days
    life_progress = (days_lived / total_life_days) * 100

    return {
        "year": round(year_progress, 1),
        "month": round(month_progress, 1),
        "day": round(day_progress, 1),
        "life": round(life_progress, 1),
        "age": round(days_lived / 365.25, 1),
        "remaining_years": round((total_life_days - days_lived) / 365.25, 1),
        "remaining_days": total_life_days - days_lived,
        "quote": get_daily_quote(),
        "target_age": TARGET_AGE
    }

@app.route('/progress')
def progress():
    return jsonify(calculate_progress())

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5051)
```

### Docker Compose (`/opt/life-progress/docker-compose.yml`)

```yaml
services:
  life-progress:
    build: .
    container_name: life-progress
    restart: unless-stopped
    ports:
      - "5051:5051"
    environment:
      - TZ=Asia/Manila
```

### Dockerfile (`/opt/life-progress/Dockerfile`)

```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask gunicorn
COPY app.py .
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5051", "app:app"]
```

### Glance Widget Template (in `/opt/glance/config/glance.yml`)

The widget is in the first column of the Home page:

```yaml
- type: custom-api
  title: Life Progress
  cache: 1h
  url: http://192.168.40.13:5051/progress
  template: |
    <div style="font-family: sans-serif; padding: 10px;">
      <div style="display: flex; align-items: center; margin-bottom: 12px;">
        <span style="width: 60px; font-weight: bold; color: #fff;">Year</span>
        <div style="flex: 1; height: 24px; background: #444; border-radius: 4px; position: relative; margin: 0 15px;">
          <div style="width: {{ .JSON.Float "year" }}%; height: 100%; background: linear-gradient(90deg, #ff4444, #ff6666); border-radius: 4px;"></div>
          <span style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: #fff; font-weight: bold; text-shadow: 1px 1px 2px #000;">{{ .JSON.Float "year" | printf "%.1f" }}%</span>
        </div>
      </div>
      <div style="display: flex; align-items: center; margin-bottom: 12px;">
        <span style="width: 60px; font-weight: bold; color: #fff;">Month</span>
        <div style="flex: 1; height: 24px; background: #444; border-radius: 4px; position: relative; margin: 0 15px;">
          <div style="width: {{ .JSON.Float "month" }}%; height: 100%; background: linear-gradient(90deg, #ffaa00, #ffcc44); border-radius: 4px;"></div>
          <span style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: #fff; font-weight: bold; text-shadow: 1px 1px 2px #000;">{{ .JSON.Float "month" | printf "%.1f" }}%</span>
        </div>
      </div>
      <div style="display: flex; align-items: center; margin-bottom: 12px;">
        <span style="width: 60px; font-weight: bold; color: #fff;">Day</span>
        <div style="flex: 1; height: 24px; background: #444; border-radius: 4px; position: relative; margin: 0 15px;">
          <div style="width: {{ .JSON.Float "day" }}%; height: 100%; background: linear-gradient(90deg, #44aa44, #66cc66); border-radius: 4px;"></div>
          <span style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: #fff; font-weight: bold; text-shadow: 1px 1px 2px #000;">{{ .JSON.Float "day" | printf "%.1f" }}%</span>
        </div>
      </div>
      <div style="display: flex; align-items: center; margin-bottom: 12px;">
        <span style="width: 60px; font-weight: bold; color: #fff;">Life</span>
        <div style="flex: 1; height: 24px; background: #444; border-radius: 4px; position: relative; margin: 0 15px;">
          <div style="width: {{ .JSON.Float "life" }}%; height: 100%; background: linear-gradient(90deg, #44aa44, #66cc66); border-radius: 4px;"></div>
          <span style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: #fff; font-weight: bold; text-shadow: 1px 1px 2px #000;">{{ .JSON.Float "life" | printf "%.1f" }}%</span>
        </div>
      </div>
      <div style="text-align: center; margin-top: 15px; padding: 10px; background: rgba(255,255,255,0.1); border-radius: 8px;">
        <em style="color: #aaa; font-size: 14px;">"{{ .JSON.String "quote" }}"</em>
      </div>
    </div>
```

### Glance Template Syntax (gjson)

| Syntax | Purpose |
|--------|---------|
| `{{ .JSON.Float "field" }}` | Access float/number fields from JSON |
| `{{ .JSON.String "field" }}` | Access string fields from JSON |
| `{{ .JSON.Int "field" }}` | Access integer fields from JSON |
| `| printf "%.1f"` | Format number to 1 decimal place |

**Important**: Do NOT use `.year` or `.field` directly - you MUST use `.JSON.Float "field"` syntax.

### API Response Example

```bash
curl http://192.168.40.13:5051/progress
```

Returns:
```json
{
  "year": 98.3,
  "month": 70.5,
  "day": 45.2,
  "life": 47.8,
  "age": 35.9,
  "remaining_years": 39.1,
  "remaining_days": 14289,
  "quote": "Time is the most valuable thing a man can spend. - Theophrastus",
  "target_age": 75
}
```

### Common Commands

```bash
# Test API
curl http://192.168.40.13:5051/progress | jq

# Rebuild after code changes
ssh hermes-admin@192.168.40.13 "cd /opt/life-progress && sudo docker compose up -d --build"

# View logs
ssh hermes-admin@192.168.40.13 "sudo docker logs life-progress"

# Restart Glance after config changes (Glance is on LXC 200)
ssh hermes-admin@192.168.40.12 "docker restart glance"

# Read current Flask app
ssh hermes-admin@192.168.40.13 "cat /opt/life-progress/app.py"

# Read current Glance config (Glance is on LXC 200)
ssh hermes-admin@192.168.40.12 "cat /opt/glance/config/glance.yml"
```

### To Modify Birth Date or Target Age

1. SSH and edit: `ssh hermes-admin@192.168.40.13 "sudo nano /opt/life-progress/app.py"`
2. Change `BIRTH_DATE = date(1989, 2, 14)` or `TARGET_AGE = 75`
3. Rebuild: `cd /opt/life-progress && sudo docker compose up -d --build`

### To Add/Modify Quotes

Edit the `QUOTES` list in `/opt/life-progress/app.py`. Quote selection uses `day_of_year % len(QUOTES)` so each day shows a consistent quote.

### Key Lessons Learned

1. **Glance v0.7.0+ requires directory mount**: Use `./config:/app/config` not `./glance.yml:/app/glance.yml`
2. **Glance max 3 columns per page**: Cannot exceed this limit
3. **Template syntax is gjson**: Use `.JSON.Float "field"` not `.field`
4. **HTML works in templates**: Can use full HTML/CSS for custom styling

## PROMPT END

---

*Use this document to bring another Claude Code instance up to speed on the Life Progress implementation.*
