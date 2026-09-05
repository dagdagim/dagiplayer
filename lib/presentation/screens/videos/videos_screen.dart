import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/video.dart';
import '../../../providers/media_provider.dart';
import '../../../providers/permission_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_filter_chips.dart';
import '../../widgets/permission_onboarding_sheet.dart';
import '../../widgets/section_header.dart';
import '../../widgets/video_card.dart';
import '../../widgets/video_thumbnail_widget.dart';

enum VideoSortOption {
  dateNewest,
  nameAZ,
  sizeLargest,
  durationLongest,
}

final videoSortOptionProvider = StateProvider<VideoSortOption>((ref) => VideoSortOption.dateNewest);

class VideosScreen extends ConsumerWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allVideosAsync = ref.watch(allVideosProvider);
    final selectedCategory = ref.watch(selectedVideoCategoryProvider);
    final continueWatchingAsync = ref.watch(continueWatchingVideosProvider);
    final sortOption = ref.watch(videoSortOptionProvider);
    final isScanning = ref.watch(isScanningMediaProvider);
    final scanStatus = ref.watch(scanProgressStatusProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: allVideosAsync.when(
          data: (allVideos) {
            // Compute dynamic categories from real videos found on the phone
            final categorySet = <String>{'All'};
            for (final v in allVideos) {
              if (v.category.isNotEmpty) {
                categorySet.add(v.category);
              }
            }
            final categoriesList = categorySet.toList();

            // Filter videos by category
            List<Video> filtered = selectedCategory == 'All'
                ? List<Video>.from(allVideos)
                : allVideos.where((v) => v.category.toLowerCase() == selectedCategory.toLowerCase()).toList();

            // Sort videos
            switch (sortOption) {
              case VideoSortOption.dateNewest:
                filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
                break;
              case VideoSortOption.nameAZ:
                filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                break;
              case VideoSortOption.sizeLargest:
                filtered.sort((a, b) => b.fileSize.compareTo(a.fileSize));
                break;
              case VideoSortOption.durationLongest:
                filtered.sort((a, b) => b.duration.compareTo(a.duration));
                break;
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Header: "Videos", Scanner, Search & Sort Icons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.screenPadding,
                      vertical: AppDimensions.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Videos',
                              style: AppTypography.displayLarge.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (allVideos.isNotEmpty)
                              Text(
                                '${allVideos.length} local files found',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
                              onPressed: () => _triggerMediaScan(context, ref),
                              tooltip: 'Scan Storage for Videos',
                            ),
                            IconButton(
                              icon: const Icon(Icons.search_rounded),
                              onPressed: () => context.push('/search'),
                              tooltip: 'Search',
                            ),
                            IconButton(
                              icon: const Icon(Icons.sort_rounded),
                              onPressed: () => _showSortDialog(context, ref),
                              tooltip: 'Sort Videos',
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
                              scanStatus.isNotEmpty ? scanStatus : 'Scanning device storage for videos...',
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

                // Category Chips (Dynamic based on mobile folders)
                if (categoriesList.length > 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.md),
                      child: MediaFilterChips(
                        categories: categoriesList,
                        selectedCategory: selectedCategory,
                        onSelected: (cat) {
                          ref.read(selectedVideoCategoryProvider.notifier).state = cat;
                        },
                      ),
                    ),
                  ),

                // Continue Watching Section
                if (selectedCategory == 'All')
                  SliverToBoxAdapter(
                    child: continueWatchingAsync.when(
                      data: (videos) {
                        if (videos.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: 'Continue Watching',
                              onSeeAll: () {},
                            ),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                                itemCount: videos.length,
                                itemBuilder: (context, index) {
                                  final video = videos[index];
                                  return VideoCard(
                                    video: video,
                                    onTap: () => _playVideo(context, video),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppDimensions.sm),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),

                // All Videos Section Header
                if (allVideos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: selectedCategory == 'All' ? 'All Videos (${filtered.length})' : '$selectedCategory (${filtered.length})',
                    ),
                  ),

                // Video List or Empty State
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.video_library_rounded,
                      title: allVideos.isEmpty ? 'No Videos Discovered Yet' : 'No Videos in this Folder',
                      description: allVideos.isEmpty
                          ? 'Scan your device to find videos, camera recordings, movies, and downloads.'
                          : 'Try selecting a different category or scan your phone for new files.',
                      actionLabel: 'Scan Device Videos',
                      onAction: () => _triggerMediaScan(context, ref),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = filtered[index];
                        return _buildVideoRow(context, video, isDark);
                      },
                      childCount: filtered.length,
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.xxxl),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Text('Error loading videos: $e'),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoRow(BuildContext context, Video video, bool isDark) {
    return InkWell(
      onTap: () => _playVideo(context, video),
      splashColor: AppColors.primaryGlow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.screenPadding,
          vertical: AppDimensions.xs + 2,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                VideoThumbnailWidget(
                  videoUri: video.uri,
                  thumbnailUri: video.thumbnailUri,
                  width: 90,
                  height: 54,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  fallbackIcon: Icons.videocam_rounded,
                ),
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(200),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      Formatters.formatDuration(video.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.md),

            // Video Title & Category Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: AppTypography.titleMedium.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          video.resolution ?? 'HD',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${video.category} • ${Formatters.formatFileSize(video.fileSize)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // More Options Icon
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              onPressed: () {
                _showVideoDetailsSheet(context, video);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _playVideo(BuildContext context, Video video) {
    context.push('/video-player/${video.id}', extra: video);
  }

  Future<void> _triggerMediaScan(BuildContext context, WidgetRef ref) async {
    final summary = await ref.read(permissionServiceProvider).checkPermissions();
    if (!summary.canScanMedia) {
      if (context.mounted) {
        PermissionOnboardingSheet.show(context);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scanning phone storage for all video files...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      final result = await ref.read(mediaActionControllerProvider).scanDevice();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovered ${result.videos.length} videos and ${result.songs.length} songs.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showSortDialog(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(videoSortOptionProvider);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sort Videos By'),
        children: [
          _sortOptionItem(ctx, ref, 'Date Added (Newest First)', VideoSortOption.dateNewest, currentSort),
          _sortOptionItem(ctx, ref, 'Title (A-Z)', VideoSortOption.nameAZ, currentSort),
          _sortOptionItem(ctx, ref, 'File Size (Largest First)', VideoSortOption.sizeLargest, currentSort),
          _sortOptionItem(ctx, ref, 'Duration (Longest First)', VideoSortOption.durationLongest, currentSort),
        ],
      ),
    );
  }

  Widget _sortOptionItem(
    BuildContext context,
    WidgetRef ref,
    String label,
    VideoSortOption option,
    VideoSortOption current,
  ) {
    final isSelected = option == current;
    return SimpleDialogOption(
      onPressed: () {
        ref.read(videoSortOptionProvider.notifier).state = option;
        Navigator.pop(context);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : null,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (isSelected) const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
        ],
      ),
    );
  }

  void _showVideoDetailsSheet(BuildContext context, Video video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
                title: const Text('Play Video', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _playVideo(context, video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded, color: Colors.white70),
                title: const Text('File Path', style: TextStyle(color: Colors.white70)),
                subtitle: Text(
                  video.uri,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                title: Text(
                  'Size: ${Formatters.formatFileSize(video.fileSize)} • Duration: ${Formatters.formatDuration(video.duration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
