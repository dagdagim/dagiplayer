import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/song.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/media_provider.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/song_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final albumAsync = ref.watch(albumDetailProvider(albumId));
    final allSongsAsync = ref.watch(allSongsProvider);

    return Scaffold(
      body: albumAsync.when(
        data: (album) {
          if (album == null) {
            return const Center(child: Text('Album not found'));
          }

          final allSongs = allSongsAsync.value ?? [];
          final albumSongs = allSongs.where((s) => s.album == album.title).toList();
          final displaySongs = albumSongs.isNotEmpty ? albumSongs : allSongs.take(4).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Sliver App Bar with large artwork
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {},
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        imageUrl: album.artworkUri,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.album_rounded,
                        placeholderText: album.title,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark ? AppColors.darkBackground : AppColors.lightBackground).withAlpha(230),
                              isDark ? AppColors.darkBackground : AppColors.lightBackground,
                            ],
                            stops: const [0.3, 0.75, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: AppDimensions.screenPadding,
                        right: AppDimensions.screenPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              album.title,
                              style: AppTypography.displayMedium.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${album.artist} • ${album.year ?? 2022} • ${displaySongs.length} songs',
                              style: AppTypography.bodyMedium.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons Row (Play, Shuffle, Favorite)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (displaySongs.isNotEmpty) {
                              ref.read(audioPlaybackNotifierProvider.notifier).playSong(
                                    displaySongs.first,
                                    queue: displaySongs,
                                    index: 0,
                                  );
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                          label: const Text('Play', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (displaySongs.isNotEmpty) {
                              final shuffled = List<Song>.from(displaySongs)..shuffle();
                              ref.read(audioPlaybackNotifierProvider.notifier).playSong(
                                    shuffled.first,
                                    queue: shuffled,
                                    index: 0,
                                  );
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
                          label: Text(
                            'Shuffle',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Song List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = displaySongs[index];
                    return SongTile(
                      song: song,
                      index: index,
                      playlistContext: displaySongs,
                      leading: SizedBox(
                        width: 24,
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: displaySongs.length,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDimensions.xxxl),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
