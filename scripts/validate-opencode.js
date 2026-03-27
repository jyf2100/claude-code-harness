#!/usr/bin/env node
/**
 * validate-opencode.js
 *
 * 验证为 opencode 转换的文件是否为正确格式
 *
 * 验证内容:
 * - frontmatter 中是否包含 opencode 不支持的字段
 * - 必需文件是否存在
 * - JSON 文件是否有效
 *
 * 使用方法:
 *   node scripts/validate-opencode.js
 *
 * 退出码:
 *   0: 验证成功
 *   1: 验证失败
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..');
const OPENCODE_DIR = path.join(ROOT_DIR, 'opencode');

// opencode 中无效的 frontmatter 字段
const INVALID_FIELDS = ['description-en', 'name'];

// 必需文件（v2.17.0+: commands 已迁移到 Skills，skills 为必需）
const REQUIRED_FILES = [
  'opencode/AGENTS.md',
  'opencode/opencode.json',
  'opencode/README.md',
  'opencode/skills',  // Skills are now the primary mechanism
];

let errors = [];
let warnings = [];

/**
 * 解析 frontmatter
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) {
    return null;
  }

  const frontmatterStr = match[1];
  const frontmatter = {};
  const lines = frontmatterStr.split('\n');

  for (const line of lines) {
    const colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim();
      const value = line.slice(colonIndex + 1).trim();
      frontmatter[key] = value;
    }
  }

  return frontmatter;
}

/**
 * 验证命令文件
 */
function validateCommandFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const frontmatter = parseFrontmatter(content);
  const relativePath = path.relative(ROOT_DIR, filePath);

  if (!frontmatter) {
    // 没有 frontmatter 的文件仅警告
    warnings.push(`${relativePath}: No frontmatter found`);
    return;
  }

  // 检查无效字段
  for (const field of INVALID_FIELDS) {
    if (frontmatter[field]) {
      errors.push(`${relativePath}: Invalid field '${field}' found in frontmatter`);
    }
  }

  // 没有 description 时警告
  if (!frontmatter.description) {
    warnings.push(`${relativePath}: Missing 'description' field`);
  }
}

/**
 * 递归验证目录内的文件
 */
function validateDirectory(dir) {
  if (!fs.existsSync(dir)) {
    errors.push(`Directory not found: ${path.relative(ROOT_DIR, dir)}`);
    return;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      validateDirectory(fullPath);
    } else if (entry.name.endsWith('.md')) {
      validateCommandFile(fullPath);
    }
  }
}

/**
 * 验证 JSON 文件
 */
function validateJsonFile(filePath) {
  const relativePath = path.relative(ROOT_DIR, filePath);

  if (!fs.existsSync(filePath)) {
    errors.push(`File not found: ${relativePath}`);
    return;
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    JSON.parse(content);
  } catch (e) {
    errors.push(`${relativePath}: Invalid JSON - ${e.message}`);
  }
}

/**
 * 确认必需文件的存在
 */
function validateRequiredFiles() {
  for (const file of REQUIRED_FILES) {
    const fullPath = path.join(ROOT_DIR, file);
    if (!fs.existsSync(fullPath)) {
      errors.push(`Required file/directory not found: ${file}`);
    }
  }
}

/**
 * 验证 opencode.json 的结构
 */
function validateOpencodeConfig() {
  const configPath = path.join(OPENCODE_DIR, 'opencode.json');

  if (!fs.existsSync(configPath)) {
    return; // 已在必需文件检查中输出错误
  }

  try {
    const content = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(content);

    // 确认 $schema 存在
    if (!config.$schema) {
      warnings.push('opencode/opencode.json: Missing $schema field');
    }

    // 确认 mcp 设置存在
    if (config.mcp && config.mcp.harness) {
      const harness = config.mcp.harness;
      if (harness.type !== 'local' && harness.type !== 'remote') {
        errors.push('opencode/opencode.json: Invalid mcp.harness.type (must be "local" or "remote")');
      }
    }
  } catch (e) {
    // JSON 解析错误已输出
  }
}

/**
 * 主处理函数
 */
function main() {
  console.log('🔍 Validating opencode files...\n');

  // 确认必需文件存在
  console.log('📁 Checking required files...');
  validateRequiredFiles();

  // 验证命令文件
  console.log('📄 Validating command files...');
  const commandsDir = path.join(OPENCODE_DIR, 'commands');
  if (fs.existsSync(commandsDir)) {
    validateDirectory(commandsDir);
  }

  // 验证 JSON 文件
  console.log('📋 Validating JSON files...');
  validateJsonFile(path.join(OPENCODE_DIR, 'opencode.json'));
  validateOpencodeConfig();

  // 输出结果
  console.log('\n' + '='.repeat(50));

  if (warnings.length > 0) {
    console.log('\n⚠️  Warnings:');
    for (const warning of warnings) {
      console.log(`   ${warning}`);
    }
  }

  if (errors.length > 0) {
    console.log('\n❌ Errors:');
    for (const error of errors) {
      console.log(`   ${error}`);
    }
    console.log(`\n❌ Validation failed with ${errors.length} error(s).`);
    process.exit(1);
  }

  console.log('\n✅ Validation passed!');
  if (warnings.length > 0) {
    console.log(`   (${warnings.length} warning(s))`);
  }
  process.exit(0);
}

main();
