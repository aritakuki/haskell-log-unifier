# Haskell Log Unifier

Haskellで実装したログ統合システム。複数のログフォーマット（Nginx、Apache、カスタム）を統一フォーマットに変換します。

## 特徴

- **megaparsec:** 現代的なパーサーライブラリを使用
- **DSL:** 変換ルールをDSLで定義可能
- **型安全:** Haskellの型システムによる安全性
- **柔軟性:** 既知のログ形式は厳密に、未知の形式は柔軟に対応

## アーキテクチャ

```
haskell-log-unifier/
├── src/
│   ├── AST.hs              # 統一ログフォーマット
│   ├── Parser.hs          # ログパーサー（megaparsec）
│   ├── Rule.hs            # 変換ルールDSL
│   ├── Transformer.hs     # ログ変換エンジン
│   └── Main.hs            # デモプログラム
├── examples/
│   ├── nginx.log          # サンプルログ
│   └── apache.log
```

## 実行方法

```bash
cabal run
```

## サンプル

**Nginxログ:**
```
192.168.1.1 - - [31/May/2024:10:00:00] GET /api/users 200
```

**Apacheログ:**
```
[31/May/2024:10:00:00] 192.168.1.1 GET /api/users 200
```

## Haskellの強み

**既知のものは厳密に:**
```haskell
data LogSource = Nginx | Apache | Custom String
```

**未知のものは柔軟に:**
- Nginx/Apache: 固定値（引数なし）
- Custom String: 任意のログタイプ（引数あり）

**型安全で拡張可能:**
- コンパイル時に型チェック
- 柔軟な拡張が可能
