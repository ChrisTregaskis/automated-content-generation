# System Architecture

This document describes the architecture of the Marketing Content Automation POC, explaining how components interact to generate fresh marketing content with human-in-the-loop approval.

**Status:** ✅ POC Complete — All workflows implemented and tested

---

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Marketing Content Automation POC                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    WORKFLOW 6: MASTER ORCHESTRATOR                   │   │
│  │  [Trigger] → [WF2: Assemble] → [WF3: Generate] → [WF4: Notify]       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                      │                      │
│                                                      ▼                      │
│  ┌──────────────┐     ┌───────────────┐     ┌──────────────┐               │
│  │  Marketing   │────▶│  Claude API   │────▶│    Slack     │               │
│  │   Assets     │     │  (Anthropic)  │     │   Review     │               │
│  │   (Local)    │     │               │     │   Channel    │               │
│  └──────────────┘     └───────────────┘     └──────┬───────┘               │
│                                                     │                       │
│                                                     ▼                       │
│                                        ┌────────────────────────┐           │
│                                        │  WORKFLOW 5: APPROVAL  │           │
│                                        │  [Approve/Reject/Edit] │           │
│                                        └────────────────────────┘           │
│                                                     │                       │
│                                                     ▼                       │
│                                        ┌────────────────────────┐           │
│                                        │   Output: Approved     │           │
│                                        │   Content + HTML       │           │
│                                        │   Platform Previews    │           │
│                                        └────────────────────────┘           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Technical Stack

| Component             | Purpose                     | Local Access          | Status       |
| --------------------- | --------------------------- | --------------------- | ------------ |
| **n8n**               | Workflow automation engine  | http://localhost:5678 | ✅ Active    |
| **PostgreSQL**        | n8n data persistence        | Port 5432             | ✅ Active    |
| **Qdrant**            | Vector store for embeddings | http://localhost:6333 | 🔜 Available |
| **Claude API**        | LLM for content generation  | Via Anthropic API     | ✅ Active    |
| **Slack**             | Human review interface      | Prototypes workspace  | ✅ Active    |
| **Cloudflare Tunnel** | Stable webhook URLs         | Via cloudflared       | ✅ Active    |

All services run as Docker containers orchestrated via `docker-compose.yml`.

---

## Workflow Architecture

### Complete Workflow Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   ┌─────────────────┐                                                       │
│   │   Workflow 1    │  Asset Inventory Reader (utility/exploration)         │
│   │   (Standalone)  │  Not part of main pipeline                            │
│   └─────────────────┘                                                       │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                  WORKFLOW 6: MASTER ORCHESTRATOR                    │   │
│   │                                                                     │   │
│   │   [Manual/Form Trigger]                                             │   │
│   │          │                                                          │   │
│   │          ▼                                                          │   │
│   │   ┌─────────────────┐     ┌─────────────────┐     ┌──────────────┐  │   │
│   │   │   Workflow 2    │────▶│   Workflow 3    │────▶│  Workflow 4  │  │   │
│   │   │    Content      │     │   AI Content    │     │    Slack     │  │   │
│   │   │   Assembler     │     │   Generator     │     │   Notifier   │  │   │
│   │   └─────────────────┘     └─────────────────┘     └──────────────┘  │   │
│   │                                                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                          │                  │
│                                                          ▼                  │
│                                               ┌──────────────────┐          │
│                                               │  Slack Message   │          │
│                                               │  with Buttons    │          │
│                                               └────────┬─────────┘          │
│                                                        │                    │
│                                          ┌─────────────┼─────────────┐      │
│                                          ▼             ▼             ▼      │
│                                     [Approve]    [Reject]    [Request       │
│                                                               Changes]      │
│                                          │             │             │      │
│                                          └─────────────┼─────────────┘      │
│                                                        ▼                    │
│                                               ┌──────────────────┐          │
│                                               │   Workflow 5     │          │
│                                               │ Approval Handler │          │
│                                               │   (Webhook)      │          │
│                                               └──────────────────┘          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Workflow Summary

