import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/video.dart';
import 'video_thumbnail_widget.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final bool isHorizontal;

  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.width,
    this.height,
    this.isHorizontal = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardWidth = width ?? (isHorizontal ? AppDimensions.videoCardWidth : double.infinity);
    final cardHeight = height ?? AppDimensions.videoCardHeight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isHorizontal ? cardWidth : null,
        margin: isHorizontal
            ? const EdgeInsets.only(right: AppDimensions.md)
            : const EdgeInsets.only(bottom: AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail container with play button and duration pill
            Container(
              width: isHorizontal ? cardWidth : double.infinity,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                color: AppColors.darkSurfaceSecondary,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnailWidget(
                    videoUri: video.uri,
                    thumbnailUri: video.thumbnailUri,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.videocam_rounded,
                  ),

                  // Scrim overlay
                  Container(
                    color: AppColors.videoScrim,
                  ),

                  // Center Play Icon Circle
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Duration Pill
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(204),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Formatters.formatDuration(video.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Resume progress bar if partially watched
                  if (video.hasResumePosition)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: video.lastPosition.inMilliseconds / video.duration.inMilliseconds,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.xs + 2),
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
            Text(
              '${video.category}${video.year != null ? ' • ${video.year}' : ''}',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
