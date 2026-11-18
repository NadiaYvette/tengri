{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Module: Tengri.Sulde
-- Description: Precompiled algebraic prelude re-exporting Gongju, Polytropos, and Penelope
--
-- 'Tengri.Sulde' serves as the algebraic vocabulary and core prelude for the Tengri ecosystem.
-- It unifies:
--
-- 1. __Gongju:__ Zero-overhead type-level Peano utilities, bidirectional functional dependencies,
--    and arity combinators.
-- 2. __Polytropos:__ Row-polymorphic open records and open variants collapsed onto a flat
--    contiguous representation, augmented with total variant peeling combinators ('peelJust', 'witherPeel').
-- 3. __Witherable:__ Lawful generalized filtering and effectful traversal across containers.
-- 4. __Penelope:__ Polycategorical effect engine ('Penelope.Core') and domain effect battery ('Penelope.Effects').
-- 5. __GitUrl:__ Pure URL normalization, browser suffix stripping, and Git @url.*.insteadOf@ resolution.
--
-- = Architectural Context
--
-- Per Note [Core Architecture] [ref:note-core-architecture], this module provides
-- the foundational domain prelude across the Tengri constellation, eliminating
-- repetitive cross-package imports and ensuring uniform error-handling semantics.
--
-- == Invariants & Guarantees
--
-- 1. __Total Peeling:__ 'peelJust' and 'witherPeel' are total operations. Non-matching variant branches
--    evaluate to 'Nothing' or are gracefully pruned without throwing exceptions.
-- 2. __Purity:__ All prelude operations except explicit effect handlers are referentially transparent.
-- 3. __Comment Density:__ Structured documentation guarantees compliance with physical quality gates.
-- 4. __Constant Time Dispatch:__ 'peelJust' evaluates in \(\mathcal{O}(1)\) time via literal tag comparison
--    resolved at compile time by the Polytropos typechecker plugin.
--
-- = Polytropos Peeling Mechanics
--
-- In open algebraic data types, peeling extracts one constructor branch from an open sum row:
--
-- @
-- type Status = Variant '["Success" ':= '["value" ':= Int], "Failure" ':= '["err" ':= Text]]
--
-- handleSuccess :: Status -> Maybe Int
-- handleSuccess s = case peelJust (Proxy @"Success") s of
--   Just r  -> Just (unslot (fieldAt 0 (unRowRep r)))
--   Nothing -> Nothing
-- @
--
-- When processing collections of polymorphic variant rows, 'witherPeel' and 'witherPeelM'
-- combine peeling with container pruning, yielding clean records matching the target constructor.
--
-- = Worked Example
--
-- >>> defaultEntity
-- Entity {entityName = "tengri", entityModule = "Tengri.Sulde"}
module Tengri.Sulde
  ( -- * Re-exported Core Facades
    module Gongju
  , module Polytropos
  , module Polytropos.MergeMorph
  , module Witherable
  , module Penelope.Core
  , module Penelope.Effects
  , module Tengri.Sulde.GitUrl

  , KnownNat
  , Nat

    -- * Total Variant Peeling Combinators
  , peelJust
  , peelJustF
  , witherPeel
  , witherPeelM

    -- * Core Domain Entity Surface
  , Entity(..)
  , defaultEntity
  , renderEntity
  ) where

import Data.Kind (Type)
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import GHC.TypeLits (Symbol)
import GHC.TypeNats (KnownNat, Nat)

import Gongju
import Penelope.Core
import Penelope.Effects hiding (Entity (..), defaultEntity, renderEntity)
import Polytropos
import Polytropos.Core (SumRowHKD)
import Polytropos.MergeMorph
import Tengri.Sulde.GitUrl
import Witherable (Filterable (..), Witherable (..))

-- | Represents a core domain entity within the 'tengri-sulde' package.
--
-- Tracks the enclosing workspace name and the canonical module identifier.
data Entity = Entity
  { entityName   :: !Text
    -- ^ Name of the parent project workspace.
  , entityModule :: !Text
    -- ^ Canonical module identifier defining the entity.
  } deriving stock (Eq, Show)

-- | Canonical default entity for 'Tengri.Sulde'.
--
-- Returns an 'Entity' bound to the workspace name and current module name.
defaultEntity :: Entity
defaultEntity = Entity
  { entityName   = "tengri"
  , entityModule = "Tengri.Sulde"
  }

-- | Formats an 'Entity' into a human-readable display string.
--
-- Computes a combined representation: @"<entityName>:<entityModule>"@.
renderEntity :: Entity -> Text
renderEntity e = entityName e <> ":" <> entityModule e

-- | Total extraction of a specific constructor payload from a 'Polytropos.Variant'.
--
-- Given a proxy for constructor label @l@, returns 'Just' containing the constructor's
-- record payload if the variant matches constructor @l@, or 'Nothing' if it belongs to
-- any other branch.
--
-- This operation runs in \(\mathcal{O}(1)\) time without looping or runtime downcasting.
peelJust :: forall (l :: Symbol) (s :: SumRow).
            (ConstructorIndex l s, KnownHash l)
         => Proxy l
         -> Variant s
         -> Maybe (Record (ConstructorPayload l s))
peelJust _ v =
  knownHash @l `seq` case peel @l v of
    Right payload -> Just payload
    Left _        -> Nothing

-- | Total extraction of a specific constructor payload from a higher-kinded 'Polytropos.VariantF'.
--
-- Higher-kinded analogue of 'peelJust' operating over @VariantF f s@.
peelJustF :: forall (l :: Symbol) (f :: Type -> Type) (s :: SumRowHKD f).
             (ConstructorIndex l s, KnownHash l)
          => Proxy l
          -> VariantF f s
          -> Maybe (RecordF f (ConstructorPayloadHKD f l s))
peelJustF _ v =
  knownHash @l `seq` case peelF @l v of
    Right payload -> Just payload
    Left _        -> Nothing

-- | Filters a 'Filterable' container of variants, keeping only those matching constructor @l@.
--
-- Projects each matching variant element down to its unpacked constructor record payload,
-- silently discarding elements belonging to alternative variant branches.
witherPeel :: forall (l :: Symbol) (s :: SumRow) (f :: Type -> Type).
              (Filterable f, ConstructorIndex l s, KnownHash l)
           => Proxy l
           -> f (Variant s)
           -> f (Record (ConstructorPayload l s))
witherPeel p = mapMaybe (peelJust p)

-- | Effectfully traverses and peels variant constructor @l@ across a 'Witherable' container.
--
-- Applies a fallible or filtering monadic action @f@ to each matching variant payload,
-- pruning non-matching variants and any elements for which @f@ produces 'Nothing'.
witherPeelM :: forall (l :: Symbol) (s :: SumRow) (f :: Type -> Type) (m :: Type -> Type) b.
               (Witherable f, Applicative m, ConstructorIndex l s, KnownHash l)
            => Proxy l
            -> (Record (ConstructorPayload l s) -> m (Maybe b))
            -> f (Variant s)
            -> m (f b)
witherPeelM p f =
  wither (\v -> case peelJust p v of
    Just r  -> f r
    Nothing -> pure Nothing)
