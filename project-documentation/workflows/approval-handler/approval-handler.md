# Workflow 5: Approval Handler

## Overview

The Approval Handler workflow receives Slack interactions (button clicks and modal submissions) and processes content review decisions. It handles three user actions: Reject, Request Changes, and Approve.

### What It Does

1. **Receives Slack webhooks** — via Cloudflare Tunnel to public endpoint
2. **Parses interaction payloads** — extracts action type, draft ID, user info
3. **Acknowledges immediately** — returns 200 to Slack within 3 seconds
4. **Routes by interaction type** — button clicks vs modal submissions
5. **Processes the specific action** — see sub-flow documentation below

### Interaction Types

| Payload Type                        | Trigger                        | Documentation                                                    |
| ----------------------------------- | ------------------------------ | ---------------------------------------------------------------- |
| `block_actions` → `reject_content`  | User clicks ❌ Reject          | [click-reject-flow.md](./click-reject-flow.md)                   |
| `block_actions` → `request_changes` | User clicks ✏️ Request Changes | [click-request-change-flow.md](./click-request-change-flow.md)   |
| `block_actions` → `approve_content` | User clicks ✅ Approve         | [click-approve-flow.md](./click-approve-flow.md)                 |
| `view_submission`                   | User submits feedback modal    | [submit-change-request-flow.md](./submit-change-request-flow.md) |

---

## Workflow Structure

```
[Slack Webhook]
       │
       ▼
[Parse Slack Payload]
       │
       ▼
[Acknowledge Slack] (200 OK)
       │
       ▼
[Route by Payload Type]
       │
       ├──► Button Click ──► [Route by Action]
       │                           │
       │    ┌──────────────────────┼──────────────────────┐
       │    ▼                      ▼                      ▼
       │ [Approve               [Reject                [Request Changes
       │  Flow]                  Flow]                  Flow]
       │    │                      │                      │
       │ See: click-         See: click-           See: click-request-
       │ approve-flow.md     reject-flow.md        change-flow.md
       │
       └──► Modal Submit ──► [Submit Change Request Flow]
                                   │
                             See: submit-change-
                             request-flow.md
```

---

## Prerequisites

### Cloudflare Tunnel

The workflow requires a public URL for Slack to send webhooks. We use Cloudflare Tunnel:

```bash
cloudflared tunnel --url http://localhost:5678
```

This provides a URL like: `https://random-words.trycloudflare.com`

**Note:** The URL changes each time you restart the tunnel. Update Slack's Request URL when this happens.

### Slack App Configuration

1. Go to https://api.slack.com/apps → Select **Content Review Bot**
2. Navigate to **Interactivity & Shortcuts**
3. Enable **Interactivity**
4. Set **Request URL**: `https://YOUR-TUNNEL-URL/webhook/approval-handler`
5. Save Changes

### n8n Credentials

- **Slack API**: Bot Token credential (for `views.open` and `chat.postMessage` API calls)
- **Anthropic**: API key (for Claude revision generation)

---

## Endpoint

| Environment | URL                                                |
| ----------- | -------------------------------------------------- |
| Production  | `https://YOUR-TUNNEL-URL/webhook/approval-handler` |
| Test        | Use n8n's "Test webhook" feature                   |

---

## Core Nodes

### Slack Webhook

- **Type**: Webhook
- **Method**: POST
- **Path**: `approval-handler`
- **Response Mode**: Respond to Webhook (allows async processing)

### Parse Slack Payload

Handles two payload formats:

- **Button clicks** (`block_actions`): Extracts `actionId`, `draftId`, `responseUrl`, `triggerId`
- **Modal submissions** (`view_submission`): Extracts `feedbackText`, `privateMetadata`

### Acknowledge Slack

Returns empty 200 response immediately. Slack requires acknowledgement within 3 seconds or shows an error to the user.

### Route by Payload Type

Switch node routing:

- `block_actions` → Button Click branch
- `view_submission` → Modal Submit branch

### Route by Action

Switch node for button clicks:

- `approve_content` → Approve Placeholder
- `reject_content` → Reject Flow
- `request_changes` → Request Changes Flow

---

## File Paths

| Resource          | Container Path                                                     |
| ----------------- | ------------------------------------------------------------------ |
| Draft Files       | `/data/shared/output/drafts/*.json`                                |
| Rejection Records | `/data/shared/output/rejected/*.json`                              |
| Approval Records  | `/data/shared/output/approved/*.json`                              |
| HTML Templates    | `/data/shared/rendered-templates/*.html`                           |
| Rendered Previews | `/data/shared/output/rendered-approved/*.html`                     |
| Brand Guidelines  | `/data/shared/marketing-assets/brand-guidelines/voice-and-tone.md` |

---

## Architectural Decisions

### Rejection Records vs File Moving

Instead of moving/deleting draft files when rejected, we create a separate rejection record. This approach:

- Works with any storage backend (local, S3, etc.)
- Follows event-sourcing patterns
- Preserves audit trail
- Avoids filesystem delete operations

### Modal private_metadata

Slack modals are stateless — the submission webhook is a separate request from the button click. We embed context (`draft_id`, `channel_id`, `message_ts`) in the modal's `private_metadata` field, which Slack returns verbatim on submission.

### response_url for Message Updates

Slack provides a `response_url` with button interactions that allows updating the original message without additional authentication. This URL expires after 30 minutes.

---

## Testing

### Test Reject Flow

1. Run Workflow 4 (Slack Notifier) to post content
2. Click ❌ Reject in Slack
3. Verify: Original message replaced with rejection notice
4. Verify: Rejection record created in `output/rejected/`

### Test Request Changes Flow

1. Run Workflow 4 to post content
2. Click ✏️ Request Changes
3. Enter feedback in modal, submit
4. Verify: New message posted with revised content
5. Verify: New draft file created with `_v2` suffix

### Test Approve Flow

1. Run Workflow 4 to post content
2. Click ✅ Approve in Slack
3. Verify: Original message replaced with approval confirmation
4. Verify: Approval record created in `output/approved/`
5. Verify: Rendered HTML created in `output/rendered-approved/`

---

## Troubleshooting

### Modal Not Opening

- Check `trigger_id` is being passed — expires after 3 seconds
- Verify Slack app has required scopes
- Check "Open Feedback Modal" node output for API errors

### Message Not Updating

- `response_url` expires after 30 minutes
- Ensure `responseUrl` is passed through the flow
- Check HTTP response from Slack for errors

### Claude Response Parse Errors

- Check raw response in "Claude: Generate Revision" output
- May need to handle different response formats
- Verify JSON is valid before parsing

### HTML Template Not Rendering

- Check template file exists at `/data/shared/rendered-templates/{platform}-post.html`
- Verify "Extract Template" Code node is converting binary to string correctly
- Check placeholder names match between Build Render Context and template

### Image URL Not Resolving

- Draft files contain local paths (e.g., `products/supersports-detail.jpg`)
- Build Render Context node contains a lookup map for public URLs
- If image shows broken, check the lookup map has the correct path → URL mapping

---

## Related Documentation

- [Workflow 4: Slack Notifier](../slack-notifier.md) — Posts content for review
- [click-approve-flow.md](./click-approve-flow.md) — Approve button handling + HTML rendering
- [click-reject-flow.md](./click-reject-flow.md) — Reject button handling
- [click-request-change-flow.md](./click-request-change-flow.md) — Request Changes button handling
- [submit-change-request-flow.md](./submit-change-request-flow.md) — Modal submission handling
