---
description: 開発ツール (AST-Grep, LSP) を一括セットアップ
description-en: Setup development tools (AST-Grep, LSP) in one command
---

# /dev-tools-setup - Development Tools Setup

Setup AST-Grep and LSP to enable advanced code intelligence features.

---

## What This Enables

After setup, these MCP tools become available:

| Tool | Purpose |
|------|---------|
| `harness_ast_search` | Structural code pattern search |
| `harness_lsp_references` | Find all symbol references |
| `harness_lsp_definition` | Go to symbol definition |
| `harness_lsp_diagnostics` | Get code diagnostics |
| `harness_lsp_hover` | Get type information |

---

## Execution Flow

### Step 1: Detect Project Languages

```bash
# Auto-detect languages
ls package.json 2>/dev/null && echo "TypeScript/JavaScript detected"
ls requirements.txt pyproject.toml 2>/dev/null && echo "Python detected"
ls Cargo.toml 2>/dev/null && echo "Rust detected"
ls go.mod 2>/dev/null && echo "Go detected"
```

### Step 2: Check AST-Grep Installation

```bash
# Check if ast-grep is installed
which sg || echo "AST-Grep not found"
```

**If not installed, suggest:**

| Platform | Install Command |
|----------|-----------------|
| macOS | `brew install ast-grep` |
| npm (any) | `npm install -g @ast-grep/cli` |
| Cargo (any) | `cargo install ast-grep --locked` |

### Step 3: Check LSP Installation

Based on detected languages:

| Language | Check Command | Install Command |
|----------|---------------|-----------------|
| TypeScript/JS | `which typescript-language-server` | `npm install -g typescript-language-server typescript` |
| Python | `which pylsp` | `pip install python-lsp-server` |
| Rust | `which rust-analyzer` | `rustup component add rust-analyzer` |
| Go | `which gopls` | `go install golang.org/x/tools/gopls@latest` |

### Step 4: Report Status

```markdown
## 🔧 Development Tools Status

### AST-Grep
- Status: ✅ Installed / ❌ Not Installed
- Version: x.x.x
- Command: `sg`

### Language Servers

| Language | Status | Server |
|----------|--------|--------|
| TypeScript | ✅/❌ | typescript-language-server |
| Python | ✅/❌ | pylsp |

### Available MCP Tools

After installation:
- `harness_ast_search` - Structural code search
- `harness_lsp_references` - Find references
- `harness_lsp_definition` - Go to definition
- `harness_lsp_diagnostics` - Get diagnostics
- `harness_lsp_hover` - Type information

### Next Steps

1. Install missing tools (commands shown above)
2. Restart Claude Code session
3. Use MCP tools in your workflow
```

---

## Usage Examples

### After Setup: AST-Grep Search

```bash
# Find all console.log calls
harness_ast_search pattern="console.log($$$)" language="typescript"

# Find empty catch blocks (code smell)
harness_ast_search pattern="catch ($ERR) { }" language="typescript"

# Find async functions without await
harness_ast_search pattern="async function $NAME($$$) { $BODY }" language="typescript"
```

### After Setup: LSP Analysis

```bash
# Find references to a function
harness_lsp_references file="src/utils.ts" line=10 column=5

# Get diagnostics for a file
harness_lsp_diagnostics file="src/components/App.tsx"
```

---

## Integration with /harness-review

When AST-Grep is installed, `/harness-review` automatically:

1. Detects code smells:
   - `console.log` remnants
   - Empty catch blocks
   - Unused async/await
   - Magic numbers

2. Reports findings in review output

---

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| Setup tools | "setup development tools" |
| Check installation | "are AST and LSP installed?" |
| Search patterns | "find all console.log" |
| Find references | "where is this function used?" |

---

## Troubleshooting

### AST-Grep not working

```bash
# Check installation
which sg
sg --version

# Test search
sg --pattern "console.log" --lang typescript .
```

### LSP not working

```bash
# Check TypeScript server
which typescript-language-server
typescript-language-server --version

# Check if tsconfig.json exists
ls tsconfig.json
```

### Still issues?

1. Restart Claude Code session
2. Check PATH environment variable
3. Try manual installation commands

---

## Related Commands

- `/harness-review` - Code review (uses AST-Grep when available)
- `/lsp-setup` - LSP-only setup (legacy)
- `/mcp-setup` - MCP server configuration
