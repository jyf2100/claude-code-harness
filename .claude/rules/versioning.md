# 版本管理规则

Harness 的版本管理基准。遵循 SemVer（Semantic Versioning）。

## 版本判定基准
| 更改类型 | 版本 | 例 |
|-----------|----------|-----|
| 技能定义（SKILL.md）的文案修正・追记 | **patch** (x.y.Z) | 模板微修正、说明文改善 |
| 文档・规则文件的更新 | **patch** (x.y.Z) | CHANGELOG 修改、rules/ 添加 |
| hooks/scripts 的 bug 修正 | **patch** (x.y.Z) | task-completed.sh 的转义修正 |
| 现有技能添加新标志/子命令 | **minor** (x.Y.0) | `--snapshot`、`--auto-mode` |
| 添加新技能/代理/hooks | **minor** (x.Y.0) | 新技能 `harness-foo` |
| TypeScript 护栏引擎的更改 | **minor** (x.Y.0) | 新规则添加、现有规则更改 |
| Claude Code 新版本兼容应对 | **minor** (x.Y.0) | CC v2.1.72 对应 |
| 破坏性更改（旧技能废弃、格式不兼容） | **major** (X.0.0) | Plans.md v1 支持删除 |

## 判断流程图
```
现有行为会破坏吗？
├─ Yes → major
└─ No → 用户能做新的事情吗？
    ├─ Yes → minor
    └─ No → patch
```

## 批量发布建议
- **同日完成多个 Phase 时**: 合并为 1 个 minor 发布
- **Phase 完成 + 文档修正**: Phase 部分为 minor，文档修正同捆（不另发布）
- **CC 兼容应对 + 功能添加**: 可合并为 1 个 minor

### 不好的例子
```
v3.6.0 (03/08 AM) — Phase 25
v3.7.0 (03/08 PM) — Phase 26    ← 同日 2 个 minor 应避免
v3.7.1 (03/09)    — Auto Mode
```

### 好的例子
```
v3.6.0 (03/08) — Phase 25 + Phase 26    ← 合并为 1 个 minor
v3.6.1 (03/09) — Auto Mode 准备         ← prep 是 patch
```

## 发布前检查
1. **列出自上次发布以来的更改**
2. **根据判定基准决定版本类型**
3. **同日的多个更改考虑批量合并**
4. **确认 VERSION / plugin.json / CHANGELOG 的 3 点同步**
5. **确认 git tag 没有缺号且连续**

## 禁止事项
- 删除/回滚标签（已发布版本不可变）
- 同日 2 次以上的 minor 版本升级
- patch 级别的更改进行 minor 版本升级
