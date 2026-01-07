# Click Request Change Flow

## Overview

Handles the ✏️ Request Changes button click. Opens a Slack modal where the reviewer can provide feedback about what changes they'd like to see.

**Important**: This flow only opens the modal. The actual revision happens in [submit-change-request-flow.md](./submit-change-request-flow.md) when the user submits the modal.

---

## Flow Diagram

```
[Route by Action] ──► Request Changes output
       │
       ▼
[Build Modal Payload]
       │
       ▼
[Open Feedback Modal]
       │
       ▼
[Modal Opened]
```

---

## Node Details

### Build Modal Payload (Code)

Constructs the Slack modal JSON with embedded context.

**Key task**: Embed `draft_id`, `channel_id`, and `message_ts` into `private_metadata` so they're available when the modal is submitted.

**Code**:

```javascript
const payload = $("Parse Slack Payload").first().json;

const privateMetadata = JSON.stringify({
  draft_id: payload.draftId,
  channel_id: payload.channelId,
  message_ts: payload.messageTs,
});

const modalPayload = {
  trigger_id: payload.triggerId,
  view: {
    type: "modal",
    callback_id: "revision_feedback",
    private_metadata: privateMetadata,
    title: { type: "plain_text", text: "Request Changes" },
    submit: { type: "plain_text", text: "Submit Feedback" },
    close: { type: "plain_text", text: "Cancel" },
    blocks: [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: `*What changes would you like?*\nDescribe adjustments for draft \`${payload.draftId}\`.`,
        },
      },
      {
        type: "input",
        block_id: "feedback_input",
        element: {
          type: "plain_text_input",
          action_id: "feedback_text",
          multiline: true,
          placeholder: {
            type: "plain_text",
            text: "e.g., Make headline more action-oriented...",
          },
        },
        label: { type: "plain_text", text: "Feedback" },
      },
    ],
  },
};

return [{ json: modalPayload }];
```

### Open Feedback Modal (HTTP Request)

Calls Slack's `views.open` API to display the modal.

- **Method**: POST
- **URL**: `https://slack.com/api/views.open`
- **Authentication**: Slack API credential (Bot Token)
- **Body**: The modal payload from previous node

### Modal Opened (Set)

Marks the end of this flow branch.

**Fields**:

- `action`: `modal_opened`
- `draftId`: The draft ID being revised

---

## Understanding private_metadata

Slack modals are stateless. When the user submits the modal, Slack sends a **new** webhook request (`view_submission`) that has no inherent connection to the original button click.

To maintain context, we embed data in `private_metadata`:

```json
{
  "draft_id": "draft-20260105T163210-10sugc",
  "channel_id": "C0A6UP3NK43",
  "message_ts": "1767799009.573219"
}
```

Slack stores this string and returns it verbatim in the submission payload. The [submit-change-request-flow](./submit-change-request-flow.md) extracts this data to know which draft to revise.

---

## Understanding trigger_id

Slack provides a `trigger_id` with every interactive component event. This ID:

- Is required to open a modal
- **Expires after 3 seconds**
- Can only be used once

This is why we acknowledge Slack immediately (200 response) before doing any other processing — if we delay, the trigger expires and the modal won't open.

---

## Modal Structure

```
┌─────────────────────────────────────────────┐
│  Request Changes                        [X] │
├─────────────────────────────────────────────┤
│                                             │
│  *What changes would you like?*             │
│  Describe adjustments for draft             │
│  `draft-20260105T163210-10sugc`.            │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ Feedback                            │    │
│  │                                     │    │
│  │ e.g., Make headline more action-    │    │
│  │ oriented...                         │    │
│  │                                     │    │
│  └─────────────────────────────────────┘    │
│                                             │
├─────────────────────────────────────────────┤
│  [Cancel]                [Submit Feedback]  │
└─────────────────────────────────────────────┘
```

---

## What Happens Next

When the user clicks "Submit Feedback":

1. Slack sends a `view_submission` webhook to our endpoint
2. The "Route by Payload Type" switch sends it to the "Modal Submit" branch
3. The [submit-change-request-flow](./submit-change-request-flow.md) processes the feedback

---

## Testing

1. Run Workflow 4 to post content to Slack
2. Click ✏️ Request Changes
3. Verify:
   - Modal appears with feedback input
   - Draft ID is shown in the modal text
   - Cancel and Submit buttons work
4. Enter feedback and submit → continues to submit-change-request-flow
