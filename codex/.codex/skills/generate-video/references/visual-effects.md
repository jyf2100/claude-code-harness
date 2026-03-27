# Visual Effects Library

为视频增加冲击力的视觉效果模板集。

---

## 颜色调色板

### Cyberpunk / Neon（推荐）

有冲击力的技术视频用。

```tsx
const colors = {
  background: "#0A0A0F",  // 深暗色
  primary: "#00F5FF",     // 青色
  secondary: "#FF00FF",   // 品红
  accent: "#7B2FFF",      // 紫色
  text: "#FFFFFF",
  glow: "rgba(0, 245, 255, 0.5)",
};
```

### Corporate / Professional

商务用沉稳色调。

```tsx
const colors = {
  background: "#FFFFFF",
  primary: "#FF6B35",     // 橙色
  secondary: "#004E89",   // 海军蓝
  accent: "#2EC4B6",      // 青绿色
  text: "#1A1A2E",
};
```

---

## 效果组件

### GlitchText - 故障文本

RGB 分离 + 随机偏移实现赛博朋克风格文本。

```tsx
import { useCurrentFrame, interpolate, random } from "remotion";

const GlitchText: React.FC<{
  text: string;
  fontSize?: number;
  startFrame?: number;
}> = ({ text, fontSize = 72, startFrame = 0 }) => {
  const frame = useCurrentFrame();
  const adjustedFrame = frame - startFrame;

  // 故障强度（前 20 帧衰减）
  const glitchIntensity = adjustedFrame < 20
    ? interpolate(adjustedFrame, [0, 20], [20, 0])
    : 0;
  const opacity = interpolate(adjustedFrame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  // 随机偏移
  const offsetX = glitchIntensity > 0
    ? (random(`x-${frame}`) - 0.5) * glitchIntensity
    : 0;
  const offsetY = glitchIntensity > 0
    ? (random(`y-${frame}`) - 0.5) * glitchIntensity * 0.5
    : 0;

  return (
    <div style={{ position: "relative", opacity }}>
      {/* Red channel (品红) */}
      <div
        style={{
          position: "absolute",
          fontSize,
          fontWeight: 800,
          color: "#FF00FF",
          transform: `translate(${offsetX - 3}px, ${offsetY}px)`,
          mixBlendMode: "screen",
          opacity: glitchIntensity > 0 ? 0.8 : 0,
        }}
      >
        {text}
      </div>
      {/* Blue channel (青色) */}
      <div
        style={{
          position: "absolute",
          fontSize,
          fontWeight: 800,
          color: "#00F5FF",
          transform: `translate(${offsetX + 3}px, ${offsetY}px)`,
          mixBlendMode: "screen",
          opacity: glitchIntensity > 0 ? 0.8 : 0,
        }}
      >
        {text}
      </div>
      {/* Main text */}
      <div
        style={{
          fontSize,
          fontWeight: 800,
          color: "#FFFFFF",
          textShadow: "0 0 20px rgba(0, 245, 255, 0.5)",
          transform: `translate(${offsetX}px, ${offsetY}px)`,
        }}
      >
        {text}
      </div>
    </div>
  );
};
```

**使用示例**:
```tsx
<GlitchText text="革新性的功能" fontSize={64} startFrame={0} />
```

---

### Particles - 粒子系统

漂浮/收敛的粒子动画。

```tsx
import { useMemo } from "react";
import { useCurrentFrame, useVideoConfig, interpolate, random } from "remotion";

const Particles: React.FC<{
  count?: number;
  converge?: boolean;      // 是否向中央收敛
  convergeFrame?: number;  // 收敛完成帧
}> = ({ count = 50, converge = false, convergeFrame = 100 }) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();

  // useMemo 固定粒子初始位置（重要！）
  const particles = useMemo(() => {
    return Array.from({ length: count }, (_, i) => ({
      id: i,
      startX: random(`px-${i}`) * width,
      startY: random(`py-${i}`) * height,
      speed: 0.5 + random(`speed-${i}`) * 2,
      size: 2 + random(`size-${i}`) * 4,
      hue: random(`hue-${i}`) > 0.5 ? "#00F5FF" : "#FF00FF",
    }));
  }, [count, width, height]);

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      {particles.map((p) => {
        const progress = converge
          ? interpolate(frame, [0, convergeFrame], [0, 1], {
              extrapolateRight: "clamp",
            })
          : 0;

        const targetX = width / 2;
        const targetY = height / 2;

        // 收敛或漂浮
        const x = converge
          ? interpolate(progress, [0, 1], [p.startX, targetX])
          : p.startX + Math.sin(frame * 0.02 * p.speed + p.id) * 30;
        const y = converge
          ? interpolate(progress, [0, 1], [p.startY, targetY])
          : p.startY + ((frame * p.speed * 0.5) % height);

        const opacity = converge
          ? interpolate(progress, [0, 0.8, 1], [0.8, 0.8, 0])
          : 0.6 + Math.sin(frame * 0.1 + p.id) * 0.4;

        return (
          <div
            key={p.id}
            style={{
              position: "absolute",
              left: x,
              top: y % height,
              width: p.size,
              height: p.size,
              borderRadius: "50%",
              backgroundColor: p.hue,
              boxShadow: `0 0 ${p.size * 2}px ${p.hue}`,
              opacity,
            }}
          />
        );
      })}
    </div>
  );
};
```

**使用示例**:
```tsx
{/* 漂浮粒子 */}
<Particles count={80} />

{/* 收敛粒子（CTA 场景用） */}
<Particles count={100} converge convergeFrame={150} />
```

