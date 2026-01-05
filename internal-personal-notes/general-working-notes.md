# n8n Marketing Content Automation POC — Complete Workflow Plan

## Project Context

Building a marketing content automation proof-of-concept using n8n for Bentley Motors. The goal is automated content generation with human-in-the-loop checkpoints.

**Key Principle:** Claude generates **new, original content** for each workflow run. Marketing assets serve as style examples and few-shot context—not a finite pool to stitch together.

**Project location:** `~/Prototypes/n8n/automated-content-generation`

## Environment

- **n8n**: http://localhost:5678 (Docker, self-hosted AI starter kit, version 2.0.3)
- **LLM**: Claude API via Anthropic credentials (configured in n8n)
- **Vector Store**: Qdrant at http://localhost:6333 (available but not yet used)
- **File System**: `./shared` on host → `/data/shared/` inside n8n container
- **Slack**: Free workspace for approval notifications (to be set up)

---

## 📋 Complete Workflow Overview

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────────┐
│   Workflow 1    │     │    Workflow 2       │     │    Workflow 3        │
│ Asset Inventory │     │ Content Assembler   │ ──► │ AI Content Generator │
│   Reader ✅     │     │ (filter & select)   │     │ (Claude API)         │
└─────────────────┘     └─────────────────────┘     └──────────┬───────────┘
                                                               │
                                                               ▼
                        ┌─────────────────────┐     ┌──────────────────────┐
                        │    Workflow 5       │ ◄── │    Workflow 4        │
                        │ Approval Handler    │     │ Slack Notifier       │
                        │ (webhook receiver)  │     │ (review request)     │
                        └─────────┬───────────┘     └──────────────────────┘
                                  │
                          ┌───────┴───────┐
                          ▼               ▼
                     [Approved]      [Rejected]
                          │               │
                          ▼               ▼
                  [Move to approved/] [Archive + feedback]
                          │
                          ▼
                  [Confirmation message]
```

| #   | Workflow               | Purpose                                                                   | Status      |
| --- | ---------------------- | ------------------------------------------------------------------------- | ----------- |
| 1   | Asset Inventory Reader | Read & summarise all marketing assets                                     | ✅ Complete |
| 2   | Content Assembler      | Filter assets by theme/vehicle/platform, select compatible combinations   | 🔜 Next     |
| 3   | AI Content Generator   | Build prompt with examples, call Claude API, validate output, save draft  | 📋 Queued   |
| 4   | Slack Notifier         | Post content preview to Slack with Approve/Reject buttons                 | 📋 Queued   |
| 5   | Approval Handler       | Webhook receives button click, moves approved content, sends confirmation | 📋 Queued   |

---

## 🎯 How I Want to Learn

**DO NOT provide JSON workflow exports to import.**

Instead, provide **step-by-step instructions** for building each workflow manually through the n8n UI, similar to this format:

1. Create new workflow, name it "X"
2. Add node Y — search for "Z", configure with these settings...
3. Connect node A to node B
4. In the Code node, paste this JavaScript...
5. Test the workflow, expected output is...

This hands-on approach helps me build proficiency with n8n's interface and understand how nodes connect and interact.

---

## ⚠️ Troubleshooting Learnings from Previous Session

### 1. Docker Compose YAML Anchors Don't Merge — They Override

**Problem:** Adding an `environment:` block to a service that uses `<<: *anchor` **completely replaces** the anchor's environment variables instead of merging them.

**Example of the bug:**

```yaml
x-n8n: &service-n8n
  environment:
    - DB_TYPE=postgresdb
    - DB_POSTGRESDB_HOST=postgres
    # ... other vars

services:
  n8n:
    <<: *service-n8n
    environment: # ❌ This OVERRIDES, doesn't merge!
      - N8N_RESTRICT_FILE_ACCESS_TO=/data/shared
