#!/usr/bin/env node
/**
 * build-opencode.js
 *
 * 将 Harness 命令转换为 opencode.ai 兼容格式的脚本
 *
 * 转换内容:
 * - commands/ → opencode/commands/ 复制
 * - 从 frontmatter 中删除 description-en
 * - CLAUDE.md → AGENTS.md 生成
 *
 * 使用方法:
 *   node scripts/build-opencode.js
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..');
const COMMANDS_DIR = path.join(ROOT_DIR, 'commands');
const SKILLS_DIR = path.join(ROOT_DIR, 'skills');
const OPENCODE_DIR = path.join(ROOT_DIR, 'opencode');
const OPENCODE_COMMANDS_DIR = path.join(OPENCODE_DIR, 'commands');
const OPENCODE_SKILLS_DIR = path.join(OPENCODE_DIR, 'skills');
const OPENCODE_TEMPLATES_DIR = path.join(ROOT_DIR, 'templates', 'opencode', 'commands');
const OPENCODE_PM_DIR = path.join(OPENCODE_COMMANDS_DIR, 'pm');

/**
 * 递归创建目录
 */
function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

/**
 * 递归清空目录
 */
function clearDir(dir) {
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

/**
 * 解析 frontmatter
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) {
    return { frontmatter: null, body: content };
  }

  const frontmatterStr = match[1];
  const body = content.slice(match[0].length);

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

  return { frontmatter, body };
}

/**
 * 将 frontmatter 转换为字符串
 */
function stringifyFrontmatter(frontmatter) {
  const lines = Object.entries(frontmatter)
    .map(([key, value]) => `${key}: ${value}`);
  return `---\n${lines.join('\n')}\n---\n`;
}

/**
 * 将 Harness 命令转换为 opencode 格式
 */
function convertCommand(content) {
  const { frontmatter, body } = parseFrontmatter(content);

  if (!frontmatter) {
    // 如果没有 frontmatter，直接返回原内容
    return content;
  }

  // 删除 opencode 不需要的字段
  const opencodeFields = ['description-en', 'name'];
  for (const field of opencodeFields) {
    delete frontmatter[field];
  }

  // 如果 frontmatter 变为空
  if (Object.keys(frontmatter).length === 0) {
    return body;
  }

  return stringifyFrontmatter(frontmatter) + body;
}

/**
 * 递归处理目录中的文件
 */
function processDirectory(srcDir, destDir) {
  ensureDir(destDir);

  const entries = fs.readdirSync(srcDir, { withFileTypes: true });
  let processedCount = 0;

  for (const entry of entries) {
    const srcPath = path.join(srcDir, entry.name);
    const destPath = path.join(destDir, entry.name);

    if (entry.isDirectory()) {
      processedCount += processDirectory(srcPath, destPath);
    } else if (entry.name.endsWith('.md')) {
      const content = fs.readFileSync(srcPath, 'utf8');
      const converted = convertCommand(content);
      fs.writeFileSync(destPath, converted);
      processedCount++;
      console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
    }
  }

  return processedCount;
}

/**
 * 生成 AGENTS.md（CLAUDE.md 的完整副本）
 *
 * opencode.ai 将 AGENTS.md 识别为规则文件，
 * 并支持 CLAUDE.md 作为后备。
 * 这里将 CLAUDE.md 的内容直接输出为 AGENTS.md。
 */
function generateAgentsMd() {
  const claudeMdPath = path.join(ROOT_DIR, 'CLAUDE.md');

  if (!fs.existsSync(claudeMdPath)) {
    console.log(`  ⚠ 未找到 CLAUDE.md，跳过 AGENTS.md 生成`);
    return;
  }

  let claudeMdContent = fs.readFileSync(claudeMdPath, 'utf8');

  // 将标题从 CLAUDE.md 转换为 AGENTS.md
  // 匹配 "# CLAUDE.md" 或 "# CLAUDE.md - ..." 的模式
  claudeMdContent = claudeMdContent.replace(
    /^# CLAUDE\.md(\s*-\s*.*)?$/m,
    (match, suffix) => `# AGENTS.md${suffix || ''}`
  );

  // 添加 opencode 兼容的头部
  const header = `<!-- Generated from CLAUDE.md by build-opencode.js -->
<!-- opencode.ai compatible version of Claude Code Harness -->

`;

  const agentsMd = header + claudeMdContent;

  const destPath = path.join(OPENCODE_DIR, 'AGENTS.md');
  fs.writeFileSync(destPath, agentsMd);
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)} (from CLAUDE.md)`);
}

/**
 * 生成 opencode.json 示例
 */
function generateOpencodeJson() {
  const config = {
    "$schema": "https://opencode.ai/config.json",
    "mcp": {
      "harness": {
        "type": "local",
        "enabled": true,
        "command": ["node", "./path/to/claude-code-harness/mcp-server/dist/index.js"]
      }
    }
  };

  const destPath = path.join(OPENCODE_DIR, 'opencode.json');
  fs.writeFileSync(destPath, JSON.stringify(config, null, 2));
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
}

/**
 * 生成 README.md（如果已存在则跳过）
 */
function generateReadme() {
  const destPath = path.join(OPENCODE_DIR, 'README.md');

  // 如果已有 README.md 则跳过
  if (fs.existsSync(destPath)) {
    console.log(`  ⏭ ${path.relative(ROOT_DIR, destPath)} (已存在，跳过)`);
    return;
  }

  const readme = `# Harness for OpenCode

