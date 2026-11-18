# tengri-ulgen

Warm `GhcMonad` evaluation engine and mock `ModSummary` source plugin pipeline for the Tengri constellation.

## Architectural Context

In classical GHCi interactive REPL prompts, source plugins implementing `parsedResultAction` (such as `Polytropos.Plugin`, which desugars `REC { ... }` into unboxed row-polymorphic records) are not executed on interactive prompt statements, because GHC's prompt evaluation pipeline operates on raw statement expressions without synthesizing a `ModSummary`.

`tengri-ulgen` (named after **Ülgen**, the supreme celestial creator deity of speech, fire, and intelligence in Mongolian mythology) solves this non-invasively:
1. It hosts a persistent, warm GHC compiler session via `GhcMonad` inside a dedicated worker thread or process.
2. It synthesizes a mock `ModSummary` for incoming interactive snippets and expressions.
3. It feeds the parsed module through the active source plugin passes (`parsedResultAction`), applying syntactic desugaring prior to typechecking and evaluation.
4. It compiles and evaluates expressions in memory, returning results over thread-safe IPC channels to `tengri-savdag` and the Tengri interactive shell.

## License & Attribution

- **License:** EUPL-1.2
- **Author:** Nadia Yvette Chambers <nadia.yvette.chambers@ik.me>
