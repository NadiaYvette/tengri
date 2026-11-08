-- | Module: Main
-- Description: Executable entrypoint for the unified tengri CLI
module Main (main) where

import qualified System.Environment as Env
import qualified Data.Text as T
import Tengri.CLI (parseArgs, runCommand)

-- | Dispatches user CLI arguments to the unified Tengri engine.
main :: IO ()
main = do
  args <- Env.getArgs
  runCommand $ parseArgs (map T.pack args)
