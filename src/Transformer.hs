module Transformer where

import AST (LogEntry(..))
import Data.List (sortBy, isInfixOf, isPrefixOf)
import Parser (parseLog)
import Rule (Rule(..), EventCondition(..))
import System.Console.ANSI (Color(..), ConsoleLayer(..), ColorIntensity(..), SGR(..), setSGRCode)
import Text.Regex.TDFA ((=~))
import Data.Time (diffUTCTime, NominalDiffTime, formatTime, defaultTimeLocale)
import qualified Data.Map as Map
import qualified Data.Set as Set
import System.FilePath (takeBaseName)

replaceString :: String -> String -> String -> String
replaceString _ _ [] = []
replaceString old new xs@(y:ys)
  | old `isPrefixOf` xs = new ++ replaceString old new (drop (length old) xs)
  | otherwise = y : replaceString old new ys

-- ANSIエスケープシーケンス
gray :: String -> String
gray s = setSGRCode [SetColor Foreground Dull Black] ++ s ++ setSGRCode [Reset]

green :: String -> String
green s = setSGRCode [SetColor Foreground Vivid Green] ++ s ++ setSGRCode [Reset]

-- ログエントリを色分けして表示
displayLogEntry :: LogEntry -> String
displayLogEntry entry =
  let serviceName = takeBaseName (source entry)
      prefix = "[" ++ serviceName ++ "] "
  in case transformed entry of
       Nothing -> gray (prefix ++ raw entry)
       Just trans -> gray (prefix ++ raw entry) ++ "\n→ " ++ green trans

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

-- イベント条件リストが、時系列順のログリストに順序を守ってマッチするか判定
matchOrderedEvents :: [EventCondition] -> [LogEntry] -> Bool
matchOrderedEvents [] _ = True
matchOrderedEvents _ [] = False
matchOrderedEvents (ev:evs) (entry:entries) =
  if matchEvent ev entry
    then matchOrderedEvents evs entries
    else matchOrderedEvents (ev:evs) entries

-- 単一ルールまたは相関ルールの適用判定
applyRuleSingleOrCorrelate :: Rule -> LogEntry -> [LogEntry] -> Maybe LogEntry
applyRuleSingleOrCorrelate rule entry past =
  case rule of
    SingleRule _ pat trans ->
      let (_, matched, _, submatches) = raw entry =~ pat :: (String, String, String, [String])
      in if not (null matched)
         then
           let withPlaceholders = replacePlaceholders trans submatches
               withDatetime = case timestamp entry of
                                Just ts -> replaceString "{datetime}" (formatTime defaultTimeLocale "%Y/%m/%d %H:%M:%S" ts) withPlaceholders
                                Nothing -> withPlaceholders
           in Just $ entry { transformed = Just withDatetime }
         else Nothing
    CorrelateRule _ events window ordered trans ->
      if null events then Nothing else
      case timestamp entry of
        Nothing -> Nothing
        Just ts ->
          -- 過去の window 秒以内のログを抽出
          let limit = fromInteger window :: NominalDiffTime
              inWindow = takeWhile (\e -> case timestamp e of
                                           Just t -> diffUTCTime ts t <= limit
                                           Nothing -> False) past
              allInWindow = entry : inWindow
              -- 現在行自体がイベント条件（順序ありなら最後のイベント、順不同ならいずれかのイベント）にマッチしているか
              isMatchingTrigger = if ordered
                                  then matchEvent (last events) entry
                                  else any (\ev -> matchEvent ev entry) events
          in if not isMatchingTrigger
             then Nothing
             else if ordered
                  then
                    -- 順序ありの場合：時系列の古い順に戻して順序判定
                    let oldToNew = reverse allInWindow
                    in if matchOrderedEvents events oldToNew
                       then
                         let formattedTime = formatTime defaultTimeLocale "%Y/%m/%d %H:%M:%S" ts
                             resolvedTrans = replaceString "{datetime}" formattedTime trans
                         in Just $ entry { transformed = Just resolvedTrans }
                       else Nothing
                  else
                    -- 順序なしの場合：すべてのイベント条件が満たされているか確認
                    if all (\ev -> any (matchEvent ev) allInWindow) events
                    then
                      let formattedTime = formatTime defaultTimeLocale "%Y/%m/%d %H:%M:%S" ts
                          resolvedTrans = replaceString "{datetime}" formattedTime trans
                      in Just $ entry { transformed = Just resolvedTrans }
                    else Nothing
    ImportRule _ -> Nothing



