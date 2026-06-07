module Rule where

import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

-- ======================
-- 変換ルールDSL
-- ======================

type RuleParser = Parsec Void String

-- イベント条件（相関ルール用）
data EventCondition = EventCondition
  { evSource :: String
  , evPattern :: String
  } deriving (Show, Eq)

-- ルール定義データ型
data Rule
  = SingleRule
      { ruleName :: String
      , rulePattern :: String
      , ruleTransform :: String
      }
  | CorrelateRule
      { ruleName :: String
      , corrEvents :: [EventCondition]
      , corrWindow :: Integer
      , ruleTransform :: String
      }
  deriving (Show, Eq)

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
parseRule :: RuleParser Rule
parseRule = parseSingleRule <|> parseCorrelateRule

parseSingleRule :: RuleParser Rule
parseSingleRule = do
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
  return $ SingleRule name pattern transform

parseCorrelateRule :: RuleParser Rule
parseCorrelateRule = do
  _ <- symbol "correlate"
  name <- lexeme quotedString
  _ <- symbol "{"
  _ <- symbol "window:"
  windowVal <- lexeme L.decimal
  _ <- symbol "events:"
  _ <- symbol "["
  events <- many parseEventCondition
  _ <- symbol "]"
  _ <- symbol "transform:"
  _ <- symbol "{"
  _ <- symbol "message:"
  transform <- lexeme quotedString
  _ <- symbol "}"
  _ <- symbol "}"
  return $ CorrelateRule name events windowVal transform

parseEventCondition :: RuleParser EventCondition
parseEventCondition = do
  _ <- symbol "event"
  _ <- symbol "{"
  _ <- symbol "source:"
  src <- lexeme quotedString
  _ <- symbol "pattern:"
  pat <- lexeme quotedString
  _ <- symbol "}"
  return $ EventCondition src pat

-- ルールファイルパース
parseRules :: String -> Either String [Rule]
parseRules input = case parse (sc *> many parseRule <* eof) "" input of
  Right rules -> Right rules
  Left err -> Left $ "Parse error: " ++ show err


