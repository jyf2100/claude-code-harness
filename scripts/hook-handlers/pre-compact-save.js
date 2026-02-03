#!/usr/bin/env node
/**
 * pre-compact-save.js
 * PreCompact hook for saving critical session context before compaction
 *
 * Usage (from hooks.json):
 *   "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/hook-handlers/pre-compact-save.js\""
 *
 * Environment variables:
 *   CLAUDE_SESSION_ID - Current session ID
 *
 * Output:
 *   Saves precompact-snapshot.json to .claude/state/
 */

const fs = require('fs');
const path = require('path');

// Configuration
const SNAPSHOT_VERSION = '1.0.0';
const GIT_TIMEOUT_MS = 5000;

/**
 * Log to stderr (non-blocking)
 * @param {string} message - Message to log
 */
function log(message) {
  process.stderr.write(`[pre-compact-save] ${message}\n`);
}

/**
 * Find repository root by walking up directory tree
 * @returns {string} Repository root path or cwd if not found
 */
function findRepoRoot() {
  let dir = process.cwd();
  const fsRoot = path.parse(dir).root;

  while (dir !== fsRoot) {
    if (fs.existsSync(path.join(dir, '.git'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return process.cwd();
}

/**
 * Get current timestamp in ISO8601 UTC format
 * @returns {string} ISO8601 timestamp
 */
function getTimestamp() {
  return new Date().toISOString();
}

/**
 * Read Plans.md and extract WIP tasks
 * @param {string} repoRoot - Repository root path
 * @returns {string[]} Array of WIP task descriptions
 */
function getWipTasks(repoRoot) {
  const plansPath = path.join(repoRoot, 'Plans.md');
  const wipTasks = [];

  try {
    if (!fs.existsSync(plansPath)) {
      return wipTasks;
    }

    const content = fs.readFileSync(plansPath, 'utf8');
    const lines = content.split('\n');

    for (const line of lines) {
      // Match TODO or in-progress markers
      if (line.includes('`cc:TODO`') || line.includes('`cc:WIP`') || line.includes('[in_progress]')) {
        // Extract task description (text after | markers in table format)
        const match = line.match(/\|\s*[\d.]+\s*\|\s*([^|]+)\s*\|/);
        if (match) {
          wipTasks.push(match[1].trim());
        }
      }
    }
  } catch (err) {
    log(`Error reading Plans.md: ${err.message}`);
  }

  return wipTasks;
}

/**
 * Get recently modified files from git with timeout
 * @param {string} repoRoot - Repository root path
 * @returns {string[]} Array of recently modified file paths
 */
function getRecentEdits(repoRoot) {
  const recentEdits = [];

  try {
    const { execFileSync } = require('child_process');

    // Get files modified in working tree with timeout
    const output = execFileSync('git', [
      'diff', '--name-only', 'HEAD~5'
    ], {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: GIT_TIMEOUT_MS
    }).trim();

    if (output) {
      const files = output.split('\n').slice(0, 20); // Limit to 20 files
      recentEdits.push(...files);
    }
  } catch (err) {
    // git command may fail if no commits or shallow repo
    // Fallback: try unstaged changes only
    try {
      const { execFileSync } = require('child_process');
      const output = execFileSync('git', ['diff', '--name-only'], {
        cwd: repoRoot,
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: GIT_TIMEOUT_MS
      }).trim();

      if (output) {
        recentEdits.push(...output.split('\n').slice(0, 20));
      }
    } catch {
      log(`Error getting recent edits: ${err.message}`);
    }
  }

  return recentEdits;
}

/**
 * Get session metrics from state
 * @param {string} repoRoot - Repository root path
 * @returns {object|null} Session metrics or null
 */
function getSessionMetrics(repoRoot) {
  const metricsPath = path.join(repoRoot, '.claude', 'state', 'session-metrics.json');

  try {
    if (fs.existsSync(metricsPath)) {
      return JSON.parse(fs.readFileSync(metricsPath, 'utf8'));
    }
  } catch (err) {
    log(`Error reading session metrics: ${err.message}`);
  }

  return null;
}

/**
 * Main function
 */
function main() {
  const sessionId = process.env.CLAUDE_SESSION_ID || '';
  const repoRoot = findRepoRoot();

  // Build snapshot
  const snapshot = {
    version: SNAPSHOT_VERSION,
    timestamp: getTimestamp(),
    sessionId: sessionId,
    wipTasks: getWipTasks(repoRoot),
    recentEdits: getRecentEdits(repoRoot),
    metrics: getSessionMetrics(repoRoot)
  };

  const claudeDir = path.join(repoRoot, '.claude');
  const stateDir = path.join(claudeDir, 'state');
  const snapshotPath = path.join(stateDir, 'precompact-snapshot.json');

  try {
    // Resolve repo root for security checks
    const resolvedRepo = fs.realpathSync(repoRoot);

    // Security: Verify .claude is not a symlink pointing outside repo
    if (fs.existsSync(claudeDir)) {
      const claudeDirStat = fs.lstatSync(claudeDir);
      if (claudeDirStat.isSymbolicLink()) {
        const resolvedClaudeDir = fs.realpathSync(claudeDir);
        if (!resolvedClaudeDir.startsWith(resolvedRepo + path.sep) &&
            resolvedClaudeDir !== resolvedRepo) {
          log('.claude symlink points outside repo');
          console.log(JSON.stringify({ continue: true, message: 'Skipped: security check failed' }));
          return;
        }
      }
    }

    // Ensure state directory exists with restricted permissions
    if (fs.existsSync(stateDir)) {
      // Security: Verify stateDir is not a symlink
      const stateDirStat = fs.lstatSync(stateDir);
      if (stateDirStat.isSymbolicLink()) {
        log('stateDir is a symlink, refusing to write');
        console.log(JSON.stringify({ continue: true, message: 'Skipped: stateDir is symlink' }));
        return;
      }
      // Ensure permissions are restricted
      fs.chmodSync(stateDir, 0o700);
    } else {
      fs.mkdirSync(stateDir, { recursive: true, mode: 0o700 });
    }

    // Security: Verify snapshot path is not a symlink
    if (fs.existsSync(snapshotPath)) {
      const snapshotStat = fs.lstatSync(snapshotPath);
      if (snapshotStat.isSymbolicLink()) {
        log('snapshotPath is a symlink, refusing to write');
        console.log(JSON.stringify({ continue: true, message: 'Skipped: snapshotPath is symlink' }));
        return;
      }
    }

    // Save snapshot with restricted permissions
    fs.writeFileSync(snapshotPath, JSON.stringify(snapshot, null, 2), { mode: 0o600 });

    // Output for hook feedback
    const result = {
      continue: true,
      message: `Saved pre-compact snapshot: ${snapshot.wipTasks.length} WIP tasks, ${snapshot.recentEdits.length} recent edits`
    };

    console.log(JSON.stringify(result));
  } catch (err) {
    log(`Error saving snapshot: ${err.message}`);
    // Don't block compaction on errors
    console.log(JSON.stringify({ continue: true, message: `Error: ${err.message}` }));
  }
}

main();
