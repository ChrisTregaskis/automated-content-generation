# n8n Marketing Automation POC - Setup Guide

> **Configuration**: Intel Mac, Docker, Claude API (no local LLM)

## Prerequisites

- Docker Desktop installed and running
- Anthropic API key (from https://console.anthropic.com/)
- Terminal access

---

## Step 1: Clone and Configure

```bash
# Clone the starter kit
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit

# Copy environment file
cp .env.example .env
```

---

## Step 2: Generate Secrets and Edit .env

Generate two secure random strings:

```bash
# Run twice, use each output for the values below
openssl rand -hex 32
```

Open the `.env` file:

```bash
code .env
```

Update these values:

```env
# Database settings
POSTGRES_USER=root
POSTGRES_PASSWORD=<generate-a-secure-password>
POSTGRES_DB=n8n

# n8n settings - paste your generated strings here
N8N_ENCRYPTION_KEY=<first-generated-string>
N8N_USER_MANAGEMENT_JWT_SECRET=<second-generated-string>

# Ollama (leave as default, we won't use it)
OLLAMA_HOST=ollama:11434
```

> ⚠️ **Keep these secrets safe** - if lost, you'll lose access to stored credentials.

---

## Step 3: Create Docker Compose Override

Create a file to disable Ollama (saves memory):

```bash
code docker-compose.override.yml
```

Paste this content:

```yaml
# docker-compose.override.yml
# Overrides to skip Ollama and reduce resource usage

services:
  # Disable Ollama since we're using Claude API
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

The n8n container mounts `./shared` to `/data/shared` inside the container.

```bash
# Create the marketing assets structure
mkdir -p shared/marketing-assets/{images/{products,lifestyle,brand},copy/{headlines,body-copy,ctas},templates/{social,email,ads},brand-guidelines}
mkdir -p shared/output/{drafts,approved}
mkdir -p shared/logs

# Verify structure
find shared -type d
```

### Folder Structure Reference

| Host Path                    | Container Path                   | Purpose           |
| ---------------------------- | -------------------------------- | ----------------- |
| `./shared/marketing-assets/` | `/data/shared/marketing-assets/` | Source assets     |
| `./shared/output/`           | `/data/shared/output/`           | Generated content |
| `./shared/logs/`             | `/data/shared/logs/`             | Workflow logs     |

---

## Step 5: Start the Stack

```bash
# Pull images (one-time)
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

## Step 6: Access n8n

| Service          | URL                             |
| ---------------- | ------------------------------- |
| n8n Editor       | http://localhost:5678           |
| Qdrant Dashboard | http://localhost:6333/dashboard |

1. Open http://localhost:5678
2. Create your owner account (first-time only)
3. You'll land on the workflow dashboard

---

## Step 7: Add Anthropic Credentials

1. Go to **Settings** (gear icon) → **Credentials**
2. Click **Add Credential**
3. Search for **Anthropic**
4. Enter your API key
5. Save

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

# Restart n8n
docker compose restart n8n

# Check running containers
docker compose ps
```

---

## Troubleshooting

### n8n won't start

```bash
# Check logs for errors
docker compose logs n8n

# Verify .env file has all required values
cat .env
```

### Port already in use

```bash
# Find what's using port 5678
lsof -i :5678

# Kill the process or change n8n's port in docker-compose.yml
```

### Reset everything (nuclear option)

```bash
docker compose down -v  # -v removes volumes (deletes all data!)
docker compose up -d
```

---

## Resource Management

If Docker is using too much memory:

1. Open **Docker Desktop** → **Settings** → **Resources**
2. Reduce memory allocation (4GB should suffice without Ollama)
3. Apply & restart Docker

---

## File Paths Quick Reference

When configuring n8n nodes to read/write files:

- **Use container paths**, not host paths
- Root shared folder: `/data/shared/`
- Marketing assets: `/data/shared/marketing-assets/`
- Output folder: `/data/shared/output/`
