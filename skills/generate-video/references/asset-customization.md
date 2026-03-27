# Asset Customization Guide

用户自定义素材（背景、音效、字体、图片）的覆盖方法和最佳实践。

---

## 概要

视频生成使用的素材按以下优先级加载:

```
1. 用户素材 (~/.harness/video/assets/)    ← 最高优先
2. 技能默认 (skills/generate-video/assets/) ← 回退
3. 内置默认（硬编码）                      ← 最后手段
```

通过此机制，无需修改技能本体即可使用自己喜欢的素材。

---

## 目录结构

### 用户素材目录

```
~/.harness/video/assets/
├── README.md                    # 使用指南（自动生成）
├── backgrounds/
│   ├── backgrounds.json         # 自定义背景定义
│   └── my-custom-bg.png         # 自定义背景图片（可选）
├── sounds/
│   ├── sounds.json              # 自定义音效定义
│   ├── impact.mp3               # 高强调音
│   ├── pop.mp3                  # 中强调音
│   ├── transition.mp3           # 场景切换音
│   └── subtle.mp3               # 低强调音
├── fonts/
│   ├── MyBrand-Bold.ttf
│   └── MyBrand-Regular.ttf
└── images/
    ├── logo.png
    └── icon.png
```

### 初始化

创建用户素材目录:

```bash
node scripts/load-assets.js init
```

或手动创建:

```bash
mkdir -p ~/.harness/video/assets/{backgrounds,sounds,fonts,images}
```

---

## 自定义方法

### 1. 背景自定义

#### 步骤

1. **复制默认设置**:

```bash
cp skills/generate-video/assets/backgrounds/backgrounds.json \
   ~/.harness/video/assets/backgrounds/
```

2. **编辑设置**:

```json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand Background",
      "description": "Company brand colors",
      "type": "gradient",
      "colors": {
        "primary": "#1e3a8a",
        "secondary": "#3b82f6",
        "accent": "#60a5fa"
      },
      "gradient": {
        "type": "linear",
        "angle": 135,
        "stops": [
          { "color": "#1e3a8a", "position": 0 },
          { "color": "#3b82f6", "position": 50 },
          { "color": "#60a5fa", "position": 100 }
        ]
      },
      "usage": {
        "scenes": ["intro", "cta"],
        "recommended_for": "Brand-focused content"
      }
    }
  ]
}
```

3. **在视频生成中使用**:

```json
{
  "scene": {
    "background": "my-brand"
  }
}
```

#### 背景类型

| Type | Description | Fields |
|------|-------------|--------|
| `gradient` | 渐变背景 | `colors`, `gradient` |
| `pattern` | 图案背景（网格等） | `colors`, `gradient`, `pattern` |
| `solid` | 纯色背景 | `colors.primary` |
| `image` | 图片背景 | `file` (path to image) |

#### 渐变类型

```json
// Linear gradient
"gradient": {
  "type": "linear",
  "angle": 135,
  "stops": [...]
}

// Radial gradient
"gradient": {
  "type": "radial",
  "stops": [...]
}
```

---

### 2. 音效自定义

#### 步骤

1. **复制默认设置**:

```bash
cp skills/generate-video/assets/sounds/sounds.json \
   ~/.harness/video/assets/sounds/
```

2. **放置音效文件**:

```bash
# 从 FreeSound 下载（推荐 CC0 许可）
cp ~/Downloads/my-impact.mp3 ~/.harness/video/assets/sounds/impact.mp3
cp ~/Downloads/my-pop.mp3 ~/.harness/video/assets/sounds/pop.mp3
```

3. **编辑设置**:

```json
{
  "version": "1.0.0",
  "sounds": [
    {
      "id": "impact",
      "name": "Custom Impact",
      "type": "effect",
      "category": "emphasis",
      "emphasis_level": "high",
      "file": {
        "placeholder": "impact.mp3",
        "expected_duration": 0.5,
        "format": "mp3"
      },
      "volume": {
        "default": 0.7,
        "with_narration": 0.4,
        "with_bgm": 0.6
      }
    }
  ]
}
```

#### 推荐格式

