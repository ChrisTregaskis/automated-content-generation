# Workflow 6: Master Orchestrator

## Overview

The Master Orchestrator connects Workflows 2, 3, and 4 into a single automated pipeline. It's the main entry point for running the content generation flow — one trigger produces a complete draft ready for human review in Slack.

**Key principle:** This workflow coordinates sub-workflows but doesn't contain business logic itself. Each sub-workflow remains independently testable.

### What It Does

1. **Accepts campaign parameters** — theme, platform, and vehicle via manual trigger or form submission
2. **Calls Content Assembler (WF2)** — passes parameters, receives content package
3. **Calls AI Content Generator (WF3)** — passes content package, receives draft info
4. **Calls Slack Notifier (WF4)** — passes draft path, posts review message to Slack
5. **Logs completion** — records pipeline execution summary

### Output

A Slack message in `#content-review` with the generated content ready for human approval. The Approval Handler (WF5) runs separately via webhook when buttons are clicked.

---

## Workflow Structure

```
[On Form Submission] ─────────────────────┐
                                          ├─► [Merge Trigger Inputs]
[Manual Trigger] → [Set Test Parameters] ─┘           │
                                                      ▼
                                          [Call: Content Assembler]
                                                      │
                                                      ▼
                                          [Call: AI Content Generator]
                                                      │
                                                      ▼
                                          [Call: Slack Notifier]
                                                      │
                                                      ▼
                                          [Log: Pipeline Complete]
```

### Node Summary

| Node                       | Type                 | Purpose                                          |
| -------------------------- | -------------------- | ------------------------------------------------ |
| On Form Submission         | Trigger              | Allows testing with different parameter combos   |
| Manual Trigger             | Trigger              | Quick testing with default parameters            |
| Set Test Parameters        | Set                  | Default test values (craftsmanship/instagram/GT) |
| Merge Trigger Inputs       | Merge (Append mode)  | Combines whichever trigger fires                 |
| Call: Content Assembler    | Execute Sub-workflow | Runs WF2, returns content package                |
| Call: AI Content Generator | Execute Sub-workflow | Runs WF3, returns draft info with file path      |
| Call: Slack Notifier       | Execute Sub-workflow | Runs WF4, posts to Slack                         |
| Log: Pipeline Complete     | Set                  | Records completion status and parameters         |

---

## Campaign Parameters

### Input Schema

```json
{
  "theme": "craftsmanship",
  "platform": "instagram",
  "vehicle": "continental-gt"
}
```

### Valid Values

| Parameter | Options                                                     |
| --------- | ----------------------------------------------------------- |
| theme     | craftsmanship, performance, heritage, lifestyle, innovation |
| platform  | instagram, linkedin, twitter                                |
| vehicle   | continental-gt, flying-spur, bentayga, mulsanne, all        |

### Test Presets

**Instagram Craftsmanship (default):**

```json
{
  "theme": "craftsmanship",
  "platform": "instagram",
  "vehicle": "continental-gt"
}
```

**LinkedIn Performance:**

```json
{ "theme": "performance", "platform": "linkedin", "vehicle": "continental-gt" }
```

**Twitter Heritage:**

```json
{ "theme": "heritage", "platform": "twitter", "vehicle": "all" }
```

---

## Data Flow Between Sub-workflows

### WF2 → WF3

Content Assembler outputs a content package object:

```json
{
  "packageId": "pkg-...",
  "params": { "theme": "...", "platform": "...", "vehicle": "..." },
  "image": { "id": "...", "filename": "...", "path": "...", ... },
  "examples": { "headlines": [...], "bodyCopy": [...], "ctas": [...] },
  "template": { "platform": "...", "maxCharacters": ..., ... },
  "validation": { "isValid": true, ... }
}
```

### WF3 → WF4

AI Content Generator outputs draft summary:

```json
{
  "success": true,
  "message": "Draft generated and saved: draft-20260108T171327-hyixwn.json",
  "summary": {
    "draftId": "draft-20260108T171327-hyixwn",
    "filePath": "/data/shared/output/drafts/draft-20260108T171327-hyixwn.json",
    "validationPassed": true,
    ...
  }
}
```

Slack Notifier reads `summary.filePath` to load the draft file.

---

## Testing the Workflow

### Quick Test (Manual Trigger)

1. Open Workflow 6 in n8n
2. Click **Test Workflow**
3. Uses default parameters from "Set Test Parameters"
4. Watch all nodes execute in sequence
5. Check `#content-review` in Slack

### Custom Parameters (Form Trigger)

1. Click the **Form Trigger** node
2. Click **Test step** to open the form
3. Fill in theme, platform, vehicle
4. Submit the form
5. Pipeline runs with custom parameters

### Expected Execution Time

- Content Assembler: ~1-2 seconds
- AI Content Generator: ~5-15 seconds (Claude API call)
- Slack Notifier: ~1-2 seconds
- **Total: ~10-20 seconds**

---

## Relationship to Workflow 5

The Approval Handler (WF5) is **not** called by the orchestrator. It operates independently:

```
[Orchestrator (WF6)] ──► [Slack Message with Buttons]
                                    │
                                    ▼ (human clicks button)
                         [Slack sends webhook]
                                    │
                                    ▼
                         [Approval Handler (WF5)]
```

This separation allows:

- Orchestrator to complete immediately after posting to Slack
- Unlimited time for human review
- Multiple approval cycles without re-running the pipeline

---

## Dual-Trigger Pattern

All sub-workflows (WF2, WF3, WF4) use a dual-trigger pattern:

```
[When Executed by Another Workflow] ──┐
                                      ├─► [Merge Inputs] → [Rest of workflow]
[Manual Trigger] → [Test Data] ───────┘
```

This enables:

- **Orchestrator calls**: Via "When Executed by Another Workflow" trigger
- **Standalone testing**: Via Manual Trigger with test data
- **Data consistency**: Same workflow logic regardless of entry point

---

## Error Handling

Currently minimal — if any sub-workflow fails, the orchestrator stops at that point.

### Future Enhancements

- Add error branches for each Execute Sub-workflow node
- Implement retry logic for transient failures (API timeouts)
- Send error notifications to Slack on failure
- Log failures to a dedicated error file

---

## File Paths

| Resource         | Container Path                           |
| ---------------- | ---------------------------------------- |
| Draft Output     | `/data/shared/output/drafts/`            |
| Approved Content | `/data/shared/output/approved/`          |
| HTML Previews    | `/data/shared/output/rendered-approved/` |

---

## Notes

- The orchestrator uses "Execute Sub-workflow" nodes (called "Execute Workflow" in some n8n versions)
- Sub-workflow selection is by database reference, not webhook URL
- Mode is set to "Wait for Sub-Workflow to Complete" (synchronous execution)
- Form trigger fields should match the parameter schema exactly
