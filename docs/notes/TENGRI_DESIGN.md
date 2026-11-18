# Tengri — Architectural Design Decisions & In-Memory Pipeline Invariants

**Status:** CANONICAL DESIGN MONOGRAPH · Cellarius Standard  
**Parent Strategy:** [`DOC_STRATEGY.md`](DOC_STRATEGY.md)  
**Documentation Index:** [`../INDEX.md`](../INDEX.md)  
**Tutorial:** [`../TUTORIAL.md`](../TUTORIAL.md)  
**Maintainer Guide:** [`../MAINTAINER_GUIDE.md`](../MAINTAINER_GUIDE.md)  
**Verification:** `./bin/tengri-verify`

---

## 1. Abstract & Theoretical Grounding

Interactive command-line shells and rapid experimentation workflows demand near-instantaneous feedback cycles ($< 50\text{ms}$). In interpreted languages (Python, Ruby, Node), this is trivial due to minimal interpreter cold-start overhead. In compiled, statically-typed languages with rich meta-programming and type-level machinery—such as Haskell under GHC—interactive statement evaluation faces two foundational hurdles:

1. **The Cold Process Startup Tax:** Every invocation of `ghc -e` or fresh `ghci` incurs heavy OS process spawning, dynamic linker resolution, package database parsing, and compiler state reconstruction, taking between 800ms and 2,500ms.
2. **The GHCi Source Plugin Blind Spot:** Standard GHCi parses prompt statements via `hscParseStmt` directly into `GhciLStmt GhcPs`. Because interactive statements do not constitute a full compilation unit, GHC's compilation pipeline does not instantiate a module summary (`ModSummary`). As a direct consequence, **source plugins (`Plugin.parsedResultAction`) are completely bypassed during interactive expression evaluation**. Syntactic extensions such as `Polytropos.Plugin`'s desugaring of row-polymorphic record literals (`REC { ... }`) fail to resolve.

**Tengri** provides an architectural solution to both challenges by combining a warm, resident GHC supervisor daemon (`tengri-savdag`) with an in-memory `GhcMonad` evaluation pipeline that synthesizes mock `ModSummary` compilation units with in-memory string buffers (`ms_hspp_buf`).

---

## 2. In-Code Design Notes

### Note [Core Architecture]

[tag:note-core-architecture]

Defines the foundational invariants for `tengri`:

1. **In-Memory Compilation Units:** Synthetic expressions are wrapped into virtual modules (`module Tengri.Interactive where it = <expr>`) with dummy source locations and in-memory `StringBuffer` representations. No temporary files touch the filesystem.
2. **Pre-Typecheck Plugin Lowering:** The in-memory parsed AST (`HsParsedModule`) is routed through `Polytropos.Plugin.Source.sourcePlugin`, desugaring `REC { ... }` records into chained `Polytropos.insertField` calls and inserting necessary qualified imports before `typecheckModule` executes.
3. **Session Concurrency & State Threading:** Interactive GHC API interactions are funneled through a single dedicated worker thread (`SavdagWorker`) communicating via asynchronous channels (`Chan SavdagRequest`) and synchronizing on rendezvous MVars (`MVar (Either String a)`).
4. **Daemon Inter-Process Communication:** Communication between shell hooks (ZLE `accept-line`), the CLI (`tengri`), and the daemon (`tengri-savdag`) occurs exclusively over POSIX Unix domain sockets using length-prefixed framing and optional `SCM_RIGHTS` descriptor passing.

### Note [Source Plugin Architecture]

[tag:note-source-plugin-arch]

Defines the interactive expression wrapper and synthetic in-memory AST pipeline for `tengri-savdag`. Bare prompt strings are framed in synthetic module envelopes before source plugin passes execute.

---

## 3. Architectural Design Decisions

### Decision D1: Modular Workspace Architecture

The repository is partitioned into six focused packages under `packages/`:

```
                    ┌─────────────────────────┐
                    │      tengri (CLI)       │
                    └────────────┬────────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         ▼                                               ▼
┌──────────────────┐                           ┌──────────────────┐
│  tengri-savdag   │                           │   tengri-toli    │
│  (Warm Daemon &  │                           │ (Reflection &    │
│  Mock ModSummary)│                           │ ZLE accept-line) │
└────────┬─────────┘                           └──────────────────┘
         │
    ┌────┴─────────────────────────────┐
    ▼                                  ▼
┌──────────────────┐         ┌──────────────────┐
│   tengri-sulde   │         │    tengri-lus    │
│(Algebraic Prelude│         │(Conduits/Streams)│
└──────────────────┘         └──────────────────┘
    │                                  │
    └──────────────────┬───────────────┘
                       ▼
             ┌──────────────────┐
             │  tengri-darkhan  │
             │(Abductive Spine) │
             └──────────────────┘
```

**Rationale:** Decoupling the daemon (`tengri-savdag`), the reflection mirror (`tengri-toli`), and the algebraic combinators (`tengri-sulde`, `tengri-lus`) ensures that CLI clients and shell hooks remain lightweight ($< 2\text{MB}$) while the heavy GHC runtime remains isolated within long-lived daemon server processes.

---

### Decision D2: Resident `GhcMonad` Evaluation Thread (`tengri-savdag`)

**Problem:** GHC's `HscEnv` and typechecker session are not thread-safe for arbitrary concurrent evaluation. Spawning multiple OS threads that each invoke `runGhc` concurrently can corrupt shared RTS data structures or global symbol tables.

**Resolution:** `tengri-savdag` encapsulates the resident GHC session inside a single dedicated worker thread managed by `SavdagWorker`:

```haskell
data SavdagWorker = SavdagWorker
  { workerReqChan  :: !(Chan SavdagRequest)
  , workerThreadId :: !ThreadId
  }
```

Clients submit evaluation requests (`SavdagRequest`), and the worker synchronizes the response via an `MVar`. This eliminates thread-safety hazards while retaining warm session state across turns.

---

### Decision D3: Synthetic In-Memory Compilation Units via Mock `ModSummary`

**Problem:** Standard `GHC.compileExpr` and `GHC.exprType` do not pass interactive statements through `Plugin.parsedResultAction`. `REC { a = 1 }` fails to parse as a constructor.

**Resolution:** `tengri-savdag` manufactures a mock `ModSummary` directly in memory using `mkMockModSummary`:

```haskell
mkMockModSummary
  :: DynFlags
  -> ModuleName
  -> FilePath
  -> ModSummary
  -> ModSummary
```

The bare expression is wrapped into:
```haskell
module Tengri.Interactive where
it = <user_expression>
```
The mock summary is populated with `ms_hspp_buf = Just buf` and `ms_hsc_src = HsSrcFile`. GHC's `hscParse` parses the in-memory buffer without touching disk. The resulting `HsParsedModule` is handed to `Polytropos.Plugin.Source.sourcePlugin`, lowering `REC { ... }` into canonical record combinators before feeding the expression to GHC's typechecker.

---

### Decision D4: IPC Protocol & SCM_RIGHTS Daemon Supervision (`tengri-savdag`)

**Protocol:** `tengri-savdag` listens on a local Unix domain socket (`/tmp/tengri-$UID.sock`). Commands (`EVAL`, `TYPE`, `DESUGAR`, `PING`, `SHUTDOWN`) are serialized with 4-byte big-endian length prefix framing. Standard file descriptors (`stdin`, `stdout`, `stderr`) can be passed via `SCM_RIGHTS` ancillary data, allowing interactive terminal formatting and streaming to occur transparently without pipe redirection bottlenecks.

---

### Decision D5: Shamanic Mirror: Type Reflection & Core Lens (`tengri-toli`)

`tengri-toli` provides sub-millisecond introspection into the resident GHC environment:
- **Type Reflection:** Inferred principal types are formatted using GHC's internal pretty printer (`Outputable`) with custom ANSI terminal highlight stylers.
- **Core AST Lens:** Developers can inspect GHC Core simplifier output directly from the terminal (`tengri core "expr"`), displaying desugared, optimized System $F_\omega$ representations.

---

## 4. Verification & Audit Invariants

All modules and packages in `tengri` adhere to the 5 standard verification gates:

1. **HLint:** Zero warnings.
2. **Cabal Test:** 100% test pass rate across all packages.
3. **Tagref:** Zero broken tag references.
4. **Linkcheck:** Zero dead or broken markdown links.
5. **CLOC Comment Density:** Strict $\ge 50\%$ comment/code ratio.
