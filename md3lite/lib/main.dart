import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'src/clock.dart';
import 'src/dock.dart';
import 'src/folia.dart';
import 'src/glass.dart';
import 'src/lyrics.dart';
import 'src/pages.dart';

void main() => runApp(const Md3LiteApp());

class Md3LiteApp extends StatelessWidget {
  const Md3LiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MD3Music Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070A),
        colorSchemeSeed: const Color(0xFF7DD3FC),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final PlaybackClock _clock;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  int _page = 2;
  int _song = 0;

  Song get _data => demoLibrary[_song];
  Color get _accent => HSVColor.fromAHSV(1, _data.hue, 0.72, 0.92).toColor();

  @override
  void initState() {
    super.initState();
    _clock = PlaybackClock(duration: _data.duration);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _clock.tick(dt.clamp(0.0, 0.05).toDouble());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _setSong(int i) {
    setState(() {
      _song = (i + demoLibrary.length) % demoLibrary.length;
      _clock.duration = demoLibrary[_song].duration;
      _clock.seek(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: IndexedStack(
                    index: _page,
                    children: [
                      SimplePages.home(_accent),
                      SimplePages.find(_accent),
                      _playPage(),
                      SimplePages.library(_accent),
                      SimplePages.settings(_accent),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: GlassDock(
                    clock: _clock,
                    title: _data.title,
                    subtitle: '${_data.artist} · ${_data.album}',
                    index: _page,
                    onIndex: (i) => setState(() => _page = i),
                    onPrev: () => _setSong(_song - 1),
                    onNext: () => _setSong(_song + 1),
                    accent: _accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    final a = _accent;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF0B1220), a, 0.22)!,
                  const Color(0xFF05070A),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -140,
          top: -160,
          child: _glow(a.withOpacity(0.55), 420),
        ),
        Positioned(
          right: -160,
          top: 120,
          child: _glow(a.withOpacity(0.28), 380),
        ),
        Positioned(
          left: -80,
          bottom: -180,
          child: _glow(a.withOpacity(0.30), 440),
        ),
      ],
    );
  }

  Widget _glow(Color c, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c, c.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          LiquidGlass(
            radius: 19,
            blur: 16,
            tint: 0.09,
            sheen: false,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '本地库 · 已连接',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          LiquidGlass(
            radius: 19,
            blur: 16,
            tint: 0.09,
            sheen: false,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: const Text(
              '富江',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
          child: Row(
            children: [
              _bigCover(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_data.artist} · ${_data.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FoliaLyrics(
            lines: _data.lines,
            clock: _clock,
            accent: _accent,
          ),
        ),
        _seekBar(),
      ],
    );
  }

  Widget _bigCover() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withOpacity(0.95),
            _accent.withOpacity(0.45),
            const Color(0xFF10121F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }

  Widget _seekBar() {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: _accent,
                  inactiveTrackColor: Colors.white.withOpacity(0.16),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _clock.progress.clamp(0.0, 1.0).toDouble(),
                  onChanged: (v) => _clock.seek(v * _clock.duration),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(_clock.t),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.45),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _fmt(_clock.duration),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.45),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(double s) {
    final v = s.floor().clamp(0, 5999);
    return '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }
}
