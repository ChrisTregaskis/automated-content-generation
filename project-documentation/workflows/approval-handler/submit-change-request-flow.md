# Submit Change Request Flow

## Overview

Handles modal submission after a reviewer requests changes. Reads the original draft, sends it to Claude with the feedback, saves the revised draft, and posts it to Slack for another review cycle.

---

## Flow Diagram

```
[Route by Payload Type] ──► Modal Submit output
       │
       ▼
[Extract Modal Data]
       │
       ▼
[Read Original Draft] → [Extract Draft JSON]
       │
       ▼
[Build Revision Context]
       │
       ▼
[Read Brand Guidelines] → [Extract Brand Guidelines]
       │
       ▼
[Build Revision Prompt]
       │
       ▼
[Claude: Generate Revision]
       │
       ▼
[Parse Revision Response]
       │
       ▼
[Convert Revision to File] → [Save Revised Draft]
       │
       ▼
[Build Revision Slack Blocks]
       │
       ▼
[Post Revision to Slack]
       │
       ▼
[Revision Complete]
```

---

## Node Details

### Extract Modal Data (Set)

Extracts data from the modal submission, including the `private_metadata` embedded when the modal was opened.

**Fields extracted**:

- `draftId` — from `privateMetadata.draft_id`
- `channelId` — from `privateMetadata.channel_id`
- `messageTs` — from `privateMetadata.message_ts`
- `feedbackText` — the reviewer's feedback
- `userName` — who submitted the feedback

### Read Original Draft

Loads the original draft file that needs revision.

- **File Path**: `/data/shared/output/drafts/{{ draftId }}.json`

### Extract Draft JSON

Converts binary file data to text for parsing.

### Build Revision Context (Code)

Parses the draft and prepares context for Claude, including:

- Original content (headline, body, CTA, hashtags)
- Platform and theme parameters
- Image information
- Version numbering (e.g., `draft-123` → `draft-123_v2`)

**Key output fields**:

```json
{
  "originalHeadline": "Precision Meets Passion",
  "originalBodyCopy": "Each Continental GT...",
  "feedbackText": "Make headline shorter",
  "baseDraftId": "draft-20260105T163210-10sugc",
  "newVersion": 2,
  "newDraftId": "draft-20260105T163210-10sugc_v2"
}
```

### Read Brand Guidelines

Loads the brand voice document to include in the prompt.

- **File Path**: `/data/shared/marketing-assets/brand-guidelines/voice-and-tone.md`

### Extract Brand Guidelines

Converts the markdown file to text.

### Build Revision Prompt (Code)

Constructs the Claude prompt including:

- Brand voice guidelines (truncated to 2500 chars)
- Original content
- Reviewer feedback
- Instructions for generating revised content
- Required JSON output format

### Claude: Generate Revision (Anthropic)

Calls Claude to generate revised content.

- **Model**: `claude-sonnet-4-20250514`
- **Max Tokens**: 1024

**Expected output format**:

```json
{
  "headline": "Revised headline",
  "bodyCopy": "Revised body copy",
  "cta": "Revised call to action",
  "hashtags": ["#Tag1", "#Tag2", "#Tag3", "#Tag4", "#Tag5"],
  "revisionNotes": "Explanation of changes made"
}
```

### Parse Revision Response (Code)

Parses Claude's JSON response and builds the complete revised draft object, including:

- New draft ID with version suffix
- Updated `generatedContent`
- Validation data
- Revision metadata (feedback received, notes, who requested)

**Handles multiple response formats** from Anthropic node:

- `message.content` (older format)
- `content[0].text` (current format)

### Convert Revision to File

Converts the draft JSON to binary file format.

- **Operation**: Convert to JSON
- **Input Data Property**: `fileContent`

### Save Revised Draft

Writes the revised draft to disk.

- **File Path**: `/data/shared/output/drafts/{{ newDraftId }}.json`

### Build Revision Slack Blocks (Code)

Constructs the Slack Block Kit message for the revised content, including:

- "✨ Revised Content for Review" header
- Draft ID and revision reference
- Image preview
- Revised content sections
- Feedback that was addressed
- Claude's revision notes
- Fresh Approve/Reject/Request Changes buttons

**Image URL lookup**: Maps local image paths to public URLs using the same lookup table as Workflow 4.

### Post Revision to Slack (HTTP Request)

Posts the revised content as a new message.

- **Method**: POST
- **URL**: `https://slack.com/api/chat.postMessage`
- **Authentication**: Slack API credential

### Revision Complete (Set)

Final output summarising the action.

**Fields**:

- `action`: `revision_posted`
- `newDraftId`: The new versioned draft ID

---

## File Outputs

| File          | Location                                         |
| ------------- | ------------------------------------------------ |
| Revised Draft | `/data/shared/output/drafts/{draftId}_v{n}.json` |

---

## Version Numbering

Revisions are tracked with version suffixes:

- Original: `draft-20260105T163210-10sugc.json`
- First revision: `draft-20260105T163210-10sugc_v2.json`
- Second revision: `draft-20260105T163210-10sugc_v3.json`

The code strips any existing `_vN` suffix before incrementing:

```javascript
const baseDraftId = draft.draftId.replace(/_v\d+$/, "");
const newVersion = currentVersion + 1;
const newDraftId = `${baseDraftId}_v${newVersion}`;
```

---

## Revision Metadata

Each revised draft includes revision history:

```json
{
  "revision": {
    "revisionOf": "draft-20260105T163210-10sugc",
    "revisionNumber": 2,
    "feedbackReceived": "Make headline shorter and more punchy",
    "revisionNotes": "Shortened headline from four words to three...",
    "revisedBy": "c.tregaskis.test"
  }
}
```

---

## Slack Message Structure

```
┌─────────────────────────────────────────────┐
│  ✨ Revised Content for Review              │
│  Draft: draft-..._v2 | Revision of: draft-..│
├─────────────────────────────────────────────┤
│  [═══════ IMAGE PREVIEW ═══════]            │
├─────────────────────────────────────────────┤
│  *Headline*                                 │
│  "Artistry in Motion"                       │
│                                             │
│  *Body Copy*                                │
│  Each Continental GT bears the mark of...   │
│                                             │
│  *Call to Action*                           │
│  Discover the Art of Creation               │
│                                             │
│  *Hashtags*                                 │
│  #BentleyMotors #Craftsmanship ...          │
├─────────────────────────────────────────────┤
│  📝 Feedback addressed: "Make headline..."  │
│  💡 What changed: Shortened headline from...│
│  Platform: instagram | Theme: craftsmanship │
├─────────────────────────────────────────────┤
│  [✅ Approve]  [❌ Reject]  [✏️ Changes]    │
└─────────────────────────────────────────────┘
```

---

## Testing

1. Run Workflow 4 to post content to Slack
2. Click ✏️ Request Changes
3. Enter feedback: "Make the headline shorter and more punchy"
4. Click Submit Feedback
5. Verify:
   - New message appears with revised content
   - Headline has changed based on feedback
   - "Feedback addressed" shows your input
   - "What changed" shows Claude's explanation
   - New file exists: `shared/output/drafts/{draftId}_v2.json`
   - Fresh buttons allow another review cycle

---

## Troubleshooting

### Claude Response Parse Error

Check the "Claude: Generate Revision" node output. The parse code handles multiple formats but may need adjustment if Anthropic changes their response structure.

### Missing Image in Slack

The `imageUrlMap` in "Build Revision Slack Blocks" must contain the image path. Add new entries as images are added to the asset library.

### Draft Not Found

Ensure the original draft still exists in `output/drafts/`. If it was moved or deleted, the Read Original Draft node will fail.
