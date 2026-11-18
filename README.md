# tengri

Replaces evalhs and ldpkgs with a warm GHC daemon (tengri-savdag), abductive spine articulation (tengri-darkhan), precompiled algebraic prelude (tengri-sulde), stream/pipe automation (tengri-lus), multi-shell type reflection (tengri-toli), and resident `GhcMonad` evaluation with mock `ModSummary` source plugin pipelines (tengri-ulgen).

## Packages

- [`packages/tengri-sulde/`](packages/tengri-sulde/) — Precompiled algebraic prelude re-exporting gongju and polytropos.
- [`packages/tengri-lus/`](packages/tengri-lus/) — Stream channels, regex conduits, and evacuable aggregation.
- [`packages/tengri-darkhan/`](packages/tengri-darkhan/) — Abductive spine and arity bridge synthesizer powered by Gargamelle and Gongju.
- [`packages/tengri-savdag/`](packages/tengri-savdag/) — Warm GHC API daemon with SCM_RIGHTS and MCP introspection.
- [`packages/tengri-ulgen/`](packages/tengri-ulgen/) — Warm GhcMonad evaluation worker with mock ModSummary source plugin pipeline.
- [`packages/tengri-toli/`](packages/tengri-toli/) — Multi-shell completion, inline type reflection mirror, and Core inspection lens.
- [`packages/tengri-zsh-preexec/`](packages/tengri-zsh-preexec/) — Zsh preexec hook preprocessor.
- [`packages/tengri/`](packages/tengri/) — Unified CLI and interactive REPL surface for the Tengri constellation.

## Quick Start

```bash
# Build all packages
cabal build all

# Run full test suite
cabal test all

# Run physical verification gates
./bin/tengri-verify
```

## Documentation

- [`AGENTS.md`](AGENTS.md) — Advisory context and rules for AI assistants.
- [`PLAN.md`](PLAN.md) — Strategic roadmap and phase delivery schedule.
- [`STATE.md`](STATE.md) — Active operational session frontier.
- [`docs/INDEX.md`](docs/INDEX.md) — Documentation corpus inventory.
- [`docs/TUTORIAL.md`](docs/TUTORIAL.md) — Getting started tutorial.

## License & Attribution

- **License:** EUPL-1.2
- **Author:** Nadia Yvette Chambers <nadia.yvette.chambers@ik.me>
