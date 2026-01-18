# 実装品質ルール

## 禁止パターン

「形骸化実装」でテストを通すことを禁止します:

### 1. テスト期待値のハードコード

```typescript
// ❌ 禁止: テストを通すためだけのハードコード
function calculate(input: number): number {
  if (input === 5) return 10; // テストケースのみ対応
  return 0;
}
```

### 2. 空実装・スタブ

```typescript
// ❌ 禁止: 何もしない実装
function processData(data: Data): void {
  // TODO: 後で実装
}
```

### 3. 特定入力のみ動作

```typescript
// ❌ 禁止: テストケースのみ対応
function parse(str: string): Result {
  if (str === 'test-input') {
    return { value: 'test-output' };
  }
  throw new Error('Not implemented');
}
```

## 正しい実装

- **汎用的なロジック**を書く
- **エッジケース**を考慮する
- **実際のユースケース**で動作することを確認

## 困難な場合の対応

1. 正直に報告（「この方法では実装が困難です」）
2. 理由を説明（技術的制約、前提条件の不備）
3. 選択肢を提示（代替案、段階的実装）
4. ユーザーの判断を仰ぐ