Claude Code Harness 的 opencode.ai 兼容版本。

## 设置

### 1. 将命令和技能复制到项目

\`\`\`bash
# 克隆 Harness
git clone https://github.com/Chachamaru127/claude-code-harness.git

# 复制 opencode 用文件
cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/
cp -r claude-code-harness/opencode/skills/ your-project/.claude/skills/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
\`\`\`

### 2. 设置 MCP 服务器（可选）

\`\`\`bash
# 构建 MCP 服务器
cd claude-code-harness/mcp-server
npm install
npm run build

# 将 opencode.json 复制到项目并调整路径
cp claude-code-harness/opencode/opencode.json your-project/
# 修改 opencode.json 中的路径为实际路径
\`\`\`

### 3. 开始使用

\`\`\`bash
cd your-project
opencode
\`\`\`

## 可用命令

| 命令 | 说明 |
|----------|------|
| \`/harness-init\` | 项目设置 |
| \`/plan-with-agent\` | 创建开发计划 |
| \`/work\` | 执行任务 |
| \`/harness-review\` | 代码审查 |

## 可用技能

opencode.ai 会自动识别 \`.claude/skills/\` 目录中的技能：

| 技能 | 说明 |
|--------|------|
| \`notebookLM\` | 文档生成（NotebookLM YAML、幻灯片） |
| \`impl\` | 功能实现 |
| \`harness-review\` | 代码审查 |
| \`verify\` | 构建验证与错误恢复 |
| \`auth\` | 认证与支付（Clerk, Stripe） |
| \`deploy\` | 部署（Vercel, Netlify） |
| \`ui\` | UI 组件生成 |

## MCP 工具

通过 MCP 服务器可使用以下工具：

| 工具 | 说明 |
|--------|------|
| \`harness_workflow_plan\` | 创建计划 |
| \`harness_workflow_work\` | 执行任务 |
| \`harness_workflow_review\` | 代码审查 |
| \`harness_session_broadcast\` | 会话间通知 |
| \`harness_status\` | 状态确认 |

## 限制

- Harness 插件系统（\`.claude-plugin/\`）在 opencode 中不可用
- 钩子需要在 opencode 端单独设置

## 相关链接

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
`;

  fs.writeFileSync(destPath, readme);
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
}

/**
 * 复制技能（.claude/skills/ 兼容格式）
 *
 * opencode.ai 识别 .claude/skills/<name>/SKILL.md。
 * 直接复制 harness 的技能。
 */
