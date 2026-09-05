import '../entities/song.dart';
import '../entities/video.dart';
import '../entities/album.dart';
import '../entities/artist.dart';

abstract class MediaRepository {
  Future<List<Song>> getAllSongs();
  Future<List<Song>> getRecentlyPlayedSongs({int limit = 10});
  Future<List<Song>> getRecentlyAddedSongs({int limit = 20});
  Future<List<Song>> getFavoriteSongs();
  Future<List<Song>> getMostPlayedSongs({int limit = 20});
  Future<List<Album>> getAllAlbums();
  Future<Album?> getAlbumById(String id);
  Future<List<Artist>> getAllArtists();
  Future<Artist?> getArtistById(String id);
  Future<List<Video>> getAllVideos();
  Future<List<Video>> getContinueWatchingVideos();
  Future<List<Video>> getVideosByCategory(String category);
  Future<void> toggleSongFavorite(String songId, [Song? songContext]);
  Future<void> toggleVideoFavorite(String videoId);
  Future<void> updateSongPlayCount(String songId);
  Future<void> updateVideoPosition(String videoId, Duration position);
  Future<void> scanDeviceMedia({bool forceRescan = false});
  Future<List<Song>> searchSongs(String query);
  Future<List<Video>> searchVideos(String query);
  Future<void> updateSongLyrics(String songId, String lyrics);
}
