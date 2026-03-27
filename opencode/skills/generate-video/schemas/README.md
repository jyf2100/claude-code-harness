# 视频生成 JSON Schema

视频生成流程的 JSON Schema 定义。定义场景配置、场景和完整视频脚本的结构。

## Schema 文件

| Schema | 用途 | 版本 |
|--------|---------|---------|
| **scenario.schema.json** | 高级场景结构与段落 | 1.0.0 |
| **scene.schema.json** | 单个场景定义（内容与方向） | 1.0.0 |
| **video-script.schema.json** | 完整视频脚本（元数据与设置） | 1.0.0 |

## Schema 概览

```
Scenario（高级结构）
    │
    ├── Section 1（介绍）
    │   ├── Scene 1.1
    │   └── Scene 1.2
    │
    ├── Section 2（演示）
    │   ├── Scene 2.1
    │   ├── Scene 2.2
    │   └── Scene 2.3
    │
    └── Section 3（CTA）
        └── Scene 3.1

Video Script = Metadata + Scenes + Output Settings
```

## 使用方法

### 1. 基本验证（无依赖）

```bash
node validate-schemas-basic.js
```

执行基本的 JSON 和结构验证，无需外部依赖。

### 2. 使用 ajv 完整验证

```bash
# 先安装依赖
npm install ajv ajv-formats

# 运行完整验证
node validate-schemas.js
```

### 3. 编程方式使用

```javascript
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fs = require('fs');

// 初始化 ajv
const ajv = new Ajv({ strict: false });
addFormats(ajv);

// 加载 schema
const sceneSchema = JSON.parse(fs.readFileSync('scene.schema.json'));
const videoScriptSchema = JSON.parse(fs.readFileSync('video-script.schema.json'));

// 添加 schema
ajv.addSchema(sceneSchema);
ajv.addSchema(videoScriptSchema);

// 验证数据
const validate = ajv.compile(videoScriptSchema);
const valid = validate(myVideoScriptData);

if (!valid) {
  console.error(validate.errors);
}
```

## Schema 详情

### scenario.schema.json

定义视频场景的高级结构。

**关键字段**:
- `title`: 场景标题
- `description`: 目的和内容概要
- `sections[]`: 段落有序列表
  - `id`: 唯一段落标识符
  - `title`: 段落名称
  - `description`: 段落目的
  - `order`: 显示顺序（0 起始）
  - `duration_estimate_ms`: 预估时长
- `metadata`: 生成元数据
  - `version`: Schema 版本
  - `generated_at`: ISO 8601 时间戳
  - `video_type`: 类型枚举（lp-teaser、intro-demo 等）
  - `target_funnel`: 营销漏斗阶段

**示例**: 参见 [examples/scenario-example.json](examples/scenario-example.json)

### scene.schema.json

定义单个视频场景，包含内容、视觉方向和素材。

**关键字段**:
- `scene_id`: 唯一场景标识符
- `section_id`: 所属段落引用
- `order`: 段落内顺序
- `type`: 场景类型枚举（intro、ui-demo、cta 等）
- `content`: 场景内容
  - `text`: 主要文本
  - `image`: 图像素材路径
  - `duration_ms`: 场景时长
  - `url`: Playwright 截图用
  - `actions[]`: UI 自动化动作
  - `mermaid`: 图表定义
  - `code`: 带高亮的代码片段
- `direction`: 视觉效果
  - `transition`: 入/出过渡
  - `emphasis`: 视觉强调效果
  - `background`: 背景配置
  - `camera`: 镜头运动（3D）
- `assets[]`: 场景素材
  - `type`: 素材类型（image、video、audio、font）
  - `source`: 路径或 URL
  - `generated`: AI 生成标记
- `audio`: 音频配置
  - `narration`: 旁白
  - `sfx[]`: 效果音

**示例**: 参见 [examples/scene-example.json](examples/scene-example.json)

### video-script.schema.json

完整视频脚本，包含所有场景、元数据和输出设置。

**关键字段**:
- `metadata`: 视频元数据
  - `title`: 视频标题
  - `version`: 脚本版本
  - `created_at`: 创建时间戳
  - `video_type`: 类型枚举
  - `scenario_id`: 源场景引用
- `scenes[]`: 场景对象数组（引用 scene.schema.json）
- `total_duration_ms`: 视频总时长
- `output_settings`: 渲染配置
  - `width`, `height`: 分辨率
  - `fps`: 帧率（24、30、60）
  - `codec`: 视频编码（h264、h265、vp9、av1）
  - `format`: 输出格式（mp4、webm、mov、gif）
  - `quality`: 质量预设
  - `preset`: 分辨率预设（1080p、4k 等）