```

**Result:** n8n loses database connection variables and shows the setup screen again.

**Solution:** Put additional env vars in the `.env` file instead, which is loaded via `env_file: - .env` in the anchor.

### 2. n8n 2.0.3 File Access Restrictions

**Problem:** The `N8N_RESTRICT_FILE_ACCESS_TO` environment variable didn't work as expected in n8n 2.0.3, even with correct paths configured. The Read/Write Files node kept blocking access despite:

- Correct volume mount (verified via `docker compose exec n8n ls -la /data/shared/`)
- Env var being read (verified via `docker compose exec n8n env | grep N8N_RESTRICT`)
- Trying multiple path formats (with/without trailing slash, wildcard `*`, commented out)

**Solution:** Claude Code found a workaround (check Workflow 1 for the implemented solution). If issues recur, use Claude Code for Docker-level troubleshooting.

### 3. Binary File Parsing in Code Nodes

**Problem:** Direct `Buffer.from(item.binary[key].data, 'base64')` doesn't work reliably in n8n 2.0.3.

**Solution:** Use n8n's built-in helper method:

```javascript
const buffer = await this.helpers.getBinaryDataBuffer(index, binaryKey);
return JSON.parse(buffer.toString("utf-8"));
```

### 4. Useful Docker Diagnostic Commands

```bash
cd ~/Prototypes/n8n/automated-content-generation

# Check env vars reaching container
docker compose exec n8n env | grep -i N8N

# Verify volume mount / file access
docker compose exec n8n ls -la /data/shared/marketing-assets/

# Check n8n logs
docker compose logs n8n --tail 50

# Full restart (sometimes needed after env changes)
docker compose down && docker compose up -d
```

---

## ✅ Completed: Workflow 1 — Asset Inventory Reader

**Location:** `~/Prototypes/n8n/automated-content-generation/n8n/demo-data/workflows/rxB9eMban4GTHany.json`

**What it does:**

- Reads all marketing asset JSON files (images manifest, headlines, body copy, CTAs)
- Merges inputs using a Merge node (4 inputs)
- Builds inventory summary with statistics (by theme, vehicle, tone, etc.)
- Formats and writes summary to `/data/shared/output/inventory-summary.txt`

**Architecture:**

```
[Manual Trigger]
    → [Read Images Manifest]  ─┐
    → [Read Headlines]        ─┤
    → [Read Body Copy]        ─┼→ [Merge (4 inputs)] → [Build Inventory Summary]
    → [Read CTAs]             ─┘           ↓
                                    [Format Output]
                                           ↓
                              [Convert to File] → [Write to Disk]
```

---

## 🔜 To Build: Workflow 2 — Content Assembler

**Purpose:** Accept parameters and filter/select matching assets from the pools.

**Architecture:**

```
[Manual Trigger with Inputs]
    → [Load Asset Files]
    → [Filter by Theme/Vehicle/Platform]
    → [Select Compatible Assets]
        • Match headlines with body copy (using pairs_well_with_headlines)
        • Select appropriate CTA by intent
        • Pick image matching theme/vehicle
    → [Load Platform Template]
    → [Validate Against Template Constraints]
    → [Output Assembled Content Package]
```

**Input parameters to accept:**

- `theme`: craftsmanship | performance | heritage | lifestyle | innovation
- `platform`: instagram | linkedin | twitter
- `vehicle`: continental-gt | flying-spur | bentayga | mulsanne | all

**Output:** JSON package with selected headline, body copy, CTA, image reference, and platform template ready for Workflow 3.

---

## 📋 To Build: Workflow 3 — AI Content Generator

**Purpose:** Use Claude API to generate fresh content using selected assets as context.

**Architecture:**

```
[Trigger from Workflow 2 OR Manual with Content Package]
    → [Load Brand Guidelines (voice-and-tone.md)]
    → [Build Prompt]
        • Include brand voice rules
        • Include platform constraints
        • Include 2-3 example headlines/body as few-shot context
        • Include selected image metadata
    → [Claude API Node - Generate NEW Content]
    → [Parse & Validate Output]
        • Check character limits
        • Verify no exclamation marks
        • Confirm British English spelling
    → [Generate Draft ID]
    → [Save to /data/shared/output/drafts/]
    → [Trigger Workflow 4 (Slack Notifier)]
```

**Claude API prompt should request:**

- New headline (inspired by examples, not copied)
- New body copy matching theme and platform length requirements
- Formatted post with proper line breaks
- Appropriate hashtags from platform pool

---

## 📋 To Build: Workflow 4 — Slack Notifier

**Purpose:** Send content preview to Slack channel with interactive approve/reject buttons.

**Prerequisites:**

- Free Slack workspace set up
- Slack app created with Bot Token and appropriate scopes
- n8n Slack credentials configured

**Architecture:**

```
[Webhook Trigger from Workflow 3]
    → [Load Draft Content from File]
    → [Build Slack Block Kit Message]
        • Image block (selected image URL or upload)
        • Section: Headline
        • Section: Body copy
        • Context: Platform, theme, vehicle, character count
        • Actions: Approve / Reject / Request Changes buttons
    → [Send to Slack Channel]
    → [Log notification sent]
