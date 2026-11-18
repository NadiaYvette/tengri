# Tengri Maintainer Guide

**Status:** CANONICAL MAINTAINER MANUAL · Cellarius Standard  
**Corpus Inventory:** [`docs/INDEX.md`](INDEX.md)  
**Tutorial:** [`docs/TUTORIAL.md`](TUTORIAL.md)  
**Design Notes:** [`docs/notes/TENGRI_DESIGN.md`](notes/TENGRI_DESIGN.md)  
**Attribution:** [`docs/notes/COMMIT_ATTRIBUTION.md`](notes/COMMIT_ATTRIBUTION.md)  
**Verification:** `./bin/tengri-verify`

---

## 1. Governance & Maintainer Invariants

As a core systems tool providing interactive evaluation and shell plumbing across the Haskell ecosystem, `tengri` must maintain flawless stability, deterministic compilation, and strict zero-regression hygiene.

All maintainers and automated contributors must abide by five foundational invariants:

1. **Zero-Warning Discipline:** All workspace packages compile under `-Wall -Wcompat -Wredundant-constraints` with 0 warnings and 0 errors.
2. **Mandatory 5-Gate Physical Verification:** No commit may be merged to `master` without passing `./bin/tengri-verify`.
3. **PVP Versioning Policy:** Every exposed API alteration strictly adheres to the Package Versioning Policy (`MAJOR.MAJOR.MINOR.PATCH`).
4. **Hackage Compliance:** Every package manifest under `packages/` must pass `cabal check` with zero warnings.
5. **RFC 2822 Attribution:** All machine-assisted commits require the standardized trailer:
   ```text
   Assisted-by: Antigravity (Google DeepMind / Gemini 3.8 Flash)
   ```

---

## 2. The 5 Physical Verification Gates (`bin/tengri-verify`)

The physical verification harness [`bin/tengri-verify`](../bin/tengri-verify) executes five sequential checks across the entire repository:

```
[./bin/tengri-verify Execution Flow]
  ├── Gate 1: HLint Static Analysis (0 hints / 0 warnings)
  ├── Gate 2: Cabal Test Suites (100% pass across all packages)
  ├── Gate 3: Tagref Referential Integrity (0 broken tag references)
  ├── Gate 4: Markdown Linkcheck (0 broken relative or anchor links)
  └── Gate 5: CLOC Comment Density (Strictly >= 50% comment/code ratio)
```

### Running the Verification Suite
```bash
# Execute the full verification harness
./bin/tengri-verify
```

### Investigating Gate Failures
- **HLint Failures:** Run `hlint packages/<pkg>/` directly to isolate linting hints. Refactor code to eliminate warnings rather than suppressing them with pragmas unless strictly justified.
- **Test Failures:** Run `cabal test <pkg> --test-show-details=always` to inspect failure logs.
- **Tagref Failures:** Run `tagref` in the workspace root to check missing definitions or broken reference tags.
- **Linkcheck Failures:** Run `./bin/tengri-linkcheck` to inspect unresolved relative markdown paths.
- **CLOC Density Failures:** Tengri enforces an institutional $\ge 50\%$ comment-to-code ratio. Document every data type constructor, record field, and top-level function with clear Haddock explanations.

---

## 3. Package Structure & Inter-Package Dependencies

The workspace comprises eight packages arranged in three architectural tiers:

```
[Tier 3: User Surface]
  tengri (CLI & REPL) ───┐
                         ▼
[Tier 2: Infrastructure & Interception]
  tengri-savdag (Daemon) ──► tengri-ulgen (GhcMonad & Plugins)
  tengri-zsh-preexec (Shell Hook)
  tengri-toli (Type Mirror & Core Lens)
                         │
                         ▼
[Tier 1: Foundations & Combinators]
  tengri-sulde (Algebraic Prelude)
  tengri-lus (Conduits & Streams)
  tengri-darkhan (Abductive Synthesis)
```

### Manifest Hygiene & Cabal Check
Maintainers must verify that all package manifests are valid for Hackage distribution:

```bash
for pkg in packages/*; do
  (cd "$pkg" && cabal check)
done
```

---

## 4. Resident Daemon & Worker Lifecycle Management

When developing or debugging daemon and worker internals:

### 1. IPC Socket Management
The daemon socket defaults to `/tmp/tengri-$UID.sock`. If the socket becomes orphaned due to an abrupt process termination:
```bash
rm -f /tmp/tengri-*.sock
```

### 2. Thread Safety in `tengri-ulgen`
The `UlgenWorker` manages GHC API state within a dedicated OS thread. Because GHC's runtime environment contains thread-local and global state in `HscEnv`:
- All interaction with `GhcMonad` must funnel through the worker's `Chan UlgenRequest`.
- Never invoke GHC API functions concurrently from multiple OS threads without isolated `HscEnv` contexts.
- Handle expression exceptions using GHC's `handleSourceError` rather than crashing the worker thread.

---

## 5. Release Checklist

Prior to tagging and publishing a new release:
1. Bump version numbers in `tengri.dhall` and corresponding `.cabal` files.
2. Regenerate documentation and check link integrity.
3. Verify `cabal check` across all packages.
4. Run full `./bin/tengri-verify`.
5. Create signed Git tag with release notes.
