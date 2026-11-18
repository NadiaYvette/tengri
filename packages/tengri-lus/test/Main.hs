{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set.NonEmpty as NESet
import Data.Text (Text)
import qualified Data.Text as T
import Test.Hspec

import Tengri.Lus

main :: IO ()
main = hspec $ parallel $ do
  describe "Tengri.Lus (Core Entity)" $ do
    it "constructs default entity with expected values" $ do
      let e = defaultEntity
      entityName e `shouldBe` "tengri"
      entityModule e `shouldBe` "Tengri.Lus"
    it "renders entity accurately" $ do
      let e = defaultEntity
      renderEntity e `shouldBe` "tengri:Tengri.Lus"

  describe "runLus pipeline execution" $ do
    it "executes pure line transformation ([Text] -> [Text])" $ do
      outRef <- newIORef ([] :: [Text])
      let mockIn = pure ["alpha", "beta", "gamma"] :: IO [Text]
          mockOut = mapM_ (\line -> modifyIORef' outRef (++ [line]))
      runLusWith mockIn mockOut (map T.toUpper)
      captured <- readIORef outRef
      captured `shouldBe` ["ALPHA", "BETA", "GAMMA"]

    it "executes word token aggregation ([[Text]] -> Map Text Int)" $ do
      outRef <- newIORef ([] :: [Text])
      let mockIn = pure [["apple", "banana"], ["apple", "cherry"]] :: IO [[Text]]
          mockOut = mapM_ (\(k, v) -> modifyIORef' outRef (++ [k <> ":" <> T.pack (show v)])) . Map.toList
      runLusWith mockIn mockOut (Map.fromListWith (+) . map (, 1 :: Int) . concat)
      captured <- readIORef outRef
      captured `shouldBe` ["apple:2", "banana:1", "cherry:1"]

    it "executes NonEmpty word pipeline ([NonEmpty Text] -> NESet Text)" $ do
      outRef <- newIORef ([] :: [Text])
      let w1 = "dog" :| ["cat"]
          w2 = "bird" :| ["dog"]
          mockIn = pure [w1, w2] :: IO [NonEmpty Text]
          mockOut = mapM_ (\line -> modifyIORef' outRef (++ [line])) . NESet.toList
          pipeline wordLists =
            case wordLists of
              (x : xs) -> NESet.fromList (NonEmpty.head x :| map NonEmpty.head xs)
              []       -> error "empty input"
      runLusWith mockIn mockOut pipeline
      captured <- readIORef outRef
      captured `shouldBe` ["bird", "dog"]

    it "executes effectful pipeline via runLusMWith" $ do
      outRef <- newIORef ([] :: [Text])
      let mockIn = pure ["foo", "bar", "baz"] :: IO [Text]
          mockOut = mapM_ (\line -> modifyIORef' outRef (++ [line]))
          effectfulPipeline linesIn = do
            pure (reverse linesIn)
      runLusMWith mockIn mockOut effectfulPipeline
      captured <- readIORef outRef
      captured `shouldBe` ["baz", "bar", "foo"]

  describe "LusOutput instances" $ do
    it "handles () without error" $ do
      writeLusStdout () `shouldReturn` ()

    it "handles empty Text safely" $ do
      writeLusStdout ("" :: Text) `shouldReturn` ()
