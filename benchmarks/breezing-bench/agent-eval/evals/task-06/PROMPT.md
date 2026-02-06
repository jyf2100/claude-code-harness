data-processor.ts の any を全て排除し、適切な型定義を追加してください。tsc --noEmit が通るようにし、既存のロジックは変更しないでください。

## 修正対象の型

以下の `any` を適切な型に置き換えてください:

### 1. データ型の定義
`processData` と `validateInput` の引数/戻り値に使われている `any` を、以下のような discriminated union で定義:
```typescript
interface UserData { type: 'user'; payload: { name: string; age: number; email: string; tags?: string[] } }
interface ProductData { type: 'product'; payload: { title: string; price: number; category: string; inStock?: boolean } }
interface OrderData { type: 'order'; payload: { orderId: string; items: OrderItem[] } }
type InputData = UserData | ProductData | OrderData;
```

### 2. 戻り値の型
`processData` の戻り値も discriminated union またはオブジェクト型で定義。

### 3. バリデーション結果
`validateInput` の戻り値の `errors` 配列の要素型を定義。

### 4. コールバック / ユーティリティ
`transformBatch` の `items` パラメータと戻り値の型を修正。
`reduce` のアキュムレータ型を明示。
