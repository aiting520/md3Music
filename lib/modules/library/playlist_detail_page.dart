import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/m3u_exporter.dart';
import '../../data/models/song.dart';
import '../../data/repositories/local_playlists_repository.dart'
    show LocalPlaylist;
import '../../providers/local_playlists_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_list_item.dart';

/// 自建歌单详情页：播放全部、添加本地歌曲、移除单首、重命名、导出 m3u。
///
/// 依赖 [LocalPlaylistsProvider]（数据源）与 [LibraryProvider]（可选曲库）。
class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalPlaylistsProvider>();
    final playlist = provider.playlistById(playlistId);

    if (playlist == null) {
      // 歌单已被删除（详情页还在栈里）——回退列表页。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: SizedBox.expand());
    }

    final songs = playlist.songs;

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '添加歌曲',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSongsSheet(context, playlistId),
          ),
          IconButton(
            tooltip: '导出 m3u',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final message = await M3uExporter.exportAndShare(
                playlistName: playlist.name,
                songs: songs,
              );
              if (!context.mounted) return;
              showToast(message ?? '歌单里没有可导出的本地歌曲');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'rename') {
                await _renamePlaylist(context, playlist);
              } else if (value == 'delete') {
                await _deletePlaylist(context, playlist);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除歌单')),
            ],
          ),
        ],
      ),
      body: songs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const Gap(AppSpacing.lg),
                  Text(
                    '歌单还是空的',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddSongsSheet(context, playlistId),
                    icon: const Icon(Icons.add),
                    label: const Text('添加歌曲'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        '${songs.length} 首',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: songs.isEmpty
                            ? null
                            : () => context
                                  .read<PlayerProvider>()
                                  .playPlaylist(songs, 0),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('播放全部'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: songs.length,
                    itemBuilder: (listContext, index) {
                      final song = songs[index];
                      return SongListItem(
                        song: song,
                        onTap: () {
                          context
                              .read<PlayerProvider>()
                              .playPlaylist(songs, index);
                        },
                        onMoreTap: () {},
                        onLongPress: () => _confirmRemoveSong(context, song),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmRemoveSong(BuildContext context, Song song) {
    final confirmed = showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('从歌单移除'),
        content: Text('把「${song.displayName}」从歌单移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    confirmed.then((value) async {
      if (value != true || !context.mounted) return;
      await context
          .read<LocalPlaylistsProvider>()
          .removeSong(playlistId, song.id);
      if (context.mounted) showToast('已从歌单移除');
    });
  }

  Future<void> _showAddSongsSheet(
    BuildContext context,
    String playlistId,
  ) async {
    final library = context.read<LibraryProvider>();
    await library.loadLocalMusic();
    if (!context.mounted) return;

    final playlistsProvider = context.read<LocalPlaylistsProvider>();
    final existing = playlistsProvider.playlistById(playlistId);
    if (existing == null) return;
    final existingIds = existing.songs.map((s) => s.id).toSet();

    final selected = <String>{};
    // 搜索词必须活在 sheet 闭包外：StatefulBuilder 每次 setSheetState 都会
    // 重跑 builder，变量放 builder 里会被重置，搜索框永远滤不出结果。
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final allSongs = library.allSongs;
            final lowerQuery = query.trim().toLowerCase();
            final candidates = lowerQuery.isEmpty
                ? allSongs
                : allSongs
                      .where(
                        (s) =>
                            s.title.toLowerCase().contains(lowerQuery) ||
                            s.artist.toLowerCase().contains(lowerQuery) ||
                            s.album.toLowerCase().contains(lowerQuery),
                      )
                      .toList();

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '添加歌曲（已选 ${selected.length}）',
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () async {
                                    final picked = [
                                      for (final s in allSongs)
                                        if (selected.contains(s.id)) s,
                                    ];
                                    Navigator.of(sheetContext).pop();
                                    final added = await playlistsProvider
                                        .addSongs(playlistId, picked);
                                    showToast(added > 0
                                        ? '已添加 $added 首歌曲'
                                        : '所选歌曲已在歌单中');
                                  },
                            child: const Text('添加'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) {
                          setSheetState(() => query = value);
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜索歌曲 / 歌手 / 专辑',
                        ),
                      ),
                    ),
                    Expanded(
                      child: candidates.isEmpty
                          ? Center(
                              child: Text(
                                allSongs.isEmpty ? '本地曲库为空，先去「曲目」页扫描音乐' : '没有匹配的歌曲',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(sheetContext)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: candidates.length,
                              itemBuilder: (itemContext, index) {
                                final song = candidates[index];
                                final inPlaylist = existingIds.contains(song.id);
                                final checked = selected.contains(song.id) ||
                                    inPlaylist;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(sheetContext)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: inPlaylist
                                        ? Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Theme.of(sheetContext)
                                                .colorScheme
                                                .primary,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: Theme.of(sheetContext)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                  ),
                                  title: Text(
                                    song.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    inPlaylist ? '已在歌单中' : song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Checkbox(
                                    value: checked,
                                    onChanged: inPlaylist
                                        ? null
                                        : (value) {
                                            setSheetState(() {
                                              if (value == true) {
                                                selected.add(song.id);
                                              } else {
                                                selected.remove(song.id);
                                              }
                                            });
                                          },
                                  ),
                                  onTap: inPlaylist
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            if (selected.contains(song.id)) {
                                              selected.remove(song.id);
                                            } else {
                                              selected.add(song.id);
                                            }
                                          });
                                        },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renamePlaylist(
    BuildContext context,
    LocalPlaylist playlist,
  ) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await context
        .read<LocalPlaylistsProvider>()
        .renamePlaylist(playlist.id, name);
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    LocalPlaylist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定删除「${playlist.name}」吗？歌曲文件不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<LocalPlaylistsProvider>().deletePlaylist(playlist.id);
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