```

**Slack Block Kit structure:**

```
┌─────────────────────────────────────────────┐
│  📝 CONTENT REVIEW REQUEST                  │
│  Draft ID: draft-2024-01-15-001             │
├─────────────────────────────────────────────┤
│  [═══════ IMAGE PREVIEW ═══════]            │
├─────────────────────────────────────────────┤
│  *Headline*                                 │
│  "Where precision meets passion"            │
│                                             │
│  *Body Copy*                                │
│  Every stitch placed by hand. Every         │
│  surface considered...                      │
│                                             │
│  *CTA*                                      │
│  Discover the Continental GT →              │
├─────────────────────────────────────────────┤
│  Platform: Instagram | Theme: Craftsmanship │
│  Vehicle: Continental GT | Chars: 847/2200  │
├─────────────────────────────────────────────┤
│  [✅ Approve]  [❌ Reject]  [✏️ Changes]    │
└─────────────────────────────────────────────┘
```

---

## 📋 To Build: Workflow 5 — Approval Handler

**Purpose:** Receive button clicks from Slack and process approval/rejection.

**Architecture:**

```
[Webhook Trigger (Slack Interactive)]
    → [Parse Slack Payload]
    → [Extract action + draft ID]
    → [Switch Node: Approve / Reject / Changes]
        │
        ├─► [Approve]
        │       → [Move file: drafts/ → approved/]
        │       → [Update Slack message: "✅ Approved by @user"]
        │       → [Log approval]
        │
        ├─► [Reject]
        │       → [Move file: drafts/ → rejected/]
        │       → [Update Slack message: "❌ Rejected by @user"]
        │       → [Log rejection with reason]
        │
        └─► [Request Changes]
                → [Open thread for feedback]
                → [Keep in drafts/]
                → [Update message: "✏️ Changes requested"]
```

**Slack webhook requirements:**

- Interactivity enabled in Slack app
- Request URL pointing to n8n webhook
- Proper response within 3 seconds (acknowledge immediately, process async if needed)

---

## Asset Structure

All assets in `/data/shared/marketing-assets/` (container path):

```
marketing-assets/
├── images/
│   └── images-manifest.json   # 22 images with metadata (category, vehicle, themes, shot_type)
├── copy/
│   ├── headlines/headlines.json    # 15 headlines (theme, tone, suggested_models)
│   ├── body-copy/body-copy.json    # 8 body copy pieces (theme, length, pairs_well_with_headlines)
│   └── ctas/ctas.json              # 10 CTAs (intent, destination, urgency)
├── templates/social/
│   ├── instagram-post.json         # Platform constraints & hashtag pools
│   ├── linkedin-post.json
│   └── twitter-post.json
└── brand-guidelines/
    └── voice-and-tone.md           # Brand voice rules, vocabulary, do's/don'ts
```

---

## Technical Preferences

- **Step-by-step n8n UI instructions only** — no JSON imports
- 2 spaces for indentation in Code nodes
- British English spelling
- Use Claude Code for Docker troubleshooting if needed

## Key Files to Reference

You can read these directly from the filesystem:

- Asset manifests: `~/Prototypes/n8n/automated-content-generation/shared/marketing-assets/`
- Brand guidelines: `~/Prototypes/n8n/automated-content-generation/shared/marketing-assets/brand-guidelines/voice-and-tone.md`
- Platform templates: `~/Prototypes/n8n/automated-content-generation/shared/marketing-assets/templates/social/`
- Completed Workflow 1: `~/Prototypes/n8n/automated-content-generation/n8n/demo-data/workflows/rxB9eMban4GTHany.json`

## Brand Context (Quick Reference)

- **Brand:** Bentley Motors (luxury automotive)
- **Voice:** Sophisticated, confident but not arrogant, understated luxury
- **Language:** British English spelling required
- **Constraints:** No exclamation marks, avoid superlatives, invitational not commanding

---

## Slack Setup Checklist

Before building Workflows 4 & 5:

- [ ] Create free Slack workspace (or use existing)
- [ ] Create Slack app at api.slack.com
- [ ] Enable Bot Token with scopes: `chat:write`, `files:write`, `channels:read`
- [ ] Enable Interactivity with n8n webhook URL
- [ ] Install app to workspace
- [ ] Create `#content-review` channel
- [ ] Add n8n Slack credentials (Bot Token)

---

**Next step:** Build Workflow 2 — Content Assembler
