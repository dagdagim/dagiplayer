import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/song.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/lyrics_provider.dart';
import '../../../services/lyrics/online_lyrics_service.dart';

class LyricsSheet extends ConsumerStatefulWidget {
  final Song song;

  const LyricsSheet({super.key, required this.song});

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isUserScrolling = false;
  Timer? _userScrollResumeTimer;
  int _lastActiveIndex = -1;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = '${widget.song.title} ${widget.song.artist}'.trim();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _userScrollResumeTimer?.cancel();
    super.dispose();
  }

  void _onUserScrolled() {
    setState(() {
      _isUserScrolling = true;
    });
    _userScrollResumeTimer?.cancel();
    _userScrollResumeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
        });
        _scrollToActiveLine();
      }
    });
  }

  void _scrollToActiveLine([int? index]) {
    if (!_scrollController.hasClients) return;
    final targetIndex = index ?? _lastActiveIndex;
    if (targetIndex < 0) return;

    // Estimate 68px per line to position the active line at ~35% from the top
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (targetIndex * 68.0) - (viewportHeight * 0.32);
    final clampedOffset = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(audioPlaybackNotifierProvider);
    final lyricsAsync = ref.watch(lyricsProvider(widget.song));

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: AppDimensions.sm, bottom: AppDimensions.xs),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Top Bar
              _buildTopBar(context, lyricsAsync.valueOrNull),

              // Inline manual search input (if toggled)
              if (_isSearching) _buildSearchInput(),

              const Divider(color: AppColors.darkBorder, height: 1),

              // Lyrics Content
              Expanded(
                child: lyricsAsync.when(
                  loading: () => _buildLoadingState(),
                  error: (err, _) => _buildErrorState(err.toString()),
                  data: (parsedLyrics) {
                    if (parsedLyrics == null || parsedLyrics.lines.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildLyricsList(parsedLyrics, playbackState.position);
                  },
                ),
              ),
            ],
          ),

          // Floating "Sync with playback" button when user scrolled manually
          if (_isUserScrolling && (lyricsAsync.valueOrNull?.isSynced ?? false))
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isUserScrolling = false;
                    });
                    _scrollToActiveLine();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Sync to playback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ParsedLyrics? lyrics) {
    final isSynced = lyrics?.isSynced ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenPadding,
        vertical: AppDimensions.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lyrics',
                      style: AppTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (lyrics != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSynced
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSynced
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.darkBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isSynced ? 'Synced' : 'Plain Text',
                          style: TextStyle(
                            color: isSynced ? AppColors.primary : AppColors.darkTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.song.title} • ${widget.song.artist}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Search / Query Action
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
              color: _isSearching ? AppColors.primary : Colors.white,
              size: 22,
            ),
            tooltip: 'Search online lyrics',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
              });
            },
          ),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Re-fetch lyrics online',
            onPressed: () {
              ref.read(songLyricsQueryProvider(widget.song.id).notifier).update(
                    (state) => LyricsQueryState(
                      manualQuery: state.manualQuery,
                      refreshId: state.refreshId + 1,
                    ),
                  );
            },
          ),

          // Close Button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenPadding,
        vertical: AppDimensions.xs,
      ),
      color: AppColors.darkCard,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search title or artist (e.g. Starboy The Weeknd)',
                hintStyle: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (query) => _performManualSearch(query),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
            onPressed: () => _performManualSearch(_searchController.text),
          ),
        ],
      ),
    );
  }

  void _performManualSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(songLyricsQueryProvider(widget.song.id).notifier).update(
          (state) => LyricsQueryState(
            manualQuery: trimmed,
            refreshId: state.refreshId + 1,
          ),
        );
    setState(() {
      _isSearching = false;
    });
  }

  Widget _buildLyricsList(ParsedLyrics parsedLyrics, Duration currentPos) {
    final lines = parsedLyrics.lines;
    final isSynced = parsedLyrics.isSynced;
    final activeIndex = isSynced ? parsedLyrics.getActiveIndex(currentPos) : -1;

    // Check if active line transitioned and trigger auto-scroll
    if (isSynced && activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      if (!_isUserScrolling) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToActiveLine(activeIndex);
        });
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _onUserScrolled();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenPadding,
          AppDimensions.screenPadding,
          AppDimensions.screenPadding,
          80, // Padding for floating sync pill
        ),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isActive = isSynced && index == activeIndex;
          final isPast = isSynced && index < activeIndex;

          return InkWell(
            onTap: isSynced
                ? () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(audioPlaybackNotifierProvider.notifier)
                        .seek(line.timestamp);
                    setState(() {
                      _isUserScrolling = false;
                      _lastActiveIndex = index;
                    });
                    _scrollToActiveLine(index);
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            splashColor: AppColors.primary.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: isActive ? 22 : 17,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? AppColors.primary
                            : isPast
                                ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                                : AppColors.darkTextSecondary,
                        height: 1.45,
                        letterSpacing: isActive ? 0.2 : 0.0,
                      ),
                      child: Text(line.text),
                    ),
                  ),
                  if (isSynced && line.timestamp > Duration.zero) ...[
                    const SizedBox(width: 8),
                    Text(
                      Formatters.formatDuration(line.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.18),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching online lyrics...',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.song.title} • ${widget.song.artist}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.darkTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(
                Icons.music_off_rounded,
                color: AppColors.darkTextSecondary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No lyrics found online',
              style: AppTypography.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We couldn\'t find synchronized lyrics for "${widget.song.title}". You can try searching with different keywords.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.darkTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.darkTextSecondary, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load lyrics',
              style: AppTypography.titleMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your internet connection and try again.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                ref.read(songLyricsQueryProvider(widget.song.id).notifier).update(
                      (state) => LyricsQueryState(
                        manualQuery: state.manualQuery,
                        refreshId: state.refreshId + 1,
                      ),
                    );
              },
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              label: const Text('Retry', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
