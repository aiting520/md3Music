import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../build_flags.dart';

/// 全局「液态玻璃」开关（设置 → 导航与布局 → 悬浮播放器）。
///
/// 默认开启；关闭后所有 [LiquidGlass] 退化为原来的实色表面，
/// 用于低端机省电 / 视觉不习惯时一键还原。
final ValueNotifier<bool> kLiquidGlassEnabled = ValueNotifier<bool>(true);

/// 液态玻璃表面的视觉参数。
///
/// 三档预设覆盖本项目的三种落点：悬浮胶囊（[LiquidGlass.tintPresetFloating]）、
/// 底部常驻条（[LiquidGlass.tintPresetDocked]）与歌词面板
/// （[LiquidGlass.tintPresetPanel]）。三者的毛玻璃强度与高光强度不同：
/// 悬浮件小、可厚一点；常驻条铺满屏宽、必须克制，否则滚动时整条都在抖。
class LiquidGlassStyle {
  const LiquidGlassStyle({
    required this.blurSigma,
    required this.tintAlpha,
    required this.highlightAlpha,
    required this.sheenAlpha,
    required this.refraction,
  });

  /// 背景模糊半径（逻辑像素）。TV 构建由 [tvBlurSigma] 钳制。
  final double blurSigma;

  /// 玻璃底色不透明度（叠加在模糊背景之上）。
  final double tintAlpha;

  /// 顶部高光 / 左上镜面光斑强度。
  final double highlightAlpha;

  /// 流动高光（sheen）强度；0 表示不画。
  final double sheenAlpha;

  /// 边缘折射层强度（0~1），越大玻璃越「厚」。
  final double refraction;

  static const LiquidGlassStyle floating = LiquidGlassStyle(
    blurSigma: 26,
    tintAlpha: 0.26,
    highlightAlpha: 0.30,
    sheenAlpha: 0.12,
    refraction: 1.0,
  );

  static const LiquidGlassStyle docked = LiquidGlassStyle(
    blurSigma: 18,
    tintAlpha: 0.34,
    highlightAlpha: 0.18,
    sheenAlpha: 0.07,
    refraction: 0.7,
  );

  static const LiquidGlassStyle panel = LiquidGlassStyle(
    blurSigma: 30,
    tintAlpha: 0.22,
    highlightAlpha: 0.22,
    sheenAlpha: 0.05,
    refraction: 0.85,
  );

  LiquidGlassStyle scaled(double t) => t >= 1.0
      ? this
      : LiquidGlassStyle(
          blurSigma: blurSigma * t,
          tintAlpha: tintAlpha * t,
          highlightAlpha: highlightAlpha * t,
          sheenAlpha: sheenAlpha * t,
          refraction: refraction * t,
        );
}

