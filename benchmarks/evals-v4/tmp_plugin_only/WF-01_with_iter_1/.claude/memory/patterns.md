# patterns.md - 再利用パターン

## P1: TypeScript プロジェクト構成

### コンテキスト
TypeScript + Vitest + ESLint を使用したプロジェクト

### パターン

```bash
# ビルド
npm run build

# テスト
npm run test

# Lint
npm run lint
```

### 適用例
- 新しいコードを追加後は `npm run build` で型チェック
- 機能実装後は `npm run test` でテスト実行
