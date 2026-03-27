# Scripts Directory

用于 JSON Schema 自动生成和验证的脚本集合。

## Available Scripts

### generate-schemas.js

从 JSON Schema 自动生成 Zod schema。

**Usage:**
```bash
npm run generate:schemas
```

**Input:**
- `schemas/*.schema.json` - JSON Schema 文件

**Output:**
- `src/schemas/*.ts` - Zod schema 定义
- `src/schemas/index.ts` - barrel export

**Example:**
```bash
# Generate all schemas
node scripts/generate-schemas.js

# Or via npm script (recommended)
npm run generate:schemas
```

**Dependencies:**
- `json-schema-to-zod` - JSON Schema → Zod 转换
- `zod` - Runtime validation

---

## Setup

### Install Dependencies

安装 schema 生成所需的包：

```bash
npm install --save-dev json-schema-to-zod
npm install zod
```

### Add npm Script

在 `package.json` 中添加：

```json
{
  "scripts": {
    "generate:schemas": "node scripts/generate-schemas.js"
  }
}
```

### Pre-commit Hook (Optional)

在 schema 变更时自动生成：

```bash
# .husky/pre-commit
npm run generate:schemas
git add src/schemas/
```

---

## Schema Development Workflow

1. **创建 Schema**: 创建 `schemas/*.schema.json`
2. **执行生成**: `npm run generate:schemas`
3. **确认类型推断**: 在 `src/schemas/*.ts` 中确认 TypeScript 类型
4. **验证**: 使用生成的 Zod schema 进行验证

### Example

```typescript
// src/example.ts
import { AssetManifestSchema, type AssetManifest } from './schemas';

// Runtime validation
const data: unknown = { /* ... */ };
const result = AssetManifestSchema.safeParse(data);

if (result.success) {
  const manifest: AssetManifest = result.data;
  console.log('Valid manifest:', manifest);
} else {
  console.error('Validation errors:', result.error.errors);
}
```

---

## Schema Versioning

### Version Format

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "version": "1.0.0",
  "title": "SchemaName",
  ...
}
```

### Breaking Changes

需要提升主版本号的变更：
- 添加 Required 字段
- 删除字段
- 类型变更

可以在次版本号中进行的变更：
- 添加 Optional 字段
- 添加 Enum 值
- Description 变更

---

## Troubleshooting

### Schema Generation Errors

**Error**: `Cannot find module 'json-schema-to-zod'`
```bash
npm install --save-dev json-schema-to-zod
```

**Error**: `No .schema.json files found`
- 确认 `schemas/` 目录中有 `*.schema.json` 文件

**Error**: `Invalid JSON`
- 检查 JSON Schema 的语法错误
- 使用 [JSONLint](https://jsonlint.com/) 验证

### Zod Schema Issues

**Type inference not working**
```typescript
// ❌ Bad
const schema = AssetManifestSchema;

