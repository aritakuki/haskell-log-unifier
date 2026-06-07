# 外部のルールファイルをインポートする
import "imported_auth.dsl"
import "imported_db.dsl"

# APIタイムアウトを検知するルール (メインファイル定義)
rule "api_timeout" {
  pattern: "timeout"
  transform: {
    message: "API TIMEOUT DETECTED"
  }
}


