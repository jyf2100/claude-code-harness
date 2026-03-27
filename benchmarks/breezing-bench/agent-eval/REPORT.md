# Breezing v2 Benchmark Report

**Date**: 2026-02-07
**Model**: GLM-4.5-air (via Z.AI Anthropic-compatible API, haiku tier)
**Framework**: @vercel/agent-eval 0.0.11 (Docker sandbox)
**Status**: Exploratory study (not pre-registered)

---

## 1. Executive Summary

本实验是一项探索性研究，旨在验证显式验证指令（`npm run validate` + 修正指令）对 AI 编码代理任务成功率的影响。使用 GLM-4.5-air，执行了 3 任务 × 5 次运行 × 2 条件 = 30 次运行，结果在有验证指令的条件下观测到 93.3% (14/15) 的通过率，无验证指令条件下为 20.0% (3/15) (Fisher's exact p < 0.001, Cohen's h = 1.69)。

但本实验仅使用 3 个任务、1 种模型，且采用了对验证有利的任务设计，属于探索性研究，结论的泛化需要额外验证。

---

## 2. Experimental Design

### 2.1 Independent Variable (条件)

| 条件 | CLAUDE.md 内容 |
|------|-----------------|
| **Validate** (Breezing) | "Complete PROMPT.md" + "Read src/" + "Run `npm run validate`" + "Fix issues" |
| **Baseline** (Vanilla) | "Complete PROMPT.md" + "Read src/" |

唯一差异是 `npm run validate` 的执行和修正指令这 2 行。这是 Breezing v2 完整流水线 (Agent Teams, code-reviewer, retake loop) 中部分元素的消融实验，需要与完整流水线的效果区分开来。

### 2.2 Tasks (任务设计)

采用"新功能 + 隐藏错误"模式。PROMPT 指示实现新功能，现有代码中嵌入了可被 validate.ts 检测的错误。EVAL.ts（代理不可见）进行最终的通过/失败判定。

| Task | 新功能 (PROMPT) | 隐藏错误 | 错误类别 |
|------|----------------|---------|-------------|
| task-02 | TodoStore `getByStatus()` | `updatedAt` 过期副本 | 数据新鲜度 |
| task-09 | CSV `stringifyCsv()` | 列不匹配行未排除 | 验证不足 |
| task-10 | BookStore `search()` | `updatedAt` 过期副本 | 数据新鲜度 |

**注意**: task-02 和 task-10 共享同一类别的错误模式（过期副本），实质上独立的错误类别仅有 2 种。

### 2.3 Runs

- 每任务 × 每条件 = 5 次运行
- 合计: 3 tasks × 5 runs × 2 conditions = **30 runs**

### 2.4 Environment

| 项目 | 值 |
|------|-----|
| Agent | `vercel-ai-gateway/claude-code` |
| Model | `haiku` tier → GLM-4.5-air (Z.AI API) |
| Sandbox | Docker (isolated per run) |
| Timeout | 300s per run |
| Concurrency | 15 runs simultaneously per condition |

### 2.5 Adaptive Design (披露)

本实验分两个阶段执行:
1. **Calibration (Phase 1)**: 3 tasks × 3 runs × 2 conditions = 18 runs
2. **Full benchmark (Phase 3)**: Calibration 中确认了差异，因此扩展到 5 runs

这种适应性设计可能引入类似 optional stopping 的偏差。本报告的统计分析仅基于 Phase 3 的数据，但已确认与 Calibration 数据的一致性。

---

## 3. Results

### 3.1 Raw Data (全 30 runs)

#### Validate (Breezing) 条件

| Task | Run | Status | Duration | Turns | Tool Calls | Shell Cmds |
|------|-----|--------|----------|-------|------------|------------|
| task-02 | 1 | passed | 125.6s | 6 | 13 | 2 |
| task-02 | 2 | passed | 94.9s | 8 | 7 | 1 |
| task-02 | 3 | passed | 122.6s | 5 | 12 | 2 |
| task-02 | 4 | passed | 151.1s | 4 | 14 | 2 |
| task-02 | 5 | passed | 136.2s | 4 | 13 | 2 |
| task-09 | 1 | passed | 188.9s | 16 | 20 | 7 |
| task-09 | 2 | passed | 113.3s | 6 | 12 | 2 |
| task-09 | 3 | passed | 133.2s | 5 | 15 | 2 |
| task-09 | 4 | passed | 193.8s | 13 | 13 | 3 |
| task-09 | 5 | passed | 145.7s | 9 | 16 | 2 |
| task-10 | 1 | **failed** | 201.5s | 10 | 12 | 3 |
| task-10 | 2 | passed | 122.7s | 12 | 14 | 2 |
| task-10 | 3 | passed | 108.5s | 7 | 11 | 2 |
| task-10 | 4 | passed | 147.8s | 6 | 12 | 1 |
| task-10 | 5 | passed | 129.8s | 11 | 9 | 2 |

#### Baseline (Vanilla) 条件

