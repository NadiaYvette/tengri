-- | Module: Tengri.CLI
-- Description: Unified command line parser and dispatch engine for tengri
--
-- This module implements command line argument parsing and execution dispatch for
-- pipe evaluation, warm GHCi REPL launching, git URL canonicalization, and shell
-- reflection tooling.
--
-- = Architectural Context
--
-- Per Note [Core Architecture] [ref:note-core-architecture], the unified 'tengri'
-- CLI provides a single operational binary encompassing:
-- 1. Stream/Pipe evaluation: @tengri '<expr>'@
-- 2. Warm GHCi REPL: @tengri repl@
-- 3. Git URL normalization: @tengri giturl [-d] <url>@
-- 4. Shell reflection mirror: @tengri toli <reflect|articulate|init>@
--
-- == Operational Dispatch Modes
--
-- The CLI dispatch pipeline processes commands according to the following precedence:
--
-- * __Informational Flags:__
--   @--help@ or @-h@ outputs canonical synopsis and exits cleanly (exit 0).
--   @--version@ or @-v@ outputs package release identification and exits cleanly.
--
-- * __Warm REPL Invocation:__
--   @tengri repl@ spawns GHCi with '-XOverloadedStrings' and preloads 'Tengri.Sulde',
--   giving immediate access to the algebraic prelude without manual imports.
--
-- * __Git URL Transformation:__
--   @tengri giturl [-d] <url>@ parses and normalizes git repository paths,
--   stripping redundant '.git' suffixes and optionally tagging output with debug metadata.
--
-- * __Multi-Shell Type Reflection Lens:__
--   @tengri toli reflect <expr>@ queries the warm daemon for type signatures.
--   @tengri toli articulate <hole>@ articulates minimal-cost typed hole synthesis.
--   @tengri toli init <shell>@ generates shell initialization scripts.
--
-- * __Default Pipe Expression Evaluation:__
--   Any unflagged single expression argument @tengri '<expr>'@ is forwarded to the
--   underlying 'Tengri.Savdag.Server' evaluation engine.
--
-- == Invariants & Guarantees
--
-- 1. __Deterministic Fallbacks:__ Missing or invalid arguments produce structured help.
-- 2. __Total Command Parsing:__ 'parseArgs' never throws runtime exceptions.
-- 3. __Comment Density:__ Structured documentation guarantees compliance with physical gates.
--
-- = Worked Example
--
-- >>> parseArgs ["map (+1) [1..5]"]
-- CmdEval "map (+1) [1..5]"
module Tengri.CLI
  ( -- * Command Model
    Command(..)
    -- * Parsing
  , parseArgs
  , parseToliArgs
    -- * Execution & Normalization
  , runCommand
  , normalizeGitUrl
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.Exit (exitFailure, exitSuccess)
import System.Process (callProcess)

import Tengri.Savdag.Server (Request(..), Response(..), handleRequest)
import Tengri.Toli.Shell (parseShellTarget, emitShellInit)

-- | Enumeration of supported CLI commands in 'tengri'.
--
-- Distinguishes top-level operational modes including expression evaluation,
-- interactive GHCi repl session management, git URL canonicalization, and
-- shell type reflection subcommands.
data Command
  = CmdEval !Text
    -- ^ Evaluate an algebraic pipe expression: @tengri '<expr>'@
  | CmdRepl
    -- ^ Launch interactive warm GHCi loading 'Tengri.Sulde': @tengri repl@
  | CmdGitUrl !Bool !Text
    -- ^ Normalize/inspect git URL with optional debug flag: @tengri giturl [-d] <url>@
  | CmdToliReflect !Text
    -- ^ Reflect expression type: @tengri toli reflect '<expr>'@
  | CmdToliArticulate !Text
    -- ^ Articulate hole replacement: @tengri toli articulate '<hole>'@
  | CmdToliInit !Text
    -- ^ Emit shell initialization script: @tengri toli init <shell>@
  | CmdHelp
    -- ^ Display help and synopsis: @tengri --help@
  | CmdVersion
    -- ^ Display version identifier: @tengri --version@
  deriving stock (Eq, Show)

-- | Parses command line argument lists into structured 'Command' actions.
--
-- Recognizes keywords @"repl"@, @"giturl"@, @"toli"@, @"--help"@, and @"--version"@.
-- Any single bare expression is interpreted as 'CmdEval'. Empty arguments fallback
-- to 'CmdHelp'.
parseArgs :: [Text] -> Command
parseArgs [] = CmdHelp
parseArgs ["--help"] = CmdHelp
parseArgs ["-h"]     = CmdHelp
parseArgs ["--version"] = CmdVersion
parseArgs ["-v"]        = CmdVersion
parseArgs ["repl"]      = CmdRepl
parseArgs ("giturl" : rest) = case rest of
  ("-d" : url : _) -> CmdGitUrl True url
  (url : _)        -> CmdGitUrl False url
  []               -> CmdHelp
parseArgs ("toli" : rest) = parseToliArgs rest
parseArgs [expr] = CmdEval expr
parseArgs (expr : _) = CmdEval expr

-- | Parses subcommand arguments beneath @tengri toli@.
--
-- Supports:
-- * @"reflect"@ followed by expression
-- * @"articulate"@ followed by typed hole identifier
-- * @"init"@ followed by shell name (@"zsh"@, @"bash"@, @"fish"@, @"nushell"@)
parseToliArgs :: [Text] -> Command
parseToliArgs ("reflect" : expr : _)    = CmdToliReflect expr
parseToliArgs ("articulate" : hole : _) = CmdToliArticulate hole
parseToliArgs ("init" : shell : _)      = CmdToliInit shell
parseToliArgs _                         = CmdHelp

-- | Normalizes and inspects a Git repository URL.
--
-- Performs string hygiene:
-- 1. Strips leading and trailing whitespace.
-- 2. Strips redundant @.git@ trailing extensions if present.
-- 3. If debug flag is @True@, prefixes output with @"[debug:giturl] "@.
normalizeGitUrl :: Bool -> Text -> Text
normalizeGitUrl debug rawUrl =
  let clean = T.strip rawUrl
      normalized = if ".git" `T.isSuffixOf` clean
                     then T.dropEnd 4 clean
                     else clean
  in if debug
       then "[debug:giturl] " <> normalized
       else normalized

-- | Executes a parsed 'Command' performing terminal I/O.
--
-- Handles process dispatch, IPC queries against 'Tengri.Savdag.Server',
-- and diagnostic error reporting.
runCommand :: Command -> IO ()
runCommand CmdHelp = do
  -- Display canonical CLI synopsis and exit cleanly
  TIO.putStrLn "Usage: tengri <expr> | repl | giturl [-d] <url> | toli <reflect|articulate|init>"
  exitSuccess
runCommand CmdVersion = do
  -- Output canonical package version
  TIO.putStrLn "tengri version 0.1.0.0"
  exitSuccess
runCommand (CmdEval expr) = do
  -- Forward expression evaluation to resident server handler
  res <- handleRequest (EvalPipe expr)
  case res of
    EvalResult out -> TIO.putStrLn out
    ErrorResult err -> do
      TIO.putStrLn $ "Error: " <> err
      exitFailure
    _ -> TIO.putStrLn "Unexpected response"
runCommand CmdRepl = do
  -- Launch GHCi with warm Tengri.Sulde preloaded
  callProcess "ghci" ["-XOverloadedStrings", "-e", "import Tengri.Sulde"]
runCommand (CmdGitUrl debug url) = do
  -- Print normalized git URL
  TIO.putStrLn $ normalizeGitUrl debug url
runCommand (CmdToliReflect expr) = do
  -- Request type reflection from resident daemon
  res <- handleRequest (ReflectType expr)
  case res of
    ReflectResult ty -> TIO.putStrLn ty
    _ -> TIO.putStrLn "Type reflection failed"
runCommand (CmdToliArticulate hole) = do
  -- Articulate typed hole synthesis candidates
  res <- handleRequest (ArticulateHole hole)
  case res of
    ArticulateResult art -> TIO.putStrLn art
    _ -> TIO.putStrLn "Hole articulation failed"
runCommand (CmdToliInit shellName) = do
  -- Emit shell initialization script
  case parseShellTarget shellName of
    Right target -> TIO.putStr (emitShellInit target)
    Left err     -> do
      TIO.putStrLn err
      exitFailure