| Format | Sample Rate | Bit Depth | Notes |
|--------|-------------|-----------|-------|
| MP3 | 44100 Hz | 16-bit | 推荐（兼容性高） |
| WAV | 44100 Hz | 16-bit | 高品质（文件大） |
| OGG | 44100 Hz | - | 轻量（注意浏览器兼容性） |

#### 音量推荐值

| Context | Volume Range | Notes |
|---------|--------------|-------|
| 有解说 | 0.15 - 0.4 | 不干扰语音 |
| 有 BGM | 0.25 - 0.6 | 对 BGM 进行 ducking |
| 无音频 | 0.3 - 1.0 | 可全音量 |

---

### 3. 字体自定义

#### 步骤

1. **放置字体文件**:

```bash
cp ~/Downloads/MyFont-Bold.ttf ~/.harness/video/assets/fonts/
cp ~/Downloads/MyFont-Regular.ttf ~/.harness/video/assets/fonts/
```

2. **在场景设置中引用**:

```json
{
  "scene": {
    "text": {
      "content": "My Message",
      "font": {
        "family": "MyFont",
        "weight": "bold",
        "file": "~/.harness/video/assets/fonts/MyFont-Bold.ttf"
      }
    }
  }
}
```

#### 在 Remotion 中使用

```typescript
import { loadFont } from '@remotion/google-fonts/Inter';

// 加载自定义字体
const fontFamily = loadFont({
  src: '~/.harness/video/assets/fonts/MyFont-Bold.ttf',
  fontFamily: 'MyFont',
  fontWeight: 'bold',
});
```

#### 推荐格式

| Format | Web Safe | Notes |
|--------|----------|-------|
| TTF | ✅ Yes | 推荐（兼容性最高） |
| OTF | ✅ Yes | 可使用 OpenType 功能 |
| WOFF/WOFF2 | ✅ Yes | Web 优化（轻量） |

---

### 4. 图片自定义

#### 步骤

1. **放置图片文件**:

```bash
cp ~/Downloads/logo.png ~/.harness/video/assets/images/
cp ~/Downloads/icon.png ~/.harness/video/assets/images/
```

2. **在场景设置中引用**:

```json
{
  "scene": {
    "image": {
      "src": "~/.harness/video/assets/images/logo.png",
      "width": 200,
      "height": 100
    }
  }
}
```

#### 推荐格式

| Format | Use Case | Notes |
|--------|----------|-------|
| PNG | Logo、图标 | 支持透明 |
| JPG | 照片、背景 | 压缩率高 |
| SVG | 矢量图形 | 放大仍清晰 |
| WebP | 现代环境 | 轻量高质 |

#### 尺寸指南

| Asset Type | Recommended Size | Max Size |
|------------|------------------|----------|
| Logo | 500x500 px | 1000x1000 px |
| Icon | 128x128 px | 512x512 px |
| Background | 1920x1080 px | 3840x2160 px |
| Screenshot | 1920x1080 px | 2560x1440 px |

---

## 优先级详情

### 加载顺序

`scripts/load-assets.js` 按以下顺序搜索素材:

```javascript
// 1. 用户素材
const userPath = '~/.harness/video/assets/{category}/{file}';
if (exists(userPath)) return userPath;

// 2. 技能默认
const skillPath = 'skills/generate-video/assets/{category}/{file}';
if (exists(skillPath)) return skillPath;

// 3. 内置默认
return getBuiltInDefault();
```

### 部分覆盖

可以只覆盖部分素材:

```bash
# 只自定义背景（音效使用默认）
cp my-backgrounds.json ~/.harness/video/assets/backgrounds/backgrounds.json
```

### JSON 内的部分覆盖

```json
// ~/.harness/video/assets/backgrounds/backgrounds.json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand"
      // ... 自定义设置
    }
    // 省略 "neutral", "highlight" 等 → 从默认加载
  ]
}
```

**注意**: 有相同 `id` 时，用户设置优先。

---

## 验证

### 测试命令

```bash
# 素材加载测试
node scripts/load-assets.js test

# 显示背景设置
node scripts/load-assets.js backgrounds

# 显示音效设置
node scripts/load-assets.js sounds

# 显示搜索路径
node scripts/load-assets.js paths
```

### 预期输出

