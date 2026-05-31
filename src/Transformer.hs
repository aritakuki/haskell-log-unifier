module Transformer where

import AST (LogEntry)
import Parser (parseLog)

-- ======================
-- ログ変換エンジン
-- ======================

-- ログ文字列をLogEntryに変換
transformLog :: String -> Either String LogEntry
transformLog = parseLog

-- 複数のログを変換
transformLogs :: [String] -> [Either String LogEntry]
transformLogs = map transformLog

-- 成功したログのみ抽出
filterSuccessful :: [Either String LogEntry] -> [LogEntry]
filterSuccessful = rights
  where
    rights (Right x:xs) = x : rights xs
    rights (Left _:xs) = rights xs
    rights [] = []
