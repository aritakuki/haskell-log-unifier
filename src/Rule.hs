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
      , corrOrdered :: Bool
      , ruleTransform :: String
      }
  | ImportRule
      { importPath :: FilePath
      }
  deriving (Show, Eq)

-- 簡易プレースホルダーマクロの置換テーブル
placeholderMap :: [(String, String)]
placeholderMap =
  [ ("{user}",   "([A-Za-z0-9_-]+)")
  , ("{ip}",     "([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})")
  , ("{number}", "([0-9]+)")
  , ("{uuid}",   "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})")
  ]

-- 簡易マクロのバリデーションと正規表現への置換
validatePattern :: String -> Either String String
validatePattern [] = Right []
validatePattern str@(x:xs)
  | "{" `isPrefixOf` str =
      let (macro, rest) = break (== '}') str
      in case rest of
        ('}':actualRest) ->
          let fullMacro = macro ++ "}"
          in if isRegisteredMacro fullMacro
             then case translateMacro fullMacro of
                    Just regex -> fmap (regex ++) (validatePattern actualRest)
                    Nothing -> Left $ "予期せぬエラーが発生しました: " ++ fullMacro
             else Left $ "未定義の簡易マクロです: " ++ fullMacro ++ " (定義されているのは {user}, {ip}, {number}, {uuid} のみです)"
        _ -> Left $ "閉じ中括弧 '}' が見つかりません: " ++ str
  | otherwise = fmap (x:) (validatePattern xs)
  where
    isRegisteredMacro m = m `elem` map fst placeholderMap
    translateMacro m = lookup m placeholderMap

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
  patternStr <- lexeme quotedString
  pattern <- case validatePattern patternStr of
    Right p -> return p
    Left err -> fail err
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
  _ <- symbol "ordered:"
  orderedVal <- (symbol "true" *> return True) <|> (symbol "false" *> return False)
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
  return $ CorrelateRule name events windowVal orderedVal transform

parseEventCondition :: RuleParser EventCondition
parseEventCondition = label "イベント条件 (event { ... })" $ do
  _ <- symbol "event"
  _ <- symbol "{"
  _ <- symbol "source:"
  src <- lexeme quotedString
  _ <- symbol "pattern:"
  patStr <- lexeme quotedString
  pat <- case validatePattern patStr of
    Right p -> return p
    Left err -> fail err
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