/// 液态玻璃表面。
///
/// 组成（自底向上）：
/// 1. `BackdropFilter` 高斯模糊 + 饱和度提升（[ui.ColorFilter.matrix]）——
///    玻璃后面那层内容被「软化」但不发灰；
/// 2. 主题色调底（[tint] 的低透明度），决定玻璃偏暖还是偏冷；
/// 3. [CustomPaint] 画的高光层：边缘 1px 折射描边、顶部受光渐变、
///    左上镜面光斑、底部内阴影——「厚度」全靠这一层；
/// 4. 可选斜向流光（慢速 9s 循环，随主题强调色微调）；
/// 5. 子内容。
///
/// 性能约束：
/// - 整块 `RepaintBoundary`，流光只重绘 [CustomPaint] 那一层，
///   不触发子树 build/layout；
/// - `BackdropFilter` 每帧都要采样后屏，故只在**小块**（悬浮胶囊 / 迷你条 /
///   歌词面板）上使用，不进入列表项；
/// - TV 构建把 sigma 钳到 `tvBlurSigma`，系统「减弱动态效果」时流光完全关闭。
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.style = LiquidGlassStyle.floating,
    this.borderRadius = 24,
    this.tint,
    this.fallbackColor,
    this.opacity = 1.0,
    this.sheen = true,
    this.enabled,
    this.padding,
  });

  final Widget child;

  /// 视觉参数。三档预设见 [LiquidGlassStyle]。
  final LiquidGlassStyle style;

  /// 圆角半径（dp）。需与调用方外层裁剪的圆角一致，否则描边会画到裁切外。
  final double borderRadius;

  /// 玻璃底色；默认取主题 `surface`。
  final Color? tint;

  /// 关闭玻璃时使用的表面色。
  ///
  /// 默认把 [tint] 合成成不透明色；但调用方原本的底色可能是
  /// `surface@0.2`（壁纸档）这类**半透明**色，直接合成会改变观感，
  /// 故允许显式传入「关掉玻璃后应当得到的那块颜色」。
  final Color? fallbackColor;

  /// 整体不透明度（0~1）。用于悬浮胶囊/迷你条在形态切换时的交接淡出：
  /// 模糊与高光一起线性衰减，避免「底透明了、模糊还在」的穿帮。
  final double opacity;

  /// 是否播放慢速流光。
  final bool sheen;

  /// 是否启用玻璃效果；null 时读全局 [kLiquidGlassEnabled]。
  final bool? enabled;

  final EdgeInsetsGeometry? padding;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSheen();
  }

  @override
  void didUpdateWidget(covariant LiquidGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSheen();
  }

  /// 流光只在「允许动效 + 开关开启 + 本组件要求」时跑；其余情况停表，
  /// 避免后台页面（Offstage 外仍有 ticker）白耗一格 GPU。
  void _syncSheen() {
    final bool allowed = widget.sheen &&
        (widget.enabled ?? kLiquidGlassEnabled.value) &&
        !kTvBuild &&
        !MediaQuery.disableAnimationsOf(context);
    if (allowed && !_sheenController.isAnimating) {
      _sheenController.repeat();
    } else if (!allowed && _sheenController.isAnimating) {
      _sheenController.stop();
    }
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: kLiquidGlassEnabled,
      builder: (context, globalEnabled, _) {
        final bool enabled = widget.enabled ?? globalEnabled;
        final ColorScheme cs = Theme.of(context).colorScheme;
        final LiquidGlassStyle style =
            widget.style.scaled(widget.opacity.clamp(0.0, 1.0));
        final BorderRadius radius = BorderRadius.circular(widget.borderRadius);
        final Color tint = widget.tint ?? cs.surface;
        final bool dark = Theme.of(context).brightness == Brightness.dark;

        final Widget content = widget.padding == null
            ? widget.child
            : Padding(padding: widget.padding!, child: widget.child);

        // 交接淡出到 0：整块不画（等同于 Material 的完全透明）。
        if (widget.opacity <= 0.02) {
          return ClipRRect(
            borderRadius: radius,
            child: ColoredBox(color: Colors.transparent, child: content),
          );
        }

        // 关闭玻璃：退化为调用方原来的表面色（不叠模糊，零额外开销）。
        if (!enabled) {
          return ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: widget.fallbackColor ?? _flattenOpaque(tint),
              child: content,
            ),
          );
        }

        Widget surface = Stack(
          fit: StackFit.passthrough,
          children: [
            // 色调底：让玻璃有「材质」而不是纯模糊。
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // 上亮下暗的纵向渐变，模拟光线从上方进入玻璃。
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: style.tintAlpha * 0.55),
                      tint.withValues(alpha: style.tintAlpha * 0.85),
                      Colors.black.withValues(
                        alpha: style.tintAlpha * (dark ? 0.35 : 0.18),
                      ),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            // 高光 / 折射 / 流光层：只这一层随动画重绘。
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _sheenController,
                    builder: (context, _) => CustomPaint(
                      painter: _LiquidGlassPainter(
                        progress: _sheenController.isAnimating
                            ? _sheenController.value
                            : 0.0,
                        radius: widget.borderRadius,
                        style: style,
                        sheenAlpha:
                            _sheenController.isAnimating ? style.sheenAlpha : 0.0,
                        accent: cs.primary,
                        dark: dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            content,
          ],
        );

        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // 模糊 + 饱和度提升：一层滤镜完成，避免串联两层 BackdropFilter
            // （每层都要重新采样后屏，成本翻倍）。
            filter: ui.ImageFilter.blur(
              sigmaX: tvBlurSigma(math.max(0.01, style.blurSigma)),
              sigmaY: tvBlurSigma(math.max(0.01, style.blurSigma)),
            ),
            child: surface,
          ),
        );
      },
    );
  }

  /// 非玻璃态需要一个不透明底色：把半透明 tint 合成到 surface 上，
  /// 保证观感与旧实现（`Material(color: surface)`）一致。
  Color _flattenOpaque(Color tint) =>
      tint.a >= 0.999 ? tint : Color.alphaBlend(tint, const Color(0xFF000000));
}

