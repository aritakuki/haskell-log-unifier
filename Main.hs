module Main where

import Transformer (transformLogs, filterSuccessful, displayLogEntry, applyRules, sortLogEntries)
import Rule (parseRules)
import System.Environment (getArgs)

-- ======================
-- メインプログラム
-- ======================

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--rules", rulesFile, "--logs", logsPath] -> do
      rulesContent <- readFile rulesFile
      case parseRules rulesContent of
        Left err -> putStrLn $ "Error parsing rules: " ++ err
        Right rules -> do
          logsContent <- readFile logsPath
          let logLines = lines logsContent
          let results = transformLogs logsPath logLines
          let successful = filterSuccessful results
          let sorted = sortLogEntries successful
          let withRules = map (applyRules rules) sorted
          mapM_ (putStrLn . displayLogEntry) withRules
    _ -> putStrLn "Usage: log-unifier --rules <rules.dsl> --logs <logs.txt>"
