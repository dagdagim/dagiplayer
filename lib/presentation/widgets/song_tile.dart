import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/song.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/playlist_provider.dart';
import 'song_artwork_widget.dart';
import 'waveform_indicator.dart';

class SongTile extends ConsumerWidget {
  final Song song;
  final List<Song>? playlistContext;
  final int? index;
  final VoidCallback? onTap;
  final bool showArtwork;
  final bool showDuration;
  final Widget? leading;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    this.playlistContext,
    this.index,
    this.onTap,
    this.showArtwork = true,
    this.showDuration = true,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(audioPlaybackNotifierProvider);
    final isCurrent = playbackState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playbackState.isPlaying;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isCurrent
        ? AppColors.primary
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap ??
          () {
            ref.read(audioPlaybackNotifierProvider.notifier).playSong(
                  song,
                  queue: playlistContext,
                  index: index,
                );
          },
      splashColor: AppColors.primaryGlow,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.screenPadding,
          vertical: AppDimensions.sm,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppDimensions.md),
            ] else if (showArtwork) ...[
              _buildArtwork(context, isPlaying),
              const SizedBox(width: AppDimensions.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isCurrent) ...[
                        WaveformIndicator(isPlaying: isPlaying),
                        const SizedBox(width: AppDimensions.xs),
                      ],
                      Expanded(
                        child: Text(
                          song.title,
                          style: AppTypography.titleMedium.copyWith(
                            color: titleColor,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: AppTypography.bodySmall.copyWith(
                      color: subtitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showDuration) ...[
              const SizedBox(width: AppDimensions.sm),
              Text(
                Formatters.formatDuration(song.duration),
                style: AppTypography.bodySmall.copyWith(
                  color: subtitleColor,
                  fontSize: 11,
                ),
              ),
            ],
            if (trailing != null)
              trailing!
            else ...[
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: AppDimensions.iconSizeMedium,
                  color: subtitleColor,
                ),
                onPressed: () => _showSongOptions(context, ref),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, bool isPlaying) {
    return SongArtworkWidget(
      song: song,
      width: AppDimensions.songArtworkSize,
      height: AppDimensions.songArtworkSize,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      isPlaying: isPlaying,
    );
  }

  void _showSongOptions(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimensions.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding, vertical: AppDimensions.xs),
                  child: Row(
                    children: [
                      SongArtworkWidget(
                        song: song,
                        width: 44,
                        height: 44,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title, style: AppTypography.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(song.artist, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded, color: AppColors.primary),
                  title: const Text('Play Next'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Add to queue right after current
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Add to Queue'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final state = ref.read(audioPlaybackNotifierProvider);
                    final newQueue = List<Song>.from(state.queue)..add(song);
                    ref.read(audioPlaybackNotifierProvider.notifier).updateQueue(newQueue);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added "${song.title}" to Queue')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: song.isFavorite ? AppColors.primary : null,
                  ),
                  title: Text(song.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(mediaActionControllerProvider).toggleSongFavorite(song.id, song);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Add to Playlist...'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddToPlaylistDialog(context, ref);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Song Info'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSongInfoDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.read(allPlaylistsProvider);
    playlistsAsync.whenData((playlists) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add to Playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (c, i) {
                final pl = playlists[i];
                return ListTile(
                  title: Text(pl.title),
                  subtitle: Text('${pl.songCount} songs'),
                  onTap: () {
                    ref.read(playlistActionControllerProvider).addSongToPlaylist(pl.id, song.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to "${pl.title}"')),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    });
  }

  void _showSongInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Song Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Title', song.title),
            _infoRow('Artist', song.artist),
            _infoRow('Album', song.album ?? 'Unknown'),
            _infoRow('Genre', song.genre ?? 'Unknown'),
            _infoRow('Duration', Formatters.formatDuration(song.duration)),
            _infoRow('File Size', Formatters.formatFileSize(song.fileSize)),
            _infoRow('Plays', '${song.playCount} times'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.darkTextSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
