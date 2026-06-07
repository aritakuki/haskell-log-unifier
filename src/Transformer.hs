module Transformer where

import AST (LogEntry(..))
import Data.List (sortBy, isInfixOf)
import Parser (parseLog)
import Rule (Rule(..), EventCondition(..))
import System.Console.ANSI (Color(..), ConsoleLayer(..), ColorIntensity(..), SGR(..), setSGRCode)
import Text.Regex.TDFA ((=~))
import Data.Time (diffUTCTime, NominalDiffTime)

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

-- ログイベントの条件判定
matchEvent :: EventCondition -> LogEntry -> Bool
matchEvent (EventCondition src pat) entry =
  (src `isInfixOf` source entry) &&
  let (_, matched, _, _) = raw entry =~ pat :: (String, String, String, [String])
  in not (null matched)

-- 各ログエントリーに対して過去のログエントリーをペアにする（時系列順の走査用）
-- 例: [1,2,3] -> [(1, []), (2, [1]), (3, [2,1])]
zipWithPast :: [a] -> [(a, [a])]
zipWithPast xs = zipWithPastHelper [] xs
  where
    zipWithPastHelper _ [] = []
    zipWithPastHelper acc (y:ys) = (y, acc) : zipWithPastHelper (y:acc) ys

-- 単一ルールまたは相関ルールの適用判定
applyRuleSingleOrCorrelate :: Rule -> LogEntry -> [LogEntry] -> Maybe LogEntry
applyRuleSingleOrCorrelate rule entry past =
  case rule of
    SingleRule _ pat trans ->
      let (_, matched, _, submatches) = raw entry =~ pat :: (String, String, String, [String])
      in if not (null matched)
         then Just $ entry { transformed = Just (replacePlaceholders trans submatches) }
         else Nothing
    CorrelateRule _ events window trans ->
      case timestamp entry of
        Nothing -> Nothing
        Just ts ->
          -- 過去の window 秒以内のログを抽出
          let limit = fromInteger window :: NominalDiffTime
              inWindow = takeWhile (\e -> case timestamp e of
                                           Just t -> diffUTCTime ts t <= limit
                                           Nothing -> False) past
              allInWindow = entry : inWindow
          -- window 内のログで、すべてのイベント条件が満たされているか確認
          in if all (\ev -> any (matchEvent ev) allInWindow) events
             then Just $ entry { transformed = Just trans }
             else Nothing
    ImportRule _ -> Nothing


-- すべてのルールをログリスト全体に適用する
applyRules :: [Rule] -> [LogEntry] -> [LogEntry]
applyRules rules entries = map applyRulesForEntry (zipWithPast entries)
  where
    applyRulesForEntry (entry, past) = applyRulesList rules entry past

    applyRulesList [] entry _ = entry
    applyRulesList (rule:rest) entry past =
      case transformed entry of
        Just _ -> entry -- すでに前のルールで変換されている場合は何もしない
        Nothing ->
          case applyRuleSingleOrCorrelate rule entry past of
            Just transformedEntry -> transformedEntry
            Nothing -> applyRulesList rest entry past



