module Transformer where

import AST (LogEntry(..))
import Data.List (sortBy, isInfixOf)
import Parser (parseLog)
import Rule (Rule(..))
import System.Console.ANSI (Color(..), ConsoleLayer(..), ColorIntensity(..), SGR(..), setSGRCode)

-- ANSIエスケープシーケンス
gray :: String -> String
gray s = setSGRCode [SetColor Foreground Dull Black] ++ s ++ setSGRCode [Reset]

green :: String -> String
green s = setSGRCode [SetColor Foreground Vivid Green] ++ s ++ setSGRCode [Reset]

-- ログエントリを色分けして表示
displayLogEntry :: LogEntry -> String
displayLogEntry entry = case transformed entry of
  Nothing -> gray (raw entry)
  Just trans -> gray (raw entry) ++ "\n→ " ++ green trans

-- ======================
-- ログ変換エンジン
-- ======================

-- ログ文字列をLogEntryに変換
transformLog :: String -> String -> Either String LogEntry
transformLog src input = case parseLog input of
  Right (ts, rawLog) -> Right $ LogEntry (Just ts) rawLog Nothing src
  Left _ -> Right $ LogEntry Nothing input Nothing src  -- タイムスタンプがない場合

-- 複数のログを変換
transformLogs :: String -> [String] -> [Either String LogEntry]
transformLogs src logs = map (transformLog src) logs

-- 成功したログのみ抽出
filterSuccessful :: [Either String LogEntry] -> [LogEntry]
filterSuccessful = rights
  where
    rights (Right x:xs) = x : rights xs
    rights (Left _:xs) = rights xs
    rights [] = []

-- タイムスタンプがないログを時系列の最後に配置
sortLogEntries :: [LogEntry] -> [LogEntry]
sortLogEntries entries =
  let (withTimestamp, withoutTimestamp) = partitionWithTimestamp entries
      sortedWithTimestamp = sortByTimestamp withTimestamp
  in sortedWithTimestamp ++ withoutTimestamp
  where
    partitionWithTimestamp = foldr (\e (ws, wos) -> if hasTimestamp e then (e:ws, wos) else (ws, e:wos)) ([], [])
    hasTimestamp e = case timestamp e of
      Just _ -> True
      Nothing -> False
    sortByTimestamp = sortBy (\e1 e2 -> case (timestamp e1, timestamp e2) of
      (Just t1, Just t2) -> compare t1 t2
      (Just _, Nothing) -> LT
      (Nothing, Just _) -> GT
      (Nothing, Nothing) -> EQ)

-- ルールを適用
applyRule :: Rule -> LogEntry -> LogEntry
applyRule rule entry = entry { transformed = Just (ruleTransform rule) }

-- ルールを適用（パターンマッチ）
applyRules :: [Rule] -> LogEntry -> LogEntry
applyRules rules entry = case rules of
  [] -> entry
  (rule:rest) -> 
    if raw entry `contains` rulePattern rule
    then applyRule rule entry
    else applyRules rest entry
  where
    contains haystack needle = needle `isInfixOf` haystack
