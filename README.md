# Marketing Content Automation POC

Automated marketing content generation using n8n workflows with human-in-the-loop approval via Slack. Built as a proof-of-concept using Bentley Motors as an example for their strong brand.

**Status:** POC Complete

## What It Does

1. **Assembles context** from marketing assets (images, copy examples, brand guidelines)
2. **Generates original content** via Claude API based on campaign parameters
3. **Posts to Slack** for human review with Approve / Reject / Request Changes buttons
4. **Handles feedback loops** — rejected content can be revised with specific feedback
5. **Renders HTML previews** of approved content for each social platform

See [architecture.md](project-documentation/architecture.md) for detailed system design and data flows.

## Technical Stack

| Component             | Purpose                 | Access                |
| --------------------- | ----------------------- | --------------------- |
| **n8n**               | Workflow automation     | http://localhost:5678 |
| **PostgreSQL**        | n8n data persistence    | Port 5432             |
| **Qdrant**            | Vector store (not used) | http://localhost:6333 |
| **Claude API**        | Content generation      | Via Anthropic API     |
| **Slack**             | Human review interface  | Prototypes workspace  |
| **Cloudflare Tunnel** | Webhook URL for Slack   | Via cloudflared       |

---

## Setup Instructions

### Prerequisites

- Docker Desktop installed and running
- Anthropic API key ([console.anthropic.com](https://console.anthropic.com/))
- Cloudflare CLI (`cloudflared`) for webhook tunnelling
- Access to the "Prototypes" Slack workspace (ask the team lead)

### 1. Clone and Configure Environment

```bash
git clone <repo-url>
cd automated-content-generation
cp .env.example .env
```

Generate secrets and update `.env`:

```bash
# Generate two secure keys
openssl rand -hex 32  # Use for N8N_ENCRYPTION_KEY
openssl rand -hex 32  # Use for N8N_USER_MANAGEMENT_JWT_SECRET
```

Required `.env` values:

- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB`
- `N8N_ENCRYPTION_KEY`
- `N8N_USER_MANAGEMENT_JWT_SECRET`

### 2. Start the Docker Stack

```bash
docker compose up -d
```

Verify services are running:

```bash
docker compose ps
```

You should see `n8n`, `postgres`, and `qdrant` containers running.

### 3. Access n8n

Open http://localhost:5678 and create your owner account (first time only).

### 4. Add Credentials in n8n

Go to **Settings** > **Credentials** and add:

| Credential Type | Name (suggested)  | Required Values                  |
| --------------- | ----------------- | -------------------------------- |
| **Anthropic**   | Anthropic API     | Your API key                     |
| **Slack API**   | Slack Bot Token   | Bot token (`xoxb-...`)           |
| **Header Auth** | Slack Header Auth | `Authorization: Bearer xoxb-...` |

### 5. Import Workflows

Workflows are stored in `n8n/demo-data/workflows/`. Import them via:

```bash
# List available workflows
ls n8n/demo-data/workflows/

# Import via n8n CLI (from inside container)
docker compose exec n8n n8n import:workflow --input=/demo-data/workflows/<filename>.json
```

Or manually import via the n8n UI: **Workflows** > **Import from File**.

### 6. Start Cloudflare Tunnel (Required for Slack Webhooks)

```bash
cloudflared tunnel --url http://localhost:5678
```

Copy the generated URL (e.g., `https://random-words.trycloudflare.com`).

**Update n8n webhook URL:**

1. Go to **Settings** > **n8n instance**
2. Set **Webhook URL** to your tunnel URL

**Update Slack app interactivity URL:**

1. Go to [api.slack.com/apps](https://api.slack.com/apps) > Your app > **Interactivity & Shortcuts**
2. Set Request URL to: `<tunnel-url>/webhook/approval-handler`

### 7. Test the Pipeline

1. Open **Workflow 6: Master Orchestrator** in n8n
2. Click **Test Workflow**
3. Select campaign parameters (theme, platform, vehicle)
4. Check `#content-review` in Slack for the review request
5. Click Approve/Reject/Request Changes to test the approval flow

---

## Project Structure

```
├── shared/                          # Mounted to /data/shared/ in n8n
│   ├── marketing-assets/            # Source assets (images, copy, templates)
│   ├── rendered-templates/          # HTML mockup templates
│   └── output/                      # Generated content
│       ├── drafts/                  # Awaiting review
│       ├── approved/                # Approval records
│       ├── rejected/                # Rejection records
│       └── rendered-approved/       # HTML previews
├── project-documentation/           # Detailed workflow documentation
├── internal-personal-notes/         # Working notes and learnings
└── n8n/demo-data/workflows/         # Exported workflow JSON files
```

---

## Workflows Overview

| #   | Workflow               | Purpose                                        |
| --- | ---------------------- | ---------------------------------------------- |
| 1   | Asset Inventory Reader | Utility for exploring assets (not in pipeline) |
| 2   | Content Assembler      | Filter assets, build content package           |
| 3   | AI Content Generator   | Generate content via Claude, save draft        |
| 4   | Slack Notifier         | Post review request to Slack                   |
| 5   | Approval Handler       | Process approve/reject/change via webhook      |
| 6   | Master Orchestrator    | Orchestrate WF2 → WF3 → WF4 pipeline           |

See [project-documentation/workflows/](project-documentation/workflows/) for detailed documentation on each workflow.

---

## Common Commands

```bash
# Start/stop stack
docker compose up -d
docker compose down

# View logs
docker compose logs -f n8n

# Restart n8n after config changes
docker compose restart n8n

# Export workflows for version control
./scripts/export-n8n.sh
```

---

## Onboarding Checklist

- [ ] Get added to "Prototypes" Slack workspace
- [ ] Get added to `#content-review` channel
- [ ] Obtain Anthropic API key
- [ ] Clone repo and configure `.env`
- [ ] Start Docker stack
- [ ] Add credentials in n8n
- [ ] Import workflows
- [ ] Start Cloudflare tunnel
- [ ] Update Slack app interactivity URL (or confirm it's pointing to your tunnel)
- [ ] Run test workflow

---

## Documentation

- [Architecture](project-documentation/architecture.md) — System design and data flows
- [Working Notes](internal-personal-notes/general-working-notes.md) — Detailed implementation notes and troubleshooting
- [Workflow Documentation](project-documentation/workflows/) — Per-workflow guides

---

## Notes for New Developers

**Slack webhook configuration:** Each developer running locally needs their own Cloudflare tunnel URL configured in the Slack app's interactivity settings. Coordinate with the team when testing webhook flows.

**Quick tunnels are ephemeral:** The `cloudflared tunnel` command generates a new URL each session. You'll need to update the Slack interactivity URL each time you restart the tunnel.

**Workflow testing:** Each workflow (2, 3, 4) has a dual-trigger pattern — you can test them standalone via Manual Trigger, or run the full pipeline via Workflow 6.
