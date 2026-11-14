# MD3Music · Liquid（UI 重写）

对 `md3Music` 播放器界面的一次**零依赖重写**：液态玻璃悬浮栏 + Folia 风格动态歌词。
纯 `HTML/CSS/JS`，无框架、无构建、无外部字体与图片，**整包 48 KB**。

原项目是 Flutter（Dart）+ Rust，565 个 Dart 文件、约 300 MB。这里把「悬浮栏 + 歌词」
这两块最重的视觉层单独抽出来重写，可以直接在浏览器里跑、逐帧调参，再照着接回 Flutter。

## 目录

| 文件 | 作用 | 体积 |
|---|---|---|
| `index.html` | 结构：顶部胶囊、播放页、首页/发现/资料库/设置、Dock | 8.6 KB |
| `style.css` | 液态玻璃分层、Folia 歌词样式、页面与响应式 | 21 KB |
| `app.js` | 播放时钟、逐字歌词引擎、弹簧滚动、液态滑块 | 13 KB |
| `lyrics.js` | 3 首自创歌词（带逐字时间轴） | 5.5 KB |

## 运行

```bash
cd web-lite
python3 -m http.server 8765
# 打开 http://127.0.0.1:8765/
```

## 液态玻璃悬浮栏

自下而上五层，和 `lib/core/widgets/liquid_glass.dart` 的 `LiquidGlassStyle` 一一对应：

1. `backdrop-filter: blur(26px) saturate(190%) brightness(1.06)` — 背后内容软化但不发灰；
2. 低透明度染色底（`--glass-tint`）；
3. `::before` 顶部受光渐变 + 底部内阴影 —— 「厚度」靠这一层；
4. `::after` 的 `conic-gradient` + `mask-composite` 边缘折射环；
5. `.sheen` 斜向流光，9 s 循环。

三档预设直接沿用原项目：悬浮胶囊 `blur 26 / tint .26`、常驻条 `blur 18 / tint .34`、
面板 `blur 30 / tint .22`。

**液态滑块**（`#blob`）不是 CSS 过渡：用弹簧积分
`a = (target - x) * 220 - v * 26` 驱动位移，并把速度映射成 `scaleX` 拉伸、
`scaleY` 轻微压缩，`transform-origin` 随方向切换 —— 滑动时像一滴液体被拖着走。

## Folia 风格动态歌词

- **逐字扫描**：每个字一条水平渐变 + `background-clip: text`，由 `--p`（0~1）推进；
  唱到的字纯白并带 `drop-shadow` 发光，未唱的字压到 34% 灰。
- **景深**：非当前行 `opacity .28` + `blur 2.4px` + `scale .84`，越远越虚。
- **弹簧滚动**：`k=168 / d=24`（欠阻尼），切句时会轻轻过冲再回弹，不是线性缓动。
- **点亮微动**：字形 `translateY(-2.5px) scale(1.06)` 仅在被扫描到的那一刻发生。
- **间奏点**：两行间隔 > 2.05 s 自动插一段跳动的三点。
- **呼吸光**：当前行背后一层径向渐变，只做透明度呼吸。

歌词全部自创，写在 `lyrics.js`：

```js
{ t: 14.0, d: .44, w: ["你","伸","手","碰","了","碰"] }   // 行起点、单字时长、字
{ t: 22.2, d: .52, w: ["有","点","温","度"] }
```

三首：《液态玻璃》《过曝的夏天》《午夜摆渡》，各 22–28 行，切歌时整页色相
（`--hue`）跟着换，背景、封面、进度条、滑块高光一起变。

## 交互

- 点歌词任意一行 → 跳到该句
- 拖进度条 → 任意 seek，已唱的行会整行补满
- 点 Dock → 切换页面，滑块弹性跟随
- 设置页可关掉液态玻璃 / 流光 / 逐字 / 弹簧，字号与景深可点按切换

## 性能取舍

初版在无 GPU 的软件渲染环境只有 3 fps，逐项定位后做了四件事，回到 24–39 fps
（真机 GPU 下为满帧）：

1. 去掉全屏 `filter: blur(52px)` —— 径向渐变本身就够柔和；
2. 三层全屏渐变（极光 + 色晕 + 暗角）合并成**单层 background**；
3. 全屏 `mask-image` 换成两条静态渐隐条，滚动时不再重算遮罩；
4. 弹簧静止时不写 `transform`，两个 rAF 循环合并成一个。

## 接回 Flutter

- 玻璃参数照 `LiquidGlassStyle` 三档传即可；
- 歌词逐字填充对应现有的 `lib/widgets/apple_lyrics/renderers/lyric_sweep_fill.dart`，
  把这里的 `--p` 推进逻辑换成 `AnimationController` + `KrcParser` 的字时间轴；
- 弹簧滚动可直接换 `lib/widgets/apple_lyrics/animation/spring.dart` 的同一套参数（k=168, d=24）。