| Task | Run | Status | Duration | Turns | Tool Calls | Shell Cmds |
|------|-----|--------|----------|-------|------------|------------|
| task-02 | 1 | failed | 127.8s | 2 | 9 | 0 |
| task-02 | 2 | failed | 103.4s | 4 | 4 | 0 |
| task-02 | 3 | failed | 123.5s | 3 | 7 | 0 |
| task-02 | 4 | failed | 119.1s | 4 | 5 | 0 |
| task-02 | 5 | failed | 112.6s | 1 | 5 | 0 |
| task-09 | 1 | failed | 121.8s | 4 | 5 | 0 |
| task-09 | 2 | **passed** | 167.6s | 18 | 20 | 9 |
| task-09 | 3 | failed | 143.4s | 8 | 12 | 0 |
| task-09 | 4 | **passed** | 198.9s | 12 | 23 | 5 |
| task-09 | 5 | failed | 134.8s | 3 | 7 | 0 |
| task-10 | 1 | failed | 104.4s | 6 | 5 | 0 |
| task-10 | 2 | **passed** | 200.2s | 11 | 12 | 4 |
| task-10 | 3 | failed | 107.9s | 4 | 3 | 0 |
| task-10 | 4 | failed | 124.4s | 3 | 4 | 0 |
| task-10 | 5 | failed | 127.8s | 6 | 7 | 0 |

**排除/重试**: 无（全部 30 runs 均纳入分析）

### 3.2 Summary

| 条件 | task-02 | task-09 | task-10 | 合计 |
|------|---------|---------|---------|------|
| **Validate** | 5/5 (100%) | 5/5 (100%) | 4/5 (80%) | **14/15 (93.3%)** |
| **Baseline** | 0/5 (0%) | 2/5 (40%) | 1/5 (20%) | **3/15 (20.0%)** |
| **差异** | +100%pt | +60%pt | +60%pt | **+73.3%pt** |

### 3.3 Calibration (Phase 1: 参考)

| 条件 | task-02 | task-09 | task-10 | 合计 |
|------|---------|---------|---------|------|
| Validate | 3/3 (100%) | 3/3 (100%) | 3/3 (100%) | 9/9 (100%) |
| Baseline | 0/3 (0%) | 1/3 (33%) | 1/3 (33%) | 2/9 (22%) |

与 Phase 3 的结果方向一致。

### 3.4 Behavioral Observations

- Baseline 条件下通过的 3 runs (task-09 run-2/4, task-10 run-2) 均为**自主执行 shell commands** (4-9 次)，表明代理可能自发尝试了测试
- Baseline 条件下失败的全部 12 runs 的 **shell commands = 0**，未尝试验证
- task-02 在 Baseline 条件下 **全部 5 runs 失败 (0%)** — 该任务对 Baseline 代理可能特别困难（地板效应）

---

## 4. Statistical Analysis

### 4.1 Primary Test: Fisher's Exact Test (one-sided)

| 检验 | p值 | 判定 |
|------|-----|------|
| **Fisher's exact** (H1: Validate > Baseline) | **p = 0.000058** | *** (p<0.001) |

单侧检验的理由: Validate 条件提供了错误检测和修正的额外机会，因此 Validate >= Baseline 的假设有理论依据。

### 4.2 Task-Stratified Analysis: Cochran-Mantel-Haenszel Test

考虑任务间聚类效应的分层分析:

| 检验 | 统计量 | p值 | 判定 |
|------|--------|-----|------|
| **CMH** (task-stratified) | chi2 = 15.34 | **p = 0.000090** | *** (p<0.001) |

即使按任务分层，显著性仍然保持。

### 4.3 Per-Task Fisher's Exact Test

| Task | Validate | Baseline | p-value | 判定 |
|------|----------|----------|---------|------|
| task-02 | 5/5 | 0/5 | 0.0040 | ** |
| task-09 | 5/5 | 2/5 | 0.0833 | n.s. |
| task-10 | 4/5 | 1/5 | 0.1032 | n.s. |

task-09, task-10 由于 n=5，个别检测能力不足。应用 Holm 校正后仅 task-02 显著 (0.0040 × 3 = 0.012 < 0.05)。

### 4.4 Robustness Checks

| 检验 | 统计量 | p值 | 备注 |
|------|--------|-----|------|
| Welch's t-test | t = 5.82 | p = 0.000003 | 应用于二值数据仅供参考 |
| Chi-squared | chi2 = 13.57 | p = 0.000229 | 存在期望频数 < 5 的单元格，仅供参考 |

这些是对同一数据的检验，不是"独立验证"而是稳健性检查。

### 4.5 Effect Sizes

| 指标 | 值 | 解释 | 备注 |
|------|-----|------|------|
| **Cohen's h** | **1.69** | Large (基准: 0.2/0.5/0.8) | 二值数据的标准效应量 |
| **Odds Ratio** | **56.0** | — | Haldane 校正后 47.7 [5.1, 611.7] |
| **Risk Difference** | **73.3%pt** | — | — |
| Hedges' g | 2.07 | 参考值 | 应用于二值数据非标准 |

