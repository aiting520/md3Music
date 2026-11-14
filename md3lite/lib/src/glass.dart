import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 液态玻璃表面。
///
/// 自下而上：
///  1. BackdropFilter 高斯模糊 + 饱和度（背后内容软化但不发灰）
///  2. 半透明染色底
///  3. 顶部受光渐变 + 底部内阴影（"厚度"）
///  4. 1px 边缘折射描边
///  5. 可选斜向流光（9s 循环）
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 26,
    this.blur = 26,
    this.tint = 0.10,
    this.sheen = true,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double tint;
  final bool sheen;
  final EdgeInsets padding;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> with SingleTickerProviderStateMixin {
  late final AnimationController _sheen =
      AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(widget.tint * 1.5),
                Colors.white.withOpacity(widget.tint * 0.75),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Stack(
            children: [
              Padding(padding: widget.padding, child: widget.child),

              // 3. 顶部受光 + 底部内阴影
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: r,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.22),
                          Colors.white.withOpacity(0.02),
                          Colors.transparent,
                          Colors.black.withOpacity(0.10),
                        ],
                        stops: const [0, 0.22, 0.62, 1],
                      ),
                    ),
                  ),
                ),
              ),

              // 5. 斜向流光
              if (widget.sheen)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: _sheen,
                        builder: (context, _) {
                          return FractionalTranslation(
                            translation: Offset(-1.8 + 3.6 * _sheen.value, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 0.32,
                                heightFactor: 1,
                                child: Transform.rotate(
                                  angle: 0.22,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withOpacity(0.16),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