---

### ScanLine - 扫描线

屏幕上穿过的解析波效果。

```tsx
const ScanLine: React.FC<{ speed?: number }> = ({ speed = 1 }) => {
  const frame = useCurrentFrame();
  const { height } = useVideoConfig();
  const y = (frame * speed * 5) % (height + 100);

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: y - 50,
        height: 100,
        background: `linear-gradient(180deg, transparent, #00F5FF40, transparent)`,
        boxShadow: "0 0 60px #00F5FF",
      }}
    />
  );
};
```

**使用示例**:
```tsx
{/* 解析中的演出 */}
{frame < 60 && <ScanLine speed={3} />}
```

---

### ProgressBar - 进度条

并行处理的进度可视化。

```tsx
const ProgressBar: React.FC<{ progress: number; label: string }> = ({
  progress,
  label,
}) => {
  return (
    <div style={{ width: 400, marginBottom: 16 }}>
      <div
        style={{
          fontSize: 18,
          color: "#FFFFFF",
          marginBottom: 8,
          fontFamily: "monospace",
        }}
      >
        {label}
      </div>
      <div
        style={{
          height: 8,
          background: "rgba(255,255,255,0.1)",
          borderRadius: 4,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            width: `${progress * 100}%`,
            height: "100%",
            background: "linear-gradient(90deg, #00F5FF, #FF00FF)",
            boxShadow: "0 0 20px #00F5FF",
            borderRadius: 4,
          }}
        />
      </div>
    </div>
  );
};
```

**使用示例**:
```tsx
const agents = [
  { name: "Agent 1: Intro", progress: Math.min(1, frame / 150) },
  { name: "Agent 2: Demo", progress: Math.min(1, (frame - 30) / 180) },
  { name: "Agent 3: CTA", progress: Math.min(1, (frame - 60) / 120) },
];

{agents.map((agent) => (
  <ProgressBar key={agent.name} progress={agent.progress} label={agent.name} />
))}
```

---

### 3D Parallax - 视差效果

有深度的 3D 卡片显示。

```tsx
const ParallaxCard: React.FC<{
  children: React.ReactNode;
  delay: number;
  color: string;
}> = ({ children, delay, color }) => {
  const frame = useCurrentFrame();

  const opacity = interpolate(frame, [delay, delay + 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const z = interpolate(frame, [delay, delay + 30], [-100, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const rotateY = interpolate(frame, [delay, delay + 30], [45, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        width: 280,
        height: 160,
        background: `linear-gradient(135deg, ${color}30, ${color}10)`,
        border: `2px solid ${color}`,
        borderRadius: 16,
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        opacity,
        transform: `translateZ(${z}px) rotateY(${rotateY}deg)`,
        boxShadow: `0 0 40px ${color}40`,
      }}
    >
      {children}
    </div>
  );
};
```

**使用示例**:
```tsx
<div style={{ display: "flex", gap: 40, perspective: 1000 }}>
  <ParallaxCard delay={30} color="#00F5FF">LP/广告</ParallaxCard>
  <ParallaxCard delay={70} color="#FF00FF">Intro演示</ParallaxCard>
  <ParallaxCard delay={110} color="#7B2FFF">发布说明</ParallaxCard>
</div>
```

---

## 组合示例

### 重视冲击力的 Hook 场景

```tsx
const HookScene: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ background: "#0A0A0F" }}>
      <Particles count={80} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
        }}
      >
        <GlitchText text="从代码到视频" fontSize={64} startFrame={0} />
        <div style={{ height: 20 }} />
        <GlitchText text="进入自动生成的时代" fontSize={64} startFrame={15} />
      </div>
      {frame < 30 && <ScanLine speed={3} />}
    </AbsoluteFill>
  );
};
```

### CTA 场景（粒子收敛）

```tsx
const CTAScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame: frame - 60, fps, config: { damping: 200 } });
  const pulse = Math.sin(frame / 10) * 0.03 + 1;

  return (
    <AbsoluteFill style={{ background: "#0A0A0F" }}>
      <Particles count={100} converge convergeFrame={150} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
        }}
      >
        <div
          style={{
            opacity: interpolate(frame, [60, 90], [0, 1], {
              extrapolateRight: "clamp",
            }),
            transform: `scale(${Math.max(0, logoScale)})`,
          }}
        >
          <Img src={staticFile("logo.png")} style={{ width: 120, height: 120 }} />
        </div>
        <div
          style={{
            marginTop: 40,
            padding: "16px 48px",
            background: "linear-gradient(90deg, #00F5FF, #FF00FF)",
            borderRadius: 12,
            fontSize: 24,
            fontWeight: 700,
            color: "#0A0A0F",
            transform: `scale(${pulse})`,
            boxShadow: "0 0 40px rgba(0, 245, 255, 0.6)",
          }}
        >
          立即尝试
        </div>
      </div>
    </AbsoluteFill>
  );
};
```

---

## 注意事项

| 项目 | 规则 |
|------|--------|
| `random()` | 必须用参数指定种子（每帧相同值） |
| `useMemo` | 粒子等大量对象必须记忆化 |
| `interpolate` | `extrapolateRight: "clamp"` 防止值失控 |
| `spring` | `config: { damping: 200 }` 使动画流畅 |
| CSS animations | 禁止使用，使用 Remotion 的 `useCurrentFrame()` |

---

## References

- [generator.md](generator.md) - 并行生成引擎
- [best-practices.md](best-practices.md) - 视频制作最佳实践
