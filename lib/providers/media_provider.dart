import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local_media_scanner.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/video.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import 'audio_player_provider.dart';
import 'database_provider.dart';

final mediaRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final isScanningMediaProvider = StateProvider<bool>((ref) => false);
final scanProgressStatusProvider = StateProvider<String>((ref) => '');
final scannedItemsCountProvider = StateProvider<int>((ref) => 0);

final allSongsProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getAllSongs();
});

final recentlyPlayedSongsProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getRecentlyPlayedSongs();
});

final recentlyAddedSongsProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getRecentlyAddedSongs();
});

final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getFavoriteSongs();
});

final allAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getAllAlbums();
});

final albumDetailProvider = FutureProvider.family<Album?, String>((ref, albumId) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getAlbumById(albumId);
});

final allArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getAllArtists();
});

final artistDetailProvider = FutureProvider.family<Artist?, String>((ref, artistId) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getArtistById(artistId);
});

final allVideosProvider = FutureProvider<List<Video>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getAllVideos();
});

final continueWatchingVideosProvider = FutureProvider<List<Video>>((ref) async {
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getContinueWatchingVideos();
});

final selectedVideoCategoryProvider = StateProvider<String>((ref) => 'All');

final filteredVideosProvider = FutureProvider<List<Video>>((ref) async {
  final category = ref.watch(selectedVideoCategoryProvider);
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(mediaRepositoryProvider);
  return await repo.getVideosByCategory(category);
});

class MediaActionController {
  final Ref _ref;
  MediaActionController(this._ref);

  Future<void> toggleSongFavorite(String songId, [Song? songContext]) async {
    final repo = _ref.read(mediaRepositoryProvider);
    await repo.toggleSongFavorite(songId, songContext);
    _ref.read(audioPlaybackNotifierProvider.notifier).toggleFavorite(songId);
    _ref.read(mediaRefreshTriggerProvider.notifier).state++;
  }

  Future<void> toggleVideoFavorite(String videoId) async {
    final repo = _ref.read(mediaRepositoryProvider);
    await repo.toggleVideoFavorite(videoId);
    _ref.read(mediaRefreshTriggerProvider.notifier).state++;
  }

  Future<void> updateVideoPosition(String videoId, Duration position) async {
    final repo = _ref.read(mediaRepositoryProvider);
    await repo.updateVideoPosition(videoId, position);
    _ref.read(mediaRefreshTriggerProvider.notifier).state++;
  }

  Future<ScanResult> scanDevice({
    void Function(String folder, int count)? onProgress,
  }) async {
    _ref.read(isScanningMediaProvider.notifier).state = true;
    _ref.read(scanProgressStatusProvider.notifier).state = 'Starting deep media scan...';
    try {
      final scanner = _ref.read(localMediaScannerProvider);
      final database = _ref.read(appDatabaseProvider);

      final result = await scanner.scanDevice(
        onProgress: (folder, count) {
          _ref.read(scanProgressStatusProvider.notifier).state = 'Scanning $folder ($count found)...';
          _ref.read(scannedItemsCountProvider.notifier).state = count;
          onProgress?.call(folder, count);
        },
      );

      if (result.songs.isNotEmpty) {
        await database.insertSongs(result.songs);
      }
      if (result.videos.isNotEmpty) {
        await database.insertVideos(result.videos);
      }

      _ref.read(mediaRefreshTriggerProvider.notifier).state++;
      return result;
    } finally {
      _ref.read(isScanningMediaProvider.notifier).state = false;
      _ref.read(scanProgressStatusProvider.notifier).state = '';
    }
  }
}

final mediaActionControllerProvider = Provider<MediaActionController>((ref) {
  return MediaActionController(ref);
});
