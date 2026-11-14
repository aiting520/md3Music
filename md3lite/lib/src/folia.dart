import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'clock.dart';
import 'lyrics.dart';

/// Folia 风格动态歌词。
///
/// 关键点：
///  - 逐字填充由 CustomPainter 完成：每个字预先排版好 hi/dim 两份 TextPainter，
///    每帧只按进度裁剪，不重新排版、不重建 widget；
///  - 只有当前行的 painter 监听时钟（`repaint: clock`），其余行是静态的；
///  - 滚动用 TweenAnimationBuilder + easeOutBack，收尾有轻微过冲。
class FoliaLyrics extends StatefulWidget {
  const FoliaLyrics({
    super.key,
    required this.lines,
    required this.clock,
    this.fontSize = 28,
    this.accent = const Color(0xFF7DD3FC),
  });

  final List<LyricLine> lines;
  final PlaybackClock clock;
  final double fontSize;
  final Color accent;

  @override
  State<FoliaLyrics> createState() => _FoliaLyricsState();
}

class _FoliaLyricsState extends State<FoliaLyrics> {
  int _index = 0;

  double get _lineHeight => widget.fontSize * 1.52 + 46;

  @override
  void initState() {
    super.initState();
    _index = _indexAt(widget.clock.t);
    widget.clock.addListener(_onClock);
  }

  @override
  void didUpdateWidget(covariant FoliaLyrics old) {
    super.didUpdateWidget(old);
    if (old.clock != widget.clock) {
      old.clock.removeListener(_onClock);
      widget.clock.addListener(_onClock);
    }
    if (old.lines != widget.lines) {
      _index = _indexAt(widget.clock.t);
    }
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onClock);
    super.dispose();
  }

  int _indexAt(double t) {
    var idx = 0;
    for (var i = 0; i < widget.lines.length; i++) {
      if (t >= widget.lines[i].start) idx = i;
    }
    return idx;
  }

  void _onClock() {
    final i = _indexAt(widget.clock.t);
    if (i != _index) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < widget.lines.length; i++) {
      rows.add(_buildRow(i));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final target = -(_index * _lineHeight + _lineHeight / 2 - h / 2);

        return ClipRect(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: target),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutBack,
            builder: (context, y, child) {
              return Transform.translate(offset: Offset(0, y), child: child);
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        );
      },
    );
  }

  Widget _buildRow(int i) {
    final line = widget.lines[i];
    final active = i == _index;
    final dist = (i - _index).abs();

    final hiStyle = TextStyle(
      fontSize: widget.fontSize,
      height: 1.18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.4,
      shadows: active
          ? [
              Shadow(color: widget.accent.withOpacity(0.55), blurRadius: 16),
            ]
          : null,
    );
    final dimStyle = hiStyle.copyWith(
      color: Colors.white.withOpacity(0.34),
      shadows: null,
    );

    final hi = <TextPainter>[];
    final dim = <TextPainter>[];
    var total = 0.0;
    for (final w in line.words) {
      final a = TextPainter(
        text: TextSpan(text: w.text, style: hiStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final b = TextPainter(
        text: TextSpan(text: w.text, style: dimStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      hi.add(a);
      dim.add(b);
      total += a.width;
    }

    Widget row = SizedBox(
      height: _lineHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(
          words: line.words,
          clock: active ? widget.clock : null,
          hi: hi,
          dim: dim,
          totalWidth: total,
        ),
      ),
    );

    // 景深：近处两行模糊 + 半透明，更远的直接压暗
    if (dist >= 3) {
      row = Opacity(opacity: 0.13, child: row);
    } else if (dist == 2) {
      row = Opacity(
        opacity: 0.24,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
          child: row,
        ),
      );
    } else if (dist == 1) {
      row = Opacity(
        opacity: 0.40,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
          child: row,
        ),
      );
    }

    if (active) {
      row = Transform.scale(scale: 1.04, child: row);
    }
    return row;
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.words,
    required this.clock,
    required this.hi,
    required this.dim,
    required this.totalWidth,
  }) : super(repaint: clock);

  final List<LyricWord> words;
  final PlaybackClock? clock;
  final List<TextPainter> hi;
  final List<TextPainter> dim;
  final double totalWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty || hi.isEmpty) return;
    final t = clock?.t;
    var x = (size.width - totalWidth) / 2;
    final y = (size.height - hi.first.height) / 2;

    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final painterHi = hi[i];
      final painterDim = dim[i];

      painterDim.paint(canvas, Offset(x, y));

      final span = w.end - w.start;
      final p = t == null
          ? 1.0
          : span <= 0
              ? 1.0
              : ((t - w.start) / span).clamp(0.0, 1.0).toDouble();

      if (p > 0) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(x, y, painterHi.width * p, painterHi.height));
        painterHi.paint(canvas, Offset(x, y));
        canvas.restore();
      }
      x += painterHi.width;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}
