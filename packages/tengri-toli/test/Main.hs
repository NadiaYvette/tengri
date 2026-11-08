{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Hspec
import Tengri.Toli
import qualified Data.Text as T

main :: IO ()
main = hspec $ parallel $ do
  describe "Tengri.Toli" $ do
    it "constructs default entity with correct properties" $ do
      let e = defaultEntity
      entityName e `shouldBe` "tengri"
      entityModule e `shouldBe` "Tengri.Toli"
    it "renders entity accurately" $ do
      let e = defaultEntity
      renderEntity e `shouldBe` "tengri:Tengri.Toli"

  describe "Tengri.Toli.Shell" $ do
    it "parses supported shell target strings" $ do
      parseShellTarget "zsh"     `shouldBe` Right Zsh
      parseShellTarget "bash"    `shouldBe` Right Bash
      parseShellTarget "fish"    `shouldBe` Right Fish
      parseShellTarget "nu"      `shouldBe` Right Nushell
      parseShellTarget "nushell" `shouldBe` Right Nushell

    it "emits valid Zsh init script containing zle widgets" $ do
      let zshOut = emitShellInit Zsh
      zshOut `shouldSatisfy` (\s -> "_tengri_reflect" `T.isInfixOf` s)
      zshOut `shouldSatisfy` (\s -> "bindkey '^X^T'" `T.isInfixOf` s)
      zshOut `shouldSatisfy` (\s -> "tengri toli reflect" `T.isInfixOf` s)

    it "emits valid Bash init script containing readline bind" $ do
      let bashOut = emitShellInit Bash
      bashOut `shouldSatisfy` (\s -> "\\C-x\\C-t" `T.isInfixOf` s)
      bashOut `shouldSatisfy` (\s -> "READLINE_LINE" `T.isInfixOf` s)

    it "emits valid Fish init script containing fish bindings" $ do
      let fishOut = emitShellInit Fish
      fishOut `shouldSatisfy` (\s -> "function _tengri_reflect" `T.isInfixOf` s)
      fishOut `shouldSatisfy` (\s -> "bind \\cxt" `T.isInfixOf` s)

    it "emits valid Nushell init script containing config keybinding" $ do
      let nuOut = emitShellInit Nushell
      nuOut `shouldSatisfy` (\s -> "name: tengri_reflect" `T.isInfixOf` s)
      nuOut `shouldSatisfy` (\s -> "executehostcommand" `T.isInfixOf` s)