- `audio_settings`: 全局音频
  - `bgm`: 背景音乐配置
  - `master_volume`: 主音量控制
- `branding`: 品牌配置
  - `logo`: Logo 路径
  - `colors`: 品牌色
  - `fonts`: 字体配置
- `transitions`: 全局过渡设置

**示例**: 参见 [examples/video-script-example.json](examples/video-script-example.json)

## 场景类型

| Type | 描述 | 用例 |
|------|-------------|----------|
| `intro` | 开场标题/logo | 第一场景、品牌介绍 |
| `ui-demo` | UI 演示（Playwright） | 功能展示 |
| `architecture` | 系统架构图 | 技术讲解 |
| `code-highlight` | 带高亮代码片段 | 开发者向内容 |
| `changelog` | 发布说明显示 | 版本更新 |
| `cta` | 行动号召 | 最后场景、转化 |
| `feature-highlight` | 特定功能聚焦 | 功能营销 |
| `problem-promise` | 问题+解决方案陈述 | 价值主张 |
| `workflow` | 多步骤工作流演示 | 流程讲解 |
| `objection` | 应对常见顾虑 | 异议处理 |
| `custom` | 自定义场景类型 | 灵活使用 |

## 视频类型（video_type）

| Type | 时长 | 漏斗阶段 | 用途 |
|------|----------|--------------|---------|
| `lp-teaser` | 30-90s | 认知 | 落地页、社交广告 |
| `intro-demo` | 2-3min | 兴趣 | 产品介绍 |
| `release-notes` | 1-3min | 考虑 | 功能更新 |
| `architecture` | 5-30min | 决策 | 技术深度解析 |
| `onboarding` | 30s-3min | 留存 | 用户引导 |
| `custom` | 可变 | 任意 | 自定义用途 |

## 音频同步规则

使用旁白时，请遵循以下时机规则:

| 规则 | 值 | 原因 |
|------|-------|--------|
| **音频开始** | 场景开始 + 1000ms | 1 秒缓冲空间 |
| **场景长度** | 1000ms + 音频长度 + 500ms | 过渡填充 |
| **过渡** | 450-500ms 重叠 | 平滑淡入淡出 |
| **场景开始计算** | 前一场景开始 + 时长 - 450ms | 重叠处理 |

**始终先检查音频时长**:
```bash
ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 audio.mp3
```

## 验证

### 各 Schema 必填字段

**scenario.schema.json**:
- ✅ title, description, sections, metadata

**scene.schema.json**:
- ✅ scene_id, section_id, order, type, content
- ✅ content.duration_ms

**video-script.schema.json**:
- ✅ metadata, scenes, total_duration_ms, output_settings
- ✅ output_settings: width, height, fps
- ✅ metadata: title, version, created_at

### 常见验证错误

| 错误 | 原因 | 解决方案 |
|-------|-------|----------|
| `Missing required property` | 未提供必填字段 | 添加缺失字段 |
| `Invalid enum value` | 无效类型/格式值 | 使用允许的枚举值 |
| `Pattern mismatch` | ID 格式不正确 | 使用小写-连字符格式 |
| `Invalid date-time` | 时间戳格式错误 | 使用 ISO 8601 格式 |
| `Invalid $ref` | Schema 引用损坏 | 确保 scene.schema.json 已加载 |

## 示例

所有示例文件位于 `examples/` 目录:

1. **scenario-example.json** - 90 秒预告场景
2. **scene-example.json** - 带效果的介绍场景
3. **video-script-example.json** - 完整视频脚本

## 集成

这些 schema 被:

1. **Planner**（planner.md）使用 - 生成场景和场景结构
2. **Generator**（generator.md）使用 - 读取 video-script.json 并渲染视频
3. **验证**使用 - 确保生成数据符合预期结构

## 版本历史

| 版本 | 日期 | 变更 |
|---------|------|---------|
| 1.0.0 | 2026-02-02 | 初始发布，包含核心 schema |

## 参考

- [JSON Schema Draft-07](https://json-schema.org/draft-07/json-schema-release-notes.html)
- [ajv 文档](https://ajv.js.org/)
- [最佳实践指南](../references/best-practices.md)
- [Planner 参考](../references/planner.md)
- [Generator 参考](../references/generator.md)