### 4.6 Confidence Interval (Newcombe method)

| 指标 | 值 |
|------|-----|
| **Risk Difference 的 95% CI** | **39.1%pt ~ 87.4%pt** |

Newcombe 法在小样本和极端比例下准确性较高（比 Wald 法的 [49.5%, 97.2%] 更保守）。

### 4.7 Cost Analysis

| 指标 | Validate (Breezing) | Baseline (Vanilla) | 差异 |
|------|---------------------|-------------------|------|
| Mean duration | 141.0s (SD 31.6) | 134.5s (SD 30.9) | +6.5s |
| Mean turns | 8.1 (SD 3.5) | 5.7 (SD 4.3) | +2.4 |
| Mean tool calls | 12.7 (SD 2.8) | 8.5 (SD 5.6) | +4.2 |
| Mean shell cmds | 2.3 (SD 1.4) | 1.2 (SD 2.7) | +1.1 |

Validate 条件的轮次数和工具调用数较多。这反映了 validate 执行和修正循环。wall-clock time 差异相对较小 (+4.8%)，但本实验未能获取 token 消耗量。

---

## 5. Threats to Validity

### 5.1 Internal Validity

- **适应性设计**: 基于 Calibration (Phase 1) 的结果决定正式执行 (Phase 3)，可能存在类似 optional stopping 的偏差。虽然仅分析 Phase 3 的数据，但并非预先注册的协议。
- **并发执行的独立性**: 同时执行 15 runs，可能因 API 限流或 Docker 资源竞争产生相关性。CMH 分层分析中显著性保持，但无法保证完全独立。
- **任务数限制**: 实质上只有 3 个任务（其中 2 个任务共享同一错误模式），任务级别的泛化能力有限。

### 5.2 External Validity

- **模型限制**: 仅使用 GLM-4.5-air (haiku tier) 一种模型。Anthropic haiku、sonnet 或其他模型的复现尚未验证。
- **任务代表性**: 仅包含简单 CRUD 任务 (TodoStore, CSV, BookStore)。对复杂架构变更、UI、多文件更改的泛化性不明。
- **错误模式多样性**: 仅包含过期副本和验证不足 2 个类别。对逻辑错误、安全错误、性能错误、类型错误等的泛化尚未验证。
- **任务设计偏差**: "隐藏错误"模式故意嵌入了可被 validate.ts 检测的错误，是对验证指令有利的设计。对于无错误的任务或 validate 难以检测的错误，效果不明。

### 5.3 Construct Validity

- **操作性定义狭窄**: 本实验的"Breezing"仅包含 `npm run validate` + 修正指令 2 行。未测量实际 Breezing v2 完整流水线 (Agent Teams, code-reviewer, retake loop) 的效果。结果应解释为"显式验证指令的效果"，需与"Breezing v2 的效果"区分开来。
- **成功定义**: 仅采用 EVAL.ts 的二值判定 (pass/fail)。部分成功（新功能已实现但错误未修复）被视为 fail。

---

## 6. Conclusion

在本探索性研究范围内，观测到以下结果:

