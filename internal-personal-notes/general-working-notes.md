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
- **Slack**: "Prototypes" workspace with `#content-review` channel

---

## 📋 Complete Workflow Overview

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────────┐
│   Workflow 1    │     │    Workflow 2       │     │    Workflow 3        │
│ Asset Inventory │     │ Content Assembler   │ ──► │ AI Content Generator │
│   Reader        │     │                     │     │                      │
└─────────────────┘     └─────────────────────┘     └──────────┬───────────┘
                                                               │
                                                               ▼
                        ┌─────────────────────┐     ┌──────────────────────┐
                        │    Workflow 5       │ ◄── │    Workflow 4        │
                        │ Approval Handler    │     │ Slack Notifier       │
                        │ (webhook receiver)  │     │                      │
                        └─────────┬───────────┘     └──────────────────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  ▼               ▼               ▼
             [Approved]      [Rejected]    [Request Changes]
                  │               │               │
                  ▼               ▼               ▼
          [Move to approved/] [Archive]    [Feedback Modal] ◄─── NEW
                  │                               │
                  ▼                               ▼
          [Render HTML Preview] ◄─── NEW   [Re-run Content Generator]
                  │                               │
                  ▼                               ▼
          [Save to rendered-approved/]     [Send revised draft to Slack]
                  │                               │
                  ▼                               └──► (back to review)
          [Confirmation message]
```

| #   | Workflow               | Purpose                                                                                  | Status      |
| --- | ---------------------- | ---------------------------------------------------------------------------------------- | ----------- |
| 1   | Asset Inventory Reader | Read & summarise all marketing assets                                                    | ✅ Complete |
| 2   | Content Assembler      | Filter assets by theme/vehicle/platform, select compatible combinations                  | ✅ Complete |
| 3   | AI Content Generator   | Build prompt with examples, call Claude API, validate output, save draft                 | ✅ Complete |
| 4   | Slack Notifier         | Post content preview to Slack with Approve/Reject buttons                                | ✅ Complete |
| 5   | Approval Handler       | Handle Slack interactions: approve (+ render HTML), reject, or iterate via feedback loop | ✅ Complete |
| 6   | Master Orchestrator    | Connect workflows 2-5 into single automated pipeline                                     | 🔜 Next     |

---

## 🔗 Workflow Integration Strategy

Currently, each workflow operates independently with manual triggers and test data. The final step after completing Workflows 4 & 5 is to connect them into a coherent automated pipeline.

### Integration Options

**Option A: Execute Workflow Node (Recommended for POC)**

n8n has an "Execute Workflow" node that can call another workflow and pass data to it. This keeps workflows modular and testable individually while allowing orchestration.

```
[Workflow 6: Master Orchestrator]
    → [Schedule or Manual Trigger]
    → [Set Campaign Parameters]
    → [Execute Workflow 2: Content Assembler]
    → [Execute Workflow 3: AI Content Generator]
    → [Execute Workflow 4: Slack Notifier]
    → [Wait for approval via Workflow 5]
```

**Option B: Webhook Chaining**

Each workflow ends with an HTTP Request node that POSTs to the next workflow's webhook trigger. More loosely coupled but harder to debug.

**Option C: Single Monolithic Workflow**

Merge all nodes into one workflow. Simpler to understand but harder to maintain and test individual components.

### Recommendation

Build Workflows 4 & 5 as standalone workflows first (easier to test Slack integration independently). Then create **Workflow 6: Master Orchestrator** that uses "Execute Workflow" nodes to chain them together.

This approach:

- Keeps each workflow testable in isolation
- Allows easy modification of individual steps
- Provides clear separation of concerns
- Makes debugging simpler (can test each workflow independently)

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

## ⚠️ Troubleshooting Learnings

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

### 4. Read/Write Files Node Requires Extract Step

**Problem:** When using "Read File(s) From Disk", text files are read as binary by default. The "Output: String" option may not be visible in the UI.

**Solution:** Add an "Extract From Text File" node after the Read node to convert binary to string.

**Pattern:**

```
[Read Files Node] → [Extract From Text File] → [Rest of workflow]
```

### 5. Saving JSON to Disk Requires Convert to File

**Problem:** The "Write File to Disk" node expects binary data as input, not a JSON object directly.

**Solution:** Add a "Convert to File" node before the Write node to serialise JSON to binary.

**Pattern:**

```
[Code Node with JSON output] → [Convert to File (Convert to JSON)] → [Write File to Disk]
```

### 6. n8n 2.0.x Anthropic Node Structure

**Problem:** The Anthropic node is accessed via "Anthropic" (not "Anthropic Claude") with specific actions.

**Solution:** Search for "Anthropic", then select "Message a model" under TEXT ACTIONS.

### 7. Useful Docker Diagnostic Commands

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

### 8. Saving Workflows to Version Control

Workflows are stored in n8n's database, not as files. To export them for version control:

```bash
# List all workflows to find the ID
docker compose exec n8n n8n list:workflow