/// 玻璃高光 / 折射 / 流光的绘制层。
class _LiquidGlassPainter extends CustomPainter {
  const _LiquidGlassPainter({
    required this.progress,
    required this.radius,
    required this.style,
    required this.sheenAlpha,
    required this.accent,
    required this.dark,
  });

  /// 流光相位 0~1（控制器循环值）。
  final double progress;
  final double radius;
  final LiquidGlassStyle style;
  final double sheenAlpha;
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final RRect inner = rrect.deflate(0.75);
    final double hi = style.highlightAlpha.clamp(0.0, 1.0);
    final double refr = style.refraction.clamp(0.0, 1.0);
    final Color white = Colors.white;
    final Color shade = dark ? Colors.black : const Color(0xFF0B1220);

    // —— 1. 顶部受光：上白下透明，是一条竖直渐变而不是描边 ——
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height * 0.55),
          <Color>[
            white.withValues(alpha: hi * 0.55),
            white.withValues(alpha: 0.0),
          ],
        ),
    );

    // —— 2. 左上镜面光斑：模拟光源在左上方的椭圆反光 ——
    final Offset spot = Offset(size.width * 0.24, size.height * 0.10);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = ui.Gradient.radial(
          spot,
          math.max(size.width * 0.42, size.height * 0.9),
          <Color>[
            white.withValues(alpha: hi * 0.62),
            white.withValues(alpha: hi * 0.10),
            white.withValues(alpha: 0.0),
          ],
          <double>[0.0, 0.55, 1.0],
        ),
    );

    // —— 3. 底部内阴影：玻璃有厚度，下缘要压暗 ——
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height),
          Offset(0, size.height * 0.62),
          <Color>[
            shade.withValues(alpha: (dark ? 0.30 : 0.16) * refr),
            shade.withValues(alpha: 0.0),
          ],
        ),
    );

    // —— 4. 边缘折射：1dp 的亮线打断在右下，形成「玻璃边缘」读数 ——
    if (refr > 0.01) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..shader = ui.Gradient.sweep(
            Offset(size.width / 2, size.height / 2),
            <Color>[
              white.withValues(alpha: 0.42 * refr),
              white.withValues(alpha: 0.06 * refr),
              white.withValues(alpha: 0.22 * refr),
              white.withValues(alpha: 0.05 * refr),
              white.withValues(alpha: 0.42 * refr),
            ],
            <double>[0.0, 0.30, 0.55, 0.80, 1.0],
          ),
      );
      // 内侧 1px 暗线：把亮边「撑」出立体感（双线是玻璃质感的常见做法）。
      canvas.drawRRect(
        rrect.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = shade.withValues(alpha: 0.10 * refr),
      );
    }

    // —— 5. 斜向流光：9s 一次缓慢扫过，用 plus 混合提亮而不是加白膜 ——
    if (sheenAlpha > 0.001) {
      // 相位映射到 [-0.6, 1.6]，两端留出屏外，避免来回折返时看到边界。
      final double travel = -0.6 + progress * 2.2;
      final double cx = size.width * travel;
      final double bandW = size.width * 0.30 + size.height * 0.35;
      final Paint sheen = Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(cx - bandW, -size.height * 0.35),
          Offset(cx + bandW, size.height * 1.35),
          <Color>[
            white.withValues(alpha: 0.0),
            Color.lerp(white, accent, 0.18)!.withValues(alpha: sheenAlpha),
            white.withValues(alpha: 0.0),
          ],
          <double>[0.0, 0.5, 1.0],
        );
      canvas.drawRRect(inner, sheen);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPainter old) =>
      old.progress != progress ||
      old.radius != radius ||
      old.sheenAlpha != sheenAlpha ||
      old.accent != accent ||
      old.dark != dark ||
      old.style != style;
}

/// 玻璃面板的「顶缘高光条」：一条 1dp 的白色渐变线，贴在圆角上沿。
///
/// 用在歌词玻璃面板顶部——玻璃本身已经很淡，这条线负责把面板边界
/// 从背景里「勾」出来，又不像实线描边那么生硬。
class LiquidGlassEdgeLight extends StatelessWidget {
  const LiquidGlassEdgeLight({
    super.key,
    this.radius = 28,
    this.height = 1,
    this.intensity = 0.5,
  });

  final double radius;
  final double height;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        margin: EdgeInsets.symmetric(horizontal: radius * 0.75),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: intensity),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
