module Main (main) where
import "polytropos-core" Polytropos
import "polytropos-core" Polytropos.Core
import "polytropos-lens" Polytropos.Lens
import "polytropos-optics" Polytropos.Optics
import "penelope-core" Penelope.Core
import "penelope-effects" Penelope.Effects
import "gongju" Gongju
import "smirk" Smirk
import "smirk" Smirk.Glob
import "smirk-penelope" Smirk.Effect.Penelope

import "pointed" Data.Pointed
import "base" System.Environment

-- main :: IO ()
-- main = runInterpretAll mainAction
-- let { action :: Eff '[] '["io" ':= UnaryEffect IO] () = send @"io" $ putStrLn "Hello world!" ; handler :: EffHandler IO IO = mkEffHandler id } in runEffM (insertField (Field @"io") (mkEffHandler id) emptyRecord) action

main :: IO ()
-- main = putStrLn "Hello world!"
main = runEffM REC { io = mkEffHandler id } action where
  action :: Eff '[] '["io" ':= UnaryEffect IO] ()
  action = send @"io" do
    args <- getArgs
    putStrLn "Hello world!"
