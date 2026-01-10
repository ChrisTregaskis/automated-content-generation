# n8n Project Setup Guide

> Reusable setup guide for self-hosted n8n prototypes with Claude API integration.
> Based on learnings from the Marketing Content Automation POC.

## Prerequisites

- Docker Desktop installed and running
- Anthropic API key (from https://console.anthropic.com/)
- Terminal access
- Cloudflare CLI (`cloudflared`) — only if using webhook triggers

---

## Step 1: Clone the Starter Kit

```bash
# Clone n8n's self-hosted AI starter kit
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit

# Rename to your project (optional)
cd ..
mv self-hosted-ai-starter-kit your-project-name
cd your-project-name

# Initialise git (if you renamed)
rm -rf .git
git init
```

---

## Step 2: Configure Environment Variables

```bash
# Copy the example environment file
cp .env.example .env
```

Generate two secure random strings for n8n secrets:

```bash
# Run twice, save each output
openssl rand -hex 32
```

Edit `.env` and update these values:

```env
# Database settings
POSTGRES_USER=root
POSTGRES_PASSWORD=<generate-a-secure-password>
POSTGRES_DB=n8n

# n8n settings — paste your generated strings here
N8N_ENCRYPTION_KEY=<first-generated-string>
N8N_USER_MANAGEMENT_JWT_SECRET=<second-generated-string>
```

> **Important:** Keep these secrets safe. If lost, you'll lose access to stored credentials in n8n.

---

## Step 3: Create Docker Compose Override (Disable Ollama)

If you're using Claude API instead of local LLMs, disable Ollama to save resources.

Create `docker-compose.override.yml`:

```yaml
# docker-compose.override.yml
# Disables Ollama to reduce resource usage when using Claude API

services:
  # Disable Ollama
  ollama:
    profiles:
      - disabled

  # Disable Ollama pull helper
  ollama-pull-llama:
    profiles:
      - disabled
```

---

## Step 4: Create Shared Folder Structure

The n8n container mounts `./shared` on the host to `/data/shared/` inside the container.

Create your project's folder structure:

```bash
# Create base shared structure
mkdir -p shared/input
mkdir -p shared/output
mkdir -p shared/logs

# Verify structure
find shared -type d
```

Adjust the folder structure to match your project needs. The key point is:

| Host Path   | Container Path  | Purpose                  |
| ----------- | --------------- | ------------------------ |
| `./shared/` | `/data/shared/` | All n8n-accessible files |

---

## Step 5: Start the Docker Stack

```bash
# Pull images (first time only)
docker compose pull

# Start services in detached mode
docker compose up -d
```

Verify containers are running:

```bash
docker compose ps
```

Expected output shows `n8n`, `postgres`, and `qdrant` as running.

---

## Step 6: Access n8n and Create Account

| Service          | URL                             |
| ---------------- | ------------------------------- |
| n8n Editor       | http://localhost:5678           |
| Qdrant Dashboard | http://localhost:6333/dashboard |

1. Open http://localhost:5678
2. Create your owner account (first time only)
3. You'll land on the workflow dashboard

---

## Step 7: Add Anthropic Credentials

1. Go to **Settings** (gear icon) → **Credentials**
2. Click **Add Credential**
3. Search for **Anthropic**
4. Enter your API key
5. Save

---

## Step 8: Initialise Git Repository

```bash
# Add standard ignores
echo ".env" >> .gitignore
echo "*.log" >> .gitignore

# Initial commit
git add .
git commit -m "Initial n8n project setup"
```

---

## Common Commands

```bash
# Start the stack
docker compose up -d

# Stop the stack
docker compose down

# View logs (all services)
docker compose logs -f

# View n8n logs only
docker compose logs -f n8n

# Restart n8n (after config changes)
docker compose restart n8n

# Check running containers
docker compose ps

# Full restart (sometimes needed after env changes)
docker compose down && docker compose up -d
```

---

## Exporting Workflows for Version Control

Workflows are stored in n8n's database, not as files. To export for version control:

```bash
# Create export directory
mkdir -p n8n/demo-data/workflows

# List all workflows to see IDs
docker compose exec n8n n8n list:workflow

# Export a specific workflow
docker compose exec n8n n8n export:workflow --id=<workflow-id> --output=/demo-data/workflows/<filename>.json

# Or create an export script (see below)
```

Example export script (`scripts/export-n8n.sh`):

```bash
#!/bin/bash
docker compose exec n8n n8n export:workflow --all --output=/demo-data/workflows/
```

**Note:** The container path `/demo-data/workflows/` maps to `./n8n/demo-data/workflows/` on the host.

---

## Importing Workflows

```bash
# Import via n8n CLI
docker compose exec n8n n8n import:workflow --input=/demo-data/workflows/<filename>.json
```

Or manually via n8n UI: **Workflows** → **Import from File**.

---

## Cloudflare Tunnel (Only If Using Webhooks)

If your workflows require external webhook triggers (e.g., Slack interactivity):

```bash
# Start a quick tunnel (generates a new URL each time)
cloudflared tunnel --url http://localhost:5678
```

The tunnel URL will be displayed in the output. Update n8n's webhook URL:

1. Go to **Settings** → **n8n instance**
2. Set **Webhook URL** to your tunnel URL

> **Note:** Quick tunnels generate a new random URL each session. For stable URLs, configure a [named tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps).

---

## Troubleshooting & Lessons Learned

### 1. YAML Anchors Override, Don't Merge

**Problem:** Adding an `environment:` block to a service using `<<: *anchor` **completely replaces** the anchor's environment variables instead of merging.

**Bad example:**

```yaml
x-n8n: &service-n8n
  environment:
    - DB_TYPE=postgresdb

services:
  n8n:
    <<: *service-n8n
    environment: # This OVERRIDES, doesn't merge!
      - CUSTOM_VAR=value
```

**Solution:** Put additional env vars in the `.env` file instead, which is loaded via `env_file: - .env` in the anchor.

---

### 2. File Access Restrictions in n8n 2.0.x

The `N8N_RESTRICT_FILE_ACCESS_TO` environment variable can be problematic. If file access issues occur:

1. Verify the volume mount: `docker compose exec n8n ls -la /data/shared/`
2. Check env vars: `docker compose exec n8n env | grep N8N_RESTRICT`
3. Try removing the restriction for local development

---

### 3. Binary File Parsing in Code Nodes

**Problem:** Direct `Buffer.from(item.binary[key].data, 'base64')` doesn't work reliably.

**Solution:** Use n8n's built-in helper:

```javascript
const buffer = await this.helpers.getBinaryDataBuffer(index, binaryKey);
return JSON.parse(buffer.toString("utf-8"));
```

---

### 4. Read/Write Files Node Patterns

**Reading text files:**

The "Read File(s) From Disk" node reads files as binary by default. Add an "Extract From Text File" node after to convert to string.

```
[Read Files Node] → [Extract From Text File] → [Rest of workflow]
```

**Writing JSON files:**

The "Write File to Disk" node expects binary data. Add a "Convert to File" node before it.

```
[Code Node with JSON] → [Convert to File (JSON)] → [Write File to Disk]
```

---

### 5. Anthropic Node in n8n 2.0.x

Search for "Anthropic" (not "Anthropic Claude"), then select "Message a model" under TEXT ACTIONS.

---

### 6. Slack Integration Tips (If Needed)

- Use "Slack API" credential type (Bot Token only) — not "Slack OAuth2 API" which requires redirect URI configuration
- Native Slack node Block Kit rendering is unreliable — use HTTP Request node to call `chat.postMessage` directly
- For interactive buttons, enable Interactivity in your Slack app and point the Request URL to your n8n webhook

---

### 7. Useful Diagnostic Commands

```bash
# Check env vars reaching container
docker compose exec n8n env | grep -i N8N

# Verify volume mount / file access
docker compose exec n8n ls -la /data/shared/

# Check n8n logs
docker compose logs n8n --tail 50

# Interactive shell in container
docker compose exec n8n sh
```

---

### 8. Port Already in Use

```bash
# Find what's using port 5678
lsof -i :5678

# Kill the process or change n8n's port in docker-compose.yml
```

---

### 9. Reset Everything (Nuclear Option)

```bash
# WARNING: -v removes volumes and deletes all data!
docker compose down -v
docker compose up -d
```

---

## File Paths Quick Reference

When configuring n8n nodes to read/write files:

- **Always use container paths**, not host paths
- Root shared folder: `/data/shared/`
- Input files: `/data/shared/input/`
- Output files: `/data/shared/output/`

---

## Resource Management

If Docker uses too much memory:

1. Open **Docker Desktop** → **Settings** → **Resources**
2. Reduce memory allocation (4GB should suffice without Ollama)
3. Apply & restart Docker

---

## Project Checklist

- [ ] Clone starter kit
- [ ] Configure `.env` with secrets
- [ ] Create `docker-compose.override.yml` to disable Ollama
- [ ] Create `shared/` folder structure
- [ ] Start Docker stack
- [ ] Create n8n owner account
- [ ] Add Anthropic credentials
- [ ] Initialise git repository
- [ ] Build first workflow

---

## Design Principles for n8n Workflows

1. **Idempotency** — workflows can safely retry without side effects
2. **Observability** — include logging and clear naming conventions
3. **Modularity** — break complex workflows into sub-workflows
4. **Error Resilience** — always include error handling branches
5. **Data Validation** — validate inputs early, fail fast with clear errors
6. **Dual Triggers** — use Manual Trigger + "When Executed by Another Workflow" for testability

---

## Next Steps

After setup is complete:

1. Create a `CLAUDE.md` file with project-specific context
2. Plan your workflow architecture
3. Build workflows incrementally, testing each in isolation
4. Connect workflows using "Execute Sub-workflow" nodes for orchestration
