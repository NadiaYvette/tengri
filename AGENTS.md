# AGENTS.md — Advisory Context for AI Coding Assistants

Pointer file. Canonical sources win on any disagreement.

## What this repository is

`tengri` — Replaces evalhs and ldpkgs with a warm GHC daemon (tengri-savdag), abductive spine articulation (tengri-darkhan), precompiled algebraic prelude (tengri-sulde), stream/pipe automation (tengri-lus), and multi-shell type reflection (tengri-toli).

## Read first, in this order

1. [`README.md`](README.md) — what this is, and its status.
2. [`PLAN.md`](PLAN.md) & [`STATE.md`](STATE.md) — operational roadmap and active session frontier.
3. [`docs/notes/TENGRI_DESIGN.md`](docs/notes/TENGRI_DESIGN.md) — canonical design notes and invariants.
4. [`docs/notes/DOC_STRATEGY.md`](docs/notes/DOC_STRATEGY.md) — documentation policy: genres, lifecycle, tone.
5. [`docs/INDEX.md`](docs/INDEX.md) — corpus inventory and reading map.

## Subdivided operational rules (`.agents/rules/`)

- [`.agents/rules/commit-attribution.md`](.agents/rules/commit-attribution.md) — Linux kernel RFC 2822 trailer format (`Assisted-by:`), DCO boundaries.
- [`.agents/rules/code-navigation.md`](.agents/rules/code-navigation.md) — Token-saving funnel (`./tags` symbol jump, targeted slice viewing).
- [`.agents/rules/compiler-verification.md`](.agents/rules/compiler-verification.md) — Zero-log compiler verification, tests, and zero-contamination.
- [`.agents/rules/documentation-precedence.md`](.agents/rules/documentation-precedence.md) — Precedence rule ("code wins at runtime; notes corrected regardless").
- [`.agents/rules/kioku-context.md`](.agents/rules/kioku-context.md) — Durable memory, context offloading loop (`kioku-remember`), and compaction cadence.
- [`.agents/rules/task-execution.md`](.agents/rules/task-execution.md) — Yamaarashi runner invariants, `executor: auto` preference, and zero-polling discipline.

## Subdivided operational skills (`.agents/skills/`)

- [`.agents/skills/code-navigation/SKILL.md`](.agents/skills/code-navigation/SKILL.md) — Fast, token-efficient code navigation using tags, ripgrep, and ast-grep.
- [`.agents/skills/contextful/SKILL.md`](.agents/skills/contextful/SKILL.md) — Query project context packs, local FTS5 BM25 search.
- [`.agents/skills/tricorder/SKILL.md`](.agents/skills/tricorder/SKILL.md) — Check continuous GHCi build status and zero-log compiler diagnostics.
- [`.agents/skills/yamaarashi/SKILL.md`](.agents/skills/yamaarashi/SKILL.md) — Autonomous task packet runner and ASCII Kanban board projection.

## Operational advisories

1. **Design docs are load-bearing.** Stale notes must be corrected in the same change set.
2. Commits: descriptive-imperative subject under 72 chars, body explains why. AI attribution uses git trailers per `sarutahiko`: `Assisted-by: <Tool> (<Provider> / <Model>)`.
3. Toolchain: GHC 9.14.1 / Cabal 3.18.
4. Two-file loop: Update `STATE.md` before ending or resetting a session.
