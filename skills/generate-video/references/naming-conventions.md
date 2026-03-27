# Naming Conventions for Video Generation Schemas

本文档定义视频生成系统中所有 JSON schema 的统一命名规范。

## 版本
**1.0.0** - 2026-02-03

---

## 1. 时间单位

### 规则
**所有时间长度必须使用毫秒（`_ms` 后缀）**

### 理由
- 毫秒为视频时序提供足够的精度
- 帧数依赖 FPS，应在运行时计算
- 所有 schema 保持一致性

### 示例

```json
// ✅ 正确
{
  "duration_ms": 5000,
  "start_offset_ms": 1000,
  "fade_in_ms": 500
}

// ❌ 错误
{
  "duration_frames": 150,
  "duration": 5,
  "durationSec": 5
}
```

### 运行时转换
```javascript
// FPS 在 output_settings 中提供
const fps = 30;
const durationMs = 5000;
const durationFrames = Math.floor((durationMs / 1000) * fps); // 150 帧
```

---

## 2. 过渡类型

### 规则
**过渡枚举值必须使用 snake_case**

### 标准枚举
```json
{
  "enum": ["fade", "slide_in", "zoom", "cut"]
}
```

### 定义

| 值 | 说明 | 用途 |
|---|------|------|
| `fade` | 渐变透明度变化 | 默认、柔和过渡 |
| `slide_in` | 从方向滑入 | 动态场景变化 |
| `zoom` | 缩放进出 | 强调、戏剧性展示 |
| `cut` | 即时切换（无过渡） | 快节奏内容 |

### 方向属性（用于 slide_in）
当 `transition.type === "slide_in"` 时，使用 `direction` 属性:

```json
{
  "transition": {
    "type": "slide_in",
    "duration_ms": 500,
    "direction": "left"
  }
}
```

**有效方向**: `"left"`, `"right"`, `"top"`, `"bottom"`

---

## 3. 属性命名大小写

### 规则
**所有属性名必须使用 snake_case**

### 理由
- 与现有代码库规范一致
- 多词属性可读性更好
- 符合 JSON Schema 最佳实践

### 示例

```json
// ✅ 正确
{
  "primary_color": "#3B82F6",
  "secondary_color": "#10B981",
  "font_size": 48,
  "font_weight": 700,
  "line_height": 1.5,
  "border_radius": 8,
  "glow_intensity": 20
}

// ❌ 错误
{
  "primaryColor": "#3B82F6",
  "fontSize": 48,
  "lineHeight": 1.5,
  "borderRadius": 8
}
```

---

## 4. 枚举值

### 规则
**枚举值必须使用小写，多词值用连字符连接**

### 标准模式

#### 场景类型
```json
["intro", "ui-demo", "architecture", "code-highlight", "changelog", "cta"]
```

#### 视觉风格
```json
["minimalist", "technical", "modern", "gradient", "flat", "3d"]
```

#### 动画缓动
```json
["linear", "ease-in", "ease-out", "ease-in-out", "ease-in-quad", "ease-out-quad"]
```

#### 背景类型
```json
["cyberpunk", "corporate", "minimal", "gradient", "particles"]
```

---

## 5. ID 模式

### 规则
**ID 必须使用 kebab-case（小写加连字符）**

### 模式
```regex
^[a-z0-9-]+$
```

### 示例

```json
// ✅ 正确
{
  "scene_id": "intro-hero",
  "section_id": "feature-highlights",
  "character_id": "expert-reviewer"
}

// ❌ 错误
{
  "scene_id": "introHero",
  "section_id": "feature_highlights",
  "character_id": "ExpertReviewer"
}
```

---

## 6. 颜色格式

### 规则
**颜色必须使用大写 HEX 格式，带 `#` 前缀**

### 模式
```regex
^#[0-9A-F]{6}$
```

### 示例

```json
// ✅ 正确
{
  "primary_color": "#3B82F6",
  "accent_color": "#F59E0B"
}

// ❌ 错误
{
  "primary_color": "#3b82f6",  // 小写
  "accent_color": "3B82F6",    // 缺少 #
  "text_color": "rgb(59, 130, 246)"  // 不是 HEX
}
```

### RGBA 例外
对于透明度，使用 `rgba()` 格式:

```json
{
  "background_color": "rgba(0, 0, 0, 0.8)"
}
```

---

## 7. 保留关键字

### 音频属性
- `fade_in_ms` / `fade_out_ms` - 音频淡入淡出长度
- `start_offset_ms` - 音频/解说开始前延迟
- `master_volume` - 全局音量（0.0 - 1.0）

### 视觉属性
- `duration_ms` - 长度（毫秒）
- `transition` - 过渡配置对象
- `emphasis` - 强调/高亮配置
- `background` - 背景配置

### 元数据属性
- `created_at` / `updated_at` - ISO 8601 时间戳
- `version` - 语义版本（如 "1.0.0"）
- `description` - 人类可读描述

---

## 8. 迁移指南

### 从 `duration_frames` 到 `duration_ms`

**之前:**
```json
{
  "transition": {
    "type": "fade",
    "duration_frames": 15
  }
}
```

**之后:**
```json
{
  "transition": {
    "type": "fade",
    "duration_ms": 500
  }
}
```

**转换公式**（假设 30 FPS）:
```
duration_ms = (duration_frames / 30) * 1000
```

### 从 `slideIn` 到 `slide_in`

**之前:**
```json
{
  "transition": {
    "type": "slideIn",
    "duration_frames": 15
  }
}
```

**之后:**
```json
{
  "transition": {
    "type": "slide_in",
    "duration_ms": 500,
    "direction": "left"
  }
}
```

### 从 camelCase 到 snake_case

**之前:**
```json
{
  "background": {
    "primaryColor": "#3B82F6",
    "secondaryColor": "#10B981"
  }
}
```

**之后:**
```json
{
  "background": {
    "primary_color": "#3B82F6",
    "secondary_color": "#10B981"
  }
}
```

---

## 9. Schema 验证

所有 schema 必须验证以下规范:

### 检查清单
- [ ] 无 `duration_frames` 属性（使用 `duration_ms`）
- [ ] 过渡枚举: `["fade", "slide_in", "zoom", "cut"]`
- [ ] 所有属性使用 `snake_case`
- [ ] 所有枚举值使用 `lowercase-with-hyphens`
- [ ] 所有 ID 匹配模式 `^[a-z0-9-]+$`
- [ ] 所有 HEX 颜色匹配模式 `^#[0-9A-F]{6}$`

---

## 10. 例外

### Character Schema（Phase 10+）
`character.schema.json` 可能保留一些 camelCase 属性，以兼容 TTS 提供商 API（如弹簧动画的 `overshootClamping`）。

### 外部 API
与外部 API（Remotion、TTS 提供商）对接时，转换层应处理命名差异。

---

## 相关文档

- [Schema Phase Plan](../PLANS.md) - Phase 11.2: Naming & Unit Standardization
- [Animation Schema](../schemas/animation.schema.json)
- [Direction Schema](../schemas/direction.schema.json)
- [Scene Schema](../schemas/scene.schema.json)