| #   | Workflow               | Purpose                                 | Trigger Type                 |
| --- | ---------------------- | --------------------------------------- | ---------------------------- |
| 1   | Asset Inventory Reader | Utility workflow for exploring assets   | Manual                       |
| 2   | Content Assembler      | Filter assets, build content package    | Manual / Form / Sub-workflow |
| 3   | AI Content Generator   | Generate content via Claude, save draft | Manual / Sub-workflow        |
| 4   | Slack Notifier         | Post review request to Slack            | Manual / Sub-workflow        |
| 5   | Approval Handler       | Process approve/reject/change requests  | Webhook (Slack interactions) |
| 6   | Master Orchestrator    | Coordinate WF2→WF3→WF4 pipeline         | Manual / Form                |

### Dual-Trigger Pattern

Workflows 2, 3, and 4 use a dual-trigger pattern enabling both orchestrated and standalone execution:

```
[When Executed by Another Workflow] ──┐
                                      ├─► [Merge Inputs] → [Workflow Logic]
[Manual Trigger] → [Test Data] ───────┘
```

This allows:

- **Orchestrator calls**: Production pipeline via WF6
- **Standalone testing**: Development and debugging via Manual Trigger
- **Form testing**: Parameter exploration via Form Submission (WF2, WF6)

---

## Content Generation Model

### Key Principle: Generation, Not Assembly

Claude **generates new, original content** for each workflow run. The marketing assets serve as **context and examples**, not a finite pool to stitch together.

### How Assets Inform Generation

| Asset Type            | Role in Prompt     | Purpose                                           |
| --------------------- | ------------------ | ------------------------------------------------- |
| **Brand Guidelines**  | System context     | Defines voice, tone, vocabulary rules             |
| **Example Headlines** | Few-shot examples  | Shows approved style and structure                |
| **Example Body Copy** | Few-shot examples  | Demonstrates sensory language, specificity        |
| **Image Metadata**    | Generation context | Provides themes, vehicle, shot type for relevance |
| **Platform Template** | Output constraints | Character limits, hashtag rules, formatting       |

### Prompt Construction

```
[System: Brand voice and tone guidelines]
[Context: Selected image metadata - vehicle, themes, shot type]
[Examples: 2-3 headlines and body copy pieces matching the theme]
[Template: Platform constraints - character limit, hashtag pool]
[Instruction: Generate new Instagram post for this Continental GT image...]
```

---

## Data Flow Architecture

### End-to-End Pipeline

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  1. TRIGGER (Workflow 6)                                                     │
│     Manual trigger or Form submission with campaign parameters               │
│     Input: { theme, platform, vehicle }                                      │
│                         │                                                    │
│                         ▼                                                    │
│  2. CONTENT ASSEMBLY (Workflow 2)                                            │
│     ┌─────────────────────────────────────────────────────┐                  │
│     │  Load: images-manifest.json, headlines, body copy   │                  │
│     │  Filter by: theme, vehicle compatibility            │                  │
│     │  Select: random image from filtered pool            │                  │
│     │  Load: platform template constraints                │                  │
│     │  Output: Content package with examples              │                  │
│     └─────────────────────────────────────────────────────┘                  │
│                         │                                                    │
│                         ▼                                                    │
│  3. AI GENERATION (Workflow 3)                                               │
│     ┌─────────────────────────────────────────────────────┐                  │
│     │  Load: brand-guidelines/voice-and-tone.md           │                  │
│     │  Build: comprehensive prompt with all context       │                  │
│     │  Call: Claude API (claude-sonnet-4-20250514)               │                  │
│     │  Parse: JSON response with generated content        │                  │
│     │  Validate: character limits, spelling, constraints  │                  │
│     │  Save: draft JSON to output/drafts/                 │                  │
│     └─────────────────────────────────────────────────────┘                  │
│                         │                                                    │
│                         ▼                                                    │
│  4. SLACK NOTIFICATION (Workflow 4)                                          │
│     ┌─────────────────────────────────────────────────────┐                  │
│     │  Read: draft JSON file                              │                  │
│     │  Build: Slack Block Kit message with preview        │                  │
│     │  Include: image, content sections, metadata         │                  │
│     │  Add: Approve / Reject / Request Changes buttons    │                  │
│     │  Post: to #content-review channel                   │                  │
│     └─────────────────────────────────────────────────────┘                  │
│                         │                                                    │
│                         ▼                                                    │
│  5. HUMAN REVIEW (Slack)                                                     │
│     Reviewer sees formatted preview, clicks action button                    │
│                         │                                                    │
│          ┌──────────────┼──────────────┐                                     │
│          ▼              ▼              ▼                                     │
│     [Approve]      [Reject]    [Request Changes]                             │
│          │              │              │                                     │
│          └──────────────┼──────────────┘                                     │
│                         ▼                                                    │
│  6. APPROVAL PROCESSING (Workflow 5 - Webhook)                               │
│     ┌─────────────────────────────────────────────────────┐                  │
│     │  Approve: Create approval record, render HTML       │                  │
│     │           preview, update Slack message             │                  │
│     │  Reject: Create rejection record, update message    │                  │
│     │  Changes: Open modal, capture feedback, regenerate  │                  │
│     │           content with Claude, post new review      │                  │
│     └─────────────────────────────────────────────────────┘                  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Inter-Workflow Data Contracts

