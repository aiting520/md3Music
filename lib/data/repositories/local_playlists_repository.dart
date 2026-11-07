import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../../core/services/diagnostic_logger.dart';

/// 自建歌单（本地歌单）数据模型。
///
/// 歌单内保存 [Song] 的完整快照（toJson/fromJson 往返），而不是仅存 id：
/// 在线歌曲的 url / quality 等字段随建单时的状态保留，本地歌曲保留
/// localPath。这样歌单不依赖 LibraryProvider 的当前扫描结果也能渲染
/// （歌曲文件被移动后仍显示标题/歌手，播放失败有明确归因）。
class LocalPlaylist {
  LocalPlaylist({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.songs,
  });

  final String id;
  String name;
  final int createdAtMs;
  final List<Song> songs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'createdAtMs': createdAtMs,
    'songs': [for (final s in songs) s.toJson()],
  };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) => LocalPlaylist(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '未命名歌单',
    createdAtMs: (json['createdAtMs'] as int?) ?? 0,
    songs: [
      for (final s in (json['songs'] as List? ?? const []))
        Song.fromJson(s as Map<String, dynamic>),
    ],
  );

  bool containsSong(String songId) => songs.any((s) => s.id == songId);
}

/// 自建歌单仓库：SharedPreferences 单 key JSON 持久化（`local_playlists_v1`）。
///
/// 数据量评估：歌单条目是歌名/歌手/路径等文本快照，百首规模约几十 KB，
/// SharedPreferences 单 key 足够；若未来出现千首级歌单再迁 sqflite。
class LocalPlaylistsRepository {
  static const String _key = 'local_playlists_v1';

  Future<List<LocalPlaylist>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <LocalPlaylist>[];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return [
        for (final m in list)
          LocalPlaylist.fromJson(Map<String, dynamic>.from(m)),
      ];
    } catch (e, stack) {
      // 损坏数据宁可返回空列表也不能让歌单页崩溃；日志里留痕便于导出诊断。
      DiagnosticLogger.instance.w('自建歌单解析失败，已按空数据处理: $e\n$stack');
      return <LocalPlaylist>[];
    }
  }

  Future<void> save(List<LocalPlaylist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final p in playlists) p.toJson()]),
    );
  }
}
