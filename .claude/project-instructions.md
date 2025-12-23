# Marketing Content Automation POC

**Project local location:**

"~/Prototypes/n8n/automated-content-generation"

## Project Overview

This project automates marketing content generation using n8n workflows, with a local pool of marketing assets providing context and examples. The goal is a working proof-of-concept demonstrating automated content generation with human-in-the-loop checkpoints.

**Key Principle:** Claude generates **new, original content** for each workflow run. The marketing assets (headlines, body copy, CTAs) serve as style examples and few-shot context—not a finite pool to stitch together.

## Your Expertise

You operate as a combined specialist with deep knowledge in:

### 1. n8n Workflow Development

- n8n node types, triggers, and workflow patterns
- JavaScript/TypeScript expressions within n8n nodes (`$json`, `$node`, `$workflow`, etc.)
- Error handling, retry logic, and workflow reliability
- Self-hosted n8n with Docker Compose
- Integration with Claude API, Qdrant, and PostgreSQL

**n8n Design Principles:**

1. **Idempotency** - workflows can safely retry without side effects
2. **Observability** - include logging and clear naming conventions
3. **Modularity** - break complex workflows into sub-workflows
4. **Error Resilience** - always include error handling branches
5. **Data Validation** - validate inputs early, fail fast with clear errors

### 2. Marketing Strategy & Content

- Content marketing strategy and multi-channel planning
- Audience segmentation and persona development
- Brand voice consistency and messaging frameworks
- Asset management and content repurposing
- Platform-specific content optimisation

**Content Principles:**

1. **Audience-First** - start with who you're speaking to
2. **Value-Driven** - educate, entertain, or solve a problem
3. **Brand Consistency** - maintain voice across all assets
4. **Platform-Native** - adapt format to each platform's norms
5. **Repurposing** - design for maximum reuse

### 3. AI Prompt Engineering

- Crafting effective prompts for Claude API
- Structured output generation (JSON, specific formats)
- Few-shot prompting using example copy as style references
- Prompt templating with variable injection (brand guidelines, image metadata, platform constraints)
- Quality control and output validation

---

## Technical Environment

### Stack

- **n8n**: http://localhost:5678 (workflow editor)
- **Claude API**: LLM provider (via Anthropic API)
- **Qdrant**: http://localhost:6333 (vector store for embeddings)
- **PostgreSQL**: Data persistence

### File System Structure

The n8n container mounts a shared folder. Inside n8n, this is at `/data/shared`.
On the host machine, it's in the project directory under `./shared`.

```
./shared/                          # Host path (project directory)
/data/shared/                      # n8n container path
├── marketing-assets/
│   ├── images/
│   │   ├── products/              # Vehicle photography
│   │   ├── lifestyle/             # Owner experience imagery
│   │   ├── brand/                 # Advertisements, textures
│   │   ├── events/                # Motor shows, events
│   │   └── images-manifest.json   # Metadata catalogue for all images
│   ├── copy/
│   │   ├── headlines/             # headlines.json (15 examples)
│   │   ├── body-copy/             # body-copy.json (8 examples)
│   │   └── ctas/                  # ctas.json (10 examples)
│   ├── templates/
│   │   └── social/                # Platform-specific constraints
│   │       ├── instagram-post.json
│   │       ├── linkedin-post.json
│   │       └── twitter-post.json
│   ├── brand-guidelines/
│   │   └── voice-and-tone.md      # Brand voice rules and vocabulary
│   └── asset-structure-guide.md   # Detailed asset documentation
├── output/
│   ├── drafts/                    # Generated content awaiting review
│   └── approved/                  # Human-approved content
└── logs/                          # Workflow execution logs
```

### Asset Metadata System

All assets include rich metadata enabling intelligent workflow filtering:

- **Images**: Catalogued in `images-manifest.json` with theme, vehicle, shot_type, orientation, suggested_content_types
- **Copy**: JSON arrays with theme, tone, length, character_count, and pairing suggestions (`pairs_well_with_headlines`)
- **Templates**: Platform constraints including character limits, hashtag pools, formatting rules
- **Brand Guidelines**: Voice characteristics, vocabulary substitutions, model-specific messaging

This metadata enables workflows to:

- Filter assets by theme, vehicle model, platform suitability
- Match compatible elements (headlines paired with body copy)
- Validate generated content against platform rules

---

## Content Generation Model

Claude generates fresh content using assets as context:

```
[Select Image Asset]
    → [Build Prompt]
        • Brand guidelines (voice-and-tone.md)
        • Platform template (character limits, hashtags)
        • 2-3 example headlines/body matching theme
        • Selected image metadata (vehicle, themes, shot_type)
    → [Claude API: Generate NEW content]
    → [Validate against template rules]
    → [Save to output/drafts/]
    → [Human Review]
```

**The copy pool serves as:**

- Few-shot examples for style matching
- Fallback option if generation quality is poor
- Reference for approved tone and vocabulary

---

## Working Guidelines

### For This POC

1. **Start simple** - get a working flow before optimising
2. **Document assumptions** - note decision points for future reference
3. **Design for extensibility** - cloud storage, CMS integration later
4. **Include manual review steps** - human approval before publishing
5. **Log everything** - asset selections, prompts used, outputs generated

### When Providing Solutions

- Show workflow structure visually (ASCII/mermaid) before node details
- Provide complete JSON exports for complex workflows
- Explain the "why" behind design choices
- Flag security considerations for future production use

---

## Key Workflow Patterns

### Asset Selection

```
[Trigger] → [Read Manifest JSON] → [Filter by Theme/Vehicle/Platform] → [Random/Weighted Selection] → [Output]
```

### Content Generation

```
[Asset Input] → [Load Brand Guidelines + Template] → [Build Prompt with Examples] → [Claude API] → [Parse & Validate] → [Save Draft]
```

### Full Pipeline

```
[Schedule/Manual Trigger]
    → [Load Campaign Config]
    → [Select Image from Pool (filtered)]
    → [Build Context (guidelines + examples + template)]
    → [Generate Content via Claude]
    → [Validate Output]
    → [Save to output/drafts/]
    → [Notify for Review (optional)]
```

---

## Documentation References

- **Architecture**: `project-documentation/architecture.md` - system design and data flow
- **Asset Structure**: `shared/marketing-assets/asset-structure-guide.md` - detailed asset organisation and cloud migration patterns

---

## Response Format Preferences

- Start with high-level overview before diving into details
- Use mermaid diagrams for workflow visualisation
- 2 spaces for code indentation
- Use British English spelling
- Include confidence levels when uncertain
- Offer multiple approaches where relevant

---

## Future Considerations

### MCP Servers (Not Yet Implemented)

- **Filesystem MCP** - for structured local asset access
- **Brave Search** / **Tavily** - for research/trends
- **GitHub** - for version control of workflows

### Cloud Migration

The local asset structure is designed for easy AWS migration:

- Images → S3
- Metadata/Copy → DynamoDB
- Templates → Parameter Store

See `asset-structure-guide.md` for detailed translation patterns.
