# Workflow 3: AI Content Generator

## Overview

The AI Content Generator workflow receives a content package from Workflow 2 (Content Assembler) and uses Claude to generate new, original social media content that adheres to Bentley's brand guidelines.

**Key principle:** Claude generates **fresh content** for each run. The headlines, body copy, and CTAs from the content package serve as few-shot style examples — not content to be copied or stitched together.

### What It Does

1. **Accepts content package** — containing filtered assets, image metadata, and platform template
2. **Loads brand guidelines** — the voice-and-tone.md file for prompt context
3. **Builds Claude prompt** — assembles brand rules, platform constraints, image context, and few-shot examples
4. **Calls Claude API** — generates new headline, body copy, CTA, and hashtag selection
5. **Parses response** — extracts structured JSON from Claude's response
6. **Validates output** — checks character limits, exclamation marks, spelling, hashtag count
7. **Saves draft** — writes JSON file to `/data/shared/output/drafts/` for human review

### Output

A draft JSON file containing:

- Unique draft ID and timestamp
- Original content package parameters
- Generated content (headline, body copy, CTA, hashtags)
- Validation results (errors and warnings)
- Formatted post preview (ready-to-copy text)

---

## Workflow Structure

```
[When Executed by Another Workflow] ──┐
                                      ├─► [Merge Package Inputs]
[Manual Trigger] → [Set Test Package] ──┘           │
                                                     ▼
                                            [Read Brand Guidelines] → [Extract Brand Guidelines Text]
       │
       ▼
[Build Claude Prompt]
       │
       ▼
[Claude: Generate Content]
       │
       ▼
[Parse Claude Response]
       │
       ▼
[Validate Output]
       │
       ▼
[Generate Draft Metadata]
       │
       ▼
[Convert Draft to File] → [Save Draft] → [Output Summary]
```

### Node Summary

| Node                              | Type                | Purpose                                           |
| --------------------------------- | ------------------- | ------------------------------------------------- |
| When Executed by Another Workflow | Trigger             | Receives content package from Master Orchestrator |
| Manual Trigger                    | Trigger             | Starts workflow for standalone testing            |
| Set Test Package                  | Set (JSON mode)     | Injects test data simulating Workflow 2 output    |
| Merge Package Inputs              | Merge (Append mode) | Combines whichever trigger fires                  |
| Read Brand Guidelines             | Read/Write Files    | Loads voice-and-tone.md as binary                 |
| Extract Brand Guidelines Text     | Extract From Text   | Converts binary to string for prompt use          |
| Build Claude Prompt               | Code                | Assembles comprehensive prompt with all context   |
| Claude: Generate Content          | Anthropic           | Calls Claude API with "Message a model" action    |
| Parse Claude Response             | Code                | Extracts and parses JSON from Claude's response   |
| Validate Output                   | Code                | Checks constraints (chars, spelling, exclamation) |
| Generate Draft Metadata           | Code                | Creates unique ID, filename, and draft object     |
| Convert Draft to File             | Convert to File     | Serialises JSON to binary for file writing        |
| Save Draft                        | Read/Write Files    | Writes draft JSON to disk                         |
| Output Summary                    | Set                 | Formats confirmation message with draft details   |

---

## Testing the Workflow

### Manual Execution

1. Open n8n at http://localhost:5678
2. Open the "AI Content Generator" workflow
3. Click **Test workflow** (or Ctrl/Cmd + Enter)
4. Watch nodes execute — all should show green checkmarks
5. Check "Output Summary" node for confirmation

### Verify Draft File Created

```bash
# List draft files
ls -la ~/Prototypes/n8n/automated-content-generation/shared/output/drafts/

# View the most recent draft (formatted)
cat ~/Prototypes/n8n/automated-content-generation/shared/output/drafts/draft-*.json | jq

# Or view specific draft
cat ~/Prototypes/n8n/automated-content-generation/shared/output/drafts/draft-20260106T124754-u84ibw.json | jq
```

### Expected Draft Structure