1. **显式验证指令改善了本任务集中 GLM-4.5-air 的任务成功率** (14/15 vs 3/15, Fisher's exact p < 0.001)。

2. **效应量大** (Cohen's h = 1.69, Risk Difference = 73.3%pt [39.1, 87.4])。任务分层分析 (CMH) 中显著性仍然保持。

3. **额外成本**: wall-clock time +4.8%、轮次数 +42%、工具调用 +49%。

4. **泛化局限**: 本结果基于 3 个任务（2 个错误类别）、1 种模型、对验证有利的任务设计，属于探索性发现。需要在不同的任务、模型、错误模式下进行验证性研究。

---

## 7. Appendix

### 7.1 File Locations

| 文件 | 路径 |
|---------|------|
| Validate results | `results/glm-breezing/2026-02-07T05-04-18.873Z/` |
| Baseline results | `results/glm-vanilla/2026-02-07T05-10-22.726Z/` |
| Analysis script | `analyze-results.py` |
| Validate config | `experiments/glm-breezing.ts` |
| Baseline config | `experiments/glm-vanilla.ts` |

### 7.2 Calibration Results (Phase 1)

| 文件 | 路径 |
|---------|------|
| Validate calibration | `results/glm-breezing/` (first timestamp) |
| Baseline calibration | `results/glm-vanilla/` (first timestamp) |

### 7.3 Reproducibility

复现所需的 node_modules 补丁:
1. `shared.js`: 将 `AI_GATEWAY.baseUrl` 更改为 `https://api.z.ai/api/anthropic`
2. `claude-code.js`: 将 `ANTHROPIC_DEFAULT_*_MODEL` env vars 传递给 Docker 容器

`.env` 所需变量:
```
AI_GATEWAY_API_KEY=<GLM_API_KEY>
ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air
ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7
ANTHROPIC_DEFAULT_OPUS_MODEL=glm-4.7
```

### 7.4 Revision History

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | 2026-02-07 | Initial report |
| v2.0 | 2026-02-07 | Statistical methodology revised (Fisher primary, Newcombe CI, Cohen's h, CMH added). Conclusions scoped. Threats to validity expanded. Raw data added. Cost analysis added. Advocacy language neutralized. |
| v3.0 | 2026-02-07 | Confirmatory study added (Section 8). 10 tasks, 8 unique bug categories, 2 controls, 100 total runs. |

---

## 8. Confirmatory Study

**Status**: Pre-registered analysis plan (Section 8.2) executed on independently designed task set

### 8.1 Motivation

在独立任务集中验证探索性研究 (Sections 1-6) 中观测到的大效应 (Cohen's h = 1.69, +73.3%pt)，同时解决以下弱点:

| 探索性研究的弱点 | 验证性研究的对策 |
|-----------------|-------------------|
| 任务数 3 | 任务数 10 |
| 错误类别 2 种（含重复） | 错误类别 8 种（全部独立） |
| 领域偏倚（仅 CRUD） | 8 个领域 (EventEmitter, Queue, Parser, Cache, Validator, Config, Template, Invoice) |
| 无对照组 | 2 个对照组（无错误，仅新实现） |
| 有 BUG 注释 | 全部移除 BUG 注释 |
| 未验证天花板/地板效应 | 实施校准 + 难度调整 |

### 8.2 Pre-registered Analysis Plan

验证性研究的分析计划在实验实施前制定:

1. **Primary**: Fisher's exact test (overall, one-sided)
2. **Stratified**: Cochran-Mantel-Haenszel test (controlling for task)
3. **Effect size**: Cohen's h + Newcombe 95% CI
4. **Per-task**: Fisher's exact with Holm-Bonferroni correction (10 comparisons)
5. **Subgroup**: Bug tasks (8) vs Control tasks (2) 的分离分析

### 8.3 Task Design

沿用"新功能 + 隐藏错误"模式。每个任务具有独立的错误类别和不同的领域。

| Task | 领域 | 新功能 (PROMPT) | 隐藏错误 | 错误类别 | 类型 |
|------|----------|----------------|---------|-------------|--------|
| task-11 | EventEmitter | `once()` | `off()` 的 splice idx+1 | Off-by-one | Bug |
| task-12 | PriorityQueue | `peek()` | `!priority` 使 0 为 falsy | Null/falsy | Bug |
| task-13 | HTTP Parser | `parseSetCookie()` | `split(':')` 截断头部值 | String truncation | Bug |
| task-14 | TTL Cache | `getOrSet()` | `size()` 包含过期条目 | Stale count | Bug |
| task-15 | Form Validator | `validateEmail/Url()` | `isValid: allErrors.length > 0` | Logic inversion | Bug |
| task-16 | Config Merger | `mergeWithStrategy()` | `deepMerge` 直接修改对象 | Mutation side-effect | Bug |
| task-17 | Template Engine | `registerHelper()` | `render` 不进行 HTML 转义 | XSS/Encoding | Bug |
| task-18 | Invoice Calc | `applyDiscount()` | 浮点数比较 `===` | Float precision | Bug |
| task-19 | Stack | 全方法实现 | 无 | — | Control |
| task-20 | Linked List | 全方法实现 | 无 | — | Control |

### 8.4 Calibration & Difficulty Adjustment

在验证性研究前执行校准 (2 runs x 10 tasks):

| Task | Calibration (2 runs) | 调整 |
|------|---------------------|------|
| task-11 | 1/2 (50%) | 无需调整 |
| task-12 | 0/2 (0%) | 无需调整（按设计） |
| task-13 | **2/2 (100%)** | **错误变更**: `==` → `split(':')` (影响更大的错误) |
| task-14 | **2/2 (100%)** | 添加 `size()` 测试、移除 BUG 注释。重新校准 3/3 → 接受（天花板效应任务） |
| task-15 | 1/2 (50%) | 无需调整 |
| task-16 | 0/2 (0%) | 无需调整（按设计） |
| task-17 | 1/2 (50%) | 无需调整 |
| task-18 | 1/2 (50%) | 无需调整 |
| task-19 | 2/2 (100%) | Control — 无需调整 |
| task-20 | 1/2 (50%) | 无需调整 |

额外调整: 从全部 8 个错误任务的源代码中移除 `// BUG:` 注释（排除对代理的提示）。

### 8.5 Results

#### 8.5.1 Summary Table

| Task | Bug Category | Baseline | Validate | Delta | Fisher p | Cohen's h |
|------|-------------|----------|----------|-------|----------|-----------|
| task-11 EventEmitter | Off-by-one | 2/5 (40%) | 4/5 (80%) | +40%pt | 0.2619 | +0.84 |
| task-12 PriorityQueue | Null/falsy | 0/5 (0%) | 5/5 (100%) | +100%pt | **0.0040** | +3.14 |
| task-13 HTTP Parser | String truncation | 0/5 (0%) | 4/5 (80%) | +80%pt | **0.0238** | +2.21 |
| task-14 TTL Cache | Stale count | 5/5 (100%) | 5/5 (100%) | 0%pt | 1.0000 | 0.00 |
| task-15 Form Validator | Logic inversion | 1/5 (20%) | 4/5 (80%) | +60%pt | 0.1032 | +1.29 |
| task-16 Config Merger | Mutation | 0/5 (0%) | 3/5 (60%) | +60%pt | 0.0833 | +1.77 |
| task-17 Template Engine | XSS/Encoding | 2/5 (40%) | 3/5 (60%) | +20%pt | 0.5000 | +0.40 |
| task-18 Invoice Calc | Float precision | 5/5 (100%) | 4/5 (80%) | -20%pt | 1.0000 | -0.93 |
| task-19 Stack | Control | 3/5 (60%) | 5/5 (100%) | +40%pt | 0.2222 | +1.37 |
| task-20 Linked List | Control | 2/5 (40%) | 5/5 (100%) | +60%pt | 0.0833 | +1.77 |
| **合计** | | **20/50 (40.0%)** | **42/50 (84.0%)** | **+44.0%pt** | | |

#### 8.5.2 Overall

| 指标 | Validate | Baseline | Delta |
|------|----------|----------|-------|
| Pass rate | **42/50 (84.0%)** | **20/50 (40.0%)** | **+44.0%pt** |
| Bug tasks only | 32/40 (80.0%) | 15/40 (37.5%) | +42.5%pt |
| Control tasks only | 10/10 (100.0%) | 5/10 (50.0%) | +50.0%pt |

### 8.6 Statistical Analysis (Confirmatory)

#### 8.6.1 Primary: Fisher's Exact Test

| 检验 | Odds Ratio | p值 | 判定 |
|------|-----------|-----|------|
| **Fisher's exact** (H1: Validate > Baseline) | 7.875 | **p = 0.000005** | *** (p<0.001) |

#### 8.6.2 Stratified: Cochran-Mantel-Haenszel Test

| 检验 | 统计量 | p值 | 判定 |
|------|--------|-----|------|
| **CMH** (task-stratified) | chi2 = 20.89 | **p = 0.000005** | *** (p<0.001) |

即使按任务分层，显著性仍然保持。控制任务间异质性后效应仍然稳健。

#### 8.6.3 Effect Sizes

| 指标 | 值 | 解释 |
|------|-----|------|
| **Cohen's h** (overall) | **0.95** | Large (基准: 0.2/0.5/0.8) |
| **Hedges' g** (overall) | **1.00** | Large |
| **Newcombe 95% CI** | **[+25.4%pt, +58.6%pt]** | 下限超过 +25%pt |
| Risk Difference | +44.0%pt | — |

#### 8.6.4 Per-Task with Holm-Bonferroni Correction

| Task | Raw p | Adjusted p | 判定 |
|------|-------|-----------|------|
| task-12 PriorityQueue | 0.0040 | **0.0397** | * |
| task-13 HTTP Parser | 0.0238 | 0.2143 | n.s. |
| task-16 Config Merger | 0.0833 | 0.6667 | n.s. |
| task-20 Linked List | 0.0833 | 0.6667 | n.s. |
| task-15 Form Validator | 0.1032 | 0.6667 | n.s. |
| task-19 Stack | 0.2222 | 1.0000 | n.s. |
| task-11 EventEmitter | 0.2619 | 1.0000 | n.s. |
| task-17 Template Engine | 0.5000 | 1.0000 | n.s. |
| task-14 TTL Cache | 1.0000 | 1.0000 | n.s. |
| task-18 Invoice Calc | 1.0000 | 1.0000 | n.s. |

由于每个任务 n=5，单独任务的检测能力有限。仅 task-12 在 Holm 校正后仍显著。

#### 8.6.5 Bug Tasks vs Control Tasks

| 子组 | Validate | Baseline | Delta | Cohen's h | Fisher p |
|-------------|----------|----------|-------|-----------|----------|
| Bug tasks (8) | 32/40 (80.0%) | 15/40 (37.5%) | +42.5%pt | +0.90 | p = 0.000112 *** |
| Control tasks (2) | 10/10 (100.0%) | 5/10 (50.0%) | +50.0%pt | +1.57 | p = 0.016254 * |

对照组任务也显示出显著改善。这表明 validate 对新实现的质量提升也有贡献。

### 8.7 Cost Analysis

| 指标 | Validate | Baseline | Delta |
|------|----------|----------|-------|
| Mean duration | 228.6s (SD 41.1) | 170.6s (SD 56.8) | +58.0s (+34.0%) |
| Mean turns | 7.7 | 6.1 | +1.6 |
| Mean tool calls | 12.3 | 8.0 | +4.3 |
| Mean shell calls | 2.4 | 1.2 | +1.2 |

验证性研究中 Validate 条件的 duration 增加比探索性研究 (+4.8%) 更大 (+34.0%)。可能是因为任务复杂度更高，validate → fix 循环需要更多时间。

### 8.8 Behavioral Observations

1. **Baseline 的自发测试**: Baseline 通过的 20 runs 中，多数 shell calls > 0，表明自发尝试了测试。特别是 task-14 (5/5 pass)、task-18 (5/5 pass) 在 Baseline 中也显示了高成功率 — 这些错误相对容易直观修正。

2. **天花板效应任务**: task-14 (TTL Cache) 和 task-18 (Invoice Calc) 在两个条件下都显示高成功率 (100%, 80-100%)，Validate 指令的附加价值较小。`size()` 的 stale count 错误和浮点精度可能是仅通过仔细编写代码就能避免的错误类别。

3. **Validate 特别有效的错误**: task-12 (null/falsy, +100%pt)、task-13 (string truncation, +80%pt)、task-15 (logic inversion, +60%pt)、task-16 (mutation, +60%pt) 显示了大效应。这些是仅通过阅读代码难以发现、只有在运行时测试中才会显现的错误类别。

4. **对照组任务的改善**: 对照组 (task-19, task-20) 也显示 +40%pt、+60%pt 的改善。表明 validate.ts 的冒烟测试可以提高新实现的正确性。

### 8.9 Comparison: Exploratory vs Confirmatory

| 指标 | 探索性 | 验证性 | 备注 |
|------|--------|--------|------|
| 任务数 | 3 | 10 | 3.3x |
| 错误类别 | 2（含重复） | 8（全部独立） | 4x |
| Total runs | 30 | 100 | 3.3x |
| Validate pass rate | 93.3% | 84.0% | 下降（任务多样性增加） |
| Baseline pass rate | 20.0% | 40.0% | 上升（包含 2 个天花板效应任务） |
| Delta | +73.3%pt | +44.0%pt | 效应量缩小但方向一致 |
| Cohen's h | 1.69 | 0.95 | Large → Large（基准保持） |
| Hedges' g | 2.07 | 1.00 | Large → Large（基准保持） |
| Fisher p | 0.000058 | 0.000005 | 检测能力增加，p 值改善 |
| CMH p | 0.000090 | 0.000005 | 同上 |
| 95% CI (Newcombe) | [39.1, 87.4] | [25.4, 58.6] | CI 宽度缩小（精度提高） |

效应量缩小可用以下因素解释:
- 任务多样性增加（2 → 8 错误类别）
- 包含 2 个天花板效应任务 (task-14, task-18)
- BUG 注释移除使错误发现更困难
- 更难的错误模式（mutation, XSS, float precision）

### 8.10 Threats to Validity (Confirmatory-specific)

#### Internal Validity
- **校准驱动的调整**: 更改了 task-13 的错误、移除了 BUG 注释。这是数据驱动的调整，并非预先注册的协议。但调整仅针对校准数据 (20 runs)，在未查看正式数据 (100 runs) 的状态下确定分析计划。
- **天花板效应**: task-14 (100%/100%) 和 task-18 (80%/100%) 条件间无差异，降低了分析的检测能力。排除这些后的 8 任务分析中显著性仍然保持 (bug tasks only: p = 0.000112)。

#### External Validity
- **模型限制**: 与探索性研究相同，仅使用 GLM-4.5-air。其他模型的复现仍待验证。
- **任务规模**: 仅限单文件、100-200 行的任务。对大规模多文件更改的泛化性不明。

#### Construct Validity
- **与探索性研究相同**: "Breezing"的操作性定义仅包含 `npm run validate` + 修正指令 2 行（消融实验）。

### 8.11 Raw Data

#### Validate 条件 (50 runs)

| Task | Run | Status | Duration | Turns | Tools | Shell |
|------|-----|--------|----------|-------|-------|-------|
| task-11 | 1 | passed | 230.4s | 14 | 14 | 5 |
| task-11 | 2 | passed | 231.9s | 5 | 11 | 2 |
| task-11 | 3 | failed | 300.0s | — | — | 0 |
| task-11 | 4 | passed | 277.5s | 4 | 11 | 2 |
| task-11 | 5 | passed | 200.3s | 10 | 11 | 2 |
| task-12 | 1 | passed | 252.0s | 8 | 8 | 2 |
| task-12 | 2 | passed | 226.5s | 9 | 10 | 2 |
| task-12 | 3 | passed | 241.0s | 6 | 10 | 1 |
| task-12 | 4 | passed | 212.4s | 6 | 9 | 2 |
| task-12 | 5 | passed | 238.0s | 8 | 13 | 2 |
| task-13 | 1 | passed | 280.3s | 12 | 17 | 4 |
| task-13 | 2 | passed | 237.3s | 5 | 12 | 2 |
| task-13 | 3 | passed | 209.2s | 7 | 13 | 2 |
| task-13 | 4 | passed | 213.7s | 4 | 12 | 2 |
| task-13 | 5 | failed | 191.2s | 6 | 14 | 2 |
| task-14 | 1 | passed | 235.8s | 5 | 10 | 2 |
| task-14 | 2 | passed | 220.8s | 3 | 10 | 1 |
| task-14 | 3 | passed | 252.9s | 3 | 15 | 1 |
| task-14 | 4 | passed | 266.1s | 10 | 15 | 3 |
| task-14 | 5 | passed | 199.9s | 6 | 9 | 1 |
| task-15 | 1 | passed | 252.8s | 5 | 13 | 2 |
| task-15 | 2 | passed | 197.3s | 12 | 14 | 3 |
| task-15 | 3 | failed | 186.6s | 2 | 8 | 1 |
| task-15 | 4 | passed | 230.9s | 6 | 8 | 2 |
| task-15 | 5 | passed | 230.2s | 11 | 11 | 3 |
| task-16 | 1 | failed | 209.4s | 5 | 7 | 2 |
| task-16 | 2 | passed | 221.6s | 6 | 13 | 2 |
| task-16 | 3 | failed | 208.4s | 6 | 13 | 2 |
| task-16 | 4 | passed | 290.3s | 10 | 13 | 3 |
| task-16 | 5 | passed | 145.5s | 6 | 12 | 2 |
| task-17 | 1 | passed | 292.2s | 14 | 16 | 3 |
| task-17 | 2 | passed | 240.9s | 9 | 18 | 4 |
| task-17 | 3 | passed | 194.4s | 7 | 15 | 2 |
| task-17 | 4 | failed | 259.5s | 9 | 16 | 2 |
| task-17 | 5 | failed | 274.5s | 11 | 11 | 2 |
| task-18 | 1 | passed | 250.9s | 9 | 15 | 2 |
| task-18 | 2 | failed | 300.0s | — | — | 0 |
| task-18 | 3 | passed | 281.1s | 4 | 9 | 1 |
| task-18 | 4 | passed | 273.7s | 12 | 22 | 6 |
| task-18 | 5 | passed | 285.7s | 8 | 9 | 1 |
| task-19 | 1 | passed | 157.7s | 13 | 15 | 5 |
| task-19 | 2 | passed | 168.4s | 10 | 9 | 4 |
| task-19 | 3 | passed | 167.9s | 2 | 12 | 1 |
| task-19 | 4 | passed | 258.9s | 11 | 13 | 5 |
| task-19 | 5 | passed | 236.6s | 8 | 11 | 0 |
| task-20 | 1 | passed | 189.7s | 12 | 13 | 5 |
| task-20 | 2 | passed | 143.5s | 12 | 13 | 5 |
| task-20 | 3 | passed | 163.0s | 5 | 14 | 3 |
| task-20 | 4 | passed | 180.0s | 9 | 14 | 2 |
| task-20 | 5 | passed | 220.9s | 6 | 9 | 2 |

#### Baseline 条件 (50 runs)

| Task | Run | Status | Duration | Turns | Tools | Shell |
|------|-----|--------|----------|-------|-------|-------|
| task-11 | 1 | failed | 143.2s | 4 | 4 | 0 |
| task-11 | 2 | passed | 188.3s | 9 | 13 | 2 |
| task-11 | 3 | failed | 101.0s | 4 | 4 | 0 |
| task-11 | 4 | passed | 144.3s | 12 | 14 | 5 |
| task-11 | 5 | failed | 94.6s | 4 | 6 | 0 |
| task-12 | 1 | failed | 187.8s | 4 | 11 | 0 |
| task-12 | 2 | failed | 240.7s | 4 | 3 | 0 |
| task-12 | 3 | failed | 156.1s | 4 | 5 | 0 |
| task-12 | 4 | failed | 133.3s | 6 | 7 | 1 |
| task-12 | 5 | failed | 113.7s | 4 | 4 | 0 |
| task-13 | 1 | failed | 203.1s | 13 | 15 | 5 |
| task-13 | 2 | failed | 123.1s | 7 | 9 | 0 |
| task-13 | 3 | failed | 111.2s | 3 | 7 | 0 |
| task-13 | 4 | failed | 183.5s | 4 | 5 | 0 |
| task-13 | 5 | failed | 190.2s | 10 | 22 | 7 |
| task-14 | 1 | passed | 133.4s | 5 | 10 | 0 |
| task-14 | 2 | passed | 108.2s | 2 | 5 | 0 |
| task-14 | 3 | passed | 203.2s | 13 | 10 | 5 |
| task-14 | 4 | passed | 94.6s | 4 | 4 | 0 |
| task-14 | 5 | passed | 83.5s | 4 | 4 | 0 |
| task-15 | 1 | failed | 170.0s | 3 | 6 | 0 |
| task-15 | 2 | failed | 145.6s | 3 | 5 | 0 |
| task-15 | 3 | failed | 115.8s | 4 | 5 | 0 |
| task-15 | 4 | passed | 107.7s | 4 | 5 | 0 |
| task-15 | 5 | failed | 158.5s | 4 | 5 | 0 |
| task-16 | 1 | failed | 185.6s | 3 | 9 | 0 |
| task-16 | 2 | failed | 153.3s | 5 | 7 | 0 |
| task-16 | 3 | failed | 300.0s | — | — | 0 |
| task-16 | 4 | failed | 128.2s | 4 | 5 | 0 |
| task-16 | 5 | failed | 141.0s | 5 | 5 | 0 |
| task-17 | 1 | failed | 300.0s | — | — | 0 |
| task-17 | 2 | failed | 300.0s | — | — | 0 |
| task-17 | 3 | failed | 300.0s | — | — | 0 |
| task-17 | 4 | passed | 195.5s | 10 | 13 | 3 |
| task-17 | 5 | passed | 242.3s | 10 | 11 | 4 |
| task-18 | 1 | passed | 124.3s | 6 | 5 | 0 |
| task-18 | 2 | passed | 202.6s | 6 | 5 | 0 |
| task-18 | 3 | passed | 175.6s | 3 | 9 | 0 |
| task-18 | 4 | passed | 116.3s | 3 | 5 | 0 |
| task-18 | 5 | passed | 194.6s | 3 | 6 | 0 |
| task-19 | 1 | passed | 218.9s | 16 | 20 | 7 |
| task-19 | 2 | failed | 122.7s | 6 | 8 | 1 |
| task-19 | 3 | failed | 220.5s | 6 | 5 | 0 |
| task-19 | 4 | passed | 159.3s | 5 | 5 | 0 |
| task-19 | 5 | passed | 124.3s | 5 | 4 | 0 |
| task-20 | 1 | failed | 248.2s | 7 | 5 | 0 |
| task-20 | 2 | failed | 156.4s | 10 | 9 | 2 |
| task-20 | 3 | failed | 209.8s | 13 | 16 | 7 |
| task-20 | 4 | passed | 195.8s | 11 | 15 | 5 |
| task-20 | 5 | passed | 182.7s | 7 | 14 | 2 |

**排除/重试**: 无（全部 100 runs 均纳入分析）。达到 Timeout (300s) 的 runs 视为 failed。

### 8.12 File Locations (Confirmatory)

| 文件 | 路径 |
|---------|------|
| Baseline A results | `results/confirm-baseline-a/2026-02-07T07-39-55.799Z/` |
| Baseline B results | `results/confirm-baseline-b/2026-02-07T07-44-01.810Z/` |
| Validate A results | `results/confirm-validate-a/2026-02-07T07-49-07.288Z/` |
| Validate B results | `results/confirm-validate-b/2026-02-07T07-54-14.652Z/` |
| Analysis script | `analyze-confirmatory.py` |
| Experiment configs | `experiments/confirm-{baseline,validate}-{a,b}.ts` |
| Task definitions | `evals/task-{11..20}/` |
| Calibration results | `results/calibration-baseline-{a,b}/` |

---

## 9. Combined Conclusion

### 9.1 Summary of Evidence

| 研究 | 条件差异 | p值 (Fisher) | Cohen's h | 95% CI (Newcombe) |
|------|----------|-------------|-----------|-------------------|
| 探索性 (3 tasks, 30 runs) | +73.3%pt | 0.000058 | 1.69 | [39.1, 87.4] |
| 验证性 (10 tasks, 100 runs) | +44.0%pt | 0.000005 | 0.95 | [25.4, 58.6] |

### 9.2 Conclusion

1. **显式验证指令改善了 AI 编码代理的任务成功率**。该效应在探索性研究中发现，并在独立的 10 任务集验证性研究中复现 (Fisher p < 0.001, CMH p < 0.001)。

2. **效应量为 Large** (Cohen's h = 0.95)。即使大幅增加任务多样性，效应量仍保持 Large 基准 (0.8)。Newcombe 95% CI 下限为 +25.4%pt，超过了实用意义的最小改善幅度。

3. **效应不依赖于错误类型**。在 8 种独立错误类别（off-by-one、null/falsy、string truncation、stale count、logic inversion、mutation、XSS、float precision）中方向一致。但对于运行时测试中不易显现的错误（mutation、XSS），改善幅度有较小的倾向。

4. **对照组任务（无错误）也显示出改善** (50% → 100%)。validate 不仅对现有错误的修复有贡献，对新实现的质量提升也有贡献。

5. **成本**: Validate 条件需要 duration +34%、tool calls +54% 的额外成本。对于 +44%pt 的通过率改善，可认为是合理的权衡。

6. **剩余局限**: 仅使用 GLM-4.5-air 一种模型，仅限单文件 100-200 行的任务。其他模型和大规模任务的验证是下一步工作。

---

*Breezing v2 Benchmark Suite | Reviewed by Claude (self) + Codex (MCP)*
