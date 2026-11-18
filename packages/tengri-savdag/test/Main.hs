{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Hspec
import Tengri.Savdag
import qualified Data.Text as T

main :: IO ()
main = hspec $ parallel $ do
  describe "Tengri.Savdag" $ do
    it "constructs default entity with correct properties" $ do
      let e = defaultEntity
      entityName e `shouldBe` "tengri"
      entityModule e `shouldBe` "Tengri.Savdag"
    it "renders entity accurately" $ do
      let e = defaultEntity
      renderEntity e `shouldBe` "tengri:Tengri.Savdag"

  describe "Tengri.Savdag.Server" $ do
    it "determines defaultSocketPath ending in tengri.sock" $ do
      sockPath <- defaultSocketPath
      sockPath `shouldSatisfy` (\p -> "tengri.sock" `T.isSuffixOf` T.pack p)

    it "roundtrips EvalPipe request serialization" $ do
      let req = EvalPipe "1 + 1"
      parseRequest (renderRequest req) `shouldBe` Right req

    it "roundtrips ReflectType request serialization" $ do
      let req = ReflectType "putStrLn"
      parseRequest (renderRequest req) `shouldBe` Right req

    it "roundtrips ArticulateHole request serialization" $ do
      let req = ArticulateHole "_$"
      parseRequest (renderRequest req) `shouldBe` Right req

    it "roundtrips Response serialization" $ do
      let res1 = EvalResult "2"
      let res2 = ReflectResult "IO ()"
      let res3 = ArticulateResult "mapMaybe"
      let res4 = ErrorResult "Parse failure"
      parseResponse (renderResponse res1) `shouldBe` Right res1
      parseResponse (renderResponse res2) `shouldBe` Right res2
      parseResponse (renderResponse res3) `shouldBe` Right res3
      parseResponse (renderResponse res4) `shouldBe` Right res4

    it "dispatches EvalPipe request" $ do
      res <- handleRequest (EvalPipe "filter isJust")
      res `shouldBe` EvalResult "evaluated: filter isJust"

    it "dispatches ReflectType request" $ do
      res <- handleRequest (ReflectType "fmap")
      res `shouldBe` ReflectResult "forall a. a -> fmap"

    it "dispatches ArticulateHole request" $ do
      res <- handleRequest (ArticulateHole "_$")
      res `shouldBe` ArticulateResult "Wither.mapMaybe (_$)"

  describe "Tengri.Savdag.MockSummary" $ do
    it "constructs mock ModSummary snippet with expected module name" $ do
      let snippet = wrapExpressionSnippet "42"
      T.isInfixOf "module Tengri.Interactive where" snippet `shouldBe` True
      T.isInfixOf "it = 42" snippet `shouldBe` True

  describe "Tengri.Savdag.Monad" $ do
    it "provides valid default configuration" $ do
      savdagImports defaultSavdagConfig `shouldBe` ["Prelude"]
      case savdagLibDir defaultSavdagConfig of
        Just p  -> p `shouldSatisfy` (\path -> not (null path))
        Nothing -> expectationFailure "Expected Just libdir"

  describe "Tengri.Savdag.Plugin" $ do
    it "wraps expression snippets into well-formed module text" $ do
      let wrapped = wrapExpressionSnippet "REC { a = 1, b = 2 }"
      T.lines wrapped `shouldBe`
        [ "module Tengri.Interactive where"
        , "it = REC { a = 1, b = 2 }"
        ]
