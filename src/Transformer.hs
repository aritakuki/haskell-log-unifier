module Transformer where

import AST (LogEntry(..))
import Data.List (sortBy)
import Parser (parseLog)
import Rule (Rule(..))
import System.Console.ANSI (Color(..), ConsoleLayer(..), ColorIntensity(..), SGR(..), setSGRCode)
import Text.Regex.TDFA ((=~))

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

-- $1, $2 などのプレースホルダーを正規表現のキャプチャグループで置換する
replacePlaceholders :: String -> [String] -> String
replacePlaceholders [] _ = []
replacePlaceholders ('$':d:xs) submatches
  | d >= '1' && d <= '9' =
      let idx = read [d] - 1
      in if idx < length submatches
         -- 置換対象を埋め込んで再帰
         then (submatches !! idx) ++ replacePlaceholders xs submatches
         -- 範囲外ならそのまま文字として出力
         else '$' : d : replacePlaceholders xs submatches
replacePlaceholders (x:xs) submatches = x : replacePlaceholders xs submatches

-- ルールを適用（パターンマッチ・正規表現対応）
applyRules :: [Rule] -> LogEntry -> LogEntry
applyRules rules entry = case rules of
  [] -> entry
  (rule:rest) ->
    let (before, matched, after, submatches) = raw entry =~ rulePattern rule :: (String, String, String, [String])
    in if not (null matched)
       then
         let transformedMsg = replacePlaceholders (ruleTransform rule) submatches
         in entry { transformed = Just transformedMsg }
       else
         applyRules rest entry

