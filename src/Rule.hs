module Rule where

import AST (LogSource(..))
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char

-- ======================
-- 変換ルールDSL
-- ======================

type RuleParser = Parsec Void String

-- ルール定義データ型
data Rule = Rule
  { ruleName :: String
  , rulePattern :: String
  , ruleSource :: LogSource
  } deriving (Show, Eq)

-- ルール定義パーサー
-- 例: rule "nginx" { pattern: "IP TIMESTAMP METHOD PATH STATUS" }
parseRule :: RuleParser Rule
parseRule = do
  _ <- string "rule"
  _ <- space
  name <- quotedString
  _ <- space
  _ <- char '{'
  _ <- space
  _ <- string "pattern:"
  _ <- space
  pattern <- quotedString
  _ <- space
  _ <- char '}'
  return $ Rule name pattern Nginx  -- TODO: ソースをパース

-- 引用符で囲まれた文字列
quotedString :: RuleParser String
quotedString = do
  _ <- char '"'
  s <- many (noneOf "\"")
  _ <- char '"'
  return s

-- ルールファイルパース
parseRules :: String -> Either String [Rule]
parseRules input = case parse parseRule "" input of
  Right rule -> Right [rule]
  Left err -> Left $ "Parse error: " ++ show err
