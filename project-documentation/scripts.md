# Project Scripts

## Overview

This document details the utility scripts available in the `/scripts` directory.

---

## export-n8n.sh

**Purpose:** Exports all n8n workflows and credentials to version-controllable JSON files.

**Location:** `./scripts/export-n8n.sh`

**What it does:**

1. Exports all workflows to `./n8n/demo-data/workflows/` (one JSON file per workflow)
2. Exports all credentials to `./n8n/demo-data/credentials/` (one JSON file per credential)

**Prerequisites:**

- Docker Compose stack must be running (`docker compose up -d`)
- n8n container must be healthy

**How to run:**

```bash
# From project root
./scripts/export-n8n.sh

# From anywhere
cd ~/Prototypes/n8n/automated-content-generation && ./scripts/export-n8n.sh
```

**Notes:**

- Credentials are exported without sensitive values (secrets are not included)
- Workflows auto-import on container startup via the `n8n-import` service
- Run this script after making changes to workflows in the n8n UI
