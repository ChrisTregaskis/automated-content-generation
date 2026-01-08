# Click Approve Flow

## Overview

Handles the Approve button click. Reads the original draft, creates an approval record, renders an HTML preview using platform-specific templates, saves both files, and updates the original Slack message to show the content was approved.

---

## Flow Diagram

```
[Route by Action] ──► Approve output
       │
       ▼
[Read Original Draft (Approved)]
       │
       ▼
[Extract Draft JSON (Approved)]
       │
       ▼
[Build Approval Record]
       │
       ▼
[Convert Approval to File]
       │
       ▼
[Save Approval Record]
       │
       ▼
[Build Render Context]
       │
       ▼
[Read HTML Template]
       │
       ▼
[Extract Template]
       │
       ▼
[Render HTML]
       │
       ▼
[Convert HTML to File]
       │
       ▼
[Save Rendered HTML]
       │
       ▼
[Update Slack: Approved]
       │
       ▼
[Approve Complete]
```

---

## Node Details

### Read Original Draft (Approved)

Reads the draft file from disk using the draftId from the webhook payload.

- **Type**: Read/Write Files from Disk
- **Operation**: Read File(s) From Disk
- **File Selector**: `{{ '/data/shared/output/drafts/' + $json.draftId + '.json' }}`

### Extract Draft JSON (Approved)

Parses the binary file content into a JSON object.

**Type**: Code

```javascript
const buffer = await this.helpers.getBinaryDataBuffer(0, "data");
const content = buffer.toString("utf-8");
return JSON.parse(content);
```

### Build Approval Record (Code)

Creates an approval event record with metadata from both the webhook and the draft file.

**Input**:

- Slack interaction data from `$('Route by Action')`: `responseUrl`, `channelId`, `messageTs`, `userId`, `userName`
- Draft content data from previous node: `platform`, `theme`, `vehicle`, `generatedContent`

**Output**:

```json
{
  "draftId": "draft-20260105T163210-10sugc",
  "status": "approved",
  "approvedAt": "2026-01-08T10:30:00.000Z",
  "approvedBy": {
    "userId": "U0A710N9350",
    "userName": "c.tregaskis.test"
  },
  "platform": "instagram",
  "theme": "performance",
  "vehicle": "continental-gt",
  "draftPath": "/data/shared/output/drafts/draft-20260105T163210-10sugc.json",
  "responseUrl": "https://hooks.slack.com/actions/...",
  "channelId": "C0A6UP3NK43",
  "messageTs": "1767799009.573219"
}
```

**Important**: Slack data (`responseUrl`, `channelId`, `messageTs`, `userId`, `userName`) must be pulled from `$('Route by Action')`, not from the draft file.

### Convert Approval to File

Converts JSON to binary file format for writing.

- **Type**: Convert to File
- **Operation**: Convert to JSON
- **Input Data Property**: `json`

### Save Approval Record

Writes approval record to disk.

- **Type**: Read/Write Files from Disk
- **Operation**: Write File to Disk
- **File Path**: `/data/shared/output/approved/approval-{{ $now.toISO() }}.json`

### Build Render Context (Code)

Assembles all values needed for HTML template rendering.

**Responsibilities**:

1. Extracts content fields: `headline`, `bodyCopy`, `cta`, `hashtags`
2. Resolves image URL using a lookup map (local path → public URL)
3. Determines template path based on platform
4. Passes through approval metadata

**Image URL Lookup Map**:

Draft files contain local paths like `products/supersports-detail.jpg`. This node maps them to public URLs (e.g., artofbrand.se hosted images).

**Output**:

```json
{
  "headline": "The content headline",
  "bodyCopy": "The body copy text",
  "cta": "Discover more",
  "hashtags": "#Bentley #ContinentalGT",
  "imageUrl": "https://artofbrand.se/images/products/supersports-detail.jpg",
  "platform": "instagram",
  "draftId": "draft-20260105T163210-10sugc",
  "theme": "performance",
  "vehicle": "continental-gt",
  "approvedAt": "2026-01-08T10:30:00.000Z",
  "approvedBy": "c.tregaskis.test",
  "templatePath": "/data/shared/rendered-templates/instagram-post.html",
  "responseUrl": "https://hooks.slack.com/actions/..."
}
```

### Read HTML Template

Reads the platform-specific HTML template.

- **Type**: Read/Write Files from Disk
- **Operation**: Read File(s) From Disk
- **File Selector**: `{{ $json.templatePath }}`

