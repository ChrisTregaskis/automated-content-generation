# System Architecture

This document describes the architecture of the Marketing Content Automation POC, explaining how components interact to generate fresh marketing content.

---

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Marketing Content Automation                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐     ┌───────────────┐     ┌──────────────┐                │
│  │   Trigger    │────▶│  n8n Workflow │────▶│   Output     │                │
│  │  (Schedule/  │     │   Engine      │     │  (Drafts/    │                │
│  │   Manual)    │     │               │     │   Approved)  │                │
│  └──────────────┘     └───────┬───────┘     └──────────────┘                │
│                               │                                             │
│                               ▼                                             │
│         ┌─────────────────────┴─────────────────────┐                       │
│         │                                           │                       │
│         ▼                                           ▼                       │
│  ┌──────────────┐                           ┌──────────────┐                │
│  │  Marketing   │                           │  Claude API  │                │
│  │   Assets     │◀─────── context ─────────▶│  (Anthropic) │                │
│  │   (Local)    │                           │              │                │
│  └──────────────┘                           └──────────────┘                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Technical Stack

| Component      | Purpose                     | Local Access          |
| -------------- | --------------------------- | --------------------- |
| **n8n**        | Workflow automation engine  | http://localhost:5678 |
| **PostgreSQL** | n8n data persistence        | Port 5432             |
| **Qdrant**     | Vector store for embeddings | http://localhost:6333 |
| **Claude API** | LLM for content generation  | Via Anthropic API     |

All services run as Docker containers orchestrated via `docker-compose.yml`.

---

## Content Generation Model

### Key Principle: Generation, Not Assembly

Claude **generates new, original content** for each workflow run. The marketing assets serve as **context and examples**, not a finite pool to stitch together.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Content Generation Flow                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐    │
│  │   Select    │   │   Build     │   │   Claude API        │    │
│  │   Image     │──▶│   Prompt    │──▶│   Generates NEW     │    │
│  │   Asset     │   │             │   │   Content           │    │
│  └─────────────┘   └─────────────┘   └──────────┬──────────┘    │
│                                                 │               │
│                                                 ▼               │
│                    ┌─────────────────────────────────────────┐  │
│                    │  Fresh, original copy that matches      │  │
│                    │  brand voice without duplicating        │  │
│                    │  existing text                          │  │
│                    └─────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### How Assets Inform Generation

| Asset Type            | Role in Prompt     | Purpose                                           |
| --------------------- | ------------------ | ------------------------------------------------- |
| **Brand Guidelines**  | System context     | Defines voice, tone, vocabulary rules             |
| **Example Headlines** | Few-shot examples  | Shows approved style and structure                |
| **Example Body Copy** | Few-shot examples  | Demonstrates sensory language, specificity        |
| **Image Metadata**    | Generation context | Provides themes, vehicle, shot type for relevance |
| **Platform Template** | Output constraints | Character limits, hashtag rules, formatting       |

### Prompt Construction

A typical generation prompt includes:

```
[System: Brand voice and tone guidelines]
[Context: Selected image metadata - vehicle, themes, shot type]
[Examples: 2-3 headlines and body copy pieces matching the theme]
[Template: Platform constraints - character limit, hashtag pool]
[Instruction: Generate new Instagram post for this Continental GT image...]
```

This approach ensures:

- **Consistency**: Output matches brand voice
- **Freshness**: Each run produces unique content
- **Relevance**: Content relates to the selected image
- **Compliance**: Output fits platform requirements

---

## Data Flow Architecture

