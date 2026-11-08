{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Module: Tengri.Lus
-- Description: Type-directed stream channel and pipe I/O engine
--
-- 'Tengri.Lus' provides type-directed standard input ingestion ('LusInput')
-- and standard output emission ('LusOutput') for composable Unix command-line
-- filters, shell pipelines, and stream aggregation.
--
-- = Architectural Context
--
-- Per Note [Core Architecture] [ref:note-core-architecture], 'Tengri.Lus'
-- serves as the stream automation layer of the Tengri ecosystem, allowing
-- Haskell functions over standard structures (such as 'Text', 'NonEmpty', 'NESet',
-- and 'Map') to be directly executed as Unix pipe filters via 'runLus' and 'runLusM'.
--
-- == Invariants & Guarantees
--
-- 1. __Type-Directed Marshalling:__ Input consumption and output formatting are
--    entirely determined by type inference; no manual deserialization boilerplate is required.
-- 2. __Total Operations:__ Default line and word splitters avoid partiality.
-- 3. __Streaming Composition:__ 'runLusWith' and 'runLusMWith' permit pure testing
--    and decoupled execution over in-memory conduits without touching standard handles.
-- 4. __Tabular Projection:__ 'Map' outputs adhere to standard Unix tab-delimited formatting,
--    enabling seamless composition with @awk@, @sort@, and @cut@.
--
-- = Unix Shell Integration Patterns
--
-- Tengri pipelines are intended to replace complex Bash string manipulations with
-- statically-typed, memory-safe Haskell expressions:
--
-- == 1. Line-by-Line Transformation
--
-- @
-- -- Uppercase input lines:
-- main = runLus (map T.toUpper)
-- @
--
-- == 2. Frequency Aggregation
--
-- @
-- -- Word count frequency table:
-- main = runLus (Map.fromListWith (+) . map (\\w -> (w, 1 :: Int)) . concat)
-- @
--
-- == 3. Deduplication and Sorting
--
-- @
-- -- Unique sorted tokens:
-- main = runLus (NESet.fromList)
-- @
--
-- = Worked Example
--
-- >>> -- In an executable:
-- >>> -- main = runLus (map T.toUpper)
-- >>> -- Reads lines from stdin as [Text], maps to upper-case, writes lines to stdout.
module Tengri.Lus
  ( -- * Typeclasses
    LusInput(..)
  , LusOutput(..)

    -- * Pipeline Runners
  , runLus
  , runLusM
  , runLusWith
  , runLusMWith

    -- * Core Domain Entity Surface
  , Entity(..)
  , defaultEntity
  , renderEntity
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Set.NonEmpty (NESet)
import qualified Data.Set.NonEmpty as NESet
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Typeable (Typeable, cast)

-- | Represents a core domain entity within the 'tengri-lus' package.
--
-- Tracks the enclosing workspace name and the canonical module identifier.
data Entity = Entity
  { entityName   :: !Text
    -- ^ Name of the parent project workspace.
  , entityModule :: !Text
    -- ^ Canonical module identifier defining the entity.
  } deriving stock (Eq, Show)

-- | Canonical default entity for 'Tengri.Lus'.
--
-- Returns an 'Entity' bound to the workspace name and current module name.
defaultEntity :: Entity
defaultEntity = Entity
  { entityName   = "tengri"
  , entityModule = "Tengri.Lus"
  }

-- | Formats an 'Entity' into a human-readable display string.
--
-- Computes a combined representation: @"<entityName>:<entityModule>"@.
renderEntity :: Entity -> Text
renderEntity e = entityName e <> ":" <> entityModule e

-- | Typeclass for data types that can be automatically ingested from standard input.
--
-- Instances dictate how standard input bytes/characters are parsed into structured types:
-- * 'Text': Ingests entire input as a single monolithic block.
-- * '[Text]': Ingests lines from standard input.
-- * '[[Text]]': Ingests lines and splits each into space-separated word tokens.
-- * '[NonEmpty Text]': Ingests non-empty lines with non-empty word tokens.
class LusInput a where
  -- | Reads and parses the entire standard input stream into value @a@.
  readLusStdin :: IO a

instance LusInput Text where
  readLusStdin = TIO.getContents

instance LusInput [Text] where
  readLusStdin = T.lines <$> TIO.getContents

instance LusInput [[Text]] where
  readLusStdin = map T.words . T.lines <$> TIO.getContents

instance LusInput [NonEmpty Text] where
  readLusStdin = mapMaybe (NonEmpty.nonEmpty . T.words) . T.lines <$> TIO.getContents

-- | Typeclass for data types that can be automatically emitted to standard output.
--
-- Instances dictate formatting conventions for Unix pipeline consumption:
-- * '()': No-op emission.
-- * 'Text': Emits single line or block to standard output.
-- * '[Text]': Emits each element as a distinct newline-terminated line.
-- * '[NonEmpty Text]': Emits each word sequence as a space-separated line.
-- * 'NESet Text': Emits set elements sorted, one per line.
-- * 'Map k v': Emits key-value pairs formatted as tab-separated rows.
class LusOutput b where
  -- | Formats and writes value @b@ to standard output.
  writeLusStdout :: b -> IO ()

instance LusOutput () where
  writeLusStdout () = pure ()

instance LusOutput Text where
  writeLusStdout t =
    if T.null t
      then pure ()
      else TIO.putStrLn t

instance LusOutput [Text] where
  writeLusStdout = mapM_ TIO.putStrLn

instance LusOutput [NonEmpty Text] where
  writeLusStdout = mapM_ (TIO.putStrLn . T.unwords . NonEmpty.toList)

instance LusOutput (NESet Text) where
  writeLusStdout = mapM_ TIO.putStrLn . NESet.toList

instance (Ord k, Show k, Typeable k, Show v, Typeable v) => LusOutput (Map k v) where
  writeLusStdout m =
    (compare :: k -> k -> Ordering) `seq`
      mapM_ (\(k, v) -> TIO.putStrLn (renderField k <> "\t" <> renderField v)) (Map.toList m)
    where
      renderField :: (Show a, Typeable a) => a -> Text
      renderField x = case cast x of
        Just (t :: Text)   -> t
        Nothing            -> case cast x of
          Just (s :: String) -> T.pack s
          Nothing            -> T.pack (show x)

-- | Executes a pure stream transformation pipeline from standard input to standard output.
--
-- Infers the input format from argument type @a@, transforms the value using function @f@,
-- and formats the resulting @b@ to standard output.
--
-- === Example
--
-- @
-- -- Capitalize all input lines:
-- main = runLus (map T.toUpper)
-- @
runLus :: (LusInput a, LusOutput b) => (a -> b) -> IO ()
runLus = runLusWith readLusStdin writeLusStdout

-- | Executes an effectful stream transformation pipeline from standard input to standard output.
--
-- Infers input parsing from type @a@, evaluates monadic action @f@, and emits the resulting @b@.
--
-- === Example
--
-- @
-- main = runLusM (\\lines -> do
--   logDebug "Processing lines..."
--   pure (filter (not . T.null) lines))
-- @
runLusM :: (LusInput a, LusOutput b) => (a -> IO b) -> IO ()
runLusM = runLusMWith readLusStdin writeLusStdout

-- | Executes a pure pipeline using explicitly supplied input ingestion and output emission actions.
--
-- Allows pipeline execution in unit tests or alternate environments without binding standard handles.
runLusWith :: IO a -> (b -> IO ()) -> (a -> b) -> IO ()
runLusWith readIn writeOut f = readIn >>= writeOut . f

-- | Executes an effectful pipeline using explicitly supplied input ingestion and output emission actions.
--
-- Allows effectful pipeline execution in unit tests or alternate environments without binding standard handles.
runLusMWith :: IO a -> (b -> IO ()) -> (a -> IO b) -> IO ()
runLusMWith readIn writeOut f = readIn >>= f >>= writeOut
