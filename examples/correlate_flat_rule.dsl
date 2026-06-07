# 複数サービスにまたがる連鎖障害を検知する相関ルール（順不同）
correlate "cascade_failure_unordered" {
  window: 60
  ordered: false
  events: [
    event { source: "apache" pattern: "Connection Refused" }
    event { source: "nginx" pattern: "502" }
    event { source: "myapp1" pattern: "Database connection failed" }
  ]
  transform: {
    message: "【警告】Apache、Nginx、myapp1 にまたがる連鎖的なシステム障害が発生しています ({datetime})"
  }
}

# データベース接続エラーの個別翻訳ルール
rule "db_connection_failed" {
  pattern: "Database connection failed"
  transform: {
    message: "【エラー】データベース接続が失われました ({datetime})"
  }
}

# Apache接続拒否の個別翻訳ルール
rule "apache_connection_refused" {
  pattern: "Connection Refused"
  transform:{
    message: "【障害】Apacheへの接続要求が拒否されました ({datetime})"
  }
}