### Workflow Execution

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  1. TRIGGER                                                              │
│     Schedule (cron) or Manual trigger                                    │
│                         │                                                │
│                         ▼                                                │
│  2. LOAD CONFIGURATION                                                   │
│     Campaign config, target platform, theme filters                      │
│                         │                                                │
│                         ▼                                                │
│  3. SELECT ASSETS                                                        │
│     ┌─────────────────────────────────────────────────────┐              │
│     │  Read images-manifest.json                          │              │
│     │  Filter by: theme, vehicle, content_type            │              │
│     │  Select: random or weighted                         │              │
│     └─────────────────────────────────────────────────────┘              │
│                         │                                                │
│                         ▼                                                │
│  4. BUILD PROMPT                                                         │
│     ┌─────────────────────────────────────────────────────┐              │
│     │  Load: brand-guidelines/voice-and-tone.md           │              │
│     │  Load: platform template (e.g., instagram-post.json)│              │
│     │  Sample: 2-3 example headlines/body matching theme  │              │
│     │  Include: selected image metadata                   │              │
│     └─────────────────────────────────────────────────────┘              │
│                         │                                                │
│                         ▼                                                │
│  5. GENERATE CONTENT                                                     │
│     ┌─────────────────────────────────────────────────────┐              │
│     │  Call Claude API with assembled prompt              │              │
│     │  Receive: new headline, body copy, hashtags         │              │
│     └─────────────────────────────────────────────────────┘              │
│                         │                                                │
│                         ▼                                                │
│  6. VALIDATE OUTPUT                                                      │
│     ┌─────────────────────────────────────────────────────┐              │
│     │  Check: character limits                            │              │
│     │  Check: British spelling                            │              │
│     │  Check: no exclamation marks                        │              │
│     │  Check: hashtag count                               │              │
│     └─────────────────────────────────────────────────────┘              │
│                         │                                                │
│                         ▼                                                │
│  7. SAVE DRAFT                                                           │
│     Write to: output/drafts/{timestamp}-{platform}.json                  │
│                         │                                                │
│                         ▼                                                │
│  8. HUMAN REVIEW (checkpoint)                                            │
│     Notify reviewer, await approval                                      │
│                         │                                                │
│                         ▼                                                │
│  9. PUBLISH (future)                                                     │
│     Move to: output/approved/                                            │
│     Post to platform API                                                 │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## File System Architecture

### Volume Mounting

```
Host Machine                          Docker Container (n8n)
─────────────────                     ─────────────────────
./shared/                     ◀────▶  /data/shared/
├── marketing-assets/                 (read: assets, write: output)
├── output/
└── logs/
```

### Asset Organisation

For detailed documentation of the marketing assets structure, see:
**[../shared/marketing-assets/asset-structure-guide.md](../shared/marketing-assets/asset-structure-guide.md)**

Summary:

| Directory           | Contents                          | Access Pattern                  |
| ------------------- | --------------------------------- | ------------------------------- |
| `images/`           | 22 JPG assets + manifest          | Read binary + query metadata    |
| `copy/`             | Headlines, body, CTAs as JSON     | Parse and sample for prompts    |
| `templates/`        | Platform composition rules        | Load constraints for generation |
| `brand-guidelines/` | Voice and tone document           | Inject into system prompt       |
| `output/drafts/`    | Generated content awaiting review | Write from workflow             |
| `output/approved/`  | Reviewed and approved content     | Move after human approval       |

---

## Human-in-the-Loop Design

This POC emphasises human oversight before any publishing:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Generate   │────▶│  Save Draft │────▶│   Review    │────▶│   Approve   │
│  Content    │     │             │     │  (Human)    │     │  & Publish  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                              │
                                              ▼
                                        ┌─────────────┐
                                        │   Reject/   │
                                        │   Revise    │
                                        └─────────────┘
```

**Review checkpoints:**

1. Content quality and brand alignment
2. Image-copy coherence
3. Platform appropriateness
4. Factual accuracy (vehicle specs, heritage claims)

---

## Logging and Observability

Each workflow run logs:

| Data Point         | Purpose                             |
| ------------------ | ----------------------------------- |
| Asset selections   | Audit trail, prevent repetition     |
| Prompt used        | Debugging, prompt refinement        |
| Claude response    | Quality analysis                    |
| Validation results | Identify common failures            |
| Reviewer decisions | Training data for future refinement |

Logs are written to: `shared/logs/`

---

## Future Considerations

### Vector Search (Qdrant)

Qdrant is included in the stack for potential use cases:

- Semantic search across copy assets
- Finding similar historical content
- Deduplication of generated content

### MCP Server Integration

Planned Model Context Protocol servers:

- **Filesystem MCP**: Structured access to local assets
- **Brave Search / Tavily**: Real-time trend research
- **GitHub**: Version control of workflow definitions

### Cloud Migration Path

The local asset structure is designed for easy cloud migration. See the Asset Structure Guide for AWS translation patterns:

- Images → S3
- Metadata → DynamoDB
- Templates → Parameter Store

---

## Design Principles

1. **Idempotency**: Workflows can safely retry without side effects
2. **Observability**: Clear logging and naming conventions
3. **Modularity**: Complex workflows broken into sub-workflows
4. **Error Resilience**: Always include error handling branches
5. **Data Validation**: Validate inputs early, fail fast with clear errors
6. **Human Oversight**: No automated publishing without review
