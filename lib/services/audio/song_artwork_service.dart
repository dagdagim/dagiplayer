import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// High performance caching service for audio album cover art & embedded ID3 artwork.
class SongArtworkService {
  SongArtworkService._();
  static final SongArtworkService instance = SongArtworkService._();

  static const _channel = MethodChannel('com.dagi.dagiplayer/media_store');
  static final Map<String, Uint8List> _memCache = <String, Uint8List>{};
  static final Map<String, Future<Uint8List?>> _inFlight = <String, Future<Uint8List?>>{};
  static String? _cacheDirPath;

  static Future<String> get _cacheDir async {
    if (_cacheDirPath != null) return _cacheDirPath!;
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/dagi_audio_artwork');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cacheDirPath = dir.path;
    return _cacheDirPath!;
  }

  /// Get cached or newly extracted artwork bytes for a song / album
  Future<Uint8List?> getArtwork({
    String? artworkUri,
    String? songUri,
    int? albumId,
  }) async {
    final key = artworkUri ?? songUri ?? (albumId != null ? 'album-$albumId' : '');
    if (key.isEmpty) return null;

    if (_memCache.containsKey(key)) {
      return _memCache[key];
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key];
    }

    final future = _loadOrExtract(key, artworkUri, songUri, albumId);
    _inFlight[key] = future;

    try {
      final bytes = await future;
      if (bytes != null && bytes.isNotEmpty) {
        if (_memCache.length > 200) {
          _memCache.remove(_memCache.keys.first);
        }
        _memCache[key] = bytes;
      }
      return bytes;
    } catch (e) {
      debugPrint('SongArtworkService error for $key: $e');
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<Uint8List?> _loadOrExtract(
    String key,
    String? artworkUri,
    String? songUri,
    int? albumId,
  ) async {
    try {
      final hash = key.hashCode.toRadixString(16);
      final cacheFolder = await _cacheDir;
      final cachedFile = File('$cacheFolder/$hash.jpg');

      if (cachedFile.existsSync()) {
        try {
          final bytes = await cachedFile.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        } catch (_) {}
      }

      Uint8List? data;

      if (!kIsWeb && Platform.isAndroid) {
        try {
          data = await _channel.invokeMethod<Uint8List>('getAudioArtwork', {
            'uri': artworkUri ?? songUri,
            'albumId': albumId,
          });
        } catch (_) {}
      }

      if (data != null && data.isNotEmpty) {
        unawaited(cachedFile.writeAsBytes(data));
        return data;
      }
    } catch (e) {
      debugPrint('Artwork extraction failed for $key: $e');
    }
    return null;
  }
}
