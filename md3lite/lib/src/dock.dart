import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'clock.dart';
import 'glass.dart';

/// 悬浮栏：迷你播放条 + 导航胶囊，两块都是液态玻璃。
class GlassDock extends StatefulWidget {
  const GlassDock({
    super.key,
    required this.clock,
    required this.title,
    required this.subtitle,
    required this.index,
    required this.onIndex,
    required this.onPrev,
    required this.onNext,
    required this.accent,
  });

  final PlaybackClock clock;
  final String title;
  final String subtitle;
  final int index;
  final ValueChanged<int> onIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Color accent;

  @override
  State<GlassDock> createState() => _GlassDockState();
}

class _GlassDockState extends State<GlassDock> with SingleTickerProviderStateMixin {
  late final AnimationController _slide =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
  int _from = 2;

  static const _items = <(IconData, String)>[
    (Icons.home_rounded, '首页'),
    (Icons.explore_rounded, '发现'),
    (Icons.play_circle_fill_rounded, '播放'),
    (Icons.library_music_rounded, '资料库'),
    (Icons.settings_rounded, '设置'),
  ];

  @override
  void didUpdateWidget(covariant GlassDock old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = old.index;
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniBar(),
        const SizedBox(height: 10),
        _navBar(),
      ],
    );
  }

  Widget _miniBar() {
    return LiquidGlass(
      radius: 22,
      blur: 24,
      tint: 0.11,
      child: SizedBox(
        height: 62,
        child: AnimatedBuilder(
          animation: widget.clock,
          builder: (context, _) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      _cover(42, 13),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _roundButton(Icons.skip_previous_rounded, widget.onPrev, 38),
                      const SizedBox(width: 8),
                      _playButton(),
                      const SizedBox(width: 8),
                      _roundButton(Icons.skip_next_rounded, widget.onNext, 38),
                    ],
                  ),
                ),
                // 底部进度
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        value: widget.clock.progress,
                        minHeight: 2,
                        backgroundColor: Colors.white.withOpacity(0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: widget.clock.toggle,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.22), blurRadius: 16),
          ],
        ),
        child: Icon(
          widget.clock.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 24,
          color: const Color(0xFF0B1020),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, double size) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.09),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, size: 19, color: Colors.white.withOpacity(0.92)),
      ),
    );
  }

  Widget _navBar() {
    return LiquidGlass(
      radius: 26,
      blur: 28,
      tint: 0.10,
      child: SizedBox(
        height: 66,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 12) / _items.length;
            final fromX = 6 + _from * w;
            final toX = 6 + widget.index * w;

            return AnimatedBuilder(
              animation: _slide,
              builder: (context, _) {
                final t = Curves.easeOutBack.transform(_slide.value.clamp(0.0, 1.0).toDouble());
                final x = fromX + (toX - fromX) * t;
                // 速度 → 沿运动方向拉伸，像一滴被拖着走的液体
                final stretch = 1 + 0.20 * math.sin(math.pi * _slide.value.clamp(0.0, 1.0).toDouble());

                return Stack(
                  children: [
                    Positioned(
                      left: x,
                      top: 8,
                      bottom: 8,
                      width: w,
                      child: Transform.scale(
                        scaleX: stretch,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.30),
                                Colors.white.withOpacity(0.10),
                              ],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.34)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.10),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(_items.length, (i) {
                        final selected = i == widget.index;
                        return SizedBox(
                          width: w,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onIndex(i),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _items[i].$1,
                                  size: 22,
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.52),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _items[i].$2,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.52),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _cover(double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.accent.withOpacity(0.95),
            widget.accent.withOpacity(0.45),
            const Color(0xFF1B1030),
          ],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.all(6),
          width: size * 0.3,
          height: size * 0.3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ),
    );
  }
}
