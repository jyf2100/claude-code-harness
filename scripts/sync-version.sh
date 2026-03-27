#!/bin/bash
# sync-version.sh - 同步 release 元数据的 VERSION / plugin.json
#
# 用法:
#   ./scripts/sync-version.sh check    # 检查不一致
#   ./scripts/sync-version.sh sync     # 将 plugin.json 与 VERSION 同步
#   ./scripts/sync-version.sh bump     # 为 release 升级 patch 版本号

set -euo pipefail

VERSION_FILE="VERSION"
PLUGIN_JSON=".claude-plugin/plugin.json"

# 获取当前版本
get_version() {
    cat "$VERSION_FILE" | tr -d '\n'
}

get_plugin_version() {
    grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version": "\([^"]*\)".*/\1/'
}

# 检查版本不一致
check_version() {
    local v1=$(get_version)
    local v2=$(get_plugin_version)

    if [ "$v1" != "$v2" ]; then
        echo "❌ 版本不一致:"
        echo "   VERSION:     $v1"
        echo "   plugin.json: $v2"
        return 1
    else
        echo "✅ 版本一致: $v1"
        return 0
    fi
}

# 将 plugin.json 与 VERSION 同步
sync_version() {
    local version=$(get_version)
    local current=$(get_plugin_version)

    if [ "$version" = "$current" ]; then
        echo "✅ 已同步: $version"
        return 0
    fi

    # 兼容 macOS 和 Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\"version\": \"$current\"/\"version\": \"$version\"/" "$PLUGIN_JSON"
    else
        sed -i "s/\"version\": \"$current\"/\"version\": \"$version\"/" "$PLUGIN_JSON"
    fi

    echo "✅ plugin.json 已更新: $current → $version"
}

# 升级 patch 版本号
bump_version() {
    local current=$(get_version)
    local major=$(echo "$current" | cut -d. -f1)
    local minor=$(echo "$current" | cut -d. -f2)
    local patch=$(echo "$current" | cut -d. -f3)

    local new_patch=$((patch + 1))
    local new_version="$major.$minor.$new_patch"

    echo "$new_version" > "$VERSION_FILE"
    echo "✅ VERSION 已更新: $current → $new_version"

    sync_version
}

# 主函数
case "${1:-check}" in
    check)
        check_version
        ;;
    sync)
        sync_version
        ;;
    bump)
        bump_version
        ;;
    *)
        echo "用法: $0 {check|sync|bump}"
        exit 1
        ;;
esac
