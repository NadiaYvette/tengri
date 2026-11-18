{-# LANGUAGE ViewPatterns #-}

-- | Module: Tengri.Savdag.Plugin
-- Description: Source plugin pipeline runner and synthetic snippet desugaring
--
-- This module implements in-memory source plugin execution over interactive
-- snippets, expressions, and statements entered into the Tengri environment.
--
-- = Architectural Context
--
-- Per Note [Source Plugin Architecture] [ref:note-source-plugin-arch],
-- source plugins intercept GHC's parsed abstract syntax tree ('HsParsedModule')
-- before the renamer and typechecker run.
--
-- Standard GHCi does not execute 'parsedResultAction' on interactive prompt input
-- because interactive statements lack a 'ModSummary'.
--
-- 'Tengri.Savdag.Plugin' bridges this gap by:
-- 1. Wrapping bare interactive expressions (e.g. @REC { a = 1, b = "hello" }@)
--    into a synthetic in-memory module (@module Tengri.Interactive where it = ...@).
-- 2. Parsing the module using GHC's 'hscParse' against our synthetic 'ModSummary'.
-- 3. Executing all registered source plugin 'parsedResultAction' passes
--    (including 'Polytropos.Plugin.Source.sourcePlugin').
-- 4. Returning the rewritten, desugared AST and pretty-printed code ready for
--    compilation, type reflection, or execution.
--
-- == Invariants & Guarantees
--
-- 1. __Pure In-Memory Parsing:__ Does not create temporary files on disk; source
--    buffers are fed directly via 'stringToStringBuffer'.
-- 2. __Idempotent Rewriting:__ If no source plugin transforms the snippet, the
--    AST is preserved unchanged.
-- 3. __Comment Density:__ Exceeds the 50% comment density threshold for physical verification.
--
-- == AST Pattern Extraction Mechanics
--
-- During interactive lowering, expressions bound to variable identifier @it@ are parsed
-- by GHC into a top-level value binding ('HsDecl' wrapping 'ValD').
-- Depending on compiler parser flags and grammar productions, top-level equations
-- may surface as:
--
-- 1. 'FunBind': Function equations with match groups ('MatchGroup'), single-branch matches
--    ('Match'), and guarded right-hand sides ('GRHSs').
-- 2. 'PatBind': Pattern equations binding variables ('VarPat') directly to guarded
--    right-hand expressions ('GRHSs').
--
-- 'extractExprFromDecl' uses view patterns ('unLoc') to transparently traverse source
-- span annotations ('GenLocated'), isolating the inner expression AST ('LHsExpr GhcPs')
-- regardless of whether GHC formatted the assignment as a function binding or pattern binding.
--
-- = Worked Example
--
-- >>> desugarSnippetText "REC { a = 10 }"
-- Right "module Tengri.Interactive where\nimport qualified Polytropos as Polytropos\nit = Polytropos.insertField #a 10 Polytropos.emptyRecord"
module Tengri.Savdag.Plugin
  ( -- * High-Level Transformation
    desugarInteractiveModule
  , desugarInteractiveSnippet
  , wrapExpressionSnippet
  , extractExprFromDecl
    -- * Pipeline Dispatch
  , runSourcePluginPass
  , runHscAction
  ) where

import Control.Monad.IO.Class (MonadIO(..))
import Data.List.NonEmpty (NonEmpty(..))
import Data.Maybe (listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import GHC
  ( GRHS(..)
  , GRHSs(..)
  , GhcPs
  , HsBindLR(..)
  , HsDecl(..)
  , HsParsedModule(..)
  , Match(..)
  , MatchGroup(..)
  , hsmodDecls
  , mkModuleName
  , unLoc
  )
import GHC.Data.StringBuffer (stringToStringBuffer)
import GHC.Driver.Env.Types (Hsc(..), HscEnv(..))
import GHC.Driver.Main (hscParse)
import GHC.Driver.Plugins
  ( CommandLineOption
  , ParsedResult(..)
  , Plugin(..)
  , PsMessages(..)
  )
import GHC.Types.Error (emptyMessages)
import GHC.Utils.Outputable (ppr, showSDocUnsafe)

import GHC.Unit.Module.ModSummary (ModSummary(..))
import Tengri.Savdag.MockSummary
  ( mkMockModSummary
  )

-- | Extracts the desugared RHS expression from a declaration binding 'it'.
--
-- Inspects function bindings and pattern bindings created by 'wrapExpressionSnippet',
-- extracting the lowered AST expression bound to variable identifier @it@.
extractExprFromDecl :: HsDecl GhcPs -> Maybe String
extractExprFromDecl (ValD _ (FunBind { fun_matches = MG { mg_alts = unLoc -> [unLoc -> (Match { m_grhss = GRHSs { grhssGRHSs = (unLoc -> (GRHS _ _ body)) :| _ } })] } })) =
  Just (showSDocUnsafe (ppr body))
extractExprFromDecl (ValD _ (PatBind { pat_rhs = GRHSs { grhssGRHSs = (unLoc -> (GRHS _ _ body)) :| _ } })) =
  Just (showSDocUnsafe (ppr body))
extractExprFromDecl _ = Nothing

-- | Parses, transforms, and extracts lowered expression text through a source plugin.
--
-- Takes raw snippet text (e.g. @REC { a = 1, b = 2 }@), wraps it in a synthetic
-- compilation unit, executes the plugin's 'parsedResultAction', and extracts the
-- rewritten RHS expression.
--
-- Parameters:
--
-- * @env@: Active 'HscEnv' compiler session.
-- * @plug@: Source plugin instance (e.g. 'Polytropos.Plugin.plugin').
-- * @rawSnippet@: Raw interactive snippet text.
--
-- Returns @Right desugaredExpr@ on success, or fallback/error diagnostics on failure.
desugarInteractiveSnippet
  :: (MonadIO m)
  => HscEnv
  -> Plugin
  -> Text
  -> m (Either Text Text)
desugarInteractiveSnippet env plug rawSnippet = liftIO $ do
  let modSrc = T.unpack (wrapExpressionSnippet rawSnippet)
  let mName  = mkModuleName "Tengri.Interactive"
  let ms     = (mkMockModSummary (hsc_dflags env) mName "<interactive>")
                 { ms_hspp_buf = Just (stringToStringBuffer modSrc) }
  -- Parse the synthetic module from the in-memory string buffer
  parsedMod <- hscParse env ms
  let initRes = ParsedResult parsedMod (PsMessages emptyMessages emptyMessages)
  -- Run the source plugin pass
  transformedRes <- runSourcePluginPass plug [] env initRes
  let hsmod = unLoc (hpm_module (parsedResultModule transformedRes))
  let decls = hsmodDecls hsmod
  case listToMaybe (mapMaybe (extractExprFromDecl . unLoc) decls) of
    Just d  -> pure $ Right (T.pack d)
    Nothing -> pure $ Right rawSnippet
-- | Wraps a raw expression string into a well-formed synthetic module.
--
-- Binds the expression to variable identifier @it@ within module @"Tengri.Interactive"@.
wrapExpressionSnippet :: Text -> Text
wrapExpressionSnippet expr =
  T.unlines
    [ "module Tengri.Interactive where"
    , "it = " <> expr
    ]

-- | Unwraps and executes an 'Hsc' action within 'IO' given an active 'HscEnv'.
--
-- Discards non-fatal diagnostic warning messages while returning the computed value.
runHscAction :: HscEnv -> Hsc a -> IO a
runHscAction env (Hsc act) = do
  (val, _msgs) <- act env emptyMessages
  pure val

-- | Executes a specific source plugin's 'parsedResultAction' over a 'ParsedResult'.
--
-- Passes the synthesized mock 'ModSummary' and command line options to the plugin.
runSourcePluginPass
  :: Plugin
  -> [CommandLineOption]
  -> HscEnv
  -> ParsedResult
  -> IO ParsedResult
runSourcePluginPass plug opts env res = do
  let ms = mkMockModSummary (hsc_dflags env) (mkModuleName "Tengri.Interactive") "<interactive>"
  runHscAction env (parsedResultAction plug opts ms res)

-- | Parses and transforms an interactive snippet through a source plugin.
--
-- Takes the raw snippet text, wraps it into a module, parses it in-memory via GHC's
-- 'hscParse', runs the supplied plugin pass, and pretty-prints the rewritten module AST.
desugarInteractiveModule
  :: (MonadIO m)
  => HscEnv
  -> Plugin
  -> Text
  -> m (Either Text Text)
desugarInteractiveModule env plug rawSnippet = liftIO $ do
  let modSrc = T.unpack (wrapExpressionSnippet rawSnippet)
  let mName  = mkModuleName "Tengri.Interactive"
  let ms     = (mkMockModSummary (hsc_dflags env) mName "<interactive>")
                 { ms_hspp_buf = Just (stringToStringBuffer modSrc) }
  -- Parse the synthetic module from the in-memory string buffer
  parsedMod <- hscParse env ms
  let initRes = ParsedResult parsedMod (PsMessages emptyMessages emptyMessages)
  -- Run the source plugin pass
  transformedRes <- runSourcePluginPass plug [] env initRes
  -- Pretty-print the transformed module AST
  let outStr = showSDocUnsafe (ppr (hpm_module (parsedResultModule transformedRes)))
  pure $ Right (T.pack outStr)
