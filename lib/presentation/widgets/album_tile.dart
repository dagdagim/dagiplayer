import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../domain/entities/album.dart';
import 'app_network_image.dart';

class AlbumTile extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final double size;

  const AlbumTile({
    super.key,
    required this.album,
    required this.onTap,
    this.size = AppDimensions.albumTileSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppNetworkImage(
              imageUrl: album.artworkUri,
              width: size,
              height: size,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              fallbackIcon: Icons.album_rounded,
              placeholderText: album.title,
            ),
            const SizedBox(height: AppDimensions.xs + 2),
            Text(
              album.title,
              style: AppTypography.titleMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              album.artist,
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
