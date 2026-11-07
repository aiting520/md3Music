import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/song.dart';

/// m3u8 歌单导出工具（借鉴 VLC / Poweramp 的歌单导出能力）。
///
/// 仅导出有 localPath 的本地歌曲：在线歌曲没有稳定的本地路径，写进 m3u
/// 会让其他播放器拿到过期 URL。在线歌曲数量在导出结果里单独告知。
class M3uExporter {
  M3uExporter._();

  /// 构建 m3u 文本。返回 (文本, 本地歌曲数, 被跳过的在线歌曲数)。
  static (String, int, int) build({
    required String playlistName,
    required List<Song> songs,
  }) {
    final buffer = StringBuffer('#EXTM3U\n');
    var exported = 0;
    var skipped = 0;
    for (final song in songs) {
      final path = song.localPath;
      if (path == null || path.isEmpty) {
        skipped++;
        continue;
      }
      final artist = song.artist.isEmpty ? '未知歌手' : song.artist;
      buffer.write('#EXTINF:${song.duration.inSeconds},$artist - ${song.title}\n');
      buffer.write('$path\n');
      exported++;
    }
    return (buffer.toString(), exported, skipped);
  }

  /// 导出为临时文件并通过系统分享面板发出。返回导出统计文案；无可导出的
  /// 本地歌曲时返回 null（调用方据此提示「歌单里没有本地歌曲」）。
  static Future<String?> exportAndShare({
    required String playlistName,
    required List<Song> songs,
  }) async {
    final (content, exported, skipped) = build(
      playlistName: playlistName,
      songs: songs,
    );
    if (exported == 0) return null;

    final dir = await getTemporaryDirectory();
    final safeName = playlistName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/MD3Music_$safeName.m3u');
    await file.writeAsString(content, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '歌单导出：$playlistName',
        text: '已导出 $exported 首本地歌曲'
            '${skipped > 0 ? '（$skipped 首在线歌曲未包含）' : ''}',
      ),
    );
    return '已导出 $exported 首本地歌曲'
        '${skipped > 0 ? '（$skipped 首在线歌曲未包含）' : ''}';
  }
}
