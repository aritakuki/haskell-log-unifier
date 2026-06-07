module Rule where

import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

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

-- 空白と1行コメント（#）を読み飛ばすスペースコンシューマ
sc :: RuleParser ()
sc = L.space space1 (L.skipLineComment "#") empty

-- トークンパース用のヘルパー
lexeme :: RuleParser a -> RuleParser a
lexeme = L.lexeme sc

symbol :: String -> RuleParser String
symbol = L.symbol sc

-- 引用符で囲まれた文字列
quotedString :: RuleParser String
quotedString = char '"' *> many (noneOf "\"") <* char '"'

-- ルール定義パーサー
-- 例: rule "auth_error" { pattern: "BAD USERNAME FAILURE" transform: { message: "AUTH ERROR" } }
parseRule :: RuleParser Rule
parseRule = do
  _ <- symbol "rule"
  name <- lexeme quotedString
  _ <- symbol "{"
  _ <- symbol "pattern:"
  pattern <- lexeme quotedString
  _ <- symbol "transform:"
  _ <- symbol "{"
  _ <- symbol "message:"
  transform <- lexeme quotedString
  _ <- symbol "}"
  _ <- symbol "}"
  return $ Rule name pattern transform

-- ルールファイルパース
parseRules :: String -> Either String [Rule]
parseRules input = case parse (sc *> many parseRule <* eof) "" input of
  Right rules -> Right rules
  Left err -> Left $ "Parse error: " ++ show err

