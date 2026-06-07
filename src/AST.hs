module AST where

import Data.Time (UTCTime)

-- ======================
-- ログエントリ（障害調査用）
-- ======================

-- ログエントリ: 単一のログ行を表すデータ構造
-- パースされたタイムスタンプ、生のログ文字列、変換後の文字列、ソース情報を保持
data LogEntry = LogEntry
  { timestamp :: Maybe UTCTime      -- パースされたタイムスタンプ（存在しない場合は Nothing）
  , raw :: String                    -- 生のログ文字列（元のログ行）
  , transformed :: Maybe String      -- ルール適用後の変換結果（未変換の場合は Nothing）
  , source :: String                 -- ログのソース（ファイル名など）
  } deriving (Show, Eq)
