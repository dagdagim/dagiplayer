import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/song.dart';

class FavoritesCacheService {
  static final FavoritesCacheService instance = FavoritesCacheService._internal();
  FavoritesCacheService._internal();

  static const String _keyFavoriteIds = 'cached_favorite_song_ids';
  static const String _keyFavoriteUris = 'cached_favorite_song_uris';
  static const String _keyFavoriteSongsJson = 'cached_favorite_songs_meta';

  SharedPreferences? _prefs;
  final Set<String> _favoriteIds = {};
  final Set<String> _favoriteUris = {};
  final Map<String, Song> _cachedSongs = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Set<String> get favoriteUris => Set.unmodifiable(_favoriteUris);

  Future<void> init([SharedPreferences? prefs]) async {
    if (_isInitialized && prefs == null) return;
    try {
      _prefs = prefs ?? await SharedPreferences.getInstance();
      final ids = _prefs!.getStringList(_keyFavoriteIds) ?? [];
      final uris = _prefs!.getStringList(_keyFavoriteUris) ?? [];
      _favoriteIds
        ..clear()
        ..addAll(ids);
      _favoriteUris
        ..clear()
        ..addAll(uris);

      final songsJson = _prefs!.getString(_keyFavoriteSongsJson);
      if (songsJson != null && songsJson.isNotEmpty) {
        final decoded = jsonDecode(songsJson) as List<dynamic>;
        _cachedSongs.clear();
        for (final item in decoded) {
          try {
            final song = Song.fromMap(item as Map<String, dynamic>);
            _cachedSongs[song.id] = song.copyWith(isFavorite: true);
            _favoriteIds.add(song.id);
            if (song.uri.isNotEmpty) {
              _favoriteUris.add(song.uri);
            }
          } catch (e) {
            debugPrint('Error restoring cached favorite song: $e');
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('FavoritesCacheService initialization error: $e');
    }
  }

  bool isFavorite(String id, [String? uri]) {
    if (_favoriteIds.contains(id)) return true;
    if (uri != null && uri.isNotEmpty && _favoriteUris.contains(uri)) return true;
    return false;
  }

  Future<void> saveFavorite(Song song, bool isFav) async {
    await init();
    if (isFav) {
      _favoriteIds.add(song.id);
      if (song.uri.isNotEmpty) {
        _favoriteUris.add(song.uri);
      }
      _cachedSongs[song.id] = song.copyWith(isFavorite: true);
    } else {
      _favoriteIds.remove(song.id);
      if (song.uri.isNotEmpty) {
        _favoriteUris.remove(song.uri);
      }
      _cachedSongs.remove(song.id);
    }
    await _persist();
  }

  Future<void> syncFromList(List<Song> favoriteSongs) async {
    await init();
    for (final song in favoriteSongs) {
      if (song.isFavorite) {
        _favoriteIds.add(song.id);
        if (song.uri.isNotEmpty) {
          _favoriteUris.add(song.uri);
        }
        _cachedSongs[song.id] = song.copyWith(isFavorite: true);
      }
    }
    await _persist();
  }

  List<Song> getCachedFavoriteSongs() {
    return _cachedSongs.values.toList();
  }

  Future<void> _persist() async {
    if (_prefs == null) return;
    try {
      await _prefs!.setStringList(_keyFavoriteIds, _favoriteIds.toList());
      await _prefs!.setStringList(_keyFavoriteUris, _favoriteUris.toList());
      final serializedList = _cachedSongs.values.map((s) => s.toMap()).toList();
      await _prefs!.setString(_keyFavoriteSongsJson, jsonEncode(serializedList));
    } catch (e) {
      debugPrint('Error persisting favorites cache: $e');
    }
  }
}
