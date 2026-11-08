{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Test.Hspec

import Gargamelle.Core.Institution.Liquid (LiquidSig(..))
import Gargamelle.Equational.AbductiveEGraph (DPORule(..))
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

  describe "Tengri.Darkhan.Articulate" $ do
    it "articulates NonEmpty.nonEmpty against IO [[Text]] selecting Wither.mapMaybe over Wither.wither with cost 2" $ do
      case articulateBridge "NonEmpty.nonEmpty" [("meas_effect", 0), ("meas_maybe", 1)] "IO [[Text]]" of
        Left err -> expectationFailure (T.unpack err)
        Right bridge -> do
          bridgeRuleName bridge `shouldBe` "darkhan_fmap_mapMaybe"
          bridgeTargetName bridge `shouldBe` "Wither.mapMaybe"
          bridgeCost bridge `shouldBe` 2

    it "articulates effectful transform selecting Wither.wither with cost 4" $ do
      case articulateBridge "action" [("meas_effect", 1), ("meas_maybe", 1)] "IO [[Text]]" of
        Left err -> expectationFailure (T.unpack err)
        Right bridge -> do
          bridgeRuleName bridge `shouldBe` "darkhan_bind_wither"
          bridgeTargetName bridge `shouldBe` "Wither.wither"
          bridgeCost bridge `shouldBe` 4

    it "articulates structural row projection selecting Polytropos.rcast with cost 1" $ do
      case articulateBridge "rec" [("meas_row", 1)] "TargetRecord" of
        Left err -> expectationFailure (T.unpack err)
        Right bridge -> do
          bridgeRuleName bridge `shouldBe` "darkhan_polytropos_rcast"
          bridgeTargetName bridge `shouldBe` "Polytropos.rcast"
          bridgeCost bridge `shouldBe` 1

    it "buildDarkhanSig exports expected measures" $ do
      let sig = buildDarkhanSig
      Map.member "meas_effect" (sigMeasures sig) `shouldBe` True
      Map.member "meas_maybe" (sigMeasures sig) `shouldBe` True
      Map.member "meas_depth" (sigMeasures sig) `shouldBe` True
      Map.member "meas_arity" (sigMeasures sig) `shouldBe` True
      Map.member "meas_row"   (sigMeasures sig) `shouldBe` True

    it "darkhanDPORules contains all 5 canonical rules" $ do
      let names = map dpoName darkhanDPORules
      names `shouldBe`
        [ "darkhan_fmap_mapMaybe"
        , "darkhan_bind_wither"
        , "darkhan_gongju_fmapN"
        , "darkhan_gongju_spineFor"
        , "darkhan_polytropos_rcast"
        ]
