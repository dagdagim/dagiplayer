import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/playlist_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/playlist_tile.dart';
import 'create_playlist_dialog.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playlistsAsync = ref.watch(allPlaylistsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header: "Playlists" and "+" Add Action
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playlists',
                      style: AppTypography.displayLarge.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 28),
                      onPressed: () => _openCreatePlaylist(context),
                      tooltip: 'Create Playlist',
                    ),
                  ],
                ),
              ),
            ),

            // Quick Hub Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.xs,
                ),
                child: Row(
                  children: [
                    _quickHubChip(context, 'Favorites', Icons.favorite_rounded, () {
                      context.push('/playlist/pl-favorites');
                    }),
                    const SizedBox(width: 8),
                    _quickHubChip(context, 'Recent', Icons.history_rounded, () {
                      context.go('/music');
                    }),
                    const SizedBox(width: 8),
                    _quickHubChip(context, 'Videos', Icons.videocam_rounded, () {
                      context.go('/videos');
                    }),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 24),
            ),

            // Playlist Items List
            playlistsAsync.when(
              data: (playlists) {
                if (playlists.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.queue_music_rounded,
                      title: 'Create your first playlist.',
                      description: 'Group your favorite songs and videos into personalized mixes.',
                      actionLabel: 'Create Playlist',
                      onAction: () => _openCreatePlaylist(context),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playlist = playlists[index];
                      return PlaylistTile(
                        playlist: playlist,
                        isHorizontal: false,
                        onTap: () => context.push('/playlist/${playlist.id}'),
                        onMore: () => _showPlaylistMenu(context, ref, playlist),
                      );
                    },
                    childCount: playlists.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.xxxl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickHubChip(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreatePlaylist(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const CreatePlaylistDialog(),
    );
  }

  void _showPlaylistMenu(BuildContext context, WidgetRef ref, dynamic playlist) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Playlist'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Playlist'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete Playlist', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(playlistActionControllerProvider).deletePlaylist(playlist.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${playlist.title}"')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
