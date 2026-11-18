-- | Module: Main
-- Description: Unit test suite for tengri-ulgen
module Main (main) where

import qualified Data.Text as T
import Test.Hspec

import Tengri.Ulgen

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Tengri.Ulgen (Core Entity)" $ do
    it "constructs default entity with expected values" $ do
      entityName defaultEntity `shouldBe` "tengri"
      entityModule defaultEntity `shouldBe` "Tengri.Ulgen"

    it "renders entity accurately" $ do
      renderEntity defaultEntity `shouldBe` "tengri:Tengri.Ulgen"

  describe "Tengri.Ulgen.MockSummary" $ do
    it "constructs mock ModSummary with given module name and path" $ do
      let snippet = wrapExpressionSnippet "42"
      T.isInfixOf "module Tengri.Interactive where" snippet `shouldBe` True
      T.isInfixOf "it = 42" snippet `shouldBe` True

  describe "Tengri.Ulgen.Monad" $ do
    it "provides valid default configuration" $ do
      ulgenImports defaultUlgenConfig `shouldBe` ["Prelude"]
      case ulgenLibDir defaultUlgenConfig of
        Just p  -> p `shouldSatisfy` (\path -> not (null path))
        Nothing -> expectationFailure "Expected Just libdir"

  describe "Tengri.Ulgen.Plugin" $ do
    it "wraps expression snippets into well-formed module text" $ do
      let wrapped = wrapExpressionSnippet "REC { a = 1, b = 2 }"
      T.lines wrapped `shouldBe`
        [ "module Tengri.Interactive where"
        , "it = REC { a = 1, b = 2 }"
        ]
