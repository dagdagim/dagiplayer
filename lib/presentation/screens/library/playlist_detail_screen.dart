import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/song.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/song_tile.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playlistAsync = ref.watch(playlistDetailProvider(playlistId));
    final playlistSongsAsync = ref.watch(playlistSongsProvider(playlistId));

    return Scaffold(
      body: playlistAsync.when(
        data: (playlist) {
          if (playlist == null) {
            return const Center(child: Text('Playlist not found'));
          }

          final songs = playlistSongsAsync.value ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header with Custom Cover / Icon
              SliverAppBar(
                expandedHeight: 280,
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
                      if (playlist.id == 'pl-favorites')
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF5722),
                                Color(0xFFFF9800),
                                Color(0xFFE91E63),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                        )
                      else
                        AppNetworkImage(
                          imageUrl: playlist.coverArtUri,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.queue_music_rounded,
                          placeholderText: playlist.title,
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark ? AppColors.darkBackground : AppColors.lightBackground).withAlpha(240),
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
                              playlist.title,
                              style: AppTypography.displayMedium.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${songs.length} songs • ${Formatters.formatDurationLong(playlist.totalDuration)}',
                              style: AppTypography.bodySmall.copyWith(
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

              // Play All & Shuffle Buttons
              if (songs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.screenPadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (songs.isNotEmpty) {
                                ref.read(audioPlaybackNotifierProvider.notifier).playSong(
                                      songs.first,
                                      queue: songs,
                                      index: 0,
                                    );
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              if (songs.isNotEmpty) {
                                final shuffled = List<Song>.from(songs)..shuffle();
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

              // Playlist Track List
              if (songs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: playlist.id == 'pl-favorites'
                        ? Icons.favorite_border_rounded
                        : Icons.queue_music_rounded,
                    title: playlist.id == 'pl-favorites'
                        ? 'No Favorites Yet'
                        : 'No Songs in this Playlist',
                    description: playlist.id == 'pl-favorites'
                        ? 'Tap the heart icon on any song while listening or in the song list to add it to your Favorites.'
                        : 'Add songs to this playlist from the track options menu.',
                    actionLabel: playlist.id == 'pl-favorites' ? 'Explore Music' : null,
                    onAction: playlist.id == 'pl-favorites'
                        ? () => context.go('/music')
                        : null,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return SongTile(
                        song: song,
                        index: index,
                        playlistContext: songs,
                      );
                    },
                    childCount: songs.length,
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
