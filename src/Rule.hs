module Rule where

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
  , ruleTransform :: String
  } deriving (Show, Eq)

-- ルール定義パーサー
-- 例: rule "auth_error" { pattern: "BAD USERNAME FAILURE" transform: { message: "AUTH ERROR" } }
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
  _ <- string "transform:"
  _ <- space
  _ <- char '{'
  _ <- space
  _ <- string "message:"
  _ <- space
  transform <- quotedString
  _ <- space
  _ <- char '}'
  _ <- space
  _ <- char '}'
  _ <- space
  return $ Rule name pattern transform

-- 引用符で囲まれた文字列
quotedString :: RuleParser String
quotedString = do
  _ <- char '"'
  s <- many (noneOf "\"")
  _ <- char '"'
  return s

-- ルールファイルパース
parseRules :: String -> Either String [Rule]
parseRules input = case parse (many parseRule) "" input of
  Right rules -> Right rules
  Left err -> Left $ "Parse error: " ++ show err