# Export all workflows
./scripts/export-n8n.sh
```

**Note:** The container path `/demo-data/workflows/` maps to `./n8n/demo-data/workflows/` on the host.

### 9. n8n Slack Node Block Kit Issues

**Problem:** The native n8n Slack node with "Block Kit" message type doesn't reliably render blocks — only the fallback text appears.

**Solution:** Use HTTP Request node to call Slack's `chat.postMessage` API directly:

- **URL:** `https://slack.com/api/chat.postMessage`
- **Method:** POST
- **Auth:** Header Auth with `Authorization: Bearer xoxb-...`
- **Body:** JSON with `channel`, `blocks`, and `text` fields

### 10. Slack OAuth2 vs API Credentials

**Problem:** When adding Slack credentials in n8n, "Slack OAuth2 API" requires redirect URI configuration which fails for localhost development.

**Solution:** Use "Slack API" credential type instead — it only requires the Bot Token (`xoxb-...`) and works immediately for local development.

---

## Completed: Workflow 1 — Asset Inventory Reader (Dummy workflow to explore n8n GUI)

**Location:** `~/Prototypes/n8n/automated-content-generation/n8n/demo-data/workflows/rxB9eMban4GTHany.json`

**What it does:**

- Reads all marketing asset JSON files (images manifest, headlines, body copy, CTAs)
- Merges inputs using a Merge node (4 inputs)
- Builds inventory summary with statistics (by theme, vehicle, tone, etc.)
- Formats and writes summary to `/data/shared/output/inventory-summary.txt`

---

## Completed: Workflow 2 — Content Assembler

**Documentation:** `project-documentation/workflows/content-assembler.md`

**What it does:**

- Accepts input parameters (theme, platform, vehicle)
- Loads all marketing asset JSON files
- Filters assets by theme and vehicle compatibility using metadata
- Selects a random image from the filtered pool
- Passes all matching headlines/body copy as few-shot examples (not randomly selected)
- Loads the appropriate platform template (Instagram/LinkedIn/Twitter)
- Validates sufficient matches exist
- Outputs a structured content package for Workflow 3

**Input parameters:**

- `theme`: craftsmanship | performance | heritage | lifestyle | innovation
- `platform`: instagram | linkedin | twitter
- `vehicle`: continental-gt | flying-spur | bentayga | mulsanne | all

**Key design decision:** No AI in this workflow — purely metadata-driven filtering. The coherence comes from filtering by shared theme/vehicle, not random assembly.

### ⚠️ Post-Integration Enhancement Required

**Issue:** Workflow 2 doesn't currently include image URLs in the content package. The `url` field was added to `images-manifest.json` (v1.1) but Workflow 2's "Assemble Content Package" node needs updating to pass it through.

**Impact:** Workflow 4 uses a hardcoded URL lookup map as a workaround. Future drafts should include the URL directly.

**Action:** After completing Workflow 5, update Workflow 2 to include `image.url` in the output package, then remove the lookup map from Workflow 4's "Parse Draft" node.

---

## Completed: Workflow 3 — AI Content Generator

**Documentation:** `project-documentation/workflows/content-generator.md`

**What it does:**

- Accepts content package (from Workflow 2 or manual test data)
- Loads brand guidelines (voice-and-tone.md)
- Builds comprehensive Claude prompt with:
  - Brand voice rules and vocabulary
  - Platform constraints (character limits, hashtag count)
  - Image metadata for visual context
  - Few-shot examples (headlines, body copy) for style reference
- Calls Claude API to generate NEW, original content
- Parses and validates response against constraints
- Saves draft JSON to `/data/shared/output/drafts/`

---

## Completed: Workflow 4 — Slack Notifier

**Documentation:** `project-documentation/workflows/slack-notifier.md`

**What it does:**

- Reads draft JSON file from `/data/shared/output/drafts/`
- Looks up public image URL (from manifest or hardcoded map)
- Builds Slack Block Kit message with:
  - Header and draft ID
  - Image preview (from public URL)
  - Headline, body copy, CTA, hashtags sections
  - Metadata context (platform, theme, vehicle, character count)
  - Interactive buttons: Approve / Reject / Request Changes
- Posts to `#content-review` channel via HTTP Request
- Outputs message timestamp for Workflow 5

**Key technical notes:**

- Uses HTTP Request node instead of native Slack node (Block Kit rendering issues)
- Includes hardcoded URL lookup map for legacy drafts (see Workflow 2 enhancement note)
- Captures `ts` (message timestamp) for message updates in Workflow 5

