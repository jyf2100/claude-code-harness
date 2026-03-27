#!/usr/bin/env bash
#
# install-git-hooks.sh
# Repo-managed git hooks installer (uses core.hooksPath).
#
# Usage:
#   ./scripts/install-git-hooks.sh
#
# Windows:
#   Requires Git for Windows (includes Git Bash).
#   Run from Git Bash, WSL, or PowerShell.
#

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "错误: 不是 Git 仓库"
  exit 1
fi

cd "$ROOT"

if [ ! -d ".githooks" ]; then
  echo "错误: 未找到 .githooks/ 目录"
  exit 1
fi

chmod +x .githooks/pre-commit 2>/dev/null || true

git config core.hooksPath .githooks

echo ""
echo "=== Git Hooks 激活完成 ==="
echo ""
echo "  core.hooksPath = .githooks"
echo ""
echo "  pre-commit:"
echo "    - 编辑 release metadata 时同步 VERSION 和 plugin.json"
echo "    - 普通代码修改不自动 bump version"
echo ""

# Windows 注意事项
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${WINDIR:-}" ]]; then
  echo "  [Windows 注意]"
  echo "    Git hooks 在 Git Bash（Git for Windows 附带）中运行。"
  echo "    如果 hooks 无法运行，请安装 Git for Windows:"
  echo "    https://gitforwindows.org/"
  echo ""
fi

echo "完成！"
