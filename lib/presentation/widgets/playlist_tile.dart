import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../domain/entities/playlist.dart';
import 'app_network_image.dart';

class PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final double size;
  final bool isHorizontal;
  final VoidCallback? onMore;

  const PlaylistTile({
    super.key,
    required this.playlist,
    required this.onTap,
    this.size = 110.0,
    this.isHorizontal = true,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isHorizontal) {
      // List Row style for Playlists / Library screen
      return InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryGlow,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPadding,
            vertical: AppDimensions.sm,
          ),
          child: Row(
            children: [
              _buildPlaylistArt(size: 52),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: AppTypography.titleMedium.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${playlist.songCount} songs',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  onPressed: onMore,
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
            ],
          ),
        ),
      );
    }

    // Horizontal Card style for Home screen
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlaylistArt(size: size),
            const SizedBox(height: AppDimensions.xs + 2),
            Text(
              playlist.title,
              style: AppTypography.titleMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '${playlist.songCount} songs',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistArt({required double size}) {
    IconData iconData = Icons.queue_music_rounded;
    Color iconBg = AppColors.darkSurfaceSecondary;

    switch (playlist.iconName) {
      case 'fitness':
        iconData = Icons.fitness_center_rounded;
        iconBg = const Color(0xFFC0392B);
        break;
      case 'palm_tree':
        iconData = Icons.wb_sunny_rounded;
        iconBg = const Color(0xFF2980B9);
        break;
      case 'heart':
        iconData = Icons.favorite_rounded;
        iconBg = const Color(0xFFC0392B);
        break;
      case 'car':
        iconData = Icons.directions_car_rounded;
        iconBg = const Color(0xFF8E44AD);
        break;
      case 'cloud_rain':
        iconData = Icons.water_drop_rounded;
        iconBg = const Color(0xFF34495E);
        break;
    }

    if (playlist.coverArtUri != null && playlist.coverArtUri!.isNotEmpty) {
      return AppNetworkImage(
        imageUrl: playlist.coverArtUri,
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        fallbackIcon: iconData,
        placeholderText: playlist.title,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        color: iconBg,
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: (size * 0.45).clamp(18.0, 32.0),
        ),
      ),
    );
  }
}

