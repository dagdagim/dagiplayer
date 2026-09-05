import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/song.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../widgets/song_tile.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(audioPlaybackNotifierProvider);
    final queue = playbackState.queue;
    final currentIndex = playbackState.currentIndex;
    final currentSong = playbackState.currentSong;

    final nextUpSongs = currentIndex >= 0 && currentIndex + 1 < queue.length
        ? queue.sublist(currentIndex + 1)
        : <Song>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: AppDimensions.sm, bottom: AppDimensions.sm),
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Queue (${queue.length})',
                  style: AppTypography.headlineLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _saveAsPlaylist(context, ref, queue),
                      icon: const Icon(Icons.playlist_add_rounded, color: AppColors.primary, size: 18),
                      label: const Text(
                        'Save',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all_rounded, color: AppColors.darkTextSecondary),
                      tooltip: 'Clear Queue',
                      onPressed: () {
                        ref.read(audioPlaybackNotifierProvider.notifier).updateQueue([]);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.darkBorder, height: 1),

          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Now Playing section
                if (currentSong != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.screenPadding,
                        AppDimensions.md,
                        AppDimensions.screenPadding,
                        AppDimensions.xs,
                      ),
                      child: Text(
                        'Now Playing',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SongTile(
                      song: currentSong,
                      index: currentIndex,
                      playlistContext: queue,
                    ),
                  ),
                ],

                // Next Up Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.screenPadding,
                      AppDimensions.md,
                      AppDimensions.screenPadding,
                      AppDimensions.xs,
                    ),
                    child: Text(
                      'Next Up',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.darkTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Next Up Reorderable List
                if (nextUpSongs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.xl),
                      child: Center(
                        child: Text(
                          'No more songs in queue',
                          style: TextStyle(color: AppColors.darkTextSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  SliverReorderableList(
                    itemCount: nextUpSongs.length,
                    onReorder: (oldIdx, newIdx) {
                      final actualOld = currentIndex + 1 + oldIdx;
                      final actualNew = currentIndex + 1 + newIdx;
                      ref.read(audioPlaybackNotifierProvider.notifier).reorderQueue(actualOld, actualNew);
                    },
                    itemBuilder: (context, index) {
                      final song = nextUpSongs[index];
                      final actualIndex = currentIndex + 1 + index;

                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(song.id + index.toString()),
                        index: index,
                        child: Dismissible(
                          key: ValueKey('dismiss-${song.id}-$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppColors.error,
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref.read(audioPlaybackNotifierProvider.notifier).removeSongFromQueue(actualIndex);
                          },
                          child: SongTile(
                            song: song,
                            index: actualIndex,
                            playlistContext: queue,
                            trailing: const Icon(
                              Icons.drag_handle_rounded,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.xxl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveAsPlaylist(BuildContext context, WidgetRef ref, List<Song> queue) {
    final titleController = TextEditingController(text: 'Queue Playlist');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Queue as Playlist'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Playlist Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ref.read(playlistActionControllerProvider).createPlaylist(
                      title: title,
                      initialSongIds: queue.map((s) => s.id).toList(),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved "$title" with ${queue.length} tracks')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
