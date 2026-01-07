# Marketing Content Automation POC

## Project Overview

Automated marketing content generation using n8n workflows, pulling from a local pool of marketing assets. This is a proof-of-concept demonstrating automated content assembly and generation with human-in-the-loop checkpoints.

## Technical Stack

- **n8n**: Self-hosted workflow automation (http://localhost:5678)
- **PostgreSQL**: Data persistence
- **Qdrant**: Vector store for embeddings (http://localhost:6333)
- **Claude API**: LLM provider (via Anthropic API, not local Ollama)

## File System Structure

```
./shared/                          # Host path (this repository)
/data/shared/                      # n8n container path (mounted volume)
├── marketing-assets/
│   ├── images/
│   │   ├── products/
│   │   ├── lifestyle/
│   │   └── brand/
│   ├── copy/
│   │   ├── headlines/
│   │   ├── body-copy/
│   │   └── ctas/
│   ├── templates/
│   │   ├── social/
│   │   ├── email/
│   │   └── ads/
│   └── brand-guidelines/
├── output/                        # Generated content output
│   ├── drafts/
│   └── approved/
└── logs/                          # Workflow logs
```

## Docker Commands

```bash
# Start the stack
docker compose up -d

# Stop the stack
docker compose down

# View logs
docker compose logs -f n8n

# Restart n8n only
docker compose restart n8n

# Check service status
docker compose ps
```

## Cloudflare Tunnel (Required for Webhooks)

Workflows using webhook triggers require a Cloudflare tunnel to expose the local n8n instance to the internet. Without the tunnel running, external services (e.g. Slack) cannot reach the webhook endpoints.

### Starting the Tunnel

```bash
# Start a quick tunnel (generates a new URL each time)
cloudflared tunnel --url http://localhost:5678
```

The tunnel URL will be displayed in the output:
```
|  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
|  https://<random-subdomain>.trycloudflare.com                                              |
```

### Configuring n8n Webhook URL

After starting the tunnel, update n8n's webhook URL in the UI:
1. Go to **Settings** > **n8n instance** (or environment variables)
2. Set the **Webhook URL** to your tunnel URL (e.g. `https://hansen-visiting-mailed-guam.trycloudflare.com`)

Alternatively, set the `WEBHOOK_URL` environment variable in your `.env` file (requires container restart).

### Important Notes

- **Quick tunnels** generate a new random URL each time they're started - you'll need to update webhook URLs in n8n and any external services
- For production use, consider a [named tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps) with a stable URL
- The tunnel must remain running for webhooks to function

## n8n Design Principles

1. **Idempotency** - workflows can safely retry without side effects
2. **Observability** - include logging and clear naming conventions
3. **Modularity** - break complex workflows into sub-workflows
4. **Error Resilience** - always include error handling branches
5. **Data Validation** - validate inputs early, fail fast with clear errors

## Key Workflow Patterns

### Asset Selection
```
[Trigger] → [Read Asset Folder] → [Filter by Criteria] → [Random/Weighted Selection] → [Output]
```

### Content Generation
```
[Asset Input] → [Build Prompt] → [Claude API] → [Parse Output] → [Quality Check] → [Save Draft]
```

### Full Pipeline
```
[Schedule/Manual Trigger]
    → [Load Campaign Config]
    → [Select Assets from Pool]
    → [Generate Content Variations]
    → [Save to Output Folder]
    → [Notify (optional)]
```

## Content Principles

1. **Audience-First** - start with who you're speaking to
2. **Value-Driven** - educate, entertain, or solve a problem
3. **Brand Consistency** - maintain voice across all assets
4. **Platform-Native** - adapt format to each platform's norms
5. **Repurposing** - design for maximum reuse

## Development Guidelines

- Use British English spelling
- 2 spaces for code indentation
- Start simple - get a working flow before optimising
- Document assumptions and decision points
- Include manual review steps before any publishing
- Log asset selections, prompts used, and outputs generated

## Environment Setup

Copy `.env.example` to `.env` and configure:

```bash
# Generate secure keys
openssl rand -hex 32
```

Required variables:
- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB`
- `N8N_ENCRYPTION_KEY`
- `N8N_USER_MANAGEMENT_JWT_SECRET`

## MCP Servers (Future)

- **Filesystem MCP** - for local asset access
- **Brave Search** / **Tavily** - for research/trends
- **GitHub** - for version control of workflows
