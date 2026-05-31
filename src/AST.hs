module AST where

import Data.Time (UTCTime)

-- ======================
-- ログソース（既知のものは厳密に、未知のものは柔軟に）
-- ======================

data LogSource = Nginx | Apache | Custom String
  deriving (Show, Eq)

-- ======================
-- 統一ログフォーマット（AST）
-- ======================

data LogEntry = LogEntry
  { timestamp :: UTCTime
  , ip :: String
  , method :: String
  , path :: String
  , status :: Int
  , source :: LogSource
  } deriving (Show, Eq)
