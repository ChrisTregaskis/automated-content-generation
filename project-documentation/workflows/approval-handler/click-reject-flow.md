# Click Reject Flow

## Overview

Handles the ❌ Reject button click. Creates a rejection record and updates the original Slack message to show the content was rejected.

---

## Flow Diagram

```
[Route by Action] ──► Reject output
       │
       ▼
[Build Rejection Record]
       │
       ▼
[Convert Rejection to File]
       │
       ▼
[Save Rejection Record]
       │
       ▼
[Update Slack: Rejected]
       │
       ▼
[Reject Complete]
```

---

## Node Details

### Build Rejection Record (Code)

Creates a rejection event record with metadata.

**Input**: Parsed Slack payload
**Output**:

```json
{
  "draftId": "draft-20260105T163210-10sugc",
  "status": "rejected",
  "rejectedAt": "2026-01-07T15:17:07.124Z",
  "rejectedBy": {
    "userId": "U0A710N9350",
    "userName": "c.tregaskis.test"
  },
  "draftPath": "/data/shared/output/drafts/draft-20260105T163210-10sugc.json",
  "responseUrl": "https://hooks.slack.com/actions/...",
  "channelId": "C0A6UP3NK43",
  "messageTs": "1767799009.573219"
}
```

### Convert Rejection to File

Converts JSON to binary file format for writing.

- **Operation**: Convert to JSON
- **Input Data Property**: `json`

### Save Rejection Record

Writes rejection record to disk.

- **Operation**: Write File to Disk
- **File Path**: `/data/shared/output/rejected/{{ draftId }}.json`

### Update Slack: Rejected (HTTP Request)

Replaces the original message with a rejection notice using Slack's `response_url`.

- **Method**: POST
- **URL**: `{{ responseUrl }}` (from Build Rejection Record)
- **Body**:

```json
{
  "replace_original": true,
  "text": "Content rejected",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "❌ *Content Rejected*\n\nDraft `draft-id` was rejected by <@userId>."
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "Rejected at 2026-01-07T15:17:07.168-05:00"
        }
      ]
    }
  ]
}
```

### Reject Complete (Set)

Final output summarising the action.

**Fields**:

- `action`: `rejected`
- `draftId`: The rejected draft ID
- `rejectedBy`: Username who rejected

---

## File Outputs

| File             | Location                                      |
| ---------------- | --------------------------------------------- |
| Rejection Record | `/data/shared/output/rejected/{draftId}.json` |

---

## Design Notes

### Why Records Instead of Moving Files

Instead of moving the draft file to a `rejected/` folder, we create a separate rejection record. Benefits:

1. **Storage agnostic** — works with S3, databases, etc.
2. **Event sourcing** — records what happened, not just end state
3. **Audit trail** — preserves original draft for reference
4. **No delete operations** — avoids filesystem permission issues

To check if a draft is rejected, look for a matching record in `output/rejected/`.

### response_url

Slack provides this URL with every button interaction. It allows updating the original message without needing the channel ID or message timestamp. The URL expires after 30 minutes.

---

## Testing

1. Run Workflow 4 to post content to Slack
2. Click ❌ Reject
3. Verify:
   - Original message replaced with rejection notice
   - File created at `shared/output/rejected/{draftId}.json`
   - Execution shows "Reject Complete" with correct data
