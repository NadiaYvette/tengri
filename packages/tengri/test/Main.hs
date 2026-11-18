{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Hspec
import qualified SmirkSpec
import Tengri

main :: IO ()
main = hspec $ parallel $ do
  SmirkSpec.spec
  describe "Tengri" $ do
    it "constructs default entity with correct properties" $ do
      let e = defaultEntity
      entityName e `shouldBe` "tengri"
      entityModule e `shouldBe` "Tengri"
    it "renders entity accurately" $ do
      let e = defaultEntity
      renderEntity e `shouldBe` "tengri:Tengri"

  describe "Tengri.CLI" $ do
    it "parses expression evaluation command" $ do
      parseArgs ["map (+1) [1..5]"] `shouldBe` CmdEval "map (+1) [1..5]"

    it "parses expression evaluation command with eval keyword" $ do
      parseArgs ["eval", "map", "(+1)", "[1..5]"] `shouldBe` CmdEval "map (+1) [1..5]"

    it "parses bare multi-word expression evaluation command" $ do
      parseArgs ["1", "+", "1"] `shouldBe` CmdEval "1 + 1"

    it "parses repl command" $ do
      parseArgs ["repl"] `shouldBe` CmdRepl

    it "parses giturl command without debug" $ do
      parseArgs ["giturl", "https://github.com/foo/bar.git"]
        `shouldBe` CmdGitUrl False "https://github.com/foo/bar.git"

    it "parses giturl command with debug flag" $ do
      parseArgs ["giturl", "-d", "https://github.com/foo/bar.git"]
        `shouldBe` CmdGitUrl True "https://github.com/foo/bar.git"

    it "normalizes giturl stripping .git suffix" $ do
      normalizeGitUrl False "https://github.com/foo/bar.git"
        `shouldBe` "https://github.com/foo/bar"

    it "normalizes giturl with debug prefix" $ do
      normalizeGitUrl True "https://github.com/foo/bar.git"
        `shouldBe` "[debug:giturl] https://github.com/foo/bar"

    it "parses toli reflect command" $ do
      parseArgs ["toli", "reflect", "putStrLn"]
        `shouldBe` CmdToliReflect "putStrLn"

    it "parses toli articulate command" $ do
      parseArgs ["toli", "articulate", "_$"]
        `shouldBe` CmdToliArticulate "_$"

    it "parses toli init command" $ do
      parseArgs ["toli", "init", "zsh"]
        `shouldBe` CmdToliInit "zsh"
