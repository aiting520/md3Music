import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/m3u_exporter.dart';
import '../../data/repositories/local_playlists_repository.dart'
    show LocalPlaylist;
import '../../providers/local_playlists_provider.dart';
import 'playlist_detail_page.dart';

/// 音乐库「歌单」tab：自建歌单列表（借鉴 BlackHole / InnerTune 的
/// 本地歌单管理——新建 / 重命名 / 删除 / m3u 导出）。
///
/// 数据完全来自 [LocalPlaylistsProvider]（Song 快照），不依赖
/// LibraryProvider 的当前扫描结果。
class LocalPlaylistsTab extends StatelessWidget {
  const LocalPlaylistsTab({super.key});

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    if (name.trim().isEmpty) return;
    await context.read<LocalPlaylistsProvider>().createPlaylist(name);
    if (!context.mounted) return;
    showToast('歌单「${name.trim()}」已创建，长按可重命名');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalPlaylistsProvider>();
    provider.ensureLoaded();
    final playlists = provider.playlists;

    if (!provider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const Gap(AppSpacing.lg),
            Text(
              '还没有自建歌单',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(AppSpacing.sm),
            Text(
              '把喜欢的歌归类整理，支持导出 m3u',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const Gap(AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('新建歌单'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 顶部新建入口：与音乐库其他 tab 的操作按钮风格一致。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '${playlists.length} 个歌单',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: playlists.length,
            itemBuilder: (listContext, index) {
              final playlist = playlists[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.queue_music),
                ),
                title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${playlist.songs.length} 首',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showPlaylistMenu(context, playlist),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPlaylistMenu(BuildContext context, LocalPlaylist playlist) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('重命名'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
                  await _renamePlaylist(context, playlist);
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('导出 m3u'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
                  final message = await M3uExporter.exportAndShare(
                    playlistName: playlist.name,
                    songs: playlist.songs,
                  );
                  if (!context.mounted) return;
                  showToast(message ?? '歌单里没有可导出的本地歌曲');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '删除歌单',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
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
                  if (confirmed == true && context.mounted) {
                    await context
                        .read<LocalPlaylistsProvider>()
                        .deletePlaylist(playlist.id);
                    if (context.mounted) {
                      showToast('歌单「${playlist.name}」已删除');
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
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
          decoration: const InputDecoration(hintText: '歌单名称'),
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
    await context.read<LocalPlaylistsProvider>().renamePlaylist(playlist.id, name);
  }
}
