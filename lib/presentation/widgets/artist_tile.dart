import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../domain/entities/artist.dart';
import 'app_network_image.dart';

class ArtistTile extends StatelessWidget {
  final Artist artist;
  final VoidCallback onTap;
  final double size;

  const ArtistTile({
    super.key,
    required this.artist,
    required this.onTap,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 20,
        margin: const EdgeInsets.only(right: AppDimensions.md),
        child: Column(
          children: [
            AppNetworkImage(
              imageUrl: artist.imageUri,
              width: size,
              height: size,
              borderRadius: BorderRadius.circular(size / 2),
              fallbackIcon: Icons.person_rounded,
              placeholderText: artist.name,
            ),
            const SizedBox(height: AppDimensions.xs + 2),
            Text(
              artist.name,
              style: AppTypography.titleMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              '${artist.songCount} songs',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