### Extract Template (Code)

Converts binary HTML file to string. Uses n8n's helper method instead of the "Extract From HTML" node (which is designed for parsing HTML tables, not reading raw HTML).

```javascript
const buffer = await this.helpers.getBinaryDataBuffer(0, "data");
const html = buffer.toString("utf-8");
return { ...items[0].json, templateHtml: html };
```

### Render HTML (Code)

Replaces all `{{placeholder}}` tokens with actual content values.

**Placeholders**:

| Placeholder      | Source Field |
| ---------------- | ------------ |
| `{{headline}}`   | headline     |
| `{{bodyCopy}}`   | bodyCopy     |
| `{{cta}}`        | cta          |
| `{{hashtags}}`   | hashtags     |
| `{{imageUrl}}`   | imageUrl     |
| `{{platform}}`   | platform     |
| `{{draftId}}`    | draftId      |
| `{{theme}}`      | theme        |
| `{{vehicle}}`    | vehicle      |
| `{{approvedAt}}` | approvedAt   |
| `{{approvedBy}}` | approvedBy   |

**Output**: Adds `renderedHtml` field containing the final HTML string.

### Convert HTML to File

Converts rendered HTML string to binary file.

- **Type**: Convert to File
- **Operation**: Move String to File
- **Text Input Field**: `renderedHtml` (field name only, not an expression)

### Save Rendered HTML

Writes rendered HTML preview to disk.

- **Type**: Read/Write Files from Disk
- **Operation**: Write File to Disk
- **File Path**: `/data/shared/output/rendered-approved/{{ $json.draftId }}-rendered.html`

### Update Slack: Approved (HTTP Request)

Replaces the original message with an approval confirmation using Slack's `response_url`.

- **Method**: POST
- **URL**: `{{ $('Render HTML').item.json.responseUrl }}`
- **Body**:

```json
{
  "replace_original": true,
  "text": "Content approved",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Content Approved*\n\nDraft `draft-id` was approved by <@userId>."
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "Approved at 2026-01-08T10:30:00.000Z | HTML preview saved"
        }
      ]
    }
  ]
}
```

### Approve Complete (Set)

Final output summarising the action.

**Fields**:

- `action`: `approved`
- `draftId`: The approved draft ID
- `approvedBy`: Username who approved
- `renderedPath`: Path to saved HTML preview

---

## File Outputs

| File            | Location                                                        |
| --------------- | --------------------------------------------------------------- |
| Approval Record | `/data/shared/output/approved/approval-{timestamp}.json`        |
| Rendered HTML   | `/data/shared/output/rendered-approved/{draftId}-rendered.html` |

---

## Design Notes

### Why HTML Previews

Rendering HTML previews on approval serves several purposes:

1. **Visual output** — Transforms abstract JSON into tangible deliverable
2. **Stakeholder demo** — Shows "this is what it would look like"
3. **Export-ready** — HTML can be opened in any browser
4. **Platform-specific** — Each template mimics the target platform's style

### Image URL Resolution

Draft files store local image paths (e.g., `products/supersports-detail.jpg`) rather than full URLs. The Build Render Context node contains a lookup map to resolve these to public URLs hosted on artofbrand.se.

Future improvement: Update Workflow 2 to include `image.url` directly in the content package.

### Data Flow Pattern

The Approve flow merges data from two sources:

1. **Slack webhook** (`$('Route by Action')`): `responseUrl`, `channelId`, `messageTs`, `userId`, `userName`
2. **Draft file** (Extract Draft JSON node): `platform`, `theme`, `vehicle`, `generatedContent`

Both streams merge in Build Approval Record, then flow through to HTML rendering.

### Extract Template vs Extract From HTML

The "Extract From HTML" node is designed for parsing HTML tables into structured data — not for reading raw HTML content. To read an HTML file as a string, use a Code node with `this.helpers.getBinaryDataBuffer()`.

### Convert to File Text Input Field

The "Convert to File" node's Text Input Field expects a **field name** (e.g., `renderedHtml`), not an expression that evaluates to the content. The node reads the value from that field automatically.

---

## Testing

1. Run Workflow 4 to post content to Slack
2. Click Approve
3. Verify:
   - Original message replaced with approval confirmation
   - File created at `shared/output/approved/approval-{timestamp}.json`
   - File created at `shared/output/rendered-approved/{draftId}-rendered.html`
   - Execution shows "Approve Complete" with correct data
4. Open the rendered HTML in a browser to verify placeholders are replaced
