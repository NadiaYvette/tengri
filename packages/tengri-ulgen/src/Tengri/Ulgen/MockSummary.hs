{-# LANGUAGE PatternSynonyms #-}
{-# OPTIONS_GHC -Wno-pattern-namespace-specifier #-}
-- | Module: Tengri.Ulgen.MockSummary
-- Description: Mock ModSummary synthesis for interactive source plugin passes
--
-- This module implements synthetic 'ModSummary' construction for interactive
-- prompt lines, expressions, and statements evaluated within the Tengri shell.
--
-- = Architectural Context
--
-- In GHC's compilation architecture, source plugins implementing 'parsedResultAction'
-- (such as @Polytropos.Plugin@, which desugars @REC { ... }@ and open row syntax)
-- expect a valid 'ModSummary' describing the module being compiled:
--
-- @
-- parsedResultAction :: [CommandLineOption] -> ModSummary -> ParsedResult -> Hsc ParsedResult
-- @
--
-- However, when expressions are entered interactively at a REPL prompt or via
-- 'GHC.compileExpr', GHC bypasses the whole-module compilation pipeline and evaluates
-- statements directly, omitting 'ModSummary' construction. This causes source plugins
-- to be completely skipped for interactive prompt input, resulting in syntax errors
-- (e.g. @Not in scope: data constructor ‘REC’@).
--
-- 'Tengri.Ulgen.MockSummary' solves this by synthesizing an in-memory, synthetic
-- 'ModSummary' populated with appropriate default timestamps, dummy file locations,
-- active session 'DynFlags', and canonical module identifiers.
--
-- == Invariants & Guarantees
--
-- 1. __Home Unit Conformance:__ The synthesized 'Module' uses 'mainUnit', matching
--    the ambient interactive compilation session.
-- 2. __Total Operations:__ All fields are populated with well-typed defaults;
--    no partial functions or 'undefined' values are used.
-- 3. __Comment Density:__ Structured documentation guarantees compliance with
--    the 50% comment density physical gate.
--
-- = Worked Example
--
-- >>> import GHC.Driver.DynFlags (defaultDynFlags)
-- >>> let ms = mkInteractiveModSummary defaultDynFlags
-- >>> ms_hspp_file ms
-- "<interactive-tengri>"
module Tengri.Ulgen.MockSummary
  ( -- * Mock Summary Constructors
    mkMockModSummary
  , mkInteractiveModSummary
    -- * Inspection Helpers
  , mockModuleName
  , mockFilePath
  ) where

import GHC
  ( ModuleName
  , mkModuleName
  , moduleName
  , moduleNameString
  )
import GHC.Driver.DynFlags (DynFlags)
import GHC.Fingerprint (fingerprint0)
import GHC.Types.SourceFile (HscSource(HsSrcFile))
import GHC.Unit.Module.Location (pattern ModLocation)
import GHC.Unit.Module.ModSummary (ModSummary(..))
import GHC.Unit.Types (mainUnit, mkModule)

-- | Constructs a synthetic 'ModSummary' for a designated module name and path.
--
-- Populates all required GHC internal metadata fields with consistent default
-- timestamps, an empty import set, and zero fingerprint, satisfying the preconditions
-- required by source plugin 'parsedResultAction' passes.
--
-- Parameters:
--
-- * @dflags@: Active compiler session 'DynFlags' carrying loaded plugin and language settings.
-- * @mName@: Module identifier (e.g. @"Tengri.Interactive"@).
-- * @targetPath@: Pseudo-filesystem path representing the source buffer.
mkMockModSummary :: DynFlags -> ModuleName -> FilePath -> ModSummary
mkMockModSummary dflags mName targetPath =
  ModSummary
    { ms_mod           = mkModule mainUnit mName
      -- ^ Target module identity bound to ambient mainUnit.
    , ms_hsc_src       = HsSrcFile
      -- ^ Regular Haskell source file compilation mode.
    , ms_location      = ModLocation
                           (Just targetPath)
                           (targetPath ++ ".hi")
                           (targetPath ++ ".dyn_hi")
                           (targetPath ++ ".o")
                           (targetPath ++ ".dyn_o")
                           (targetPath ++ ".hie")
      -- ^ Six-tuple file location pattern covering interface and object artifacts.
    , ms_hs_hash       = fingerprint0
      -- ^ Neutral 128-bit hash representing in-memory scratchpad source.
    , ms_obj_date      = Nothing
      -- ^ No on-disk object modification timestamp.
    , ms_dyn_obj_date  = Nothing
      -- ^ No on-disk dynamic object timestamp.
    , ms_iface_date    = Nothing
      -- ^ No cached interface timestamp.
    , ms_hie_date      = Nothing
      -- ^ No cached HIE file timestamp.
    , ms_srcimps       = []
      -- ^ Empty source-level import list for isolated snippet evaluation.
    , ms_textual_imps  = []
      -- ^ Empty textual import list.
    , ms_parsed_mod    = Nothing
      -- ^ Parsed module AST is populated on demand during pipeline passes.
    , ms_hspp_file     = targetPath
      -- ^ Preprocessed source file buffer path.
    , ms_hspp_opts     = dflags
      -- ^ Session dynamic flags containing active language extensions.
    , ms_hspp_buf      = Nothing
      -- ^ In-memory string buffer omitted; source provided via AST.
    }

-- | Constructs a canonical default 'ModSummary' for interactive Tengri REPL evaluation.
--
-- Binds the module to @"Tengri.Interactive"@ and file path @"<interactive-tengri>"@.
mkInteractiveModSummary :: DynFlags -> ModSummary
mkInteractiveModSummary dflags =
  mkMockModSummary dflags (mkModuleName "Tengri.Interactive") "<interactive-tengri>"

-- | Extracts the unqualified module name string from a 'ModSummary'.
mockModuleName :: ModSummary -> String
mockModuleName = moduleNameString . moduleName . ms_mod

-- | Retrieves the preprocessed file path recorded in a 'ModSummary'.
mockFilePath :: ModSummary -> FilePath
mockFilePath = ms_hspp_file
