import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/video.dart';

class ScanResult {
  final List<Song> songs;
  final List<Video> videos;
  final int totalScanned;
  final Duration elapsed;

  const ScanResult({
    required this.songs,
    required this.videos,
    required this.totalScanned,
    required this.elapsed,
  });
}

class LocalMediaScanner {
  static const _mediaStoreChannel = MethodChannel('com.dagi.dagiplayer/media_store');

  static const Set<String> supportedAudioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
    '.m4r',
    '.amr',
    '.mid',
    '.midi',
  };

  static const Set<String> supportedVideoExtensions = {
    '.mp4',
    '.mkv',
    '.mov',
    '.webm',
    '.avi',
    '.3gp',
    '.flv',
    '.ts',
    '.wmv',
    '.m4v',
    '.mpg',
    '.mpeg',
    '.vob',
    '.asf',
    '.rmvb',
  };

  Future<bool> requestMediaPermissions() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        // Request modern media permissions
        final statuses = await [
          Permission.audio,
          Permission.videos,
          Permission.photos,
          Permission.storage,
        ].request();

        final audioGranted = statuses[Permission.audio]?.isGranted ?? false;
        final videoGranted = statuses[Permission.videos]?.isGranted ?? false;
        final photosGranted = statuses[Permission.photos]?.isGranted ?? false;
        final storageGranted = statuses[Permission.storage]?.isGranted ?? false;

        return audioGranted || videoGranted || photosGranted || storageGranted;
      }

      if (Platform.isIOS) {
        final photosStatus = await Permission.photos.request();
        return photosStatus.isGranted || photosStatus.isLimited;
      }
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
    }

    return true;
  }

  /// Scan device using high-speed native Android MediaStore first, supplemented by deep directory traversal.
  Future<ScanResult> scanDevice({
    void Function(String currentFolder, int count)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final songs = <Song>[];
    final videos = <Video>[];
    final seenFilePaths = <String>{};

    await requestMediaPermissions();

    int lastProgressTick = 0;
    void reportProgress(String folder, int count) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastProgressTick > 150) {
        lastProgressTick = now;
        onProgress?.call(folder, count);
      }
    }

    // 1. FAST NATIVE MEDIASTORE QUERY (Android) - Takes ~30ms total
    if (Platform.isAndroid) {
      try {
        onProgress?.call('Media Library', 0);
        
        // Query Native Android MediaStore Audio
        final rawAudio = await _mediaStoreChannel.invokeListMethod<Map<dynamic, dynamic>>('getAudioList');
        if (rawAudio != null) {
          for (final item in rawAudio) {
            final path = item['path'] as String? ?? '';
            final playableUri = item['uri'] as String? ?? path;
            if (path.isEmpty || seenFilePaths.contains(path)) continue;

            final durationMs = (item['durationMs'] as num? ?? 0).toInt();
            final size = (item['size'] as num? ?? 0).toInt();
            final dateAddedSec = (item['dateAdded'] as num? ?? 0).toInt();

            final parentName = path.startsWith('content://')
                ? 'Media'
                : p.basename(p.dirname(path));
            final album = item['album'] as String? ?? parentName;

            final song = Song(
              id: item['id'] as String? ?? 'local-audio-${path.hashCode.abs()}',
              title: item['title'] as String? ?? p.basenameWithoutExtension(path),
              artist: item['artist'] as String? ?? 'Unknown Artist',
              album: album,
              albumArtist: item['artist'] as String?,
              duration: Duration(milliseconds: durationMs > 0 ? durationMs : 210000),
              uri: (path.isNotEmpty && !path.startsWith('content://')) ? path : playableUri,
              fileSize: size,
              artworkUri: item['artworkUri'] as String?,
              dateAdded: dateAddedSec > 0
                  ? DateTime.fromMillisecondsSinceEpoch(dateAddedSec * 1000)
                  : DateTime.now(),
            );

            seenFilePaths.add(path);
            songs.add(song);
          }
          reportProgress('Audio Catalog', songs.length);
        }

        // Query Native Android MediaStore Videos
        final rawVideos = await _mediaStoreChannel.invokeListMethod<Map<dynamic, dynamic>>('getVideoList');
        if (rawVideos != null) {
          for (final item in rawVideos) {
            final path = item['path'] as String? ?? '';
            final playableUri = item['uri'] as String? ?? path;
            if (path.isEmpty || seenFilePaths.contains(path)) continue;

            final durationMs = (item['durationMs'] as num? ?? 0).toInt();
            final size = (item['size'] as num? ?? 0).toInt();
            final dateAddedSec = (item['dateAdded'] as num? ?? 0).toInt();
            final width = (item['width'] as num? ?? 0).toInt();
            final height = (item['height'] as num? ?? 0).toInt();

            String res = 'HD';
            if (width >= 3840 || height >= 2160) {
              res = '4K UHD';
            } else if (width >= 1920 || height >= 1080) {
              res = '1080p FHD';
            } else if (width >= 1280 || height >= 720) {
              res = '720p HD';
            } else if (width > 0) {
              res = '${width}x$height';
            }

            final fileName = p.basenameWithoutExtension(path);
            final parentName = path.startsWith('content://')
                ? 'Videos'
                : p.basename(p.dirname(path));
            final folderPath = path.startsWith('content://')
                ? 'Videos'
                : p.dirname(path);

            final video = Video(
              id: item['id'] as String? ?? 'local-vid-${path.hashCode.abs()}',
              title: item['title'] as String? ?? fileName,
              duration: Duration(milliseconds: durationMs > 0 ? durationMs : 300000),
              uri: (path.isNotEmpty && !path.startsWith('content://')) ? path : playableUri,
              category: _detectCategory(path, fileName, parentName),
              fileSize: size,
              folderPath: folderPath,
              dateAdded: dateAddedSec > 0
                  ? DateTime.fromMillisecondsSinceEpoch(dateAddedSec * 1000)
                  : DateTime.now(),
              resolution: res,
            );

            seenFilePaths.add(path);
            videos.add(video);
          }
          reportProgress('Video Catalog', songs.length + videos.length);
        }
      } catch (e) {
        debugPrint('Native MediaStore query error: $e');
      }
    }

    // 2. COMPLEMENTARY NON-BLOCKING DIRECTORY CRAWLER (For chat apps, SD cards, and download folders)
    // Uses async stream and periodic micro-yields to prevent UI freezes and ANRs.
    try {
      final rootDirs = await getScanRootDirectories();
      final dirQueue = <Directory>[...rootDirs];
      final visitedDirs = <String>{};
      int processedCount = 0;
      final isMediaStorePopulated = songs.isNotEmpty || videos.isNotEmpty;

      while (dirQueue.isNotEmpty) {
        final currentDir = dirQueue.removeAt(0);
        final dirPath = currentDir.path;

        if (visitedDirs.contains(dirPath)) continue;
        visitedDirs.add(dirPath);

        final folderName = p.basename(dirPath);
        if (dirPath.contains('/Android/data') ||
            dirPath.contains('/Android/obb') ||
            dirPath.contains('/DCIM') ||
            dirPath.contains('/Pictures') ||
            folderName.startsWith('.') ||
            folderName == '.thumbnails' ||
            folderName == '.trash' ||
            folderName == '.cache') {
          continue;
        }

        try {
          if (!await currentDir.exists()) continue;

          await for (final entity in currentDir.list(followLinks: false)) {
            processedCount++;
            if (processedCount % 35 == 0) {
              // Micro-yield to Flutter event loop so the UI remains fluid
              await Future.delayed(Duration.zero);
            }

            if (entity is File) {
              final filePath = entity.path;
              if (seenFilePaths.contains(filePath)) continue;

              final baseName = p.basename(filePath);
              if (baseName.startsWith('.')) continue;

              final ext = p.extension(filePath).toLowerCase();
              final fileName = p.basenameWithoutExtension(filePath);

              if (supportedVideoExtensions.contains(ext)) {
                seenFilePaths.add(filePath);
                final video = await _createVideoFromFileAsync(entity, fileName);
                videos.add(video);
                reportProgress(folderName, songs.length + videos.length);
              } else if (supportedAudioExtensions.contains(ext)) {
                seenFilePaths.add(filePath);
                final song = await _createSongFromFileAsync(entity, fileName);
                songs.add(song);
                reportProgress(folderName, songs.length + videos.length);
              }
            } else if (entity is Directory && !isMediaStorePopulated) {
              // Only recurse into subdirectories if MediaStore failed to populate the library
              final subName = p.basename(entity.path);
              final subPath = entity.path;
              if (!subName.startsWith('.') &&
                  !subPath.contains('/Android/data') &&
                  !subPath.contains('/Android/obb') &&
                  !subPath.contains('/DCIM') &&
                  !subPath.contains('/Pictures') &&
                  !visitedDirs.contains(entity.path)) {
                dirQueue.add(entity);
              }
            }
          }
        } catch (_) {
          // Continue scanning remaining folders if one folder has OS restricted access
        }
      }
    } catch (e) {
      debugPrint('Deep directory crawler error: $e');
    }

    onProgress?.call('Done', songs.length + videos.length);
    stopwatch.stop();
    debugPrint('Local media scan finished: ${videos.length} videos, ${songs.length} songs in ${stopwatch.elapsedMilliseconds}ms');

    return ScanResult(
      songs: songs,
      videos: videos,
      totalScanned: songs.length + videos.length,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<List<Directory>> getScanRootDirectories() async {
    final dirs = <Directory>{};
    if (kIsWeb) return dirs.toList();

    try {
      if (Platform.isAndroid) {
        // Focused media directories (Excludes DCIM/Pictures which MediaStore already indexes directly)
        const standardPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/storage/emulated/0/Download/Telegram',
          '/storage/emulated/0/Download/Vidmate',
          '/storage/emulated/0/Download/Snaptube',
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Videos',
          '/storage/emulated/0/Video',
          '/storage/emulated/0/Audiobooks',
          '/storage/emulated/0/Podcasts',
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
          '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes',
          '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
          '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
          '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Video',
          '/storage/emulated/0/Telegram/Telegram Video',
          '/storage/emulated/0/Telegram/Telegram Audio',
          '/storage/emulated/0/Bluetooth',
          '/storage/emulated/0/Xender/video',
          '/storage/emulated/0/Xender/audio',
          '/storage/emulated/0/ShareMe',
        ];

        for (final path in standardPaths) {
          try {
            final dir = Directory(path);
            if (dir.existsSync()) dirs.add(dir);
          } catch (_) {}
        }

        // Check external SD card mounts
        try {
          final storageRoot = Directory('/storage');
          if (storageRoot.existsSync()) {
            for (final entity in storageRoot.listSync(followLinks: false)) {
              if (entity is Directory) {
                final base = p.basename(entity.path);
                if (base != 'emulated' && base != 'self' && !base.startsWith('.')) {
                  dirs.add(entity);
                }
              }
            }
          }
        } catch (_) {}
      } else {
        try {
          final musicDir = await getApplicationDocumentsDirectory();
          dirs.add(musicDir);
        } catch (_) {}

        try {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null && downloadsDir.existsSync()) {
            dirs.add(downloadsDir);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error discovering root directories: $e');
    }

    return dirs.toList();
  }

  String _detectCategory(String fullPath, String fileName, String parentName) {
    final lowerPath = fullPath.toLowerCase();
    final lowerName = fileName.toLowerCase();

    if (lowerPath.contains('camera') || lowerPath.contains('dcim')) {
      return 'Camera';
    } else if (lowerPath.contains('movie') || lowerName.contains('movie') || lowerName.contains('film')) {
      return 'Movies';
    } else if (lowerPath.contains('whatsapp')) {
      return 'WhatsApp';
    } else if (lowerPath.contains('telegram')) {
      return 'Telegram';
    } else if (lowerPath.contains('screen') || lowerPath.contains('record')) {
      return 'Screen Recordings';
    } else if (lowerPath.contains('download') || lowerPath.contains('vidmate') || lowerPath.contains('snaptube')) {
      return 'Downloads';
    } else if (lowerName.contains('music') || lowerName.contains('official') || lowerName.contains('clip')) {
      return 'Music Videos';
    } else if (parentName.isNotEmpty && parentName != '0' && parentName != 'emulated') {
      return parentName;
    }
    return 'Videos';
  }

  Song _createSongFromFile(File file, String fileName) {
    String title = fileName;
    String artist = 'Unknown Artist';

    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else if (fileName.contains('_')) {
      title = fileName.replaceAll('_', ' ').trim();
    }

    final trackMatch = RegExp(r'^\d+[\s\.\-_]+(.*)$').firstMatch(title);
    if (trackMatch != null && trackMatch.group(1) != null) {
      title = trackMatch.group(1)!.trim();
    }

    int fileSize = 0;
    DateTime dateAdded = DateTime.now();

    try {
      final stat = file.statSync();
      fileSize = stat.size;
      dateAdded = stat.modified;
    } catch (_) {}

    final estimatedSeconds = fileSize > 0 ? (fileSize / (20 * 1024)).clamp(30.0, 3600.0).toInt() : 210;

    return Song(
      id: 'local-${file.path.hashCode.abs()}',
      title: title.isNotEmpty ? title : fileName,
      artist: artist,
      album: p.basename(file.parent.path),
      albumArtist: artist,
      duration: Duration(seconds: estimatedSeconds),
      uri: file.path,
      fileSize: fileSize,
      dateAdded: dateAdded,
    );
  }

  Video _createVideoFromFile(File file, String fileName) {
    int fileSize = 0;
    DateTime dateAdded = DateTime.now();

    try {
      final stat = file.statSync();
      fileSize = stat.size;
      dateAdded = stat.modified;
    } catch (_) {}

    final parentName = p.basename(file.parent.path);
    String resolution = 'HD';
    if (fileSize > 800000000) {
      resolution = '4K UHD';
    } else if (fileSize > 80000000) {
      resolution = '1080p FHD';
    } else if (fileSize > 15000000) {
      resolution = '720p HD';
    } else {
      resolution = 'SD';
    }

    final estimatedSeconds = fileSize > 0 ? (fileSize / (150 * 1024)).clamp(10.0, 7200.0).toInt() : 600;

    return Video(
      id: 'local-vid-${file.path.hashCode.abs()}',
      title: fileName.replaceAll('_', ' ').replaceAll('.', ' ').trim(),
      duration: Duration(seconds: estimatedSeconds),
      uri: file.path,
      category: _detectCategory(file.path, fileName, parentName),
      fileSize: fileSize,
      folderPath: file.parent.path,
      dateAdded: dateAdded,
      resolution: resolution,
    );
  }

  Future<Song> _createSongFromFileAsync(File file, String fileName) async {
    String title = fileName;
    String artist = 'Unknown Artist';

    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else if (fileName.contains('_')) {
      title = fileName.replaceAll('_', ' ').trim();
    }

    final trackMatch = RegExp(r'^\d+[\s\.\-_]+(.*)$').firstMatch(title);
    if (trackMatch != null && trackMatch.group(1) != null) {
      title = trackMatch.group(1)!.trim();
    }

    int fileSize = 0;
    DateTime dateAdded = DateTime.now();

    try {
      final stat = await file.stat();
      fileSize = stat.size;
      dateAdded = stat.modified;
    } catch (_) {}

    final estimatedSeconds = fileSize > 0 ? (fileSize / (20 * 1024)).clamp(30.0, 3600.0).toInt() : 210;

    return Song(
      id: 'local-${file.path.hashCode.abs()}',
      title: title.isNotEmpty ? title : fileName,
      artist: artist,
      album: p.basename(file.parent.path),
      albumArtist: artist,
      duration: Duration(seconds: estimatedSeconds),
      uri: file.path,
      fileSize: fileSize,
      dateAdded: dateAdded,
    );
  }

  Future<Video> _createVideoFromFileAsync(File file, String fileName) async {
    int fileSize = 0;
    DateTime dateAdded = DateTime.now();

    try {
      final stat = await file.stat();
      fileSize = stat.size;
      dateAdded = stat.modified;
    } catch (_) {}

    final parentName = p.basename(file.parent.path);
    String resolution = 'HD';
    if (fileSize > 800000000) {
      resolution = '4K UHD';
    } else if (fileSize > 80000000) {
      resolution = '1080p FHD';
    } else if (fileSize > 15000000) {
      resolution = '720p HD';
    } else {
      resolution = 'SD';
    }

    final estimatedSeconds = fileSize > 0 ? (fileSize / (150 * 1024)).clamp(10.0, 7200.0).toInt() : 600;

    return Video(
      id: 'local-vid-${file.path.hashCode.abs()}',
      title: fileName.replaceAll('_', ' ').replaceAll('.', ' ').trim(),
      duration: Duration(seconds: estimatedSeconds),
      uri: file.path,
      category: _detectCategory(file.path, fileName, parentName),
      fileSize: fileSize,
      folderPath: file.parent.path,
      dateAdded: dateAdded,
      resolution: resolution,
    );
  }
}