**WF6 → WF2 (Campaign Parameters):**

```json
{
  "theme": "craftsmanship",
  "platform": "instagram",
  "vehicle": "continental-gt"
}
```

**WF2 → WF3 (Content Package):**

```json
{
  "packageId": "pkg-...",
  "params": { "theme": "...", "platform": "...", "vehicle": "..." },
  "image": { "id": "...", "filename": "...", "path": "...", "themes": [...] },
  "examples": { "headlines": [...], "bodyCopy": [...], "ctas": [...] },
  "template": { "platform": "...", "maxCharacters": ..., "hashtagPool": [...] },
  "validation": { "isValid": true, "counts": {...} }
}
```

**WF3 → WF4 (Draft Summary):**

```json
{
  "success": true,
  "summary": {
    "draftId": "draft-20260108T171327-hyixwn",
    "filePath": "/data/shared/output/drafts/draft-20260108T171327-hyixwn.json",
    "validationPassed": true
  }
}
```

---

## Human-in-the-Loop Design

### Slack Review Interface

```
┌─────────────────────────────────────────────┐
│  📝 Content Review Request                  │
│  Draft ID: draft-20260108T171327-hyixwn     │
├─────────────────────────────────────────────┤
│  [═══════ IMAGE PREVIEW ═══════]            │
│  📷 Image: products/supersports-detail.jpg  │
├─────────────────────────────────────────────┤
│  *Headline*                                 │
│  "Precision Meets Passion"                  │
│                                             │
│  *Body Copy*                                │
│  Each Continental GT bears the mark...      │
│                                             │
│  *Call to Action*                           │
│  Discover the Art of Creation               │
│                                             │
│  *Hashtags*                                 │
│  #BentleyMotors #Craftsmanship ...          │
├─────────────────────────────────────────────┤
│  Platform: instagram | Theme: craftsmanship │
│  Characters: 274/2200 | Valid: ✅            │
├─────────────────────────────────────────────┤
│  [✅ Approve]  [❌ Reject]  [✏️ Changes]    │
└─────────────────────────────────────────────┘
```

### Approval Flow Outcomes

| Action              | Result                                                              |
| ------------------- | ------------------------------------------------------------------- |
| **Approve**         | Creates approval record, renders HTML platform preview              |
| **Reject**          | Creates rejection record with timestamp                             |
| **Request Changes** | Opens modal for feedback, regenerates with Claude, posts new review |

### Iterative Refinement

The "Request Changes" flow supports multiple revision cycles:

```
[Draft v1] → [Feedback] → [Draft v2] → [Feedback] → [Draft v3] → [Approve]
```

Each revision is tracked with versioned draft IDs (e.g., `draft-xxx_v2`, `draft-xxx_v3`).

---

## File System Architecture

### Volume Mounting

```
Host Machine                          Docker Container (n8n)
─────────────────                     ─────────────────────
./shared/                     ◀────▶  /data/shared/
```

