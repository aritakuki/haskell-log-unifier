# データベースのエラーを検知するルール (インポート用)
rule "db_error" {
  pattern: "ERROR: database"
  transform: {
    message: "DATABASE CONNECTION FAILED"
  }
}
