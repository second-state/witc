module Main (main) where

import System.Environment
import Wit.Parser

-- cli design
--
--   witc instance import xxx.wit
--   witc runtime export xxx.wit

main :: IO ()
main = do
  args <- getArgs
  handle args

handle :: [String] -> IO ()
handle ["instance", mode, file] = do
  -- ast <- parse file
  -- output <- gen mode ast
  putStrLn "TODO"
handle ["runtime", mode, file] = putStrLn "TODO"
handle _ = putStrLn "bad usage"
