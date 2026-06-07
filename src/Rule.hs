module Rule where

import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L
import Data.List (isPrefixOf)

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
  | ImportRule
      { importPath :: FilePath
      }
  deriving (Show, Eq)


-- 空白と1行コメント（#）を読み飛ばすスペースコンシューマ
sc :: RuleParser ()
sc = L.space space1 (L.skipLineComment "#") empty

-- トークンパース用のヘルパー
lexeme :: RuleParser a -> RuleParser a
lexeme = L.lexeme sc

symbol :: String -> RuleParser String
symbol sym = label ("'" ++ sym ++ "'") $ L.symbol sc sym

-- 引用符で囲まれた文字列
quotedString :: RuleParser String
quotedString = label "ダブルクォーテーションで囲まれた文字列（例: \"auth_error\" や \"502\"）" $
  char '"' *> many (noneOf "\"") <* char '"'

-- ルール定義パーサー
parseRule :: RuleParser Rule
parseRule = parseSingleRule <|> parseCorrelateRule <|> parseImportRule

parseImportRule :: RuleParser Rule
parseImportRule = label "インポート宣言 (import \"...\")" $ do
  _ <- symbol "import"
  path <- lexeme quotedString
  return $ ImportRule path


parseSingleRule :: RuleParser Rule
parseSingleRule = label "単一ルール定義 (rule \"...\")" $ do
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
parseCorrelateRule = label "相関ルール定義 (correlate \"...\")" $ do
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
parseEventCondition = label "イベント条件 (event { ... })" $ do
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
  Left err -> Left $ "\nルールファイルの解析に失敗しました。以下の記述を確認してください：\n\n" 
                   ++ translateMegaparsecError (errorBundlePretty err)

-- エラーメッセージの簡易日本語化
translateMegaparsecError :: String -> String
translateMegaparsecError msg = unlines $ map translateLine (lines msg)
  where
    translateLine line
      | "unexpected end of input" `isPrefixOf` lTrim =
          indent ++ "想定外の入力: ファイルの末尾で予期せず入力が途切れています（中括弧 } や閉じブラケット ] の閉じ忘れはありませんか？）"
      | "unexpected" `isPrefixOf` lTrim =
          indent ++ "想定外の入力: " ++ translateTerms (drop 10 lTrim)
      | "expecting" `isPrefixOf` lTrim =
          indent ++ "期待されていた入力: " ++ translateTerms (drop 9 lTrim)
      | otherwise = line
      where
        lTrim = dropWhile (== ' ') line
        indent = takeWhile (== ' ') line

    translateTerms term
      | "end of input" `isPrefixOf` term = "ファイルの末尾"
      | otherwise = term