---

## Completed: Workflow 5 — Approval Handler

**Documentation:** `project-documentation/workflows/approval-handler/approval-handler.md`

**Purpose:** Receive Slack interactions (button clicks and modal submissions), process approval/rejection/feedback, render HTML previews on approval, and support iterative content refinement.

**What it does:**

- Handles approve/reject/request-changes button clicks from Slack
- Generates HTML platform mockups on approval (saved to `rendered-approved/`)
- Captures feedback via Slack modal and re-generates content with Claude
- Supports iterative refinement with versioned drafts (`_v2`, `_v3`, etc.)

**Sub-flow documentation:**

- [click-reject-flow.md](project-documentation/workflows/approval-handler/click-reject-flow.md)
- [click-request-change-flow.md](project-documentation/workflows/approval-handler/click-request-change-flow.md)
- [click-approve-flow.md](project-documentation/workflows/approval-handler/click-approve-flow.md)
- [submit-change-request-flow.md](project-documentation/workflows/approval-handler/submit-change-request-flow.md)

---

## 🔜 To Build: Workflow 6 — Master Orchestrator

**Purpose:** Connect Workflows 2-5 into a single automated pipeline using "Execute Workflow" nodes.

**Architecture:**

```
[Schedule Trigger or Manual]
       │
       ▼
[Set Campaign Parameters]
       │
       ▼
[Execute Workflow: Content Assembler]
       │
       ▼
[Execute Workflow: AI Content Generator]
       │
       ▼
[Execute Workflow: Slack Notifier]
       │
       ▼
[Log: Pipeline Complete — Awaiting Human Review]
```

**Benefits of this approach:**

- Each workflow remains testable in isolation
- Easy to modify individual steps without affecting others
- Clear separation of concerns
- Simplified debugging
- Can run sub-workflows independently for testing

---

## Asset Structure

All assets in `/data/shared/` (container path):

```
shared/
├── marketing-assets/
│   ├── images/
│   │   └── images-manifest.json   # 22 images with metadata + URLs (v1.1)
│   ├── copy/
│   │   ├── headlines/headlines.json    # 15 headlines (theme, tone, suggested_models)
│   │   ├── body-copy/body-copy.json    # 8 body copy pieces (theme, length, pairs_well_with_headlines)
│   │   └── ctas/ctas.json              # 10 CTAs (intent, destination, urgency)
│   ├── templates/social/
│   │   ├── instagram-post.json         # Platform constraints & hashtag pools
│   │   ├── linkedin-post.json
│   │   └── twitter-post.json
│   └── brand-guidelines/
│       └── voice-and-tone.md           # Brand voice rules, vocabulary, do's/don'ts
│
├── rendered-templates/                  # HTML mockup templates
│   ├── instagram-post.html
│   ├── linkedin-post.html
│   └── twitter-post.html
│
└── output/
    ├── drafts/                          # Generated content awaiting review
    ├── approved/                        # Approved content metadata
    ├── rejected/                        # Rejection records
    └── rendered-approved/               # HTML visual previews
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
- Workflow documentation: `~/Prototypes/n8n/automated-content-generation/project-documentation/workflows/`

## Brand Context (Quick Reference)

- **Brand:** Bentley Motors (luxury automotive)
- **Voice:** Sophisticated, confident but not arrogant, understated luxury
- **Language:** British English spelling required
- **Constraints:** No exclamation marks, avoid superlatives, invitational not commanding

---

## Slack Setup (Complete)

- [x] Create free Slack workspace — "Prototypes"
- [x] Create Slack app at api.slack.com — "Content Review Bot"
- [x] Enable Bot Token with scopes: `chat:write`, `chat:write.public`, `files:write`, `channels:read`
- [x] Enable Interactivity (placeholder URL — update for Workflow 5)
- [x] Install app to workspace
- [x] Create `#content-review` channel
- [x] Add n8n credentials:
  - Slack API credential (Bot Token for native nodes)
  - Header Auth credential (for HTTP Request to Slack API)

---

## Post-Completion Tasks

After all workflows are complete:

1. **Update Workflow 2** — Include `image.url` in content package output
2. **Update Workflow 4** — Remove hardcoded URL lookup map from "Parse Draft" node
3. ~~**Update Slack Interactivity URL** — Point to Workflow 5's webhook~~ Done
4. **Export all workflows** — Save to `n8n/demo-data/workflows/` for version control
5. **Test end-to-end** — Run full pipeline from Workflow 6
6. ~~**Create HTML templates** — Build `shared/rendered-templates/` with platform mockups~~ Done

---

**Next step:** Build Workflow 6 — Master Orchestrator (connect Workflows 2-5 into automated pipeline)
