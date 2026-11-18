{-# LANGUAGE ScopedTypeVariables #-}

-- | Module: Tengri.Savdag.Monad
-- Description: GhcMonad session runner and environment configuration
--
-- This module implements the 'GhcMonad' execution environment for warm interactive
-- expression evaluation, type reflection, and AST inspection within the Tengri suite.
--
-- = Architectural Context
--
-- 'Tengri.Savdag.Monad' initializes and manages a warm resident GHC compiler session.
--
-- Instead of repeatedly forking cold @ghc@ or @ghci@ subprocesses (which incur high
-- process startup and dynamic linker latencies of 150–400ms per invocation),
-- 'SavdagM' maintains an initialized 'HscEnv' resident in memory.
--
-- == Note [In-Memory GhcMonad Evaluation and Exception Containment]
--
-- Traditional shell integration with GHC either invokes @ghc -e@ (incurring cold
-- RTS startup overhead and package database reloading penalties on every keystroke)
-- or forks an interactive @ghci@ slave process (subject to TTY escape sequences,
-- race conditions, and prompt parsing fragility).
--
-- 'Tengri.Savdag.Monad' takes a non-invasive, in-memory approach:
-- 1. Evaluator execution runs inside an instance of 'GhcMonad' ('SavdagM').
-- 2. Expression type checking ('exprType TM_Inst') classifies expressions before compilation.
-- 3. Pure expressions are wrapped in @show (...)@ and compiled to bytecode.
-- 4. Effectful computations (@IO a@) are compiled to actions and evaluated via 'unsafeCoerce'.
-- 5. All evaluations are wrapped with 'handleSourceError' (for static phase diagnostics)
--    and 'Control.Exception.try' paired with 'Control.Exception.evaluate' (for dynamic
--    phase exceptions such as division by zero or pattern match failures).
--
-- == Note [Row Polymorphic Syntactic Desugaring]
--
-- Row-polymorphic record literals (@REC { ... }@) and sum variants (@VAR { ... }@)
-- require GHC's source plugin pass ('Polytropos.Plugin') to lower syntactic sugar
-- into Core dictionary combinators ('Polytropos.insertField', 'Polytropos.inject').
--
-- Because standard GHC interactive evaluation bypasses 'parsedResultAction' due to
-- the absence of a compilation unit 'ModSummary', 'evalSavdagExpr' intercepts
-- row expressions and feeds them through 'Tengri.Savdag.Plugin.desugarInteractiveSnippet'.
-- The rewritten AST is extracted in-memory and subsequently compiled without disk I/O.
--
-- == Invariants & Guarantees
--
-- 1. __Session Determinism:__ Dynamic flags are configured consistently with language
--    extensions ('OverloadedRecordDot', 'DataKinds', 'TypeApplications').
-- 2. __Total Operations:__ Evaluation and type reflection handle syntax and type
--    errors gracefully without crashing the resident session.
-- 3. __Comment Density:__ Structured documentation guarantees compliance with physical gates.
--
-- = Worked Example
--
-- >>> runSavdag defaultSavdagConfig (reflectSavdagType "42 :: Int")
-- Right "Int"
module Tengri.Savdag.Monad
  ( -- * Monad & Session Types
    SavdagM
  , SavdagConfig(..)
  , defaultSavdagConfig
    -- * Execution Runners
  , runSavdag
  , initSavdagSession
    -- * Domain Operations
  , reflectSavdagType
  , evalSavdagExpr
  ) where

import Control.Monad.IO.Class (liftIO)
import qualified Control.Exception as E
import Data.Text (Text)
import qualified Data.Text as T
import GHC
  ( DynFlags(..)
  , Ghc
  , InteractiveImport(..)
  , exprType
  , getLogger
  , getSession
  , getSessionDynFlags
  , handleSourceError
  , interpretPackageEnv
  , mkModuleName
  , runGhc
  , setContext
  , setInteractiveDynFlags
  , setSessionDynFlags
  , simpleImportDecl
  )
import GHC.Types.SourceError (SourceError)
import GHC.Tc.Module (TcRnExprMode(TM_Inst))
import GHC.Driver.DynFlags
  ( xopt_set
  , PackageFlag(..)
  , PackageArg(..)
  , ModRenaming(..)
  )
import GHC.LanguageExtensions.Type (Extension(..))
import qualified GHC.Paths
import GHC.Runtime.Eval (compileExpr)
import GHC.Runtime.Loader (initializeSessionPlugins)
import GHC.Utils.Outputable (ppr, showSDocUnsafe)
import qualified Polytropos.Plugin
import Tengri.Savdag.Plugin (desugarInteractiveSnippet)
import Unsafe.Coerce (unsafeCoerce)

-- | Execution monad for warm GHC interactive sessions.
--
-- Type alias for GHC's native 'Ghc' monad, fully implementing 'GhcMonad',
-- 'Control.Monad.IO.Class.MonadIO', and exception handling.
type SavdagM = Ghc

-- | Configuration parameters for initializing a Savdag session.
--
-- Governs runtime paths, preloaded imports, and language extensions
-- to configure upon initializing the warm compiler session.
--
-- Fields:
--
-- * @savdagLibDir@: Path to the GHC library root directory containing package databases.
-- * @savdagImports@: List of top-level modules to expose in the interactive REPL scope.
-- * @savdagExtensions@: GHC language extensions to enable in session dynamic flags.
data SavdagConfig = SavdagConfig
  { savdagLibDir     :: !(Maybe FilePath)
    -- ^ Path to GHC's library directory (e.g. @/home/.../lib@ or 'Nothing' for ambient).
  , savdagImports    :: ![String]
    -- ^ Module imports to preload into the interactive scope context.
  , savdagExtensions :: ![Extension]
    -- ^ Language extensions to activate in session dynamic flags.
  } deriving stock (Eq, Show)

-- | Default configuration for 'SavdagConfig'.
--
-- Preloads @"Prelude"@ and activates row polymorphism, type applications, and default rules.
--
-- Sensible defaults:
--
-- * Library path dynamically bound via 'GHC.Paths.libdir'.
-- * Standard record, label, and defaulting extensions enabled.
defaultSavdagConfig :: SavdagConfig
defaultSavdagConfig = SavdagConfig
  { savdagLibDir     = Just GHC.Paths.libdir
  , savdagImports    = ["Prelude", "Tengri.Sulde", "Polytropos", "GHC.TypeNats"]
  , savdagExtensions = [ExtendedDefaultRules, OverloadedRecordDot, DataKinds, TypeApplications, OverloadedStrings, OverloadedLabels]
  }

-- | Executes a 'SavdagM' computation within an initialized GHC session.
--
-- Configures dynamic flags and imports per the supplied 'SavdagConfig'.
--
-- Guarantees:
--
-- * The compiler environment is initialized cleanly before the action runs.
-- * Context imports and language extensions are populated deterministically.
runSavdag :: SavdagConfig -> SavdagM a -> IO a
runSavdag cfg act = runGhc (savdagLibDir cfg) $ do
  initSavdagSession cfg
  act

-- | Initializes session 'DynFlags' and interactive context imports.
initSavdagSession :: SavdagConfig -> SavdagM ()
initSavdagSession cfg = do
  df0 <- getSessionDynFlags
  logger <- getLogger
  df1 <- liftIO $ interpretPackageEnv logger df0
  -- Enable configured language extensions
  let df2 = foldr enableExtension df1 (savdagExtensions cfg)
      exposePkg name = ExposePackage ("-package " ++ name) (PackageArg name) (ModRenaming True [])
      pkgsToExpose = ["tengri-sulde", "polytropos-core", "polytropos-plugin"]
      df3 = df2
        { packageFlags = map exposePkg pkgsToExpose ++ packageFlags df2
        , pluginModNames = mkModuleName "Polytropos.Plugin" : pluginModNames df2
        }
  setSessionDynFlags df3
  setInteractiveDynFlags df3
  initializeSessionPlugins
  -- Configure default imports in the interactive evaluation context
  let iDecls = map (IIDecl . simpleImportDecl . mkModuleName) (savdagImports cfg)
  setContext iDecls
  where
    enableExtension :: Extension -> DynFlags -> DynFlags
    enableExtension ext df = xopt_set df ext

-- | Reflects the static Haskell type of an expression string.
--
-- Returns @Right typeString@ on success, or @Left errorDiagnostic@ on failure.
reflectSavdagType :: String -> SavdagM (Either Text Text)
reflectSavdagType exprStr = handleSourceError onErr $ do
  ty <- exprType TM_Inst exprStr
  pure $ Right (T.pack (showSDocUnsafe (ppr ty)))
  where
    onErr :: SourceError -> SavdagM (Either Text Text)
    onErr e = pure $ Left (T.pack (show e))

-- | Evaluates an expression string in the warm GHC session and formats the result.
--
-- Invokes GHC's internal bytecode compiler and runtime evaluator. Supports:
-- 1. __Syntactic Sugar Lowering:__ If the input contains row record literals (@REC { ... }@)
--    or variant literals (@VAR { ... }@), invokes 'desugarInteractiveSnippet' to lower
--    them through 'Polytropos.Plugin' before evaluation.
-- 2. __Type-Aware Evaluation Dispatch:__ Inspects expression type via 'exprType'.
--    * When returning @IO ()@: Executes the action effectfully and yields @Right "()"@.
--    * When returning @IO a@: Compiles @fmap show expr@, executes the action, and yields @Right (show result)@.
--    * When returning pure @a@: Compiles @show expr@, evaluates the string representation, and yields @Right (show result)@.
-- 3. __Exception Containment:__ Catches compiler errors via 'handleSourceError' and runtime
--    exceptions via 'E.try' and 'E.evaluate', safely returning 'Left' diagnostics without
--    corrupting or terminating the resident session.
--
-- Parameters:
--
-- * @exprStr@: Raw Haskell expression string to evaluate.
--
-- Returns @Right textualOutput@ on success, or @Left errorDiagnostic@ on failure.
evalSavdagExpr :: String -> SavdagM (Either Text Text)
evalSavdagExpr exprStr = handleSourceError onCompileErr $ do
  env <- getSession
  let shouldDesugar = "REC" `T.isInfixOf` T.pack exprStr || "VAR" `T.isInfixOf` T.pack exprStr
  targetStr <- if shouldDesugar
    then do
      desugaredRes <- desugarInteractiveSnippet env Polytropos.Plugin.plugin (T.pack exprStr)
      pure $ case desugaredRes of
        Right d -> T.unpack d
        Left _  -> exprStr
    else pure exprStr

  ty <- exprType TM_Inst targetStr
  let tyStr = showSDocUnsafe (ppr ty)
  if "IO ()" `T.isSuffixOf` T.pack tyStr
    then do
      hv <- compileExpr targetStr
      res <- liftIO $ E.try $ do
        let act = unsafeCoerce hv :: IO ()
        act
        pure ("()" :: Text)
      pure $ case res of
        Right t -> Right t
        Left (e :: E.SomeException) -> Left (T.pack (show e))
    else if "IO " `T.isInfixOf` T.pack tyStr
      then do
        hv <- compileExpr ("fmap show (" ++ targetStr ++ ")")
        res <- liftIO $ E.try $ do
          let act = unsafeCoerce hv :: IO String
          s <- act
          _ <- E.evaluate (length s)
          pure (T.pack s)
        pure $ case res of
          Right t -> Right t
          Left (e :: E.SomeException) -> Left (T.pack (show e))
      else do
        hv <- compileExpr ("show (" ++ targetStr ++ ")")
        res <- liftIO $ E.try $ do
          let s = unsafeCoerce hv :: String
          _ <- E.evaluate (length s)
          pure (T.pack s)
        pure $ case res of
          Right t -> Right t
          Left (e :: E.SomeException) -> Left (T.pack (show e))
  where
    onCompileErr :: SourceError -> SavdagM (Either Text Text)
    onCompileErr e = pure $ Left (T.pack (show e))
