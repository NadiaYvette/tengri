-- ~/src/tengri/tengri.dhall
let Prelude = https://prelude.dhall-lang.org/package.dhall
let Schema = https://raw.githubusercontent.com/NadiaYvette/gachi/refs/heads/master/packages/gachi-schema/dhall/Schema.dhall
let PackagePrecursor = { name : Text, synopsis : Text }
let packagePrecursorList
  = [ { name = "tengri-sulde"
      , synopsis = "Precompiled algebraic prelude re-exporting gongju, polytropos, and total pattern peelers"
      }
    , { name = "tengri-lus"
      , synopsis = "Type-directed stdin/stdout stream channels, regex conduits, and evacuability-polymorphic aggregation"
      }
    , { name = "tengri-darkhan"
      , synopsis = "Abductive spine and arity bridge synthesizer powered by Gargamelle and Gongju"
      }
    , { name = "tengri-savdag"
      , synopsis = "Persistent warm GHC API daemon with SCM_RIGHTS file-descriptor passing and MCP introspection"
      }
    , { name = "tengri-toli"
      , synopsis = "Multi-shell completion, inline type reflection mirror, and Core inspection lens"
      }
    , { name = "tengri"
      , synopsis = "Unified CLI and interactive REPL surface for the Tengri constellation"
      }
    ]

-- I have strong suspicions Package.exposes needs to be NonEmpty vs. List
let packageList : List Schema.Package
  = Prelude.List.map
      PackagePrecursor
      { name : Text, synopsis : Text, exposes : List Text }
      (λ(item : PackagePrecursor) → item // { exposes = [] : List Text })
      packagePrecursorList

let project : Schema.Project
  = { name = "tengri"

    -- category is not only a problem to omit, it needs to be a
    -- NonEmpty, because there has to be one or more of them
    -- , category = "Development"

    -- I'm unsure about synopsis; this level is more of the
    -- cabal.project than a package.cabal
    -- , synopsis = "The Eternal Blue Sky: type-directed Haskell shell exploration and REPL arena"

    -- version is also a problem to omit; perhaps a NonEmpty Natural
    -- could represent the validity constraints on an isolated version
    -- number, but there's a problem where the versions must be
    -- monotonically increasing in the lexicographical ordrering
    -- , version = "0.1.0.0"

    -- The licence needs to be a NonEmpty to represent an n-ary OR of
    -- one or more licences. 
    , license = "EUPL-1.2"

    -- I suspect packages, too, needs to be a NonEmpty instead of a List
    , packages = packageList

    , description =
        "Replaces evalhs and ldpkgs with a warm GHC daemon (tengri-savdag), abductive spine articulation (tengri-darkhan), precompiled algebraic prelude (tengri-sulde), stream/pipe automation (tengri-lus), and multi-shell type reflection (tengri-toli)."
    , author =
      { name = "Nadia Yvette Chambers"
      , email = "nadia.yvette.chambers@ik.me"
      }
    , ghcVersion = "9.10.1"
    , cabalVersion = "3.12"
    , remotes =
      [ { name = "disroot",  url = "git@git.disroot.org:NadiaYvette/tengri" }
      , { name = "framagit", url = "git@framagit.org:NadiaYvette/tengri
      , { name = "gitcode",  url = "git@gitcode.com:NadiaYvette/tengri" }
      , { name = "github",   url = "git@github.com:NadiaYvette/tengri" }
      -- I'm not sure there's enough upstream rad integration
      -- sourcehut has gone anti-AI
      -- , { name = "srht",   url = "git@git.sr.ht:~nadiayvette/tengri" }
      ]
    }
in project