function copySkills() {
  if (!fs.existsSync(SKILLS_DIR)) {
    console.log(`  ⚠ 未找到 skills/ 目录，跳过`);
    return 0;
  }

  // 清空现有技能目录
  clearDir(OPENCODE_SKILLS_DIR);
  ensureDir(OPENCODE_SKILLS_DIR);

  const entries = fs.readdirSync(SKILLS_DIR, { withFileTypes: true });
  let copiedCount = 0;

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const skillName = entry.name;
    const srcSkillDir = path.join(SKILLS_DIR, skillName);
    const destSkillDir = path.join(OPENCODE_SKILLS_DIR, skillName);

    // 跳过测试用、开发用、不支持 opencode 的技能
    const skipSkills = ['breezing'];
    if (skillName.startsWith('test-') || skillName.startsWith('x-') || skipSkills.includes(skillName)) {
      console.log(`  ⏭ ${skillName}/ (开发/测试/不支持的技能，跳过)`);
      continue;
    }

    // 确认 SKILL.md 是否存在
    const skillMdPath = path.join(srcSkillDir, 'SKILL.md');
    if (!fs.existsSync(skillMdPath)) {
      console.log(`  ⏭ ${skillName}/ (无 SKILL.md，跳过)`);
      continue;
    }

    // 递归复制技能目录
    copyDirectoryRecursive(srcSkillDir, destSkillDir);
    copiedCount++;
    console.log(`  ✓ ${skillName}/`);
  }

  return copiedCount;
}

/**
 * 递归复制目录
 */
function copyDirectoryRecursive(src, dest) {
  ensureDir(dest);

  const entries = fs.readdirSync(src, { withFileTypes: true });

  // 排除的目录/文件模式
  const excludePatterns = [
    'CLAUDE.md',           // 自动生成的内存上下文
    'node_modules',        // npm 依赖
    'coverage',            // 测试覆盖率
    '.claude',             // Claude 会话状态
  ];

  // 排除的文件名模式（startsWith）
  const excludePrefixes = [
    'IMPLEMENTATION_',     // 开发中文档
    'TASK_',               // 任务相关文档
  ];

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    // 完全匹配排除
    if (excludePatterns.includes(entry.name)) {
      continue;
    }

    // 前缀排除
    if (excludePrefixes.some(prefix => entry.name.startsWith(prefix))) {
      continue;
    }

    if (entry.isDirectory()) {
      copyDirectoryRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

/**
 * 主处理流程
 */
function main() {
  console.log('🔄 构建 opencode 版本...\n');

  // 清空 opencode 目录
  clearDir(OPENCODE_COMMANDS_DIR);
  clearDir(OPENCODE_SKILLS_DIR);
  ensureDir(OPENCODE_DIR);

  // 转换命令（v2.17.0+: commands/ 已迁移到 Skills，仅当存在时处理）
  console.log('📁 转换命令:');
  let commandCount = 0;
  if (fs.existsSync(COMMANDS_DIR)) {
    const commandEntries = fs.readdirSync(COMMANDS_DIR);
    if (commandEntries.length === 0) {
      console.log('  ⏭ commands/ 为空（v2.17.0+ 已迁移到 skills）');
    } else {
      commandCount = processDirectory(COMMANDS_DIR, OPENCODE_COMMANDS_DIR);
    }
  } else {
    console.log('  ⏭ 未找到 commands/（v2.17.0+ 已迁移到 skills）');
  }

  // 转换 PM 命令（从 templates/opencode/commands/）
  console.log('\n📁 处理 PM 命令（来自 templates/opencode/）:');
  let pmCount = 0;
  if (fs.existsSync(OPENCODE_TEMPLATES_DIR)) {
    pmCount = processDirectory(OPENCODE_TEMPLATES_DIR, OPENCODE_PM_DIR);
    console.log(`   PM 命令: ${pmCount} 个文件`);
  } else {
    console.log('   ⚠ 未找到 templates/opencode/commands/，跳过 PM 命令');
  }

  // 复制技能
  console.log('\n📁 复制技能:');
  const skillCount = copySkills();

  // 生成额外文件
  console.log('\n📄 生成额外文件:');
  generateAgentsMd();
  generateOpencodeJson();
  generateReadme();

  console.log(`\n✅ 完成！`);
  console.log(`   命令: ${commandCount} 个文件`);
  console.log(`   PM 命令: ${pmCount} 个文件`);
  console.log(`   技能: ${skillCount} 个目录`);
  console.log(`   输出: ${path.relative(process.cwd(), OPENCODE_DIR)}/`);
}

main();
