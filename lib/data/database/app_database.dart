import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/video.dart';
import '../../domain/entities/playlist.dart';
import '../datasources/mock_initial_catalog.dart';
import '../datasources/favorites_cache_service.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;
  bool _isInitialized = false;

  // In-memory fallback cache for web or fallback environments
  final Map<String, Song> _memorySongs = {};
  final Map<String, Video> _memoryVideos = {};
  final Map<String, Playlist> _memoryPlaylists = {};
  final Map<String, List<String>> _memoryPlaylistSongs = {};

  Future<void> init() async {
    if (_isInitialized) return;

    await FavoritesCacheService.instance.init();

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    try {
      if (kIsWeb) {
        _seedMemory();
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        final dbPath = p.join(docsDir.path, 'dagiplayer.db');
        _db = await openDatabase(
          dbPath,
          version: 3,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );

        // Ensure all table columns exist on existing databases
        await _ensureSchemaUpgrades(_db!);

        // Check if database needs initial playlists
        final count = Sqflite.firstIntValue(
          await _db!.rawQuery('SELECT COUNT(*) FROM playlists'),
        );
        if (count == null || count == 0) {
          await _seedPlaylists(_db!);
        }
      }
    } catch (e) {
      debugPrint('Database initialization fallback to memory: $e');
      _seedMemory();
    }

    _isInitialized = true;
  }

  Future<void> _ensureSchemaUpgrades(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(videos)');
      final colNames = columns.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('playback_speed')) {
        await db.execute('ALTER TABLE videos ADD COLUMN playback_speed REAL DEFAULT 1.0');
      }
      if (!colNames.contains('audio_track')) {
        await db.execute('ALTER TABLE videos ADD COLUMN audio_track TEXT');
      }
      if (!colNames.contains('selected_subtitle')) {
        await db.execute('ALTER TABLE videos ADD COLUMN selected_subtitle TEXT');
      }
    } catch (e) {
      debugPrint('Schema upgrade check error: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT,
        albumArtist TEXT,
        duration_ms INTEGER NOT NULL,
        uri TEXT NOT NULL,
        artwork_uri TEXT,
        genre TEXT,
        year INTEGER,
        track_number INTEGER,
        disc_number INTEGER,
        file_size INTEGER,
        date_added INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        play_count INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER,
        lyrics TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE videos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        uri TEXT NOT NULL,
        thumbnail_uri TEXT,
        category TEXT NOT NULL,
        year INTEGER,
        resolution TEXT,
        last_position_ms INTEGER NOT NULL DEFAULT 0,
        date_added INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        file_size INTEGER,
        folder_path TEXT,
        playback_speed REAL DEFAULT 1.0,
        audio_track TEXT,
        selected_subtitle TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        cover_art_uri TEXT,
        icon_name TEXT,
        date_created INTEGER NOT NULL,
        date_modified INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        playlist_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, song_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _seedPlaylists(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _purgeDemoData(db);
    }
    if (oldVersion < 3) {
      await _ensureSchemaUpgrades(db);
    }
  }

  Future<void> _purgeDemoData(Database db) async {
    try {
      // Purge fake mock web songs and demo videos only if not favorited
      await db.delete('songs',
          where: '(uri LIKE ? OR uri LIKE ? OR id LIKE ?) AND is_favorite = 0',
          whereArgs: ['http%', 'https%', 'song-%']);
      await db.delete('videos',
          where: '(uri LIKE ? OR uri LIKE ? OR id LIKE ? OR uri LIKE ?) AND is_favorite = 0',
          whereArgs: ['http%', 'https%', 'vid-%', '%butterfly%']);
    } catch (e) {
      debugPrint('Error purging demo media: $e');
    }
  }

  Future<void> _seedPlaylists(Database db) async {
    final batch = db.batch();
    for (final playlist in MockInitialCatalog.initialPlaylists) {
      batch.insert('playlists', playlist.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  void _seedMemory() {
    for (final playlist in MockInitialCatalog.initialPlaylists) {
      _memoryPlaylists[playlist.id] = playlist;
      _memoryPlaylistSongs[playlist.id] = [];
    }
  }

  // Database Accessors

  Future<List<Song>> getAllSongs() async {
    await init();
    if (_db == null) return _memorySongs.values.toList();

    final results = await _db!.query('songs', orderBy: 'title ASC');
    return results.map((m) => Song.fromMap(m)).toList();
  }

  Future<Song?> getSongById(String id) async {
    await init();
    if (_db == null) return _memorySongs[id];

    final results = await _db!.query('songs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Song.fromMap(results.first);
  }

  Future<void> insertSongs(List<Song> songs) async {
    await init();
    final favCache = FavoritesCacheService.instance;
    final newlyFoundFavorites = <Song>[];

    if (_db == null) {
      for (final song in songs) {
        final existing = _memorySongs[song.id];
        final isFav = (existing?.isFavorite ?? false) ||
            favCache.isFavorite(song.id, song.uri) ||
            song.isFavorite;
        final playCount = existing != null && existing.playCount > song.playCount
            ? existing.playCount
            : song.playCount;
        final lastPlayedAt = existing?.lastPlayedAt ?? song.lastPlayedAt;
        final existingLyrics = existing?.lyrics;
        final lyrics = (song.lyrics != null && song.lyrics!.isNotEmpty) ? song.lyrics : existingLyrics;

        final merged = song.copyWith(
          isFavorite: isFav,
          playCount: playCount,
          lastPlayedAt: lastPlayedAt,
          lyrics: lyrics,
        );
        _memorySongs[song.id] = merged;
        if (isFav) {
          newlyFoundFavorites.add(merged);
        }
      }
      if (newlyFoundFavorites.isNotEmpty) {
        await favCache.syncFromList(newlyFoundFavorites);
      }
      return;
    }

    // Retrieve existing song states so user favorites, play stats & downloaded lyrics are NEVER wiped
    final existingRows = await _db!.rawQuery(
      'SELECT id, is_favorite, play_count, last_played_at, lyrics FROM songs',
    );
    final existingMap = <String, Map<String, dynamic>>{};
    for (final row in existingRows) {
      existingMap[row['id'] as String] = row;
    }

    final batch = _db!.batch();
    for (final song in songs) {
      final existing = existingMap[song.id];
      final isFav = (existing != null && (existing['is_favorite'] as int? ?? 0) == 1) ||
          favCache.isFavorite(song.id, song.uri) ||
          song.isFavorite;
      final playCount = (existing != null && (existing['play_count'] as int? ?? 0) > song.playCount)
          ? (existing['play_count'] as int)
          : song.playCount;
      final lastPlayedMs = existing != null && existing['last_played_at'] != null
          ? (existing['last_played_at'] as int)
          : song.lastPlayedAt?.millisecondsSinceEpoch;
      final existingLyrics = existing != null ? existing['lyrics'] as String? : null;
      final lyrics = (song.lyrics != null && song.lyrics!.isNotEmpty) ? song.lyrics : existingLyrics;

      final merged = song.copyWith(
        isFavorite: isFav,
        playCount: playCount,
        lastPlayedAt: lastPlayedMs != null ? DateTime.fromMillisecondsSinceEpoch(lastPlayedMs) : null,
        lyrics: lyrics,
      );

      _memorySongs[song.id] = merged;
      batch.insert('songs', merged.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      if (isFav) {
        newlyFoundFavorites.add(merged);
      }
    }
    await batch.commit(noResult: true);
    if (newlyFoundFavorites.isNotEmpty) {
      await favCache.syncFromList(newlyFoundFavorites);
    }
  }

  Future<void> updateSongLyrics(String songId, String lyrics) async {
    await init();
    if (_memorySongs.containsKey(songId)) {
      _memorySongs[songId] = _memorySongs[songId]!.copyWith(lyrics: lyrics);
    }
    if (_db != null) {
      await _db!.update(
        'songs',
        {'lyrics': lyrics},
        where: 'id = ?',
        whereArgs: [songId],
      );
    }
  }

  Future<void> toggleSongFavorite(String songId, [Song? songContext]) async {
    await init();
    final favCache = FavoritesCacheService.instance;

    Song? targetSong;
    if (_db != null) {
      final results = await _db!.query('songs', where: 'id = ?', whereArgs: [songId], limit: 1);
      if (results.isNotEmpty) {
        targetSong = Song.fromMap(results.first);
      }
    }
    targetSong ??= _memorySongs[songId] ?? songContext;

    if (targetSong != null) {
      final newFav = !targetSong.isFavorite;
      final updated = targetSong.copyWith(isFavorite: newFav);
      _memorySongs[songId] = updated;

      if (_db != null) {
        await _db!.insert('songs', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await favCache.saveFavorite(updated, newFav);
    } else {
      // Song record not found directly in catalog yet; toggle by ID in cache & DB
      final isFavNow = !favCache.isFavorite(songId);
      if (_db != null) {
        await _db!.rawUpdate(
          'UPDATE songs SET is_favorite = 1 - is_favorite WHERE id = ?',
          [songId],
        );
      }
      if (songContext != null) {
        final updated = songContext.copyWith(isFavorite: isFavNow);
        _memorySongs[songId] = updated;
        if (_db != null) {
          await _db!.insert('songs', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await favCache.saveFavorite(updated, isFavNow);
      }
    }
  }

  Future<void> toggleVideoFavorite(String videoId) async {
    await init();
    if (_db == null) {
      final video = _memoryVideos[videoId];
      if (video != null) {
        _memoryVideos[videoId] = video.copyWith(isFavorite: !video.isFavorite);
      }
      return;
    }

    await _db!.rawUpdate(
      'UPDATE videos SET is_favorite = 1 - is_favorite WHERE id = ?',
      [videoId],
    );
  }

  Future<List<Song>> getFavoriteSongs() async {
    await init();
    final favCache = FavoritesCacheService.instance;
    final cachedFavorites = favCache.getCachedFavoriteSongs();
    final songMap = <String, Song>{};

    for (final s in cachedFavorites) {
      songMap[s.id] = s.copyWith(isFavorite: true);
    }

    if (_db == null) {
      for (final s in _memorySongs.values) {
        if (s.isFavorite || favCache.isFavorite(s.id, s.uri)) {
          songMap[s.id] = s.copyWith(isFavorite: true);
        }
      }
      return songMap.values.toList();
    }

    final results = await _db!.query('songs', where: 'is_favorite = 1', orderBy: 'title ASC');
    for (final m in results) {
      final s = Song.fromMap(m);
      songMap[s.id] = s.copyWith(isFavorite: true);
    }

    // Also check memory for any runtime favorited songs not yet in sqlite query
    for (final s in _memorySongs.values) {
      if (s.isFavorite || favCache.isFavorite(s.id, s.uri)) {
        songMap[s.id] = s.copyWith(isFavorite: true);
      }
    }

    return songMap.values.toList();
  }

  Future<void> updateSongPlayCount(String songId) async {
    await init();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_db == null) {
      final song = _memorySongs[songId];
      if (song != null) {
        _memorySongs[songId] = song.copyWith(
          playCount: song.playCount + 1,
          lastPlayedAt: DateTime.now(),
        );
      }
      return;
    }

    await _db!.rawUpdate(
      'UPDATE songs SET play_count = play_count + 1, last_played_at = ? WHERE id = ?',
      [nowMs, songId],
    );
  }

  Future<List<Video>> getAllVideos() async {
    await init();
    if (_db == null) return _memoryVideos.values.toList();

    final results = await _db!.query('videos', orderBy: 'title ASC');
    return results.map((m) => Video.fromMap(m)).toList();
  }

  Future<Video?> getVideoById(String id) async {
    await init();
    if (_db == null) return _memoryVideos[id];

    final results = await _db!.query('videos', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Video.fromMap(results.first);
  }

  Future<void> insertVideos(List<Video> videos) async {
    await init();
    if (_db == null) {
      for (final video in videos) {
        final existing = _memoryVideos[video.id];
        final isFav = existing?.isFavorite ?? video.isFavorite;
        final lastPos = existing != null && existing.lastPosition.inMilliseconds > 0
            ? existing.lastPosition
            : video.lastPosition;
        _memoryVideos[video.id] = video.copyWith(
          isFavorite: isFav,
          lastPosition: lastPos,
          playbackSpeed: existing?.playbackSpeed ?? video.playbackSpeed,
          audioTrack: existing?.audioTrack ?? video.audioTrack,
          selectedSubtitle: existing?.selectedSubtitle ?? video.selectedSubtitle,
        );
      }
      return;
    }

    // Preserve existing video state so favorites and resume positions are never wiped
    final existingRows = await _db!.rawQuery(
      'SELECT id, is_favorite, last_position_ms, playback_speed, audio_track, selected_subtitle FROM videos',
    );
    final existingMap = <String, Map<String, dynamic>>{};
    for (final row in existingRows) {
      existingMap[row['id'] as String] = row;
    }

    final batch = _db!.batch();
    for (final video in videos) {
      final existing = existingMap[video.id];
      final isFav = (existing != null && (existing['is_favorite'] as int? ?? 0) == 1) || video.isFavorite;
      final lastPosMs = existing != null && (existing['last_position_ms'] as int? ?? 0) > 0
          ? (existing['last_position_ms'] as int)
          : video.lastPosition.inMilliseconds;
      final speed = (existing != null && existing['playback_speed'] != null)
          ? (existing['playback_speed'] as num).toDouble()
          : video.playbackSpeed;
      final audioTrack = existing?['audio_track'] as String? ?? video.audioTrack;
      final subtitle = existing?['selected_subtitle'] as String? ?? video.selectedSubtitle;

      final merged = video.copyWith(
        isFavorite: isFav,
        lastPosition: Duration(milliseconds: lastPosMs),
        playbackSpeed: speed,
        audioTrack: audioTrack,
        selectedSubtitle: subtitle,
      );

      _memoryVideos[video.id] = merged;
      batch.insert('videos', merged.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateVideoPosition(String videoId, Duration position) async {
    await init();
    if (_db == null) {
      final video = _memoryVideos[videoId];
      if (video != null) {
        _memoryVideos[videoId] = video.copyWith(lastPosition: position);
      }
      return;
    }

    await _db!.rawUpdate(
      'UPDATE videos SET last_position_ms = ? WHERE id = ?',
      [position.inMilliseconds, videoId],
    );
  }

  Future<List<Playlist>> getAllPlaylists() async {
    await init();
    final favSongs = await getFavoriteSongs();
    final favTotalMs = favSongs.fold<int>(0, (sum, s) => sum + s.duration.inMilliseconds);
    final favPlaylist = Playlist(
      id: 'pl-favorites',
      title: 'Favorites',
      description: 'Your favorite tracks in one place',
      coverArtUri: favSongs.isNotEmpty ? favSongs.first.artworkUri : null,
      iconName: 'favorite',
      songCount: favSongs.length,
      totalDuration: Duration(milliseconds: favTotalMs),
      dateCreated: DateTime.now(),
      dateModified: DateTime.now(),
      isPinned: true,
      songIds: favSongs.map((s) => s.id).toList(),
    );

    if (_db == null) {
      final list = _memoryPlaylists.values.where((p) => p.id != 'pl-favorites').toList();
      return [favPlaylist, ...list];
    }

    final results = await _db!.query('playlists', where: 'id != ?', whereArgs: ['pl-favorites'], orderBy: 'title ASC');
    final dbPlaylists = results.map((m) => Playlist.fromMap(m)).toList();
    return [favPlaylist, ...dbPlaylists];
  }

  Future<Playlist?> getPlaylistById(String id) async {
    await init();
    if (id == 'pl-favorites') {
      final favSongs = await getFavoriteSongs();
      final totalMs = favSongs.fold<int>(0, (sum, s) => sum + s.duration.inMilliseconds);
      return Playlist(
        id: 'pl-favorites',
        title: 'Favorites',
        description: 'Your favorite tracks in one place',
        coverArtUri: favSongs.isNotEmpty ? favSongs.first.artworkUri : null,
        iconName: 'favorite',
        songCount: favSongs.length,
        totalDuration: Duration(milliseconds: totalMs),
        dateCreated: DateTime.now(),
        dateModified: DateTime.now(),
        isPinned: true,
        songIds: favSongs.map((s) => s.id).toList(),
      );
    }
    if (_db == null) return _memoryPlaylists[id];

    final results = await _db!.query('playlists', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Playlist.fromMap(results.first);
  }

  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    await init();
    if (playlistId == 'pl-favorites') {
      return await getFavoriteSongs();
    }
    if (_db == null) {
      final songIds = _memoryPlaylistSongs[playlistId] ?? [];
      return songIds.map((id) => _memorySongs[id]).whereType<Song>().toList();
    }

    final results = await _db!.rawQuery('''
      SELECT s.* FROM songs s
      INNER JOIN playlist_songs ps ON s.id = ps.song_id
      WHERE ps.playlist_id = ?
      ORDER BY ps.sort_order ASC
    ''', [playlistId]);

    return results.map((m) => Song.fromMap(m)).toList();
  }

  Future<void> createPlaylist(Playlist playlist) async {
    await init();
    if (_db == null) {
      _memoryPlaylists[playlist.id] = playlist;
      _memoryPlaylistSongs[playlist.id] = [];
      return;
    }

    await _db!.insert('playlists', playlist.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePlaylist(String id) async {
    await init();
    if (_db == null) {
      _memoryPlaylists.remove(id);
      _memoryPlaylistSongs.remove(id);
      return;
    }

    await _db!.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await _db!.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await init();
    if (_db == null) {
      _memoryPlaylistSongs.putIfAbsent(playlistId, () => []).add(songId);
      return;
    }

    final countResult = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    await _db!.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_id': songId,
      'sort_order': count,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await init();
    if (_db == null) {
      _memoryPlaylistSongs[playlistId]?.remove(songId);
      return;
    }

    await _db!.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
  }

  Future<void> clearAllData() async {
    await init();
    if (_db != null) {
      await _db!.delete('songs');
      await _db!.delete('videos');
    }
    _memorySongs.clear();
    _memoryVideos.clear();
  }
}
