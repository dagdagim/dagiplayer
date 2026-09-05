import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../domain/entities/song.dart';
import '../../services/audio/song_artwork_service.dart';

/// Premium music artwork widget that renders real embedded album covers
/// and generates beautiful vinyl/gradient artwork for tracks without covers.
class SongArtworkWidget extends StatefulWidget {
  final Song? song;
  final String? artworkUri;
  final String? songUri;
  final String? title;
  final String? artist;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool isPlaying;
  final bool isSpinning;

  const SongArtworkWidget({
    super.key,
    this.song,
    this.artworkUri,
    this.songUri,
    this.title,
    this.artist,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.isPlaying = false,
    this.isSpinning = false,
  });

  @override
  State<SongArtworkWidget> createState() => _SongArtworkWidgetState();
}

class _SongArtworkWidgetState extends State<SongArtworkWidget> {
  Future<Uint8List?>? _artworkFuture;

  String get _effectiveArtworkUri =>
      widget.artworkUri ?? widget.song?.artworkUri ?? widget.songUri ?? widget.song?.uri ?? '';
  String get _effectiveTitle => widget.title ?? widget.song?.title ?? 'Music';
  String get _effectiveArtist => widget.artist ?? widget.song?.artist ?? 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant SongArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkUri != widget.artworkUri ||
        oldWidget.songUri != widget.songUri ||
        oldWidget.song?.id != widget.song?.id) {
      _loadArtwork();
    }
  }

  void _loadArtwork() {
    final uri = _effectiveArtworkUri;
    if (uri.isEmpty || uri.startsWith('http://') || uri.startsWith('https://')) {
      _artworkFuture = null;
    } else {
      _artworkFuture = SongArtworkService.instance.getArtwork(
        artworkUri: uri,
        songUri: widget.songUri ?? widget.song?.uri,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(AppDimensions.radiusSm);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uri = _effectiveArtworkUri;

    Widget content;

    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      content = Image.network(
        uri,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, __, ___) => _buildStylizedPlaceholder(isDark),
      );
    } else if (uri.startsWith('file://') || (uri.startsWith('/') && !uri.startsWith('content://'))) {
      final cleanPath = uri.replaceFirst('file://', '');
      final localFile = File(cleanPath);
      if (localFile.existsSync()) {
        content = Image.file(
          localFile,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: (_, __, ___) => _buildStylizedPlaceholder(isDark),
        );
      } else if (_artworkFuture != null) {
        content = _buildFutureImage(isDark);
      } else {
        content = _buildStylizedPlaceholder(isDark);
      }
    } else if (_artworkFuture != null) {
      content = _buildFutureImage(isDark);
    } else {
      content = _buildStylizedPlaceholder(isDark);
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

  Widget _buildFutureImage(bool isDark) {
    return FutureBuilder<Uint8List?>(
      future: _artworkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, __, ___) => _buildStylizedPlaceholder(isDark),
          );
        }
        return _buildStylizedPlaceholder(isDark);
      },
    );
  }

  static const List<List<Color>> _gradientPalettes = [
    [Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFE64A19)],
    [Color(0xFF7C4DFF), Color(0xFF536DFE), Color(0xFF3F51B5)],
    [Color(0xFFE91E63), Color(0xFFFF4081), Color(0xFFC2185B)],
    [Color(0xFF00B0FF), Color(0xFF00E5FF), Color(0xFF0288D1)],
    [Color(0xFF00E676), Color(0xFF1DE9B6), Color(0xFF00BFA5)],
    [Color(0xFFFF1744), Color(0xFFFF5252), Color(0xFFD50000)],
    [Color(0xFFFFAB00), Color(0xFFFFD740), Color(0xFFFF6D00)],
    [Color(0xFF651FFF), Color(0xFF7C4DFF), Color(0xFF311B92)],
  ];

  Widget _buildStylizedPlaceholder(bool isDark) {
    final title = _effectiveTitle;
    final artist = _effectiveArtist;
    final hash = (title + artist).hashCode.abs();
    final palette = _gradientPalettes[hash % _gradientPalettes.length];

    final isLarge = (widget.height != null && widget.height! > 120);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette[0].withAlpha(isDark ? 220 : 180),
            palette[1].withAlpha(isDark ? 160 : 140),
            palette[2].withAlpha(isDark ? 240 : 200),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle Vinyl Groove Ring Overlay for Large Covers
          if (isLarge) ...[
            Container(
              width: (widget.height ?? 300) * 0.75,
              height: (widget.height ?? 300) * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(20), width: 1.5),
              ),
            ),
            Container(
              width: (widget.height ?? 300) * 0.5,
              height: (widget.height ?? 300) * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(25), width: 1.5),
              ),
            ),
          ],

          // Center Icon & Initial Badge
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isLarge ? 16 : 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withAlpha(70),
                  border: Border.all(color: Colors.white.withAlpha(40), width: 1),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: isLarge ? 48 : (widget.height != null ? widget.height! * 0.42 : 20),
                ),
              ),
              if (isLarge) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  artist,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
