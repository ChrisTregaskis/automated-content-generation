# Marketing Assets Structure Guide

A reference document explaining the local asset pool structure, its design rationale for automation workflows, and considerations for cloud storage migration.

---

## Folder Structure Overview

```
shared/marketing-assets/
├── images/
│   ├── products/              # 7 product photography assets
│   ├── lifestyle/             # 4 lifestyle/experience imagery
│   ├── brand/                 # 7 advertisement/brand assets
│   ├── events/                # 4 event photography assets
│   └── images-manifest.json   # Metadata catalogue for all 22 images
├── copy/
│   ├── headlines/
│   │   └── headlines.json     # 15 headline variations
│   ├── body-copy/
│   │   └── body-copy.json     # 8 body copy pieces
│   └── ctas/
│   │   └── ctas.json          # 10 call-to-action options
├── templates/
│   └── social/
│       ├── instagram-post.json
│       ├── linkedin-post.json
│       └── twitter-post.json
└── brand-guidelines/
    └── voice-and-tone.md
```

---

## Asset Categories Explained

### Images (22 total)

Binary assets organised by usage context:

| Category     | Count | Purpose                                                 |
| ------------ | ----- | ------------------------------------------------------- |
| `products/`  | 7     | Vehicle photography (hero shots, details, showroom)     |
| `lifestyle/` | 4     | Owner experience, craftsmanship details, environmental  |
| `brand/`     | 7     | Historical advertisements, website references, textures |
| `events/`    | 4     | Motor shows, record-breaking moments                    |

Each image is catalogued in `images-manifest.json` with rich metadata:

```json
{
  "id": "img-001",
  "filename": "supersports-rear.jpg",
  "path": "products/supersports-rear.jpg",
  "category": "products",
  "vehicle": "supersports",
  "shot_type": "hero",
  "orientation": "landscape",
  "style": "colour",
  "themes": ["performance", "luxury"],
  "suggested_content_types": ["social-feed", "advertisement"],
  "notes": "Strong rear 3/4 angle showcasing vehicle lines"
}
```

### Copy Pool (33 total text assets)

Text content stored as JSON arrays with metadata:

| File             | Count | Key Attributes                                                    |
| ---------------- | ----- | ----------------------------------------------------------------- |
| `headlines.json` | 15    | theme, tone, suggested_models, character_count                    |
| `body-copy.json` | 8     | theme, length, word_count, pairs_well_with_headlines              |
| `ctas.json`      | 10    | intent (awareness/consideration/conversion), destination, urgency |

### Templates (3 platform templates)

Platform-specific composition rules defining:

- Character limits and optimal lengths
- Element ordering (headline → body → CTA → hashtags)
- Hashtag pools and placement rules
- Tone and formatting constraints

### Brand Guidelines

Single source-of-truth document covering:

- Voice characteristics and tone spectrum
- Vocabulary substitutions (approved/avoided terms)
- Model-specific messaging guidance
- Platform adaptation rules

---

## Why This Structure for Automation

### 1. Metadata-Driven Selection

Every asset carries rich metadata enabling intelligent workflow filtering:

```
[Trigger] → [Query: theme=craftsmanship, vehicle=continental-gt] → [Filtered Assets] → [Random Selection]
```

The manifest/JSON approach means workflows can:

- Filter by theme, vehicle model, content type, orientation
- Match compatible elements (headlines paired with body copy)
- Select appropriate CTAs based on funnel stage

### 2. Separation of Binary and Structured Data

| Type           | Storage     | Access Pattern                 |
| -------------- | ----------- | ------------------------------ |
| Images         | File system | Read binary, reference by path |
| Copy/Templates | JSON files  | Parse, query, combine          |
| Guidelines     | Markdown    | Reference for prompts          |

This separation allows:

- Binary assets to be served/cached efficiently
- Text content to be queried and combined dynamically
- Guidelines to be injected into LLM prompts

### 3. Modular Composition

Content elements are intentionally atomic:

- Headlines stand alone
- Body copy is self-contained
- CTAs work independently

Workflows combine these modular pieces based on template rules, enabling:

- Consistent output structure per platform
- Varied combinations without manual authoring
- Theme-coherent content assembly

