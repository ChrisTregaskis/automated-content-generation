# Workflow 2: Content Assembler

## Overview

The Content Assembler workflow accepts content brief parameters (theme, platform, vehicle) and filters the marketing asset pool to produce a coherent content package for AI generation.

**Key principle:** This workflow uses metadata-driven filtering — no AI is involved. Assets are selected based on matching themes, vehicle compatibility, and explicit pairing relationships defined in the asset JSON files.

### What It Does

1. **Accepts input parameters** — theme, platform, and vehicle define the content brief
2. **Loads all marketing assets** — images manifest, headlines, body copy, CTAs
3. **Filters assets by parameters** — only assets matching theme/vehicle pass through
4. **Selects a random image** — from the filtered pool
5. **Passes all matching examples** — headlines and body copy become few-shot examples for Claude
6. **Loads platform template** — character limits, hashtag pools, formatting rules
7. **Validates and packages** — checks for sufficient matches, builds output JSON

### Output

A content package JSON containing:

- Selected image metadata
- All matching headline examples (for few-shot prompting)
- All matching body copy examples (for few-shot prompting)
- Platform template constraints
- Validation results

This package is passed to Workflow 3 (AI Content Generator) where Claude generates new, original content inspired by the examples.

---

## Workflow Structure

```
[When Executed by Another Workflow] ──┐
                                      ├─► [Merge Trigger Inputs]
[Manual Trigger] → [Set Test Parameters] ─┘           │
       │                                               │
       ▼                                               ▼
[On Form Submission] ─────────────────────────────────►│
       │
       ├──► [Read Images Manifest] → [Extract Image Manifest JSON]    ─┐
       ├──► [Read Headlines] → [Extract Headlines JSON]               ─┤
       ├──► [Read Body Copy] → [Extract Body Copy JSON]               ─┼──► [Merge Assets]
       └──► [Read CTAs] → [Extract CTAs JSON]                         ─┘         │
                                                                                  ▼
                                              [Read Platform Template] → [Extract Template JSON]
                                                                                  │
                                                                                  ▼
                                                              [Assemble Content Package]
```

### Node Summary

| Node                              | Type                     | Purpose                                         |
| --------------------------------- | ------------------------ | ----------------------------------------------- |
| When Executed by Another Workflow | Trigger                  | Receives parameters from Master Orchestrator    |
| Manual Trigger                    | Trigger                  | Starts workflow for standalone testing          |
| On Form Submission                | Trigger                  | Allows testing with different parameter combos  |
| Set Test Parameters               | Set                      | Provides default test parameters                |
| Merge Trigger Inputs              | Merge (Append mode)      | Combines whichever trigger fires                |
| Read Images Manifest              | Read/Write Files         | Loads image metadata file                       |
| Extract Image Manifest JSON       | Extract From JSON        | Parses JSON from file data                      |
| Read Headlines                    | Read/Write Files         | Loads headlines file                            |
| Extract Headlines JSON            | Extract From JSON        | Parses JSON from file data                      |
| Read Body Copy                    | Read/Write Files         | Loads body copy file                            |
| Extract Body Copy JSON            | Extract From JSON        | Parses JSON from file data                      |
| Read CTAs                         | Read/Write Files         | Loads CTAs file                                 |
| Extract CTAs JSON                 | Extract From JSON        | Parses JSON from file data                      |
| Merge Assets                      | Merge (4 inputs, append) | Combines all asset streams                      |
| Read Platform Template            | Read/Write Files         | Loads platform-specific template (dynamic path) |
| Extract Template JSON             | Extract From JSON        | Parses JSON from file data                      |
| Assemble Content Package          | Code                     | Filters, selects, validates, builds output      |

---

## Test Parameters

Use these parameter combinations to verify the filtering logic works correctly.

### Test 1: Craftsmanship + Continental GT (Default)

```json
{
  "theme": "craftsmanship",
  "platform": "instagram",
  "vehicle": "continental-gt"
}
```

**Expected results:**

- Images matched: 2
- Headlines matched: 4
- Body copy matched: 3
- CTAs included: 3

---

### Test 2: Performance + Continental GT

```json
{
  "theme": "performance",
  "platform": "instagram",
  "vehicle": "continental-gt"
}
```

**Expected results:**

- Images matched: ~4-5 (performance theme images)
- Headlines matched: 3
- Body copy matched: 1
- CTAs included: 3

---

### Test 3: Heritage + All Vehicles

```json
{
  "theme": "heritage",
  "platform": "linkedin",
  "vehicle": "all"
}
```

**Expected results:**

- Images matched: ~4 (heritage theme images)
- Headlines matched: 3
- Body copy matched: 1
- CTAs included: 3

---

### Test 4: Innovation + All Vehicles

```json
{
  "theme": "innovation",
  "platform": "twitter",
  "vehicle": "all"
}
```

**Expected results:**

- Images matched: 1 (environment-tree.jpg)
- Headlines matched: 2
- Body copy matched: 1
- CTAs included: 3

---

### Test 5: Lifestyle + Bentayga

```json
{
  "theme": "lifestyle",
  "platform": "instagram",
  "vehicle": "bentayga"
}
```

**Expected results:**

- Images matched: ~3-4 (lifestyle theme images)
- Headlines matched: 3
- Body copy matched: 2
- CTAs included: 3

---

### Test 6: Edge Case — No Matches

```json
{
  "theme": "innovation",
  "platform": "instagram",
  "vehicle": "mulsanne"
}
```

**Expected results:**

- Should produce validation errors or warnings
- Tests the error handling in the Code node

---

## Validation Checks

The workflow validates the following and reports in `validation.errors` and `validation.warnings`:

| Check                  | Type    | Message                                                                     |
| ---------------------- | ------- | --------------------------------------------------------------------------- |
| No matching images     | Error   | "No images found for theme=X and vehicle=Y"                                 |
| No matching headlines  | Error   | "No headlines found for theme=X and vehicle=Y"                              |
| No matching body copy  | Error   | "No body copy found for theme=X and vehicle=Y"                              |
| < 2 headline examples  | Warning | "Only N headline example(s) available — ideally 2+ for few-shot prompting"  |
| < 2 body copy examples | Warning | "Only N body copy example(s) available — ideally 2+ for few-shot prompting" |

---

## File Paths

All paths are relative to `/data/shared/marketing-assets/` inside the n8n container:

| Asset              | Path                                   |
| ------------------ | -------------------------------------- |
| Images Manifest    | `images/images-manifest.json`          |
| Headlines          | `copy/headlines/headlines.json`        |
| Body Copy          | `copy/body-copy/body-copy.json`        |
| CTAs               | `copy/ctas/ctas.json`                  |
| Instagram Template | `templates/social/instagram-post.json` |
| LinkedIn Template  | `templates/social/linkedin-post.json`  |
| Twitter Template   | `templates/social/twitter-post.json`   |

---

## Notes

- The "Extract From JSON" nodes are required because the Read/Write Files node outputs file data with a nested structure; the Extract node pulls the parsed JSON into a cleaner format
- Platform template path is dynamic using expression: `/data/shared/marketing-assets/templates/social/{{ $('Set Input Parameters').item.json.platform }}-post.json`
- Random image selection uses `Math.random()` — each run may select a different image from the filtered pool
- All matching headlines/body copy are passed as examples (not randomly selected) to give Claude maximum context
