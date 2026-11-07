---
name: tricorder
description: Check continuous GHCi build status, compiler errors, warnings, or test results via the background tricorder daemon or MCP server. Use when verifying compilation or checking build diagnostics.
user-invocable: true
---

# Checking Build Status with Tricorder

Using `tricorder` slashes token burn by >95%: instead of dumping 300+ lines of raw GHC build logs into context (~2,500 tokens), it returns machine-readable JSON diagnostics in <50 tokens.

## 1. CLI Invocation Fallback
```bash
tricorder status --json
tricorder status --wait --json
```

## 2. Standard Compilation Fallback
```bash
cabal build all
cabal test all
```
