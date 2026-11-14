import 'package:flutter/foundation.dart';

/// 播放时钟：整个界面只有一个时间源。
///
/// 真实接入音频时，只要把 [t] 换成 `audio.position.inSeconds`，
/// 其余（歌词、进度条、悬浮栏环）都跟着走。
class PlaybackClock extends ChangeNotifier {
  PlaybackClock({this.duration = 90});

  double duration;
  double t = 0;
  bool playing = true;

  /// 由 Ticker 每帧推进。
  void tick(double dt) {
    if (!playing) return;
    t += dt;
    if (t >= duration) t = 0;
    notifyListeners();
  }

  void toggle() {
    playing = !playing;
    notifyListeners();
  }

  void seek(double v) {
    t = v.clamp(0.0, duration).toDouble();
    notifyListeners();
  }

  double get progress => duration <= 0 ? 0 : (t / duration).clamp(0.0, 1.0).toDouble();
}
