import 'package:flutter/foundation.dart';

import '../data/models/song.dart';
import '../data/repositories/local_playlists_repository.dart';

/// 自建歌单（本地歌单）Provider。
///
/// 数据源：`LocalPlaylistsRepository`（SharedPreferences `local_playlists_v1`）。
/// 与本地收藏（LocalFavoritesProvider，单列表）不同，本 Provider 管理多个
/// 命名歌单；歌单内自带 Song 快照，不依赖 LibraryProvider 的扫描结果。
class LocalPlaylistsProvider extends ChangeNotifier {
  final LocalPlaylistsRepository _repository = LocalPlaylistsRepository();

  List<LocalPlaylist> _playlists = <LocalPlaylist>[];
  bool _loaded = false;

  List<LocalPlaylist> get playlists => List.unmodifiable(_playlists);
  bool get loaded => _loaded;

  LocalPlaylist? playlistById(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _playlists = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _repository.save(_playlists);

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// 新建歌单，返回新歌单实例（空歌单，无歌曲）。
  Future<LocalPlaylist> createPlaylist(String name) async {
    await ensureLoaded();
    final playlist = LocalPlaylist(
      id: _newId(),
      name: name.trim().isEmpty ? '未命名歌单' : name.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      songs: <Song>[],
    );
    _playlists.add(playlist);
    await _persist();
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final playlist = playlistById(id);
    if (playlist == null) return;
    playlist.name = name.trim().isEmpty ? playlist.name : name.trim();
    await _persist();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  /// 批量加入歌曲（按 song.id 去重，已存在的跳过）。
  /// 返回实际新加入的数量，供 UI 提示。
  Future<int> addSongs(String id, List<Song> songs) async {
    final playlist = playlistById(id);
    if (playlist == null) return 0;
    var added = 0;
    for (final song in songs) {
      if (playlist.containsSong(song.id)) continue;
      playlist.songs.add(song);
      added++;
    }
    if (added > 0) {
      await _persist();
      notifyListeners();
    }
    return added;
  }

  Future<void> removeSong(String id, String songId) async {
    final playlist = playlistById(id);
    if (playlist == null) return;
    final before = playlist.songs.length;
    playlist.songs.removeWhere((s) => s.id == songId);
    if (playlist.songs.length != before) {
      await _persist();
      notifyListeners();
    }
  }
}
