module Main where

import Transformer (transformLogs, filterSuccessful, displayLogEntry, applyRules, sortLogEntries)
import Rule (parseRules)
import AST (LogEntry(..))
import System.Environment (getArgs)
import System.Directory (doesDirectoryExist, listDirectory)
import Data.List (isSuffixOf, isPrefixOf)
import Data.List.Split (splitOn)
import Data.Time (parseTimeM, defaultTimeLocale, UTCTime)

-- ======================
-- メインプログラム
-- ======================

-- 時間範囲をパース
parseTimeRange :: String -> Maybe (UTCTime, UTCTime)
parseTimeRange timeRange =
  let parts = splitOn "-" timeRange
  in if length parts == 2
     then case (parseTimeM True defaultTimeLocale "%Y/%m/%d %H:%M:%S" (head parts),
                parseTimeM True defaultTimeLocale "%Y/%m/%d %H:%M:%S" (parts !! 1)) of
            (Just startTime, Just endTime) -> Just (startTime, endTime)
            _ -> case (parseTimeM True defaultTimeLocale "%Y/%m/%d %H:%M" (head parts),
                      parseTimeM True defaultTimeLocale "%Y/%m/%d %H:%M" (parts !! 1)) of
                   (Just startTime, Just endTime) -> Just (startTime, endTime)
                   _ -> Nothing
     else Nothing

-- ログエントリが時間範囲内か確認
isInTimeRange :: (UTCTime, UTCTime) -> LogEntry -> Bool
isInTimeRange (startTime, endTime) entry = case timestamp entry of
  Just ts -> ts >= startTime && ts <= endTime
  Nothing -> False

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--rules", rulesFile, "--logs", logsPath] -> do
      rulesContent <- readFile rulesFile
      case parseRules rulesContent of
        Left err -> putStrLn $ "Error parsing rules: " ++ err
        Right rules -> do
          isDir <- doesDirectoryExist logsPath
          if isDir
            then do
              files <- listDirectory logsPath
              let logFiles = filter (\f -> ".log" `isSuffixOf` f) files
              allLogs <- mapM (\f -> readFile (logsPath ++ "/" ++ f)) logFiles
              let logLines = concatMap lines allLogs
              let results = transformLogs logsPath logLines
              let successful = filterSuccessful results
              let sorted = sortLogEntries successful
              let withRules = map (applyRules rules) sorted
              mapM_ (putStrLn . displayLogEntry) withRules
            else do
              logsContent <- readFile logsPath
              let logLines = lines logsContent
              let results = transformLogs logsPath logLines
              let successful = filterSuccessful results
              let sorted = sortLogEntries successful
              let withRules = map (applyRules rules) sorted
              mapM_ (putStrLn . displayLogEntry) withRules
    ["--rules", rulesFile, "--services", services, "--time", timeRange, "--logs", logsPath] -> do
      rulesContent <- readFile rulesFile
      case parseRules rulesContent of
        Left err -> putStrLn $ "Error parsing rules: " ++ err
        Right rules -> do
          case parseTimeRange timeRange of
            Nothing -> putStrLn $ "Error parsing time range: " ++ timeRange
            Just (startTime, endTime) -> do
              isDir <- doesDirectoryExist logsPath
              if isDir
                then do
                  files <- listDirectory logsPath
                  let serviceList = splitOn "," services
                  let logFiles = filter (\f -> ".log" `isSuffixOf` f && any (\s -> s `isPrefixOf` f) serviceList) files
                  allLogs <- mapM (\f -> readFile (logsPath ++ "/" ++ f)) logFiles
                  let logLines = concatMap lines allLogs
                  let results = transformLogs logsPath logLines
                  let successful = filterSuccessful results
                  let sorted = sortLogEntries successful
                  let filtered = filter (isInTimeRange (startTime, endTime)) sorted
                  let withRules = map (applyRules rules) filtered
                  mapM_ (putStrLn . displayLogEntry) withRules
                else do
                  logsContent <- readFile logsPath
                  let logLines = lines logsContent
                  let results = transformLogs logsPath logLines
                  let successful = filterSuccessful results
                  let sorted = sortLogEntries successful
                  let filtered = filter (isInTimeRange (startTime, endTime)) sorted
                  let withRules = map (applyRules rules) filtered
                  mapM_ (putStrLn . displayLogEntry) withRules
    _ -> do
      putStrLn "Usage: log-unifier --rules <rules.dsl> --logs <logs.txt or logs directory>"
      putStrLn "       log-unifier --rules <rules.dsl> --services nginx,apache --time \"2026/05/30 13:00-14:00\" --logs ./logs"
