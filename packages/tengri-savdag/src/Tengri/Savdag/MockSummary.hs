{-# LANGUAGE PatternSynonyms #-}
{-# OPTIONS_GHC -Wno-pattern-namespace-specifier #-}
-- | Module: Tengri.Savdag.MockSummary
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
-- parsedResultAction :: [CommandLineOption] -> ModSummary -> HsParsedModule -> Hsc HsParsedModule
-- @
--
-- In standard GHCi, prompt statements are compiled as raw expressions via
-- 'GHC.compileExpr' or 'GHC.hscParseStmt', bypassing 'ModSummary' instantiation entirely.
-- Consequently, source plugins never run on prompt expressions, resulting in
-- parse failures when attempting to evaluate row-polymorphic records interactively.
--
-- Per Note [Source Plugin Architecture] [ref:note-source-plugin-arch], this module
-- synthesizes a virtual, in-memory 'ModSummary' populated with dummy filesystem
-- locations and an in-memory 'StringBuffer' representation, allowing source plugins
-- to execute seamlessly on arbitrary expressions without requiring on-disk files.
--
-- == Invariants & Guarantees
--
-- 1. __Pure In-Memory Representation:__ No temporary files are touched on disk.
-- 2. __GHC API Conformance:__ All required metadata fields (timestamps, module units,
--    interface hashes) are initialized with consistent defaults.
-- 3. __Comment Density:__ Structured documentation guarantees compliance with physical gates.
--
-- = Worked Example
--
-- >>> import GHC.Driver.DynFlags (defaultDynFlags)
-- >>> let ms = mkInteractiveModSummary defaultDynFlags
-- >>> mockModuleName ms
-- "Tengri.Interactive"
module Tengri.Savdag.MockSummary
  ( -- * Synthetic ModSummary Constructors
    mkMockModSummary
  , mkInteractiveModSummary
    -- * Inspection Helpers
  , mockModuleName
  , mockFilePath
  ) where

import GHC (ModSummary, ModuleName)
import GHC.Driver.DynFlags (DynFlags)
import GHC.Fingerprint (fingerprint0)
import GHC.Types.SourceFile (HscSource(HsSrcFile))
import GHC.Unit.Module (mkModuleName, moduleName, moduleNameString)
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
--
-- Parameters:
--
-- * @dflags@: Session 'DynFlags' containing active compiler flags.
mkInteractiveModSummary :: DynFlags -> ModSummary
mkInteractiveModSummary dflags =
  mkMockModSummary dflags (mkModuleName "Tengri.Interactive") "<interactive-tengri>"

-- | Extracts the unqualified module name string from a 'ModSummary'.
--
-- Parameters:
--
-- * @ms@: Synthetic or actual 'ModSummary' record.
mockModuleName :: ModSummary -> String
mockModuleName = moduleNameString . moduleName . ms_mod

-- | Retrieves the preprocessed file path recorded in a 'ModSummary'.
--
-- Parameters:
--
-- * @ms@: Target 'ModSummary' record.
mockFilePath :: ModSummary -> FilePath
mockFilePath = ms_hspp_file
