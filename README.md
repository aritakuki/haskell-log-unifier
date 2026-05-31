# Haskell Log Unifier

**「障害調査で育つ、実行可能運用ノート」**

障害対応時にログ調査を行い、得られたノウハウをDSLルールとして保存し、次回以降の障害対応に活かすツール。

## 特徴

- **megaparsec:** 現代的なパーサーライブラリを使用
- **DSL:** 変換ルールをDSLで定義可能（人に対して超親切）
- **型安全:** Haskellの型システムによる安全性（ルールミスを防ぐ）
- **詳細なエラーメッセージ:** 障害対応時に役立つ

## アーキテクチャ

```
haskell-log-unifier/
├── src/
│   ├── AST.hs              # ログエントリ定義
│   ├── Parser.hs          # ログパーサー（megaparsec）
│   ├── Rule.hs            # 変換ルールDSL
│   ├── Transformer.hs     # ログ変換エンジン
│   └── Main.hs            # メインプログラム
├── examples/
│   ├── nginx.log          # サンプルログ
│   └── apache.log
└── SPEC.md                # 仕様書
```

## 実行方法

```bash
# ビルド
cabal build

# 実行
./log-unifier --rules rules.dsl --logs ./logs
```

## サンプル

**入力ログ:**
```
2026/05/30 13:43 BAD ALICE FAILURE
```

**DSLルール:**
```haskell
rule "auth_error" {
  pattern: "BAD USERNAME FAILURE"
  transform: {
    message: "AUTH ERROR"
  }
}
```

**出力:**
```
2026/05/30 13:43 BAD ALICE FAILURE (灰色)
→ AUTH ERROR (緑色)
```

## 障害対応のフロー

1. **障害発生:** システムで障害が発生
2. **ログ調査:** 複数サービスのログを時系列で確認
3. **ノウハウ蓄積:** 調査結果をDSLルールとして保存
4. **次回活用:** 次回以降、ルールが自動適用されて調査が容易になる

詳細な仕様は [SPEC.md](SPEC.md) を参照してください。
