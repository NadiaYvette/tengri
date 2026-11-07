---
name: contextful
description: Query project context packs, local FTS5 BM25 search, and token-budgeted citations via Contextful.
user-invocable: true
---

# Project Context & Search with Contextful

Instead of reading dozens of files, Contextful indexes the workspace once and returns ranked, cited, token-budgeted **context packs**.

## Usage Workflows

### 1. Generating Context Packs for Queries
```bash
cxf query "<query>" --budget 2000
cxf search "<query>" --limit 10
```

### 2. Inspecting Project Index Status
```bash
cxf status
```