```json
{
  "draftId": "draft-20260105T161305-qgh5so",
  "createdAt": "2026-01-05T16:13:05.123Z",
  "status": "pending_review",
  "sourcePackageId": "pkg-test-001",
  "params": {
    "theme": "craftsmanship",
    "platform": "instagram",
    "vehicle": "continental-gt"
  },
  "image": {
    "id": "img-003",
    "filename": "supersports-detail.jpg",
    "path": "products/supersports-detail.jpg",
    "themes": ["craftsmanship", "performance"]
  },
  "generatedContent": {
    "headline": "Where Precision Meets Artistry",
    "bodyCopy": "Each Continental GT emerges from 130 hours of meticulous handcraft...",
    "cta": "Discover the Art Within",
    "hashtags": [
      "#BentleyMotors",
      "#Craftsmanship",
      "#ContinentalGT",
      "#Handcrafted",
      "#BritishLuxury"
    ],
    "totalCharacters": 284
  },
  "validation": {
    "isValid": true,
    "errors": [],
    "warnings": [],
    "totalCharacters": 284,
    "bodyCharacters": 127,
    "hashtagCount": 5
  },
  "formattedPost": "Where Precision Meets Artistry\n\nEach Continental GT emerges from 130 hours of meticulous handcraft...\n\nDiscover the Art Within\n\n#BentleyMotors #Craftsmanship #ContinentalGT #Handcrafted #BritishLuxury"
}
```

---

## Validation Checks

The workflow validates generated content against platform constraints:

| Check                    | Type    | Trigger Condition                              |
| ------------------------ | ------- | ---------------------------------------------- |
| Exclamation marks        | Error   | Content contains `!` anywhere                  |
| Hashtag count mismatch   | Error   | Count ≠ template.hashtagCount                  |
| Character limit exceeded | Error   | Total chars > template.maxCharacters           |
| American spelling        | Warning | Detects: color, honor, center, customize, etc. |
| Body copy too long       | Warning | Body chars > optimal × 1.5                     |
| Unapproved hashtags      | Warning | Hashtag not in template.hashtagPool            |

### Validation Output Example

```json
{
  "isValid": true,
  "errors": [],
  "warnings": [
    "Body copy (245 chars) is significantly longer than optimal (150)"
  ],
  "totalCharacters": 412,
  "bodyCharacters": 245,
  "hashtagCount": 5
}
```

---

## Claude Prompt Structure

The prompt sent to Claude includes:

1. **Brand voice guidelines** — first 3000 characters of voice-and-tone.md
2. **Campaign parameters** — theme, vehicle, platform
3. **Image metadata** — filename, shot type, themes, art direction notes
4. **Platform constraints** — character limits, hashtag count, formatting rules
5. **Few-shot examples** — 2-3 headlines and body copy for style reference
6. **Output format** — strict JSON structure requirement
7. **Critical reminders** — no exclamation marks, British spelling, originality

Claude is instructed to return **only** valid JSON with no additional text.

---

## File Paths

| Resource         | Container Path                                                     |
| ---------------- | ------------------------------------------------------------------ |
| Brand Guidelines | `/data/shared/marketing-assets/brand-guidelines/voice-and-tone.md` |
| Draft Output     | `/data/shared/output/drafts/`                                      |

---

## Troubleshooting

### Claude API Errors

- **401 Unauthorized**: Check Anthropic credentials in n8n Settings → Credentials
- **429 Rate Limited**: Wait and retry, or check API quota
- **Model not found**: Verify model name is `claude-sonnet-4-20250514` or available variant

### JSON Parse Errors

If "Parse Claude Response" fails:

1. Check the raw response in "Claude: Generate Content" output
2. Claude may have added explanatory text despite instructions
3. The parsing code handles markdown code blocks (`\`\`\`json`), but other formats may need adjustment

### File Save Errors

```bash
# Ensure drafts directory exists
mkdir -p ~/Prototypes/n8n/automated-content-generation/shared/output/drafts

# Check Docker volume mount
docker compose exec n8n ls -la /data/shared/output/

# Verify write permissions
docker compose exec n8n touch /data/shared/output/drafts/test.txt
```

### Validation Failures

If `validation.isValid` is `false`:

1. Check `validation.errors` array for specific issues
2. Claude occasionally includes exclamation marks despite instructions — re-run or adjust prompt
3. Character count issues may require tweaking `optimalCharacters` in the platform template

---

## Notes

- The workflow currently uses **Manual Trigger** with test data; production use will receive content packages from Workflow 2
- Claude model used: `claude-sonnet-4-20250514` — good balance of quality and speed for content generation
- Max tokens set to 1024 — sufficient for JSON response with content
- Each run generates a unique draft ID using timestamp + random suffix
- Drafts are saved with `status: "pending_review"` for Workflow 4 (Slack Notifier) to process
