{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Hspec
import Tengri.Darkhan

main :: IO ()
main = hspec $ parallel $ do
  describe "Tengri.Darkhan" $ do
    it "constructs default entity with correct properties" $ do
      let e = defaultEntity
      entityName e `shouldBe` "tengri"
      entityModule e `shouldBe` "Tengri.Darkhan"
    it "renders entity accurately" $ do
      let e = defaultEntity
      renderEntity e `shouldBe` "tengri:Tengri.Darkhan"
