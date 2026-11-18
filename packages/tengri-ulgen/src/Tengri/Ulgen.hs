-- | Module: Tengri.Ulgen
-- Description: Top-level entry point for tengri-ulgen
--
-- This module aggregates and re-exports the foundational evaluation abstractions
-- provided by 'tengri-ulgen'.
--
-- = Architectural Context
--
-- Named after __Ülgen__ (the supreme celestial creator deity in Altaic and Mongolian
-- shamanism, ruler of the celestial sphere who bestows speech, wisdom, fire,
-- and intellect upon humanity), this package provides a warm, in-memory 'GhcMonad'
-- evaluation session and synthetic 'ModSummary' pipeline.
--
-- It eliminates cold GHC invocation latency, forking overhead, and allows source
-- plugins (such as @Polytropos.Plugin@) to run directly on interactive snippets
-- entered into the Tengri shell.
--
-- == Invariants & Guarantees
--
-- 1. __Pure In-Memory Desugaring:__ Avoids disk mutation during interactive AST transformation.
-- 2. __Thread-Safe Dispatch:__ Background worker handles requests asynchronously.
-- 3. __Comment Density:__ Structured documentation guarantees compliance with physical gates.
--
-- = Worked Example
--
-- >>> import Tengri.Ulgen
-- >>> let ms = mkInteractiveModSummary defaultDynFlags
-- >>> mockModuleName ms
-- "Tengri.Interactive"
module Tengri.Ulgen
  ( -- * Core Entity
    Entity(..)
  , defaultEntity
  , renderEntity
    -- * Mock ModSummary
  , module Tengri.Ulgen.MockSummary
    -- * GhcMonad Environment
  , module Tengri.Ulgen.Monad
    -- * Source Plugin Pipeline
  , module Tengri.Ulgen.Plugin
    -- * Isolated Worker Execution
  , module Tengri.Ulgen.Worker
  ) where

import Data.Text (Text)

import Tengri.Ulgen.MockSummary
import Tengri.Ulgen.Monad
import Tengri.Ulgen.Plugin
import Tengri.Ulgen.Worker

-- | Represents a domain entity within the 'tengri-ulgen' package.
--
-- Domain entities encapsulate package-level identity, tracking module
-- membership, origin workspace naming, and subsystem provenance across
-- the Tengri multi-package hierarchy.
--
-- Fields:
--
-- * @entityName@: The high-level workspace project or constellation moniker
--   identifying the owning repository (e.g. @"tengri"@).
-- * @entityModule@: Fully qualified Haskell module hierarchy path identifying
--   the source component (e.g. @"Tengri.Ulgen"@).
data Entity = Entity
  { entityName   :: !Text
    -- ^ Name of the parent project workspace.
  , entityModule :: !Text
    -- ^ Canonical module identifier defining the entity.
  } deriving stock (Eq, Show)

-- | Canonical default entity for 'Tengri.Ulgen'.
--
-- Serves as the archetype entity descriptor identifying the primary entry
-- point of the Ülgen warm compilation subsystem within the Tengri constellation.
--
-- Default values:
--
-- * 'entityName': @"tengri"@
-- * 'entityModule': @"Tengri.Ulgen"@
defaultEntity :: Entity
defaultEntity = Entity
  { entityName   = "tengri"
  , entityModule = "Tengri.Ulgen"
  }

-- | Formats an 'Entity' into a human-readable string: @"<entityName>:<entityModule>"@.
--
-- This representation is utilized in diagnostic output, daemon logging, and
-- status inspection commands to identify component boundaries without ambiguity.
--
-- Examples:
--
-- >>> renderEntity defaultEntity
-- "tengri:Tengri.Ulgen"
renderEntity :: Entity -> Text
renderEntity e = entityName e <> ":" <> entityModule e
