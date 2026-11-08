{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import Data.Functor.Identity (Identity)
import Data.Proxy (Proxy (..))
import qualified Data.Text as T
import GHC.Exts (Any)
import Polytropos
import Polytropos.Core (ConstructorIndex (..), fieldAt, noInlineUnsafeCo, unRowRep)
import Test.Hspec

import Tengri.Sulde

-- | Helper to coerce an untyped slot to its expected payload type.
unslot :: Identity Any -> a
unslot = noInlineUnsafeCo

-- | A sum row representing animals for Polytropos peeling tests.
type AnimalSum = '[ "Cat" ':= '[ "meow" ':= String ], "Dog" ':= '[ "bark" ':= String ] ]

instance ConstructorIndex "Cat" AnimalSum where
  constructorIndex = 0

instance ConstructorIndex "Dog" AnimalSum where
  constructorIndex = 1

instance KnownHash "Cat" where
  knownHash = fnv1a64 "Cat"

instance KnownHash "Dog" where
  knownHash = fnv1a64 "Dog"

main :: IO ()
main = hspec $ parallel $ do
  describe "Tengri.Sulde (Core Entity)" $ do
    it "constructs default entity with expected values" $ do
      let e = defaultEntity
      entityName e `shouldBe` "tengri"
      entityModule e `shouldBe` "Tengri.Sulde"
    it "renders entity accurately" $ do
      let e = defaultEntity
      renderEntity e `shouldBe` "tengri:Tengri.Sulde"

  describe "Tengri.Sulde.GitUrl" $ do
    describe "stripBrowserSuffix" $ do
      it "strips GitHub tree and blob paths" $ do
        stripBrowserSuffix "https://github.com/owner/repo/tree/master/packages/foo"
          `shouldBe` "https://github.com/owner/repo"
        stripBrowserSuffix "https://github.com/owner/repo/blob/main/README.md"
          `shouldBe` "https://github.com/owner/repo"
      it "strips GitLab /-/tree/ paths" $ do
        stripBrowserSuffix "https://gitlab.com/group/repo/-/tree/v1.0/src"
          `shouldBe` "https://gitlab.com/group/repo"
      it "strips pull requests and query parameters" $ do
        stripBrowserSuffix "https://github.com/owner/repo/pull/12?tab=commits#diff-1"
          `shouldBe` "https://github.com/owner/repo"
      it "preserves clean cloneable URLs unchanged" $ do
        stripBrowserSuffix "https://github.com/owner/repo.git"
          `shouldBe` "https://github.com/owner/repo.git"
        stripBrowserSuffix "git@github.com:owner/repo.git"
          `shouldBe` "git@github.com:owner/repo.git"

    describe "repoDirName" $ do
      it "extracts directory name from HTTPS and SSH URLs" $ do
        repoDirName "https://github.com/NadiaYvette/tengri.git" `shouldBe` "tengri"
        repoDirName "git@github.com:NadiaYvette/tengri.git" `shouldBe` "tengri"
        repoDirName "git@git.disroot.org:NadiaYvette/tengri" `shouldBe` "tengri"
      it "extracts directory name from browser URLs" $ do
        repoDirName "https://github.com/owner/my-cool-tool/tree/master/docs" `shouldBe` "my-cool-tool"
      it "handles bare repo names" $ do
        repoDirName "standalone" `shouldBe` "standalone"

    describe "toSshUrl" $ do
      it "converts HTTPS URLs to canonical SSH URLs" $ do
        toSshUrl "https://github.com/NadiaYvette/tengri"
          `shouldBe` "git@github.com:NadiaYvette/tengri.git"
        toSshUrl "https://github.com/NadiaYvette/tengri/tree/main/src"
          `shouldBe` "git@github.com:NadiaYvette/tengri.git"
      it "converts ssh:// prefixed URLs to SCP-style SSH URLs" $ do
        toSshUrl "ssh://git@github.com/foo/bar.git"
          `shouldBe` "git@github.com:foo/bar.git"
      it "ensures .git suffix on existing SCP-style URLs" $ do
        toSshUrl "git@github.com:foo/bar"
          `shouldBe` "git@github.com:foo/bar.git"
        toSshUrl "git@github.com:foo/bar.git"
          `shouldBe` "git@github.com:foo/bar.git"

    describe "applyGitInsteadOfRules" $ do
      it "rewrites prefixes according to rule set" $ do
        let rules = [("git@github.com:", "https://github.com/")]
        applyGitInsteadOfRules rules "https://github.com/owner/repo"
          `shouldBe` "git@github.com:owner/repo"
      it "picks the longest matching prefix when multiple match" $ do
        let rules =
              [ ("git@gh-corp:corp/", "https://github.com/corp/")
              , ("git@gh:", "https://github.com/")
              ]
        applyGitInsteadOfRules rules "https://github.com/corp/project"
          `shouldBe` "git@gh-corp:corp/project"
        applyGitInsteadOfRules rules "https://github.com/other/project"
          `shouldBe` "git@gh:other/project"
      it "strips browser suffixes before applying rules" $ do
        let rules = [("git@github.com:", "https://github.com/")]
        applyGitInsteadOfRules rules "https://github.com/owner/repo/tree/master"
          `shouldBe` "git@github.com:owner/repo"

    describe "parseGitConfigContent" $ do
      it "parses INI section insteadOf blocks" $ do
        let content = T.unlines
              [ "[url \"git@github.com:\"]"
              , "    insteadOf = \"https://github.com/\""
              , "[user]"
              , "    name = Alice"
              ]
        parseGitConfigContent content `shouldBe` [("git@github.com:", "https://github.com/")]
      it "parses flat git config format" $ do
        let content = "url.https://github.com/.insteadof git@github.com:"
        parseGitConfigContent content `shouldBe` [("https://github.com/", "git@github.com:")]

    describe "applyGitInsteadOf (IO)" $ do
      it "executes safely and returns non-empty rewritten URL" $ do
        result <- applyGitInsteadOf "https://github.com/NadiaYvette/tengri/tree/main"
        T.null result `shouldBe` False

  describe "Polytropos Variant Peeling & WitherPeel" $ do
    let catPayload = insertField (Field @"meow") ("nya" :: String) emptyRecord
        dogPayload = insertField (Field @"bark") ("woof" :: String) emptyRecord
        catVar = injectVariant (Field @"Cat") catPayload :: Variant AnimalSum
        dogVar = injectVariant (Field @"Dog") dogPayload :: Variant AnimalSum

    it "peelJust isolates the target constructor" $ do
      case peelJust (Proxy @"Cat") catVar of
        Just p  -> unslot (fieldAt 0 (unRowRep p)) `shouldBe` ("nya" :: String)
        Nothing -> expectationFailure "Expected Just on matching constructor"

    it "peelJust returns Nothing on non-matching constructor" $ do
      case peelJust (Proxy @"Cat") dogVar of
        Nothing -> pure ()
        Just _  -> expectationFailure "Expected Nothing on non-matching constructor"
      case peelJust (Proxy @"Dog") dogVar of
        Just p  -> unslot (fieldAt 0 (unRowRep p)) `shouldBe` ("woof" :: String)
        Nothing -> expectationFailure "Expected Just on matching constructor"

    it "witherPeel filters containers to the requested variant branch" $ do
      let variants = [catVar, dogVar, catVar, dogVar]
          cats = witherPeel (Proxy @"Cat") variants
      length cats `shouldBe` 2
      map (unslot . fieldAt 0 . unRowRep) cats `shouldBe` ["nya" :: String, "nya"]

    it "witherPeelM effectfully traverses and filters payloads" $ do
      let variants = [catVar, dogVar, catVar]
      res <- witherPeelM (Proxy @"Cat") (\p -> pure (Just (unslot (fieldAt 0 (unRowRep p)) ++ "!"))) variants
      res `shouldBe` ["nya!", "nya!"]
