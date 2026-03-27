#!/bin/bash
# config-utils.sh
# 从 Harness 配置文件获取值的工具函数
#
# Usage: source "${SCRIPT_DIR}/config-utils.sh"
#        plans_path=$(get_plans_file_path)

# 配置文件的默认路径
CONFIG_FILE="${CONFIG_FILE:-.claude-code-harness.config.yaml}"

# plansDirectory 验证（安全检查）
# 拒绝绝对路径、父目录引用、符号链接逃逸
validate_plans_directory() {
  local value="$1"
  local default="."

  # 空值时返回默认值
  [ -z "$value" ] && echo "$default" && return 0

  # Security: 拒绝绝对路径
  case "$value" in
    /*) echo "$default" && return 0 ;;
  esac

  # Security: 拒绝父目录引用 (..)
  case "$value" in
    *..*)  echo "$default" && return 0 ;;
  esac

  # Security: 检测符号链接逃逸（当 realpath 可用时）
  if command -v realpath >/dev/null 2>&1 && [ -e "$value" ]; then
    local project_root
    local resolved_path
    project_root=$(realpath "." 2>/dev/null) || project_root=$(pwd)
    resolved_path=$(realpath "$value" 2>/dev/null)

    if [ -n "$resolved_path" ]; then
      # 确认解析后的路径在项目根目录内
      case "$resolved_path" in
        "$project_root"/*) ;; # OK: 项目内部
        "$project_root") ;;   # OK: 项目根目录本身
        *) echo "$default" && return 0 ;; # NG: 项目外部
      esac
    fi
  fi

  echo "$value"
}

# 获取 plansDirectory 设置（默认值: "."）
get_plans_directory() {
  local default="."

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "$default"
    return 0
  fi

  local value=""

  # 当 yq 可用时
  if command -v yq >/dev/null 2>&1; then
    value=$(yq -r '.plansDirectory // empty' "$CONFIG_FILE" 2>/dev/null)
  fi

  # yq 无法获取时，尝试 Python
  if [ -z "$value" ] && command -v python3 >/dev/null 2>&1; then
    # 使用 Python 解析 YAML（如果没有 pyyaml 则返回空）
    value=$(python3 - "$CONFIG_FILE" <<'PY' 2>/dev/null
import sys
try:
    import yaml
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f) or {}
    print(data.get('plansDirectory', ''))
except ImportError:
    # pyyaml not installed - return empty to trigger grep fallback
    pass
except:
    pass
PY
)
  fi

  # yq/Python 都无法获取时，使用 grep + sed 回退方案
  if [ -z "$value" ]; then
    value=$(grep "^plansDirectory:" "$CONFIG_FILE" 2>/dev/null | sed 's/^plansDirectory:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")
  fi

  # 验证后返回
  validate_plans_directory "$value"
}

# 获取 Plans.md 的完整路径
get_plans_file_path() {
  local plans_dir
  plans_dir=$(get_plans_directory)

  # 在目录中查找 Plans.md（不区分大小写）
  for f in Plans.md plans.md PLANS.md PLANS.MD; do
    local full_path="${plans_dir}/${f}"
    # "." 时省略 "./"
    [ "$plans_dir" = "." ] && full_path="$f"

    if [ -f "$full_path" ]; then
      echo "$full_path"
      return 0
    fi
  done

  # 未找到时返回默认路径
  local default_path="${plans_dir}/Plans.md"
  [ "$plans_dir" = "." ] && default_path="Plans.md"
  echo "$default_path"
}

# 检查 Plans.md 是否存在
plans_file_exists() {
  local plans_path
  plans_path=$(get_plans_file_path)
  [ -f "$plans_path" ]
}
