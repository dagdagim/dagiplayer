import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/audio/song_artwork_service.dart';

/// Robust media image renderer supporting Web, Android ContentProvider, Local Files, and Memory.
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final String? placeholderText;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note_rounded,
    this.placeholderText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;

    if (imageUrl == null || imageUrl!.isEmpty) {
      content = _buildFallback(isDark);
    } else if (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://')) {
      content = Image.network(
        imageUrl!,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withAlpha(150),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback(isDark);
        },
      );
    } else if (imageUrl!.startsWith('content://')) {
      content = FutureBuilder<Uint8List?>(
        future: SongArtworkService.instance.getArtwork(artworkUri: imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return Image.memory(
              snapshot.data!,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (_, __, ___) => _buildFallback(isDark),
            );
          }
          return _buildFallback(isDark);
        },
      );
    } else {
      final cleanPath = imageUrl!.replaceFirst('file://', '');
      final localFile = File(cleanPath);
      if (localFile.existsSync()) {
        content = Image.file(
          localFile,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _buildFallback(isDark),
        );
      } else {
        content = FutureBuilder<Uint8List?>(
          future: SongArtworkService.instance.getArtwork(artworkUri: cleanPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.isNotEmpty) {
              return Image.memory(
                snapshot.data!,
                fit: fit,
                width: width,
                height: height,
                errorBuilder: (_, __, ___) => _buildFallback(isDark),
              );
            }
            return _buildFallback(isDark);
          },
        );
      }
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildFallback(bool isDark) {
    final isVideo = fallbackIcon == Icons.videocam_rounded ||
        fallbackIcon == Icons.video_collection_rounded ||
        fallbackIcon == Icons.play_arrow_rounded;

    if (isVideo) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF282828),
              Color(0xFF141414),
            ],
          ),
          border: Border.all(color: Colors.white10, width: 0.8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.videocam_rounded,
              color: Colors.white.withAlpha(40),
              size: (height != null ? height! * 0.45 : 24.0).clamp(18.0, 36.0).toDouble(),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(180),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
            ? [
                const Color(0xFF242424),
                const Color(0xFF161616),
              ]
            : [
                const Color(0xFFE8E5DF),
                const Color(0xFFDAD6CF),
              ],
        ),
      ),
      child: Center(
        child: placeholderText != null && placeholderText!.isNotEmpty
            ? Text(
                placeholderText!.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              )
            : Icon(
                fallbackIcon,
                color: AppColors.primary.withAlpha(180),
                size: 24,
              ),
      ),
    );
  }
}