### Directory Structure

```
shared/
├── marketing-assets/
│   ├── images/
│   │   └── images-manifest.json        # 22 images with metadata + URLs
│   ├── copy/
│   │   ├── headlines/headlines.json    # 15 headlines
│   │   ├── body-copy/body-copy.json    # 8 body copy pieces
│   │   └── ctas/ctas.json              # 10 CTAs
│   ├── templates/social/
│   │   ├── instagram-post.json         # Platform constraints
│   │   ├── linkedin-post.json
│   │   └── twitter-post.json
│   └── brand-guidelines/
│       └── voice-and-tone.md           # Brand voice rules
│
├── rendered-templates/                  # HTML mockup templates
│   ├── instagram-post.html
│   ├── linkedin-post.html
│   └── twitter-post.html
│
└── output/
    ├── drafts/                          # Generated content awaiting review
    ├── approved/                        # Approval records (JSON)
    ├── rejected/                        # Rejection records (JSON)
    └── rendered-approved/               # HTML visual previews
```

---

## External Integrations

### Slack Integration

| Component          | Configuration                                   |
| ------------------ | ----------------------------------------------- |
| **Workspace**      | "Prototypes"                                    |
| **Channel**        | #content-review                                 |
| **App**            | "Content Review Bot"                            |
| **Bot Scopes**     | chat:write, chat:write.public, files:write      |
| **Interactivity**  | Enabled, pointing to WF5 webhook via Cloudflare |
| **Message Format** | Block Kit (via HTTP Request, not native node)   |

### Cloudflare Tunnel

Provides stable, persistent webhook URLs for Slack interactions:

- Avoids ngrok session expiry issues
- Production-ready URL pattern
- Configured via `cloudflared` Docker service

### Claude API

| Setting        | Value                    |
| -------------- | ------------------------ |
| **Model**      | claude-sonnet-4-20250514 |
| **Max Tokens** | 1024                     |
| **Credential** | Anthropic API (n8n)      |

---

## Validation & Quality Controls

### Content Validation (WF3)

| Check                    | Type    | Trigger Condition                   |
| ------------------------ | ------- | ----------------------------------- |
| Exclamation marks        | Error   | Content contains `!`                |
| Hashtag count mismatch   | Error   | Count ≠ template requirement        |
| Character limit exceeded | Error   | Total chars > platform max          |
| American spelling        | Warning | Detects: color, honor, center, etc. |
| Body copy too long       | Warning | Body > optimal × 1.5                |

### Asset Validation (WF2)

| Check                 | Type    | Trigger Condition                   |
| --------------------- | ------- | ----------------------------------- |
| No matching images    | Error   | Zero images for theme/vehicle combo |
| No matching headlines | Error   | Zero headlines for theme            |
| < 2 examples          | Warning | Fewer than 2 few-shot examples      |

---

## Future Considerations

### Not Yet Implemented

| Feature              | Purpose                            | Complexity |
| -------------------- | ---------------------------------- | ---------- |
| **Schedule Trigger** | Automated daily/weekly runs        | Low        |
| **Batch Generation** | Multiple posts per run             | Medium     |
| **Vector Search**    | Semantic asset matching via Qdrant | Medium     |
| **Error Recovery**   | Retry logic, failure notifications | Medium     |
| **Analytics**        | Generation quality tracking        | High       |

### Cloud Migration Path

The local asset structure supports easy cloud migration:

| Local               | AWS Equivalent    |
| ------------------- | ----------------- |
| `images/`           | S3 bucket         |
| `copy/*.json`       | DynamoDB tables   |
| `templates/`        | Parameter Store   |
| `brand-guidelines/` | S3 or Secrets Mgr |

---

## Design Principles

1. **Idempotency**: Workflows can safely retry without side effects
2. **Observability**: Clear naming conventions and logging
3. **Modularity**: Sub-workflows testable independently
4. **Error Resilience**: Validation at each stage
5. **Data Validation**: Fail fast with clear error messages
6. **Human Oversight**: No content published without review
7. **Iterative Refinement**: Support for revision cycles
