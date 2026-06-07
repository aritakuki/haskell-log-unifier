# 複数サービスにまたがる連鎖障害を検知する相関ルール
correlate "cascade_failure" {
  window: 30
  events: [
    event { source: "apache" pattern: "Connection Refused" }
    event { source: "nginx" pattern: "502" }
    event { source: "myapp1" pattern: "Database connection failed" }
  ]
  transform; {
    message: "【警告】Apache、Nginx、myapp1 にまたがる連鎖的なシステム障害が発生しています！"
  }
}



