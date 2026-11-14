/// 自创歌词（逐字时间轴）。
///
/// 数据格式很轻：[起始秒, 单字时长, 整行文字]，构建时按 rune 拆成逐字。
/// 想换成真实 LRC/KRC，只要产出同样的 `List<LyricLine>` 即可。
library;

class LyricWord {
  const LyricWord(this.text, this.start, this.end);
  final String text;
  final double start;
  final double end;
}

class LyricLine {
  const LyricLine(this.words);
  final List<LyricWord> words;

  double get start => words.isEmpty ? 0 : words.first.start;
  double get end => words.isEmpty ? 0 : words.last.end;
}

class Song {
  const Song({
    required this.title,
    required this.artist,
    required this.album,
    required this.hue,
    required this.lines,
  });

  final String title;
  final String artist;
  final String album;
  final double hue;
  final List<LyricLine> lines;

  double get duration => lines.isEmpty ? 0 : lines.last.end + 3.5;
}

List<LyricLine> _build(List<List<Object>> raw) {
  final out = <LyricLine>[];
  for (final row in raw) {
    final start = (row[0] as num).toDouble();
    final per = (row[1] as num).toDouble();
    final text = row[2] as String;
    final runes = text.runes.toList();
    final words = <LyricWord>[];
    var cursor = start;
    for (final r in runes) {
      words.add(LyricWord(String.fromCharCode(r), cursor, cursor + per));
      cursor += per;
    }
    if (words.isNotEmpty) out.add(LyricLine(words));
  }
  return out;
}

final List<Song> demoLibrary = <Song>[
  Song(
    title: '液态玻璃',
    artist: '富江',
    album: '透明剧场',
    hue: 196,
    lines: _build(const [
      [2.4, 0.46, '雨停在窗上'],
      [4.6, 0.40, '不肯落下'],
      [6.8, 0.42, '光穿过我'],
      [9.0, 0.38, '碎成好几块'],
      [11.6, 0.44, '你伸手碰了碰'],
      [14.4, 0.40, '我的边界'],
      [17.0, 0.46, '说这里好像'],
      [19.6, 0.52, '有点温度'],
      [23.4, 0.40, '我把自己'],
      [25.6, 0.38, '烧成透明'],
      [28.0, 0.42, '好让你看见'],
      [30.6, 0.40, '背后的天'],
      [33.6, 0.40, '可玻璃最怕'],
      [36.0, 0.36, '被人握住'],
      [38.6, 0.44, '一用力'],
      [40.4, 0.38, '就全是裂痕'],
      [44.2, 0.42, '如果碎了'],
      [46.6, 0.40, '请别扫走'],
      [49.2, 0.44, '每一片都还'],
      [52.0, 0.42, '映着你的脸'],
      [56.0, 0.46, '液态的夜'],
      [58.8, 0.44, '慢慢流下来'],
      [61.8, 0.40, '把我浇成'],
      [64.2, 0.42, '你喜欢的色'],
      [67.8, 0.44, '别擦干我'],
      [70.4, 0.40, '我还没看够'],
      [73.4, 0.46, '这个世界'],
      [76.2, 0.60, '透明的样子'],
    ]),
  ),
  Song(
    title: '过曝的夏天',
    artist: '富江',
    album: '透明剧场',
    hue: 32,
    lines: _build(const [
      [2.6, 0.34, '太阳把照片'],
      [4.6, 0.32, '晒成白'],
      [6.8, 0.34, '你的脸在里面'],
      [9.4, 0.30, '看不清'],
      [11.8, 0.36, '我们骑车经过'],
      [14.6, 0.32, '整条街'],
      [17.0, 0.34, '风把蝉声吹进'],
      [19.6, 0.36, '我耳朵'],
      [23.0, 0.32, '那年的我'],
      [25.2, 0.30, '什么都敢'],
      [27.6, 0.34, '包括把喜欢'],
      [30.0, 0.32, '喊出口'],
      [33.2, 0.34, '后来一场雨'],
      [35.6, 0.30, '全都模糊'],
      [38.0, 0.36, '只剩下光的轮廓'],
      [41.2, 0.34, '还在烧'],
      [44.6, 0.38, '过曝的夏天'],
      [47.2, 0.34, '亮得过分'],
      [49.8, 0.36, '我们都被拍进'],
      [52.6, 0.34, '同一格'],
      [55.8, 0.36, '别调曝光'],
      [58.4, 0.32, '我想留着'],
      [61.0, 0.38, '这点过亮的错'],
      [64.6, 0.40, '夏天太短'],
      [67.2, 0.34, '短到不够后悔'],
    ]),
  ),
  Song(
    title: '午夜摆渡',
    artist: '富江',
    album: '透明剧场',
    hue: 268,
    lines: _build(const [
      [3.0, 0.50, '零点的河面'],
      [6.0, 0.44, '没有灯'],
      [8.8, 0.46, '我撑着一条'],
      [11.6, 0.44, '很旧的船'],
      [14.8, 0.48, '你站在岸上'],
      [17.8, 0.42, '不说话'],
      [20.6, 0.50, '只把影子投给我'],
      [23.8, 0.46, '当作船票'],
      [28.0, 0.46, '摆渡的人'],
      [30.8, 0.42, '不问去向'],
      [33.6, 0.48, '只问你要不要上'],
      [36.8, 0.44, '我的船'],
      [40.4, 0.48, '水声很轻'],
      [43.2, 0.44, '像在劝人'],
      [46.0, 0.50, '别回头看岸上'],
      [49.4, 0.46, '那盏灯'],
      [53.4, 0.48, '天亮以前'],
      [56.2, 0.44, '我们都在水上'],
      [59.4, 0.46, '谁也不是'],
      [62.2, 0.44, '谁的岸'],
      [66.0, 0.50, '到了那边'],
      [69.0, 0.44, '你就忘了'],
      [71.8, 0.52, '我这条船'],
    ]),
  ),
];