// ✅ Good
import { type AssetManifest } from './schemas';
const manifest: AssetManifest = { /* ... */ };
```

---

## Validation Scripts (Phase 2)

### validate-scene.js

对单个场景 JSON 针对 `scene.schema.json` 进行验证。

**Usage:**
```bash
node scripts/validate-scene.js <scene-file.json>
```

**Example:**
```bash
node scripts/validate-scene.js schemas/examples/scene-example.json
```

**Output:**
```json
{
  "valid": true,
  "errors": []
}
```

**Exit Codes:**
- `0` - Validation successful
- `1` - Validation failed (schema errors)
- `2` - File not found or invalid JSON

---

### validate-scenario.js

对场景 JSON 针对 `scenario.schema.json` 进行验证。
也执行语义检查：
- Section ID 的唯一性
- Section 顺序的正确性
- Duration 的合理性

**Usage:**
```bash
node scripts/validate-scenario.js <scenario-file.json>
```

**Example:**
```bash
node scripts/validate-scenario.js schemas/examples/scenario-example.json
```

**Semantic Checks:**
- ✅ Section ID uniqueness
- ✅ Section order sequence (0, 1, 2, ...)
- ✅ Duration estimates (negative, excessive values)

**Exit Codes:**
- `0` - Validation successful
- `1` - Validation failed (schema or semantic errors)
- `2` - File not found or invalid JSON

---

### validate-video.js

对完整的视频脚本 JSON 进行 E2E 验证。
Critical 错误会停止，Warning 只输出日志并继续。

**Usage:**
```bash
node scripts/validate-video.js <video-script-file.json>
```

**Example:**
```bash
node scripts/validate-video.js schemas/examples/video-script-example.json
```

**E2E Validation Checks:**
- ✅ Scene ID uniqueness (across all scenes)
- ✅ Scene order sequence (within each section)
- ✅ Total duration calculation
- ⚠️ Asset file existence
- ⚠️ Audio sync validation
- ⚠️ Resolution/aspect ratio

**Severity Levels:**
| Level | Behavior | Examples |
|-------|----------|----------|
| **Critical** | Stops validation, exit code 1 | Duplicate IDs, invalid schema |
| **Warning** | Logs warning, continues | Missing assets, unusual aspect ratio |

**Output:**
```json
{
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "severity": "warning",
      "path": "/scenes/0/assets/0/source",
      "message": "Asset not found: \"assets/intro.png\"",
      "keyword": "asset-missing"
    }
  ]
}
```

**Exit Codes:**
- `0` - Validation successful (warnings are ok)
- `1` - Validation failed (critical errors)
- `2` - File not found or invalid JSON

---

## Asset Management (Phase 7)

### load-assets.js

资源（背景、音效、字体、图片）的加载和用户覆盖支持。

**Priority System:**
1. User assets: `~/.harness/video/assets/`
2. Skill defaults: `skills/generate-video/assets/`
3. Built-in defaults: Hardcoded fallbacks

**Usage:**
```bash
# Load backgrounds configuration
node scripts/load-assets.js backgrounds

# Load sounds configuration
node scripts/load-assets.js sounds

# Show asset search paths
node scripts/load-assets.js paths

# Initialize user asset directory
node scripts/load-assets.js init

# Test all loading functions
node scripts/load-assets.js test
```

**Programmatic Usage:**
```javascript
const { loadBackgrounds, loadSounds, loadAssetFile } = require('./scripts/load-assets.js');

// Load configurations
const backgrounds = loadBackgrounds();
// → { version: "1.0.0", backgrounds: [...] }

const sounds = loadSounds();
// → { version: "1.0.0", sounds: [...] }

// Load specific asset file
const assetPath = loadAssetFile('sounds', 'impact.mp3');
// → "/path/to/impact.mp3" or null
```

**Functions:**
- `loadBackgrounds()` - Load background configurations
- `loadSounds()` - Load sound effect configurations
- `loadAssetFile(category, filename)` - Load specific asset file
- `updateManifest(manifestPath, assets)` - Update asset manifest
- `getAssetPaths()` - Get asset search paths (debug)
- `initUserAssetDir()` - Initialize `~/.harness/video/assets/`

**Asset Types:**
- **backgrounds** - 5 types: neutral, highlight, dramatic, tech, warm
- **sounds** - 4 types: impact, pop, transition, subtle
- **fonts** - Custom font files (TTF, OTF, WOFF)
- **images** - Custom images (PNG, JPG, SVG, WebP)

**Customization:**
See [references/asset-customization.md](../references/asset-customization.md) for detailed customization guide.

**Test:**
```bash
npm test -- asset-loader.test.js
```

---

## Future Scripts (Phase 3+)

计划将来添加的脚本：

- `merge-scenes.js` - 场景 JSON 合并
- `optimize-assets.js` - 资源优化
- `generate-thumbnails.js` - 缩略图自动生成
- `render-video.js` - 视频渲染 (Phase 8)

---

## References

- [JSON Schema](https://json-schema.org/)
- [Zod Documentation](https://zod.dev/)
- [json-schema-to-zod](https://github.com/StefanTerdell/json-schema-to-zod)
- [Asset Customization Guide](../references/asset-customization.md)
