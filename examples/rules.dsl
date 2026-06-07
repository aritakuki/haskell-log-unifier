# 認証エラーを検知するルール
rule "auth_error" {
  pattern: "BAD"
  transform: {
    message: "AUTH ERROR"
  }
}

# データベース接続やクエリのエラーを検知するルール
rule "db_error" {
  pattern: "ERROR: database"
  transform: {
    message: "DATABASE CONNECTION FAILED"
  }
}

# API接続のタイムアウトを検知するルール
rule "api_timeout" {
  pattern: "timeout"
  transform: {
    message: "API TIMEOUT DETECTED"
  }
}

# 高レイテンシー（応答遅延）を検知するルール
rule "high_latency" {
  pattern: "latency"
  transform: {
    message: "HIGH LATENCY WARNING"
  }
}

