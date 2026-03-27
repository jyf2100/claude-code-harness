# 测试套件

本目录包含用于保证 claude-code-harness 插件质量的测试。

## VibeCoder 面向的测试

不是企业级复杂测试，而是**让独自承接客户项目的 VibeCoder** 能简单确认插件正常工作的简易测试。

## 测试运行方法

### 插件结构验证

验证插件的基本结构是否正确：

```bash
./tests/validate-plugin.sh
./tests/validate-plugin-v3.sh
./scripts/ci/check-consistency.sh
```

### Unified Memory 验证

验证共享内存 daemon 的基本运行：

```bash
./tests/test-memory-daemon.sh
```

循环验证是否不会残留僵尸进程：

```bash
./tests/test-memory-daemon-zombie.sh 100
```

验证搜索质量（hybrid ranking / privacy filter / API 路由）：

```bash
./tests/test-memory-search-quality.sh
```

这些验证确认以下内容：

1. **插件结构**: plugin.json 的存在和有效性
2. **命令**: 注册的命令文件是否存在
3. **技能**: 技能定义的存在和基本质量
4. **代理**: 代理定义是否存在
5. **钩子**: hooks.json 的有效性
6. **脚本**: 自动化脚本的存在和执行权限
7. **文档**: README 等必需文档

### 预期输出

```
==========================================
Claude harness - 插件验证测试
==========================================

1. 插件结构验证
----------------------------------------
✓ plugin.json 存在
✓ plugin.json 是有效 JSON
✓ plugin.json 有 name 字段
✓ plugin.json 有 version 字段
...

==========================================
测试结果摘要
==========================================
合格: 25
警告: 1
失败: 0

✓ 所有测试都通过了！
```

## 添加测试

添加新命令或技能时，请运行此测试确认结构正确。

## CI/CD 中的使用

GitHub Actions 中 `.github/workflows/validate-plugin.yml` 执行以下内容：

- `./tests/validate-plugin.sh`
- `./scripts/ci/check-consistency.sh`
- `./tests/test-codex-package.sh`
- `cd core && npm test`

`/harness-work all` 的 success / failure fixture 分为 smoke / full 管理。详情参见 [docs/evidence/work-all.md](../docs/evidence/work-all.md)。

## 故障排除

### 找不到 jq 命令

测试脚本使用 `jq` 命令。未安装时：

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (WSL)
sudo apt-get install jq
```

### 测试失败时

1. 确认错误消息
2. 确认相关文件是否存在
3. 确认 JSON 文件是否有语法错误

## VibeCoder 的要点

- **简单**: 不需要复杂测试框架
- **实用**: 检测实际成为问题的结构错误
- **快速**: 数秒完成
- **易懂**: 结果一目了然

此测试用于在修改插件后快速确认"没有坏掉"。