```
🧪 Testing asset loader...

🎨 Loading backgrounds...
  ✅ Loaded user backgrounds from: ~/.harness/video/assets/backgrounds/backgrounds.json

🔊 Loading sounds...
  ✅ Loaded skill sounds from: skills/generate-video/assets/sounds/sounds.json

📂 Asset paths:
{
  "user": "~/.harness/video/assets",
  "skill": "skills/generate-video/assets"
}
```

---

## 故障排除

### 问题: 素材未加载

**原因**: 文件路径错误

**解决方案**:
```bash
# 确认路径
node scripts/load-assets.js paths

# 确认文件存在
ls -la ~/.harness/video/assets/backgrounds/
```

### 问题: JSON 解析错误

**原因**: JSON 格式不正确

**解决方案**:
```bash
# 检查 JSON 有效性
cat ~/.harness/video/assets/backgrounds/backgrounds.json | jq .

# 确认错误消息
node scripts/load-assets.js test
```

### 问题: 音效不播放

**原因**: 文件格式不支持

**解决方案**:
```bash
# 转换为 MP3
ffmpeg -i input.wav -codec:a libmp3lame -b:a 192k output.mp3

# 确认文件信息
ffprobe output.mp3
```

### 问题: 字体不显示

**原因**: 字体文件路径无法解析

**解决方案**:
```typescript
// 使用绝对路径
const fontPath = path.join(os.homedir(), '.harness/video/assets/fonts/MyFont.ttf');
```

---

## 最佳实践

### 1. 版本控制

如需 Git 管理自定义素材:

```bash
# 放置在项目根目录
project-root/
├── .video-assets/
│   ├── backgrounds/
│   ├── sounds/
│   └── fonts/
└── .gitignore  # 排除 .harness/

# 创建符号链接
ln -s $(pwd)/.video-assets ~/.harness/video/assets
```

### 2. 团队共享

团队使用共同素材:

```bash
# 共享仓库
git clone https://github.com/company/video-assets.git ~/.harness/video/assets
```

### 3. 项目别素材

每个项目使用不同素材:

```bash
# 通过环境变量切换
export VIDEO_ASSETS_DIR=/path/to/project-specific/assets

# load-assets.js 引用环境变量
const assetsDir = process.env.VIDEO_ASSETS_DIR || defaultPath;
```

### 4. 许可证管理

```
~/.harness/video/assets/
└── LICENSES.md    # 各素材的许可证信息
```

```markdown
# Asset Licenses

## Sounds

- impact.mp3: CC0, from freesound.org/s/12345
- pop.mp3: CC BY 3.0, by Author Name

## Fonts

- MyFont-Bold.ttf: SIL Open Font License
```

---

## 示例集

### 品牌色背景

```json
{
  "id": "brand-primary",
  "name": "Brand Primary",
  "type": "gradient",
  "colors": {
    "primary": "#your-brand-color",
    "secondary": "#your-secondary-color"
  },
  "gradient": {
    "type": "linear",
    "angle": 135,
    "stops": [
      { "color": "#your-brand-color", "position": 0 },
      { "color": "#your-secondary-color", "position": 100 }
    ]
  },
  "usage": {
    "scenes": ["intro", "outro", "cta"]
  }
}
```

### 自定义音效集

```json
{
  "id": "whoosh",
  "name": "Whoosh Transition",
  "type": "effect",
  "category": "transition",
  "file": {
    "placeholder": "whoosh.mp3",
    "expected_duration": 0.6
  },
  "volume": {
    "default": 0.5,
    "with_narration": 0.3
  },
  "timing": {
    "offset_before_visual": -0.1
  }
}
```

### 企业 Logo

```json
{
  "scene": {
    "image": {
      "src": "~/.harness/video/assets/images/company-logo.png",
      "width": 300,
      "height": 150,
      "position": "top-right"
    }
  }
}
```

---

## 参考

- **Asset Loader**: `scripts/load-assets.js`
- **Default Backgrounds**: `assets/backgrounds/backgrounds.json`
- **Default Sounds**: `assets/sounds/sounds.json`
- **BackgroundLayer Component**: `remotion/src/components/BackgroundLayer.tsx`
- **Plans.md**: Phase 7 - Asset Foundation

---

## 更新历史

- **2026-02-02**: 初版创建（Phase 7 实现）
