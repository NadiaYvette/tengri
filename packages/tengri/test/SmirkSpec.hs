{-# LANGUAGE OverloadedStrings #-}

-- | Module: SmirkSpec
-- Description: Test suite for Tengri.Smirk integration bridge
--
-- Verifies:
-- 1. Smirk Zsh glob qualifier evaluation over candidate files.
-- 2. Zsh inside-out parameter expansion within line editor buffers.
-- 3. Penelope polycategorical effect evaluation execution.
module SmirkSpec (spec) where

import Test.Hspec

import Smirk.Glob.Zsh (FileInfo (..), FileType (..))
import Tengri.Smirk
  ( runTengriWithPenelope
  , wireSmirkGlobEngine
  , wireZshExpansionLineEditor
  )

-- | Canonical HSpec test tree for 'Tengri.Smirk'.
spec :: Spec
spec = describe "Tengri.Smirk" $ do
  describe "wireSmirkGlobEngine" $ do
    it "filters files by type qualifier" $ do
      let f1 = ("foo.txt", FileInfo RegularFile 100 1000)
          f2 = ("bar_dir", FileInfo Directory 0 1000)
          f3 = ("baz_lnk", FileInfo Symlink 10 1000)
      wireSmirkGlobEngine "*(.)" [f1, f2, f3] `shouldBe` Right ["foo.txt"]
      wireSmirkGlobEngine "*(/)" [f1, f2, f3] `shouldBe` Right ["bar_dir"]
      wireSmirkGlobEngine "*(@)" [f1, f2, f3] `shouldBe` Right ["baz_lnk"]

    it "filters files by size qualifier" $ do
      let fSmall = ("small.txt", FileInfo RegularFile 50 1000)
          fBig   = ("big.txt", FileInfo RegularFile 200 1000)
      wireSmirkGlobEngine "*(L+100)" [fSmall, fBig] `shouldBe` Right ["big.txt"]

  describe "wireZshExpansionLineEditor" $ do
    it "expands simple scalar variables" $ do
      let env = [("USER", "nadia"), ("HOST", "thinkpad")]
      wireZshExpansionLineEditor env "${USER}" `shouldBe` Right "nadia"
      wireZshExpansionLineEditor env "${HOST}" `shouldBe` Right "thinkpad"

    it "applies prefix stripping" $ do
      let env = [("FILE", "test.tar.gz")]
      wireZshExpansionLineEditor env "${FILE#*.}" `shouldBe` Right "tar.gz"

    it "applies substitution operators" $ do
      let env = [("PATH", "/usr/bin:/bin")]
      wireZshExpansionLineEditor env "${PATH:s/bin/sbin/}" `shouldBe` Right "/usr/sbin:/bin"

  describe "runTengriWithPenelope" $ do
    it "dispatches expressions with penelope framing" $ do
      res <- runTengriWithPenelope "map (+1) [1,2,3]"
      res `shouldBe` "[penelope] map (+1) [1,2,3]"
