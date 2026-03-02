#!/bin/bash
# pre-tool.sh — Harness v3 PreToolUse 薄いシム（5行以内）
# stdin JSON → core エンジン → stdout JSON
node "${CLAUDE_PLUGIN_ROOT}/core/dist/index.js" pre-tool