-- すべてのルールをログリスト全体に適用する
-- すべてのルールをログリスト全体に適用する (2パス方式で相関障害の個別アラートを自動抑制)
applyRules :: [Rule] -> [LogEntry] -> [LogEntry]
applyRules rules entries =
  let indexedEntries = zip [0..] entries
      -- 1パス目: 相関ルールの判定と適合したグループのインデックス抽出
      (corrWarnings, suppressedIndices) = evaluateCorrelations rules indexedEntries
      -- 2パス目: 単一ルールの適用（相関で吸収された行はスキップ）
      applied = map (applySingleRules corrWarnings suppressedIndices) indexedEntries
  in applied
  where
    singleRules = [ r | r@SingleRule {} <- rules ]
    
    applySingleRules corrWarnings suppressedIndices (i, entry)
      -- 相関ルールのトリガー行の場合、その警告メッセージを適用
      | Map.member i corrWarnings =
          entry { transformed = Map.lookup i corrWarnings }
      -- 相関ルールの構成要素となった過去のエラー行の場合、個別ルール適用をスキップして生ログのまま残す
      | Set.member i suppressedIndices =
          entry
      -- 通常のログ行の場合、単一ルールを通常通り適用
      | otherwise =
          applySingleRulesList singleRules entry
          
    applySingleRulesList [] entry = entry
    applySingleRulesList (rule:rest) entry =
      case transformed entry of
        Just _ -> entry
        Nothing ->
          case applyRuleSingleOrCorrelate rule entry [] of
            Just transformedEntry -> transformedEntry
            Nothing -> applySingleRulesList rest entry

-- 相関に該当したインデックスを収集するヘルパー
evaluateCorrelations :: [Rule] -> [(Int, LogEntry)] -> (Map.Map Int String, Set.Set Int)
evaluateCorrelations rules indexedEntries =
  foldl processEntry (Map.empty, Set.empty) (zipWithPast indexedEntries)
  where
    processEntry acc (entry, past) =
      foldl (applyCorrRule entry past) acc rules
      
    applyCorrRule (i, entry) past (currMap, currSet) rule =
      case rule of
        CorrelateRule _ events window ordered trans ->
          if null events then (currMap, currSet)
          else case timestamp entry of
            Nothing -> (currMap, currSet)
            Just ts ->
              let limit = fromInteger window :: NominalDiffTime
                  inWindow = takeWhile (\(_, e) -> case timestamp e of
                                               Just t -> diffUTCTime ts t <= limit
                                               Nothing -> False) past
                  allInWindow = (i, entry) : inWindow
                  isMatchingTrigger = if ordered
                                      then matchEvent (last events) entry
                                      else any (\ev -> matchEvent ev entry) events
              in if not isMatchingTrigger
                 then (currMap, currSet)
                 else if ordered
                      then
                        let oldToNew = reverse allInWindow
                        in if matchOrderedEvents events (map snd oldToNew)
                           then
                             let matchedGroup = findOrderedMatches events oldToNew
                                 matchedIndices = map fst matchedGroup
                                 formattedTime = formatTime defaultTimeLocale "%Y/%m/%d %H:%M:%S" ts
                                 resolvedTrans = replaceString "{datetime}" formattedTime trans
                                 newMap = Map.insert i resolvedTrans currMap
                                 newSet = foldr Set.insert currSet (filter (/= i) matchedIndices)
                             in (newMap, newSet)
                           else (currMap, currSet)
                      else
                        if all (\ev -> any (matchEvent ev) (map snd allInWindow)) events
                        then
                          let matchedGroup = findUnorderedMatches events allInWindow
                              matchedIndices = map fst matchedGroup
                              formattedTime = formatTime defaultTimeLocale "%Y/%m/%d %H:%M:%S" ts
                              resolvedTrans = replaceString "{datetime}" formattedTime trans
                              newMap = Map.insert i resolvedTrans currMap
                              newSet = foldr Set.insert currSet (filter (/= i) matchedIndices)
                          in (newMap, newSet)
                        else (currMap, currSet)
        _ -> (currMap, currSet)

-- 順序あり相関の構成ログ抽出
findOrderedMatches :: [EventCondition] -> [(Int, LogEntry)] -> [(Int, LogEntry)]
findOrderedMatches [] _ = []
findOrderedMatches _ [] = []
findOrderedMatches (ev:evs) (x:xs) =
  if matchEvent ev (snd x)
    then x : findOrderedMatches evs xs
    else findOrderedMatches (ev:evs) xs

-- 順不同相関の構成ログ抽出
findUnorderedMatches :: [EventCondition] -> [(Int, LogEntry)] -> [(Int, LogEntry)]
findUnorderedMatches evs window =
  [ x | ev <- evs, let matches = filter (\w -> matchEvent ev (snd w)) window, not (null matches), let x = head matches ]



