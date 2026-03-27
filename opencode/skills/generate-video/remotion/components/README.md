# Remotion 视觉组件

Phase 5: 视觉组件实现

## 组件

### 1. EmphasisBox

3 段强调显示组件。

**特性**:
- 3 级别: `high`, `medium`, `low`
- 5 样式: `bold`, `glitch`, `underline`, `highlight`, `glow`
- 脉冲动画支持
- 发光效果
- 效果音集成
- 可自定义颜色和字体

**使用**:
```tsx
import { EmphasisBox } from './components';

<EmphasisBox
  level="high"
  text="重要信息"
  color="#00F5FF"
  enablePulse={true}
  enableGlow={true}
  sound="pop"
  startFrame={30}
  durationFrames={90}
/>
```

**属性**:
- `level`: `'high' | 'medium' | 'low'` - 强调强度
- `text`: `string` - 显示文本
- `color`: `string` - 主色（十六进制）
- `sound`: `'none' | 'pop' | 'whoosh' | 'chime' | 'ding'` - 效果音
- `style`: `'bold' | 'glitch' | 'underline' | 'highlight' | 'glow'`
- `enablePulse`: `boolean` - 启用脉冲动画
- `enableGlow`: `boolean` - 启用发光效果
- `startFrame`: `number` - 开始帧（相对于场景）
- `durationFrames`: `number` - 持续帧数

---

### 2. TransitionWrapper

用 4 种过渡效果包装内容。

**特性**:
- 4 类型: `fade`, `slideIn`, `zoom`, `cut`
- 支持 Remotion `interpolate` 和 `spring`
- 4 缓动函数: `linear`, `easeIn`, `easeOut`, `easeInOut`
- 可自定义滑动方向
- 弹簧物理选项
- 预设配置

**使用**:
```tsx
import { TransitionWrapper, TransitionPresets } from './components';

<TransitionWrapper
  type="slideIn"
  duration={20}
  direction="right"
  easing="easeInOut"
>
  <YourContent />
</TransitionWrapper>

// 或使用预设
<TransitionWrapper {...TransitionPresets.fadeIn(15)}>
  <YourContent />
</TransitionWrapper>
```

**属性**:
- `type`: `'fade' | 'slideIn' | 'zoom' | 'cut'` - 过渡类型
- `duration`: `number` - 持续帧数（默认: 15）
- `direction`: `'left' | 'right' | 'top' | 'bottom'` - 滑动方向
- `easing`: `'linear' | 'easeIn' | 'easeOut' | 'easeInOut'`
- `useSpring`: `boolean` - 使用弹簧物理而非插值
- `springConfig`: `{ damping, stiffness, mass }` - 弹簧参数
- `delay`: `number` - 过渡开始前延迟（帧）

**预设**:
- `TransitionPresets.fadeIn(duration)`
- `TransitionPresets.fadeOut(duration)`
- `TransitionPresets.slideFromRight(duration)`
- `TransitionPresets.slideFromLeft(duration)`
- `TransitionPresets.zoomIn(duration)`
- `TransitionPresets.springBounce()`

---

### 3. ProgressIndicator

段落位置显示组件。

**特性**:
- 3 样式: `bar`, `dots`, `minimal`
- 4 位置: `top`, `bottom`, `left`, `right`
- 自动检测当前段落
- 动画过渡
- 可选段落标签
- 3 大小: `small`, `medium`, `large`

**使用**:
```tsx
import { ProgressIndicator, createSections } from './components';

const sections = createSections([
  { id: 'intro', name: 'Intro', startFrame: 0, durationFrames: 90 },
  { id: 'demo', name: 'Demo', startFrame: 90, durationFrames: 180 },
  { id: 'cta', name: 'CTA', startFrame: 270, durationFrames: 60 },
]);

<ProgressIndicator
  sections={sections}
  position="bottom"
  style="dots"
  showLabels={true}
  activeColor="#00F5FF"
  size="medium"
/>
```

**属性**:
- `sections`: `Section[]` - 段落数组
- `currentIndex`: `number` - 当前段落（省略时自动检测）
- `position`: `'top' | 'bottom' | 'left' | 'right'`
- `style`: `'bar' | 'dots' | 'minimal'`
- `showLabels`: `boolean` - 显示段落名称
- `activeColor`: `string` - 激活段落颜色
- `inactiveColor`: `string` - 非激活段落颜色
- `size`: `'small' | 'medium' | 'large'`
- `animated`: `boolean` - 动画过渡

**Section 类型**:
```typescript
interface Section {
  id: string;
  name: string;
  startFrame: number;
  endFrame: number;
  color?: string;
}
```

---

### 4. BackgroundLayer

5 种动画背景层。

**特性**:
- 5 类型: `neutral`, `highlight`, `dramatic`, `tech`, `warm`
- 静态图像或视频支持
- 动画渐变
- 类型特定效果:
  - `tech`: 动画网格覆盖
  - `dramatic`: 暗角效果
  - `highlight`: 漂浮粒子
  - `warm`: 脉冲径向渐变
