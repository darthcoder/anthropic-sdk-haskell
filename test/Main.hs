module Main where

import Test.Hspec
import qualified Test.Types as Types

main :: IO ()
main = hspec Types.spec