### 4. Single-Pass Validation

All constraints are codified:

- Character limits per platform
- Hashtag counts and pools
- British spelling requirement
- No exclamation marks

Workflows can validate generated content against template rules before output.

### 5. Idempotent Operations

Local file-based storage supports:

- Safe retries (re-reading files has no side effects)
- Predictable paths for debugging
- Version control of asset definitions

---

## Translation to Cloud Storage

### High-Level Migration Mapping

| Local Approach          | AWS Equivalent                                |
| ----------------------- | --------------------------------------------- |
| `images/*.jpg` files    | **S3 bucket** with folder prefixes            |
| `images-manifest.json`  | **DynamoDB table** or S3 JSON with CloudFront |
| `copy/*.json` files     | **DynamoDB tables** (one per content type)    |
| `templates/*.json`      | **DynamoDB** or **Parameter Store**           |
| `brand-guidelines/*.md` | **S3** or embedded in workflow config         |

### Image Assets → S3

```
Local:  /data/shared/marketing-assets/images/products/supersports-rear.jpg
AWS:    s3://brand-assets-bucket/images/products/supersports-rear.jpg
```

- Store binaries in S3 with appropriate folder structure
- Enable CloudFront CDN for delivery if public access needed
- Metadata moves to DynamoDB (not S3 object metadata—too limited)

### Metadata Manifest → DynamoDB

The `images-manifest.json` translates to a DynamoDB table:

```
Table: ImageAssets
├── PK: id (img-001)
├── category: products
├── vehicle: supersports
├── themes: ["performance", "luxury"]  (list type)
├── s3_path: images/products/supersports-rear.jpg
└── ... other attributes
```

Enables:

- Query by category, vehicle, theme using GSIs
- Consistent single-digit millisecond reads
- No need to load full manifest into memory

### Copy Pools → DynamoDB

Each JSON file becomes a table:

```
Table: Headlines
├── PK: id (hl-001)
├── text: "Handcrafted in Crewe..."
├── theme: craftsmanship
├── tone: evocative
└── suggested_models: ["all"]

Table: BodyCopy
├── PK: id (bc-001)
├── text: "In Crewe, skilled craftsmen..."
├── theme: craftsmanship
├── length: short
└── pairs_well_with: ["hl-001", "hl-004"]

Table: CTAs
├── PK: id (cta-001)
├── text: "Discover Your Bentley"
├── intent: awareness
└── destination: website
```

### Templates → DynamoDB or Parameter Store

Templates are configuration, not dynamic content:

- **DynamoDB**: If templates change frequently or need querying
- **Parameter Store / Secrets Manager**: If templates are stable config

### n8n Workflow Changes

| Local Pattern           | Cloud Pattern                         |
| ----------------------- | ------------------------------------- |
| Read File node → JSON   | HTTP Request → DynamoDB API / Lambda  |
| Filter JSON array       | Query with filter expressions         |
| Reference image by path | Construct S3 URL from path attribute  |
| Load full manifest      | Query specific items (more efficient) |

### Abstraction Layer Consideration

For a production system, consider an abstraction layer:

```
[n8n Workflow]
    ↓
[Asset Service API]  ← Lambda or container
    ↓
[DynamoDB + S3]
```

Benefits:

- Workflows don't change when storage changes
- Centralised caching and query optimisation
- Access control and audit logging

### Content Addressing vs Path-Based

Local storage uses paths (`products/supersports-rear.jpg`). Cloud options:

1. **Preserve paths**: Keep folder structure in S3, store path in DynamoDB
2. **Content-addressed**: Store by hash, resolve via DynamoDB lookup

Path-based is simpler and sufficient for this use case.

---

## Summary

The local asset structure is designed for:

- **Queryability**: Rich metadata on every asset
- **Composability**: Modular elements combined via templates
- **Consistency**: Brand guidelines enforced at generation time
- **Simplicity**: File-based for easy local development

Cloud migration (AWS) would:

- Move binaries to **S3** with CDN delivery
- Move metadata and copy to **DynamoDB** for efficient querying
- Optionally add a **Lambda-based API** for abstraction
- Preserve the same logical structure and query patterns

The key insight: the metadata architecture translates directly—only the storage and access mechanisms change.
