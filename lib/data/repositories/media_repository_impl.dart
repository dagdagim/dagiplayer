import '../../domain/entities/song.dart';
import '../../domain/entities/video.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/repositories/media_repository.dart';
import '../database/app_database.dart';
import '../datasources/local_media_scanner.dart';
import '../datasources/mock_initial_catalog.dart';

class MediaRepositoryImpl implements MediaRepository {
  final AppDatabase database;
  final LocalMediaScanner scanner;

  MediaRepositoryImpl({
    required this.database,
    required this.scanner,
  });

  @override
  Future<List<Song>> getAllSongs() async {
    return await database.getAllSongs();
  }

  @override
  Future<List<Song>> getRecentlyPlayedSongs({int limit = 10}) async {
    final all = await getAllSongs();
    final played = all.where((s) => s.lastPlayedAt != null).toList()
      ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    if (played.isEmpty) {
      return all.take(limit).toList();
    }
    return played.take(limit).toList();
  }

  @override
  Future<List<Song>> getRecentlyAddedSongs({int limit = 20}) async {
    final all = await getAllSongs();
    final sorted = List<Song>.from(all)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Song>> getFavoriteSongs() async {
    return await database.getFavoriteSongs();
  }

  @override
  Future<List<Song>> getMostPlayedSongs({int limit = 20}) async {
    final all = await getAllSongs();
    final sorted = List<Song>.from(all)..sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Album>> getAllAlbums() async {
    final songs = await getAllSongs();
    final Map<String, List<Song>> albumGroups = {};

    for (final song in songs) {
      final albumName = song.album ?? 'Unknown Album';
      albumGroups.putIfAbsent(albumName, () => []).add(song);
    }

    final albums = <Album>[];
    albumGroups.forEach((albumName, albumSongs) {
      final firstSong = albumSongs.first;
      final totalMs = albumSongs.fold<int>(0, (sum, s) => sum + s.duration.inMilliseconds);
      albums.add(Album(
        id: 'album-${albumName.hashCode.abs()}',
        title: albumName,
        artist: firstSong.albumArtist ?? firstSong.artist,
        artworkUri: firstSong.artworkUri,
        year: firstSong.year,
        songCount: albumSongs.length,
        totalDuration: Duration(milliseconds: totalMs),
        songIds: albumSongs.map((s) => s.id).toList(),
      ));
    });

    if (albums.isEmpty) {
      return MockInitialCatalog.initialAlbums;
    }
    return albums;
  }

  @override
  Future<Album?> getAlbumById(String id) async {
    final albums = await getAllAlbums();
    try {
      return albums.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Artist>> getAllArtists() async {
    final songs = await getAllSongs();
    final Map<String, List<Song>> artistGroups = {};

    for (final song in songs) {
      final artistName = song.artist.split(',').first.split('ft.').first.trim();
      artistGroups.putIfAbsent(artistName, () => []).add(song);
    }

    final artists = <Artist>[];
    artistGroups.forEach((name, artistSongs) {
      final albums = artistSongs.map((s) => s.album).whereType<String>().toSet();
      artists.add(Artist(
        id: 'artist-${name.hashCode.abs()}',
        name: name,
        imageUri: artistSongs.first.artworkUri,
        songCount: artistSongs.length,
        albumCount: albums.length,
      ));
    });

    if (artists.isEmpty) {
      return MockInitialCatalog.initialArtists;
    }
    return artists;
  }

  @override
  Future<Artist?> getArtistById(String id) async {
    final artists = await getAllArtists();
    try {
      return artists.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Video>> getAllVideos() async {
    return await database.getAllVideos();
  }

  @override
  Future<List<Video>> getContinueWatchingVideos() async {
    final videos = await getAllVideos();
    final watched = videos.where((v) => v.hasResumePosition).toList()
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    if (watched.isEmpty) {
      return videos.take(3).toList();
    }
    return watched;
  }

  @override
  Future<List<Video>> getVideosByCategory(String category) async {
    final all = await getAllVideos();
    if (category == 'All') return all;
    return all.where((v) => v.category.toLowerCase() == category.toLowerCase()).toList();
  }

  @override
  Future<void> toggleSongFavorite(String songId, [Song? songContext]) async {
    await database.toggleSongFavorite(songId, songContext);
  }

  @override
  Future<void> toggleVideoFavorite(String videoId) async {
    await database.toggleVideoFavorite(videoId);
  }

  @override
  Future<void> updateSongPlayCount(String songId) async {
    await database.updateSongPlayCount(songId);
  }

  @override
  Future<void> updateVideoPosition(String videoId, Duration position) async {
    await database.updateVideoPosition(videoId, position);
  }

  @override
  Future<void> scanDeviceMedia({bool forceRescan = false}) async {
    final result = await scanner.scanDevice();
    if (result.songs.isNotEmpty) {
      await database.insertSongs(result.songs);
    }
    if (result.videos.isNotEmpty) {
      await database.insertVideos(result.videos);
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await getAllSongs();
    final lower = query.toLowerCase();
    return all.where((s) {
      return s.title.toLowerCase().contains(lower) ||
          s.artist.toLowerCase().contains(lower) ||
          (s.album?.toLowerCase().contains(lower) ?? false) ||
          (s.genre?.toLowerCase().contains(lower) ?? false);
    }).toList();
  }

  @override
  Future<List<Video>> searchVideos(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await getAllVideos();
    final lower = query.toLowerCase();
    return all.where((v) {
      return v.title.toLowerCase().contains(lower) ||
          v.category.toLowerCase().contains(lower);
    }).toList();
  }

  @override
  Future<void> updateSongLyrics(String songId, String lyrics) async {
    await database.updateSongLyrics(songId, lyrics);
  }
}
