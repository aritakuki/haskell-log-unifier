module AST where

import Data.Time (UTCTime)

-- ======================
-- ログエントリ（障害調査用）
-- ======================

data LogEntry = LogEntry
  { timestamp :: Maybe UTCTime
  , raw :: String
  , transformed :: Maybe String
  , source :: String
  } deriving (Show, Eq)
