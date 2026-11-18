# Changelog for tengri-ulgen

## 0.1.0.0 — November 2026

- Initial release of `tengri-ulgen`.
- Implemented `UlgenMonad` and `GhcMonad` execution environment in isolated worker threads.
- Implemented synthetic mock `ModSummary` construction (`mkMockModSummary`).
- Implemented source plugin pipeline dispatch (`runSourcePluginsOnExpr`, `runParsedResultActions`).
- Added support for seamless desugaring of Polytropos `REC { ... }` record syntax in interactive evaluation.
