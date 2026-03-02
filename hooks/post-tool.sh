#!/bin/bash
# post-tool.sh — Harness v3 PostToolUse 薄いシム（5行以内）
# stdin JSON → core エンジン → stdout JSON
node "${CLAUDE_PLUGIN_ROOT}/core/dist/index.js" post-tool
