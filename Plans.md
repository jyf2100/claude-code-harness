# Breezing v2 ベンチマーク — GLM 検証プラン

## 現状

| 項目 | 状態 |
|------|------|
| GLM API | `https://api.z.ai/api/anthropic` 経由で動作確認済み |
| モデル | `haiku` → `glm-4.5-air` マッピング |
| task-02 (breezing) | 1/1 pass (69.4s) ✅ |
| 前回結果 (Anthropic haiku) | Vanilla 4/20 = Breezing 4/20 → **差なし** |
| validate.ts あり | task-02, 09, 10 のみ (他7タスクは echo プレースホルダー) |

### "新機能 + 隠しバグ" パターン (task-02, 09, 10)

| タスク | PROMPT (新機能) | 隠しバグ (既存コード) |
|--------|----------------|---------------------|
| task-02 | `getByStatus()` 追加 | `updatedAt` が `new Date(old.getTime())` でコピー |
| task-09 | `stringifyCsv()` 追加 | カラム不一致行を除外せず push |
| task-10 | `search()` 追加 | `updatedAt` が `new Date(old.getTime())` でコピー |

---

## Phase 1: GLM クイック検証 [feature:decision-gate] ✅ DONE

3タスク × 3runs × 2条件 = 18 runs で Breezing の効果を確認

### 1.1 GLM 用 experiment configs 作成

| Task | 内容 | Status |
|------|------|--------|
| 1.1.1 | `experiments/glm-calibrate-breezing.ts` 作成 (task-02,09,10 × 3runs, validate あり) | `cc:DONE` |
| 1.1.2 | `experiments/glm-calibrate-vanilla.ts` 作成 (task-02,09,10 × 3runs, validate なし) | `cc:DONE` |

### 1.2 Breezing 条件実行

| Task | 内容 | Status |
|------|------|--------|
| 1.2.1 | `npx @vercel/agent-eval glm-calibrate-breezing` 実行 | `cc:DONE` |

結果: **9/9 (100%)** — task-02: 3/3, task-09: 3/3, task-10: 3/3

### 1.3 Vanilla 条件実行

| Task | 内容 | Status |
|------|------|--------|
| 1.3.1 | `npx @vercel/agent-eval glm-calibrate-vanilla` 実行 | `cc:DONE` |

結果: **2/9 (22%)** — task-02: 0/3, task-09: 1/3, task-10: 1/3

### 1.4 結果判定

**✅ gap あり: Breezing 100% vs Vanilla 22% (+78%pt)** → Phase 3 に直行

---

## Phase 2: タスク拡張 — DEFERRED

Phase 1 で 78%pt の gap を確認。3 タスクでの統計的検出力は十分。
拡張は将来の追加検証として保留し、Phase 3 に直行する。

| Task | 内容 | Status |
|------|------|--------|
| 2.x | 残り 7 タスクへの validate.ts 追加 | `DEFERRED` |

---

## Phase 3: 本番ベンチマーク ✅ DONE

| Task | 内容 | Status |
|------|------|--------|
| 3.1 | `glm-breezing.ts` / `glm-vanilla.ts` 最終版作成 (3タスク × 5runs) | `cc:DONE` |
| 3.2 | Breezing 条件実行 | `cc:DONE` |
| 3.3 | Vanilla 条件実行 | `cc:DONE` |

### 結果

| 条件 | task-02 | task-09 | task-10 | 合計 |
|------|---------|---------|---------|------|
| **Breezing** | 5/5 (100%) | 5/5 (100%) | 4/5 (80%) | **14/15 (93.3%)** |
| **Vanilla** | 0/5 (0%) | 2/5 (40%) | 1/5 (20%) | **3/15 (20.0%)** |
| **差分** | +100%pt | +60%pt | +60%pt | **+73.3%pt** |

---

## Phase 4: 統計分析 & レポート ✅ DONE

| Task | 内容 | Status |
|------|------|--------|
| 4.1 | `analyze-results.py` 作成・実行 | `cc:DONE` |
| 4.2 | 統計検定（Welch's t, Fisher's exact, Chi-squared） | `cc:DONE` |
| 4.3 | 最終レポート | `cc:DONE` |

### 統計分析結果

| 検定 | 統計量 | p値 | 判定 |
|------|--------|-----|------|
| Welch's t-test | t = 5.82 | p = 0.000003 | *** (p<0.001) |
| Fisher's exact test | — | p = 0.000058 | *** (p<0.001) |
| Chi-squared test | χ² = 13.57 | p = 0.000229 | *** (p<0.001) |

| 効果量 | 値 | 判定 |
|--------|-----|------|
| **Hedges' g** | **2.07** | **Large** (基準: >0.8) |
| **95% CI** | **[49.5%pt, 97.2%pt]** | 全区間が0を大きく超過 |

### 結論

**Breezing 条件は Vanilla 条件に対し統計的に有意に優れている (p < 0.001)**
- パス率改善: +73.3%pt (93.3% vs 20.0%)
- 効果量: Hedges' g = 2.07 (Large)
- validate-and-fix サイクルが実質的な品質改善をもたらす

---

## 技術メモ

### node_modules パッチ (npm install で消える)
- `shared.js`: `AI_GATEWAY.baseUrl` → `https://api.z.ai/api/anthropic`
- `claude-code.js`: `ANTHROPIC_DEFAULT_*_MODEL` env vars をコンテナに pass-through

### .env (agent-eval/)
```
AI_GATEWAY_API_KEY=<GLM_API_KEY>
ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air
ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7
ANTHROPIC_DEFAULT_OPUS_MODEL=glm-4.7
```
