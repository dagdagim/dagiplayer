import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/song.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/media_provider.dart';
import '../../widgets/song_artwork_widget.dart';
import 'queue_sheet.dart';
import 'lyrics_sheet.dart';
import 'sleep_timer_dialog.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double _dragValue = -1.0;

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(audioPlaybackNotifierProvider);
    final currentSong = playbackState.currentSong;

    if (currentSong == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: Text('No song playing', style: TextStyle(color: Colors.white))),
      );
    }

    final duration = playbackState.duration.inMilliseconds > 0
        ? playbackState.duration
        : currentSong.duration;
    final position = playbackState.position;
    final currentPosMs = _dragValue >= 0 ? _dragValue : position.inMilliseconds.toDouble();
    final maxMs = duration.inMilliseconds.toDouble();
    final sliderVal = currentPosMs.clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(context),

              const Spacer(flex: 1),

              // Large Square Album Artwork (tap to view lyrics)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openLyricsSheet(context, currentSong);
                },
                child: _buildArtwork(currentSong, playbackState.isPlaying),
              ),

              const Spacer(flex: 2),

              // Song Title, Artist & Favorite Action
              _buildTitleSection(currentSong, ref),

              const SizedBox(height: AppDimensions.lg),

              // Progress Scrubber & Timers
              _buildProgressSlider(
                sliderVal,
                maxMs,
                position,
                duration,
                ref,
              ),

              const SizedBox(height: AppDimensions.md),

              // Playback Controls Row (Shuffle, Prev, Play/Pause Orange Circle, Next, Repeat)
              _buildControls(playbackState, ref),

              const Spacer(flex: 2),

              // Bottom Actions Row (Lyrics, Queue, Equalizer, More)
              _buildBottomActions(context, currentSong),

              const SizedBox(height: AppDimensions.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
            onPressed: () => context.pop(),
          ),
          Column(
            children: [
              Text(
                'PLAYING FROM',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.darkTextSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Favorites',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 26),
            onPressed: () => _openQueueSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(Song song, bool isPlaying) {
    return Center(
      child: Hero(
        tag: 'album-artwork-${song.id}',
        child: Container(
          width: 310,
          height: 310,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(40),
                blurRadius: 35,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SongArtworkWidget(
            song: song,
            width: 310,
            height: 310,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            isPlaying: isPlaying,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(dynamic song, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: AppTypography.displaySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                song.artist,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.darkTextSecondary,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: song.isFavorite ? AppColors.primary : Colors.white,
            size: 26,
          ),
          tooltip: song.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(mediaActionControllerProvider).toggleSongFavorite(song.id, song);
          },
        ),
      ],
    );
  }

  Widget _buildProgressSlider(
    double sliderVal,
    double maxMs,
    Duration position,
    Duration duration,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.darkBorder,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primaryGlow,
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: maxMs > 0 ? sliderVal : 0.0,
            min: 0.0,
            max: maxMs > 0 ? maxMs : 1.0,
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              ref
                  .read(audioPlaybackNotifierProvider.notifier)
                  .seek(Duration(milliseconds: val.toInt()));
              setState(() {
                _dragValue = -1.0;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.formatDuration(
                  _dragValue >= 0 ? Duration(milliseconds: _dragValue.toInt()) : position,
                ),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.darkTextSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                Formatters.formatDuration(duration),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.darkTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(AudioPlaybackState state, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: state.isShuffleEnabled ? AppColors.primary : AppColors.darkTextSecondary,
            size: 22,
          ),
          onPressed: () => ref.read(audioPlaybackNotifierProvider.notifier).toggleShuffle(),
        ),

        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
          onPressed: () => ref.read(audioPlaybackNotifierProvider.notifier).previous(),
        ),

        // Main Play/Pause Button (Burnt Orange Circle)
        GestureDetector(
          onTap: () => ref.read(audioPlaybackNotifierProvider.notifier).togglePlayPause(),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),

        // Next
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
          onPressed: () => ref.read(audioPlaybackNotifierProvider.notifier).next(),
        ),

        // Repeat
        IconButton(
          icon: Icon(
            state.repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: state.repeatMode != RepeatMode.off ? AppColors.primary : AppColors.darkTextSecondary,
            size: 22,
          ),
          onPressed: () => ref.read(audioPlaybackNotifierProvider.notifier).toggleRepeat(),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context, dynamic currentSong) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _bottomActionItem(
          icon: Icons.article_outlined,
          label: 'Lyrics',
          onTap: () => _openLyricsSheet(context, currentSong),
        ),
        _bottomActionItem(
          icon: Icons.queue_music_rounded,
          label: 'Queue',
          onTap: () => _openQueueSheet(context),
        ),
        _bottomActionItem(
          icon: Icons.graphic_eq_rounded,
          label: 'Equalizer',
          onTap: () => context.push('/equalizer'),
        ),
        _bottomActionItem(
          icon: Icons.timer_outlined,
          label: 'Timer',
          onTap: () => _openSleepTimerDialog(context),
        ),
      ],
    );
  }

  Widget _bottomActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.darkTextSecondary, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.darkTextSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QueueSheet(),
    );
  }

  void _openLyricsSheet(BuildContext context, dynamic song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LyricsSheet(song: song),
    );
  }

  void _openSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const SleepTimerDialog(),
    );
  }
}
