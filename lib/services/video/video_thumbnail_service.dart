import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// High performance caching service for local video frame snapshots.
class VideoThumbnailService {
  VideoThumbnailService._();
  static final VideoThumbnailService instance = VideoThumbnailService._();

  // In-memory cache for ultra-fast instant UI rendering during scrolling
  static final Map<String, Uint8List> _memCache = <String, Uint8List>{};
  static final Map<String, Future<Uint8List?>> _inFlight = <String, Future<Uint8List?>>{};
  static String? _cacheDirPath;

  static Future<String> get _cacheDir async {
    if (_cacheDirPath != null) return _cacheDirPath!;
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/dagi_video_thumbs');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheDirPath = dir.path;
    return _cacheDirPath!;
  }

  /// Get cached or newly generated thumbnail bytes for a video file
  Future<Uint8List?> getThumbnail(
    String videoUri, {
    int maxWidth = 360,
    int quality = 70,
  }) async {
    if (videoUri.isEmpty) return null;

    final cleanPath = videoUri.replaceFirst('file://', '');

    // 1. Check RAM memory cache
    if (_memCache.containsKey(cleanPath)) {
      return _memCache[cleanPath];
    }

    // 2. In-flight request deduplication
    if (_inFlight.containsKey(cleanPath)) {
      return _inFlight[cleanPath];
    }

    final future = _loadOrGenerate(cleanPath, maxWidth, quality);
    _inFlight[cleanPath] = future;

    try {
      final bytes = await future;
      if (bytes != null) {
        // Keep memory cache within reasonable size (~150 thumbnails)
        if (_memCache.length > 150) {
          _memCache.remove(_memCache.keys.first);
        }
        _memCache[cleanPath] = bytes;
      }
      return bytes;
    } catch (e) {
      debugPrint('VideoThumbnailService error for $cleanPath: $e');
      return null;
    } finally {
      _inFlight.remove(cleanPath);
    }
  }

  static const _channel = MethodChannel('com.dagi.dagiplayer/media_store');

  Future<Uint8List?> _loadOrGenerate(String filePath, int maxWidth, int quality) async {
    try {
      // Generate unique cache file name
      final hash = filePath.hashCode.toRadixString(16);
      final cacheFolder = await _cacheDir;
      final cachedFile = File('$cacheFolder/$hash.jpg');

      // 1. Check persistent disk cache
      if (cachedFile.existsSync()) {
        try {
          final bytes = await cachedFile.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        } catch (_) {}
      }

      Uint8List? data;

      // 2. Try native MediaStore Android thumbnail generator (very fast & hardware-accelerated)
      if (!kIsWeb && Platform.isAndroid) {
        try {
          data = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
            'uri': filePath,
            'width': maxWidth,
            'height': (maxWidth * 9 ~/ 16),
          });
        } catch (_) {}
      }

      // 3. Fallback to video_thumbnail package
      if (data == null || data.isEmpty) {
        try {
          data = await VideoThumbnail.thumbnailData(
            video: filePath,
            imageFormat: ImageFormat.JPEG,
            maxWidth: maxWidth,
            quality: quality,
          );
        } catch (_) {}
      }

      if (data != null && data.isNotEmpty) {
        // Save to disk asynchronously
        unawaited(cachedFile.writeAsBytes(data));
        return data;
      }
    } catch (e) {
      debugPrint('Thumbnail extraction failed for $filePath: $e');
    }
    return null;
  }
}
