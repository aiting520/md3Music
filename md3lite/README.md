# md3lite — MD3Music 精简重写版

Flutter 重写，**只做两件事**：液态玻璃悬浮栏、Folia 风格动态歌词。
不依赖主工程的 565 个 Dart 文件，独立成一个可直接 `flutter build apk` 的工程。

## 结构

```
md3lite/
├── pubspec.yaml          仅 flutter sdk，零第三方依赖
└── lib/
    ├── main.dart         入口 / 播放页 / 背景光晕
    └── src/
        ├── clock.dart    播放时钟（唯一时间源）
        ├── dock.dart     液态玻璃悬浮栏（迷你条 + 导航胶囊）
        ├── folia.dart    Folia 歌词引擎（CustomPainter 逐字裁剪）
        ├── glass.dart    液态玻璃表面（blur + 受光 + 折射 + 流光）
        ├── lyrics.dart   3 首自创歌词 + 逐字时间轴
        └── pages.dart    首页 / 发现 / 资料库 / 设置
```

## 构建

CI 已经配好：`.github/workflows/lite-apk.yml`，推 `md3lite/**` 自动出包。

本地：

```bash
flutter create --org com.md3lite --project-name md3lite /tmp/app
rm -rf /tmp/app/lib && cp -r md3lite/lib /tmp/app/lib
cp md3lite/pubspec.yaml /tmp/app/pubspec.yaml
cd /tmp/app && flutter pub get && flutter build apk --release --target-platform android-arm64
```

## 液态玻璃悬浮栏

`glass.dart` 自下而上五层：`BackdropFilter` 模糊 → 半透明染色 → 顶部受光 +
底部内阴影 → 1px 折射描边 → 9s 斜向流光。

导航滑块用 `AnimationController` 驱动：`easeOutBack` 位移 + `sin(πt)` 横向拉伸，
滑动时像一滴被拖着的液体，停稳回弹。

## Folia 动态歌词

- **逐字填充**：每个字预排版两份 `TextPainter`（亮/暗），每帧只按进度
  `clipRect` 裁剪，不重新排版、不重建 widget；
- **只有当前行**的 painter 挂 `repaint: clock`，其余行完全静态；
- **景深**：相邻行 `ImageFiltered` 模糊 + 降透明度，更远的直接压暗到 0.13；
- **回弹滚动**：`TweenAnimationBuilder` + `easeOutBack`，切句有过冲；
- **发光**：当前行文字带 accent 色 `Shadow(blurRadius: 16)`。

歌词三首：《液态玻璃》《过曝的夏天》《午夜摆渡》，切歌时整页 accent 色跟着换。

## 体积

零第三方依赖 → 只有 Flutter 引擎本身，arm64 release APK 约 8–10 MB，
主工程 lite 包的一半以下。

## 接真实音频

`clock.dart` 的 `t` 换成 `AudioPlayer.position` 即可，歌词/进度条/悬浮栏都读同一个时钟。

## 出包说明（需要一次性操作）

GitHub 的 OAuth token 必须带 `workflow` scope 才能写入 `.github/workflows/`，
当前 token 只有 `read:org, repo`，所以 CI 文件放在 `md3lite/ci/lite-apk.yml`。

**二选一，一次即可：**

1. 网页上把 `md3lite/ci/lite-apk.yml` 复制成 `.github/workflows/lite-apk.yml`；
   之后每次推 `md3lite/**` 会自动构建并上传 artifact `md3lite-apk`。
2. 直接本地 `flutter build apk --release --target-platform android-arm64`。
