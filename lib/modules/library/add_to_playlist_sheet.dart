import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_toast.dart';
import '../../data/models/song.dart';
import '../../data/repositories/local_playlists_repository.dart'
    show LocalPlaylist;
import '../../providers/local_playlists_provider.dart';

/// 「加入自建歌单」底部弹层：从歌曲的更多菜单（SongListItem 的
/// extraMenuTilesBuilder 宫格入口）唤起，选择歌单即加入（去重）。
Future<void> showAddToPlaylistSheet(BuildContext context, Song song) async {
  final provider = context.read<LocalPlaylistsProvider>();
  await provider.ensureLoaded();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final playlists = sheetContext.watch<LocalPlaylistsProvider>().playlists;
      Future<void> addTo(LocalPlaylist playlist) async {
        final added = await provider.addSongs(playlist.id, [song]);
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        showToast(
          added > 0 ? '已加入「${playlist.name}」' : '「${song.displayName}」已在「${playlist.name}」中',
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建歌单并加入'),
              onTap: () async {
                final controller = TextEditingController();
                final name = await showDialog<String>(
                  context: sheetContext,
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
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(controller.text),
                        child: const Text('创建'),
                      ),
                    ],
                  ),
                );
                if (name == null || name.trim().isEmpty) return;
                final playlist = await provider.createPlaylist(name);
                await addTo(playlist);
              },
            ),
            const Divider(height: 1),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('还没有歌单，点上面新建一个吧'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (itemContext, index) {
                    final playlist = playlists[index];
                    final already = playlist.containsSong(song.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(sheetContext)
                            .colorScheme
                            .primaryContainer,
                        child: Text(
                          '${playlist.songs.length}',
                          style: Theme.of(sheetContext).textTheme.labelMedium,
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: already ? const Text('已在该歌单中') : null,
                      trailing: already
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            )
                          : null,
                      onTap: () => addTo(playlist),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