- 模糊和覆盖支持
- 可自定义颜色

**使用**:
```tsx
import { BackgroundLayer, getRecommendedBackground } from './components';

// 生成渐变背景
<BackgroundLayer
  type="tech"
  animated={true}
  opacity={0.8}
/>

// 图像背景
<BackgroundLayer
  type="neutral"
  src="/path/to/background.jpg"
  blur={5}
  overlayColor="rgba(0,0,0,0.3)"
/>

// 视频背景
<BackgroundLayer
  type="highlight"
  src="/path/to/background.mp4"
  isVideo={true}
  opacity={0.6}
/>

// 根据场景类型自动选择
const bgType = getRecommendedBackground('intro'); // 返回 'highlight'
```

**属性**:
- `type`: `'neutral' | 'highlight' | 'dramatic' | 'tech' | 'warm'`
- `src`: `string` - 图像/视频路径（可选）
- `isVideo`: `boolean` - 源是视频吗？
- `primaryColor`: `string` - 主渐变色（十六进制）
- `secondaryColor`: `string` - 次渐变色（十六进制）
- `opacity`: `number` - 背景透明度（0-1）
- `animated`: `boolean` - 启用动画
- `blur`: `number` - 模糊强度（像素）
- `overlayColor`: `string` - 覆盖层色调色
- `overlayOpacity`: `number` - 覆盖层透明度（0-1）

**背景类型**:
| Type | Primary | Secondary | 用例 |
|------|---------|-----------|----------|
| `neutral` | 深灰 | 浅灰 | 通用内容、演示 |
| `highlight` | 青色 | 品红 | 介绍、CTA、强调 |
| `dramatic` | 黑色 | 红色 | Hook、问题陈述 |
| `tech` | 深蓝 | 海军蓝 | 架构、技术内容 |
| `warm` | 橙色 | 黄色 | 结论、温暖 CTA |

---

## 与 Schema 的集成

所有组件设计为与 Phase 4 schema 配合使用:

- `EmphasisBox` ← `emphasis.schema.json`
- `TransitionWrapper` ← `animation.schema.json`
- `BackgroundLayer` ← `direction.schema.json`（背景部分）

**集成示例**:
```typescript
import { EmphasisBox, TransitionWrapper, BackgroundLayer } from './components';
import { EmphasisSchema, AnimationSchema, DirectionSchema } from '../schemas';

// 从 JSON 加载 direction 数据
const direction = DirectionSchema.parse(directionData);

// 在 Remotion composition 中使用
<>
  <BackgroundLayer
    type={direction.background.type}
    primaryColor={direction.background.primaryColor}
    opacity={direction.background.opacity}
  />

  <TransitionWrapper
    type={direction.transition.type}
    duration={direction.transition.duration_frames}
    easing={direction.transition.easing}
  >
    <EmphasisBox
      level={direction.emphasis.level}
      text={direction.emphasis.text[0]}
      sound={direction.emphasis.sound}
      color={direction.emphasis.color}
    />
  </TransitionWrapper>
</>
```

---

## 动画性能

所有组件使用 Remotion 原生 `interpolate` 和 `spring` 函数以获得最佳性能:

- **CPU 高效**: 无重型 React 重渲染
- **可预测**: 确定性动画
- **流畅**: 60fps @ 1920x1080

**最佳实践**:
1. 使用 `spring` 实现自然运动（弹跳、弹性）
2. 使用 `interpolate` 实现线性/缓动运动
3. 避免在动画区域使用复杂 CSS 滤镜
4. 优先使用 CSS transform 而非布局更改

---

## 测试

各组件可在 Remotion Studio 中单独测试:

```bash
cd remotion
npm run dev
```

在 `src/Root.tsx` 中创建测试 composition:

```tsx
import { Composition } from 'remotion';
import { EmphasisBox, TransitionWrapper, ProgressIndicator, BackgroundLayer } from './components';

export const RemotionRoot = () => (
  <>
    <Composition
      id="EmphasisTest"
      component={EmphasisBox}
      durationInFrames={180}
      fps={30}
      width={1920}
      height={1080}
      defaultProps={{
        level: 'high',
        text: 'Test Emphasis',
        enablePulse: true,
      }}
    />
    {/* 更多测试 composition... */}
  </>
);
```

---

## 下一步

### Phase 6: 图像生成模式

视觉组件已实现，接下来与 AI 生成图像集成:

1. **Task 6.1**: 定义 `visual-patterns.schema.json`
2. **Task 6.2**: 创建图像提示词模板
3. **Task 6.3**: 实现 comparison/concept/flow 模式
4. **Task 6.4**: 与 Nano Banana Pro 集成

### 集成点

- 使用 `BackgroundLayer` 配合 AI 生成背景
- 在 AI 生成图表上叠加 `EmphasisBox`
- 用 `TransitionWrapper` 动画 AI 图像
- 用 `ProgressIndicator` 显示生成进度

---

## 许可证

Claude Code Harness - generate-video skill 的一部分。
MIT 许可证。
