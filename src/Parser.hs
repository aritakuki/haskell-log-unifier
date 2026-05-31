module Parser where

import AST (LogEntry(..), LogSource(..))
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

-- ======================
-- ログパーサー（megaparsec）
-- ======================

type Parser = Parsec Void String

-- Nginxログパーサー
-- 例: 192.168.1.1 - - [31/May/2024:10:00:00] GET /api/users 200
parseNginxLog :: Parser LogEntry
parseNginxLog = do
  ipAddr <- ipAddress
  _ <- space
  _ <- string "-"
  _ <- space
  _ <- string "-"
  _ <- space
  ts <- parseTimestamp
  _ <- space
  httpMethod <- parseMethod
  _ <- space
  reqPath <- parsePath
  _ <- space
  statusCode <- parseStatus
  return $ LogEntry ts ipAddr httpMethod reqPath statusCode Nginx

-- Apacheログパーサー
-- 例: [31/May/2024:10:00:00] 192.168.1.1 GET /api/users 200
parseApacheLog :: Parser LogEntry
parseApacheLog = do
  ts <- parseTimestamp
  _ <- space
  ipAddr <- ipAddress
  _ <- space
  httpMethod <- parseMethod
  _ <- space
  reqPath <- parsePath
  _ <- space
  statusCode <- parseStatus
  return $ LogEntry ts ipAddr httpMethod reqPath statusCode Apache

-- IPアドレスパーサー
ipAddress :: Parser String
ipAddress = do
  a <- L.decimal :: Parser Integer
  _ <- char '.'
  b <- L.decimal :: Parser Integer
  _ <- char '.'
  c <- L.decimal :: Parser Integer
  _ <- char '.'
  d <- L.decimal :: Parser Integer
  return $ concat [show a, ".", show b, ".", show c, ".", show d]

-- タイムスタンプパーサー
-- 例: [31/May/2024:10:00:00]
parseTimestamp :: Parser UTCTime
parseTimestamp = do
  _ <- char '['
  tsStr <- many (noneOf "]")
  _ <- char ']'
  case parseTimeM True defaultTimeLocale "%d/%b/%Y:%H:%M:%S" tsStr of
    Just ts -> return ts
    Nothing -> fail $ "Invalid timestamp: " ++ tsStr

-- メソッドパーサー
parseMethod :: Parser String
parseMethod = string "GET" <|> string "POST" <|> string "PUT" <|> string "DELETE"

-- パスパーサー
parsePath :: Parser String
parsePath = do
  _ <- char '/'
  reqPath <- many (noneOf " ")
  return $ "/" ++ reqPath

-- ステータスコードパーサー
parseStatus :: Parser Int
parseStatus = L.decimal

-- ログパース（自動判定）
parseLog :: String -> Either String LogEntry
parseLog input = case parse parseNginxLog "" input of
  Right entry -> Right entry
  Left _ -> case parse parseApacheLog "" input of
    Right entry -> Right entry
    Left err -> Left $ "Parse error: " ++ show err
