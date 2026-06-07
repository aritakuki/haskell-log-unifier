module Parser where

import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char

-- ======================
-- ログパーサー（megaparsec）
-- ======================

type Parser = Parsec Void String  -- Megaparsecのパーサー型: Stringを入力、カスタムエラーなし、結果型は各関数で指定

-- タイムスタンプパーサー
-- 例: [31/May/2024:10:00:00] または 2026/05/30 13:43
parseTimestamp :: Parser UTCTime  -- Apache形式のタイムスタンプをパースしてUTCTimeを返す
parseTimestamp = do  -- do記法でパース手順を記述
  _ <- char '['  -- 開き括弧を消費
  tsStr <- many (noneOf "]")  -- ]でない文字をすべて読み取り（タイムスタンプ文字列）
  _ <- char ']'  -- 閉じ括弧を消費
  case parseTimeM True defaultTimeLocale "%d/%b/%Y:%H:%M:%S" tsStr of  -- 文字列をUTCTimeに変換
    Just ts -> return ts  -- 変換成功: UTCTimeを返す
    Nothing -> fail $ "Invalid timestamp: " ++ tsStr  -- 変換失敗: エラー

-- ISO形式タイムスタンプパーサー
-- 例: 2026/05/30 13:43
parseISOTimestamp :: Parser UTCTime  -- ISO形式のタイムスタンプをパースしてUTCTimeを返す
parseISOTimestamp = do  -- do記法でパース手順を記述
  yearStr <- count 4 digitChar  -- 4桁の数字（年）
  _ <- char '/'  -- スラッシュを消費
  monthStr <- count 2 digitChar  -- 2桁の数字（月）
  _ <- char '/'  -- スラッシュを消費
  dayStr <- count 2 digitChar  -- 2桁の数字（日）
  _ <- space  -- スペースを消費
  hourStr <- count 2 digitChar  -- 2桁の数字（時）
  _ <- char ':'  -- コロンを消費
  minuteStr <- count 2 digitChar  -- 2桁の数字（分）
  let tsStr = yearStr ++ "/" ++ monthStr ++ "/" ++ dayStr ++ " " ++ hourStr ++ ":" ++ minuteStr  -- 文字列を結合して日時フォーマットを作成
  case parseTimeM True defaultTimeLocale "%Y/%m/%d %H:%M" tsStr of  -- 文字列をUTCTimeに変換
    Just ts -> return ts  -- 変換成功: UTCTimeを返す
    Nothing -> fail $ "Invalid timestamp: " ++ tsStr  -- 変換失敗: エラー

-- ログパース（タイムスタンプ抽出）
parseLog :: String -> Either String (UTCTime, String)  -- ログ文字列からタイムスタンプを抽出
parseLog input = case parse (skipMany (noneOf "[") *> try parseTimestamp) "" input of  -- まずApache形式を試す
  Right ts -> Right (ts, input)  -- 成功: (UTCTime, 元の文字列)を返す
  Left _ -> case parse (skipMany (noneOf "0123456789") *> try parseISOTimestamp) "" input of  -- 失敗: ISO形式を試す
    Right ts -> Right (ts, input)  -- 成功: (UTCTime, 元の文字列)を返す
    Left err -> Left $ "Parse error: " ++ show err  -- 両方失敗: エラーメッセージを返す
