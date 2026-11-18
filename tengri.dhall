-- ~/src/tengri/tengri.dhall
let Prelude = https://prelude.dhall-lang.org/package.dhall
let Schema = /home/nyc/src/gachi/packages/gachi-schema/dhall/Schema.dhall ? https://raw.githubusercontent.com/NadiaYvette/gachi/refs/heads/master/packages/gachi-schema/dhall/Schema.dhall
let PackagePrecursor = { name : Text, synopsis : Text }

let toPackage =
  \(item : PackagePrecursor) -> item // { exposes = [] : List Text }

let project : Schema.Project
  = { name = "tengri"

    , category = "Development"

    -- I'm unsure about synopsis; this level is more of the
    -- cabal.project than a package.cabal
    -- , synopsis = "The Eternal Blue Sky: type-directed Haskell shell exploration and REPL arena"

    , version = "0.1.0.0"

    -- The licence is a NonEmpty representing an n-ary OR of one or more licences.
    , license = Schema.singleton Text "EUPL-1.2"

    -- packages is a NonEmpty representing one or more workspace packages.
    , packages =
        Schema.cons
          Schema.Package
          (toPackage { name = "tengri-sulde", synopsis = "Precompiled algebraic prelude re-exporting gongju and polytropos" })
          (Prelude.List.map PackagePrecursor Schema.Package toPackage
            [ { name = "tengri-lus"
              , synopsis = "Stream channels, regex conduits, and evacuable aggregation"
              }
            , { name = "tengri-darkhan"
              , synopsis = "Abductive spine and arity bridge synthesizer powered by Gargamelle and Gongju"
              }
            , { name = "tengri-savdag"
              , synopsis = "Warm GHC API daemon with SCM_RIGHTS, mock ModSummary pipeline, and resident worker"
              }
            , { name = "tengri-toli"
              , synopsis = "Multi-shell completion, inline type reflection mirror, and Core inspection lens"
              }
            , { name = "tengri"
              , synopsis = "Unified CLI and interactive REPL surface for the Tengri constellation"
              }
            ])

    , description =
        "Replaces evalhs and ldpkgs with a warm GHC daemon (tengri-savdag), abductive spine articulation (tengri-darkhan), precompiled algebraic prelude (tengri-sulde), stream/pipe automation (tengri-lus), and multi-shell type reflection (tengri-toli)."
    , author =
      { name = "Nadia Yvette Chambers"
      , email = "nadia.yvette.chambers@ik.me"
      }
    , ghcVersion = "9.14.1"
    , cabalVersion = "3.18"
    , remotes =
      [ { name = "disroot",  url = "git@git.disroot.org:NadiaYvette/tengri" }
      , { name = "framagit", url = "git@framagit.org:NadiaYvette/tengri" }
      , { name = "gitcode",  url = "git@gitcode.com:NadiaYvette/tengri" }
      , { name = "github",   url = "git@github.com:NadiaYvette/tengri" }
      -- I'm not sure there's enough upstream rad integration
      -- sourcehut has gone anti-AI
      -- , { name = "srht",   url = "git@git.sr.ht:~nadiayvette/tengri" }
      ]
    }
in project
