#!/usr/bin/env node
/**
 * run-script.js
 * Windows/Mac/Linux 跨平台 bash 脚本运行器
 *
 * 目的:
 * - 解决 Windows 环境下 ${CLAUDE_PLUGIN_ROOT} 的路径问题
 * - 将 C:\Users\... 转换为 /c/Users/... 格式后传递给 bash
 *
 * 使用方法:
 *   node run-script.js <script-name> [args...]
 *   例: node run-script.js session-init
 *       node run-script.js pretooluse-guard
 *
 * 在 hooks.json 中使用:
 *   "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js session-init"
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// 平台检测
const isWindows = process.platform === 'win32';

/**
 * 将 Windows 路径转换为 MSYS/Git Bash 格式
 * C:\Users\foo → /c/Users/foo
 * \\server\share → //server/share
 */
function toMsysPath(windowsPath) {
  if (!windowsPath) return windowsPath;

  // 将反斜杠转换为正斜杠
  let msysPath = windowsPath.replace(/\\/g, '/');

  // 驱动器字母转换: C:/ → /c/
  const driveMatch = msysPath.match(/^([A-Za-z]):\//);
  if (driveMatch) {
    msysPath = '/' + driveMatch[1].toLowerCase() + msysPath.slice(2);
  }

  return msysPath;
}

/**
 * 检测 bash 可执行文件的路径
 */
function findBash() {
  if (!isWindows) {
    return 'bash';
  }

  // Windows: 查找 Git Bash 的 bash
  const possiblePaths = [
    'C:\\Program Files\\Git\\bin\\bash.exe',
    'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
    process.env.PROGRAMFILES + '\\Git\\bin\\bash.exe',
    process.env['PROGRAMFILES(X86)'] + '\\Git\\bin\\bash.exe',
    'C:\\msys64\\usr\\bin\\bash.exe',
    'C:\\msys32\\usr\\bin\\bash.exe',
  ];

  for (const bashPath of possiblePaths) {
    if (bashPath && fs.existsSync(bashPath)) {
      return bashPath;
    }
  }

  // 回退: 从 PATH 中使用 bash
  return 'bash';
}

/**
 * 主处理函数
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: node run-script.js <script-name> [args...]');
    console.error('Example: node run-script.js session-init');
    process.exit(1);
  }

  const scriptName = args[0];
  const scriptArgs = args.slice(1);

  // 获取脚本目录
  const scriptsDir = __dirname;

  // 构建脚本路径
  let scriptPath = path.join(scriptsDir, scriptName);

  // 如果没有 .sh 扩展名则添加
  if (!scriptPath.endsWith('.sh')) {
    scriptPath += '.sh';
  }

  // 确认脚本存在
  if (!fs.existsSync(scriptPath)) {
    console.error(`Error: Script not found: ${scriptPath}`);
    process.exit(1);
  }

  // 检测 bash 可执行文件
  const bashPath = findBash();

  // Windows 下将路径转换为 MSYS 格式
  let bashScriptPath = scriptPath;
  if (isWindows) {
    bashScriptPath = toMsysPath(scriptPath);
  }

  // 准备环境变量
  const env = { ...process.env };

  if (isWindows) {
    // 禁用 MSYS 路径转换（防止双重转换）
    env.MSYS_NO_PATHCONV = '1';
    env.MSYS2_ARG_CONV_EXCL = '*';

    // 同时转换 CLAUDE_PLUGIN_ROOT
    if (env.CLAUDE_PLUGIN_ROOT) {
      env.CLAUDE_PLUGIN_ROOT = toMsysPath(env.CLAUDE_PLUGIN_ROOT);
    }
  }

  // 执行 bash 脚本
  const child = spawn(bashPath, [bashScriptPath, ...scriptArgs], {
    env,
    stdio: 'inherit',  // 透明转发 stdin/stdout/stderr
    shell: false,
  });

  child.on('error', (err) => {
    console.error(`Failed to execute bash: ${err.message}`);
    if (isWindows) {
      console.error('Hint: Make sure Git Bash is installed');
    }
    process.exit(1);
  });

  child.on('exit', (code, signal) => {
    if (signal) {
      process.exit(1);
    }
    process.exit(code || 0);
  });
}

main();
