import Text.Megaparsec
import Text.Megaparsec.Char

type Parser = Parsec Void String

testSkipManySpace :: Parser ()
testSkipManySpace = skipMany space

testSkipManyNoneOf :: Parser ()
testSkipManyNoneOf = skipMany (noneOf "\n")

testCommentParser :: Parser ()
testCommentParser = do
  _ <- optional (do
    _ <- char '#'
    skipMany (noneOf "\n")
    optional (char '\n'))
  skipMany space

main :: IO ()
main = do
  putStrLn "Testing skipMany space with empty input:"
  print $ parse testSkipManySpace "" ""
  
  putStrLn "\nTesting skipMany (noneOf \"\\n\") with empty input:"
  print $ parse testSkipManyNoneOf "" ""
  
  putStrLn "\nTesting comment parser with empty input:"
  print $ parse testCommentParser "" ""
  
  putStrLn "\nTesting comment parser with comment:"
  print $ parse testCommentParser "" "# comment\nrule"
  
  putStrLn "\nTesting comment parser without comment:"
  print $ parse testCommentParser "" "rule"
