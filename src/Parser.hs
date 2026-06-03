module Parser where

import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char

-- ======================
-- ログパーサー（megaparsec）
-- ======================

type Parser = Parsec Void String

-- タイムスタンプパーサー
-- 例: [31/May/2024:10:00:00] または 2026/05/30 13:43
parseTimestamp :: Parser UTCTime
parseTimestamp = do
  _ <- char '['
  tsStr <- many (noneOf "]")
  _ <- char ']'
  case parseTimeM True defaultTimeLocale "%d/%b/%Y:%H:%M:%S" tsStr of
    Just ts -> return ts
    Nothing -> fail $ "Invalid timestamp: " ++ tsStr

-- ISO形式タイムスタンプパーサー
-- 例: 2026/05/30 13:43
parseISOTimestamp :: Parser UTCTime
parseISOTimestamp = do
  yearStr <- count 4 digitChar
  _ <- char '/'
  monthStr <- count 2 digitChar
  _ <- char '/'
  dayStr <- count 2 digitChar
  _ <- space
  hourStr <- count 2 digitChar
  _ <- char ':'
  minuteStr <- count 2 digitChar
  let tsStr = yearStr ++ "/" ++ monthStr ++ "/" ++ dayStr ++ " " ++ hourStr ++ ":" ++ minuteStr
  case parseTimeM True defaultTimeLocale "%Y/%m/%d %H:%M" tsStr of
    Just ts -> return ts
    Nothing -> fail $ "Invalid timestamp: " ++ tsStr

-- ログパース（タイムスタンプ抽出）
parseLog :: String -> Either String (UTCTime, String)
parseLog input = case parse (skipMany (noneOf "[") *> try parseTimestamp) "" input of
  Right ts -> Right (ts, input)
  Left _ -> case parse (skipMany (noneOf "0123456789") *> try parseISOTimestamp) "" input of
    Right ts -> Right (ts, input)
    Left err -> Left $ "Parse error: " ++ show err
