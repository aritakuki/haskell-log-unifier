# ユーザーごとの認証エラーを検知し、ユーザー名を動的に抽出する
rule "user_auth_error" {
  pattern: "BAD ([a-zA-Z]+) Error"
  transform: {
    message: "ユーザー $1 の認証エラーが発生しました"
  }
}
