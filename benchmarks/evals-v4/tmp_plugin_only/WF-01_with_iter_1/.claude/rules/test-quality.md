# テスト品質ルール

## 禁止パターン

テスト失敗時に以下の「楽をする」変更を行ってはいけません:

### 1. テストのスキップ

```typescript
// ❌ 禁止
it.skip('should work', () => {});
test.skip('should work', () => {});
```

### 2. アサーションの削除・緩和

```typescript
// ❌ 禁止: アサーションを削除してテストを通す
it('should return value', () => {
  const result = func();
  // expect(result).toBe(expected); ← 削除してはいけない
});
```

### 3. eslint-disable の追加

```typescript
// ❌ 禁止: テスト品質を下げるための disable
// eslint-disable-next-line @typescript-eslint/no-explicit-any
```

## 正しい対応

テストが失敗した場合:

1. **実装を修正する**（テストではなく）
2. **テストが間違っている場合は理由を説明して修正**
3. **困難な場合は正直に報告**

```
「この方法では実装が困難です」
→ 理由を説明
→ 代替案を提示
→ ユーザーの判断を仰ぐ
```
