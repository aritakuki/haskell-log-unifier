# 認証エラーを検知するルール (インポート用)
rule "auth_error" {
  pattern: "BAD"
  transform: {
    message: "AUTH ERROR"
  }
}
