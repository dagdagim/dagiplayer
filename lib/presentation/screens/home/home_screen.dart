import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/video.dart';
import '../../../providers/media_provider.dart';
import '../../../providers/permission_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/developer_card.dart';
import '../../widgets/permission_onboarding_sheet.dart';
import '../../widgets/section_header.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/video_card.dart';
import '../../widgets/playlist_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _hasPromptedPermissions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialPermissions();
    });
  }

  Future<void> _checkInitialPermissions() async {
    if (_hasPromptedPermissions) return;
    _hasPromptedPermissions = true;

    final summary = await ref.read(permissionServiceProvider).checkPermissions();
    if (!summary.canScanMedia && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        PermissionOnboardingSheet.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentlyPlayedAsync = ref.watch(recentlyPlayedSongsProvider);
    final continueWatchingAsync = ref.watch(continueWatchingVideosProvider);
    final playlistsAsync = ref.watch(allPlaylistsProvider);
    final isScanning = ref.watch(isScanningMediaProvider);
    final scanStatus = ref.watch(scanProgressStatusProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar with AppLogo and Quick Utilities
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenPadding,
                  AppDimensions.xs + 2,
                  AppDimensions.screenPadding,
                  AppDimensions.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Identity Logo
                    const Flexible(
                      child: AppLogo(
                        size: 28,
                        showText: true,
                      ),
                    ),

                    // Quick Actions (Scanner Sync, Equalizer, Search)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 20),
                          onPressed: () => context.push('/equalizer'),
                          tooltip: 'Equalizer',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.sync_rounded,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            size: 20,
                          ),
                          onPressed: _triggerMediaScan,
                          tooltip: 'Scan Device Storage',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            size: 20,
                          ),
                          onPressed: () => DeveloperCard.showAboutModal(context),
                          tooltip: 'About & Developer',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            size: 20,
                          ),
                          onPressed: () => context.push('/search'),
                          tooltip: 'Search',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Live Media Scanner Banner (when scanning)
            if (isScanning)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.screenPadding,
                    vertical: AppDimensions.xs,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          scanStatus.isNotEmpty ? scanStatus : 'Scanning device storage...',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Search Trigger Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.screenPadding,
                  AppDimensions.sm,
                  AppDimensions.screenPadding,
                  AppDimensions.sm,
                ),
                child: GestureDetector(
                  onTap: () => context.push('/search'),
                  child: Container(
                    height: AppDimensions.searchBarHeight,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Text(
                            'Search music, videos, artists...',
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⌘K',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Quick Media Filter Shortcuts Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                    children: [
                      _quickCategoryPill(context, '🎵 Music', () => context.go('/music'), isDark),
                      const SizedBox(width: 8),
                      _quickCategoryPill(context, '🎬 Videos', () => context.go('/videos'), isDark),
                      const SizedBox(width: 8),
                      _quickCategoryPill(context, '⭐ Favorites', () => context.push('/playlist/pl-favorites'), isDark),
                      const SizedBox(width: 8),
                      _quickCategoryPill(context, '🎛️ Equalizer', () => context.push('/equalizer'), isDark),
                      const SizedBox(width: 8),
                      _quickCategoryPill(context, '📁 Scan Storage', _triggerMediaScan, isDark),
                    ],
                  ),
                ),
              ),
            ),

            // Continue Watching Section
            SliverToBoxAdapter(
              child: continueWatchingAsync.when(
                data: (videos) {
                  if (videos.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Continue Watching',
                        onSeeAll: () => context.go('/videos'),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return VideoCard(
                              video: video,
                              onTap: () => _openVideoPlayer(context, video),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Recently Played Section
            SliverToBoxAdapter(
              child: recentlyPlayedAsync.when(
                data: (songs) {
                  if (songs.isEmpty) return const SizedBox.shrink();
                  final displaySongs = songs.take(4).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Recently Played',
                        onSeeAll: () => context.go('/music'),
                      ),
                      ...displaySongs.asMap().entries.map((entry) {
                        return SongTile(
                          song: entry.value,
                          index: entry.key,
                          playlistContext: songs,
                        );
                      }),
                      const SizedBox(height: AppDimensions.md),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Featured Playlists Section
            SliverToBoxAdapter(
              child: playlistsAsync.when(
                data: (playlists) {
                  if (playlists.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Playlists',
                        onSeeAll: () => context.go('/library'),
                      ),
                      SizedBox(
                        height: 175,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return PlaylistTile(
                              playlist: playlist,
                              onTap: () => context.push('/playlist/${playlist.id}'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xl),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Bottom Spacing for MiniPlayer & Bottom Nav
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.bottomNavHeight + AppDimensions.miniPlayerHeight),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerMediaScan() async {
    final summary = await ref.read(permissionServiceProvider).checkPermissions();
    if (!mounted) return;

    if (!summary.canScanMedia) {
      PermissionOnboardingSheet.show(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning phone storage for music and videos...'),
          duration: Duration(seconds: 2),
        ),
      );
      final result = await ref.read(mediaActionControllerProvider).scanDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan complete: ${result.songs.length} songs, ${result.videos.length} videos found.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Widget _quickCategoryPill(BuildContext context, String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, Video video) {
    context.push('/video-player/${video.id}', extra: video);
  }
}
