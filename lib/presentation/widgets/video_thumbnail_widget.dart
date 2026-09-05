import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/video/video_thumbnail_service.dart';
import 'app_network_image.dart';

/// Renders real snapshot thumbnails for local and remote videos.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoUri;
  final String? thumbnailUri;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final bool showPlayPill;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUri,
    this.thumbnailUri,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.videocam_rounded,
    this.showPlayPill = false,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Future<Uint8List?>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUri != widget.videoUri || oldWidget.thumbnailUri != widget.thumbnailUri) {
      _initThumbnail();
    }
  }

  void _initThumbnail() {
    if (widget.thumbnailUri != null && widget.thumbnailUri!.isNotEmpty) {
      _thumbnailFuture = null;
    } else if (widget.videoUri.isNotEmpty) {
      _thumbnailFuture = VideoThumbnailService.instance.getThumbnail(widget.videoUri);
    } else {
      _thumbnailFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(AppDimensions.radiusSm);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;

    // 1. Explicit remote/local thumbnail image
    if (widget.thumbnailUri != null && widget.thumbnailUri!.isNotEmpty) {
      final thumb = widget.thumbnailUri!;
      if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
        content = AppNetworkImage(
          imageUrl: thumb,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          borderRadius: radius,
          fallbackIcon: widget.fallbackIcon,
        );
      } else {
        final localFile = File(thumb.replaceFirst('file://', ''));
        if (localFile.existsSync()) {
          content = Image.file(
            localFile,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          );
        } else {
          content = _buildPlaceholder(isDark);
        }
      }
    } else if (_thumbnailFuture != null) {
      // 2. Extracted video frame snapshot
      content = FutureBuilder<Uint8List?>(
        future: _thumbnailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return Image.memory(
              snapshot.data!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
            );
          }
          return _buildPlaceholder(isDark);
        },
      );
    } else {
      content = _buildPlaceholder(isDark);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
        child: content,
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1F24),
                  const Color(0xFF141518),
                ]
              : [
                  const Color(0xFFE5E7EB),
                  const Color(0xFFD1D5DB),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          color: (isDark ? Colors.white : Colors.black).withAlpha(40),
          size: 22,
        ),
      ),
    );
  }
}
