import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dagiplayer/domain/entities/song.dart';
import 'package:dagiplayer/data/datasources/favorites_cache_service.dart';
import 'package:dagiplayer/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesCacheService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and retrieves favorite song IDs and URIs', () async {
      final cache = FavoritesCacheService.instance;
      await cache.init();

      final song = Song(
        id: 'test-song-fav-1',
        title: 'Save Your Tears',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 35),
        uri: 'file:///storage/music/save_your_tears.mp3',
        dateAdded: DateTime.now(),
      );

      expect(cache.isFavorite(song.id, song.uri), false);

      await cache.saveFavorite(song, true);
      expect(cache.isFavorite(song.id, song.uri), true);
      expect(cache.isFavorite('non-existent'), false);

      final cachedList = cache.getCachedFavoriteSongs();
      expect(cachedList.length, 1);
      expect(cachedList.first.id, 'test-song-fav-1');
      expect(cachedList.first.isFavorite, true);

      // Verify un-favoriting
      await cache.saveFavorite(song, false);
      expect(cache.isFavorite(song.id, song.uri), false);
      expect(cache.getCachedFavoriteSongs().isEmpty, true);
    });

    test('reloads persisted favorites across fresh initialization', () async {
      SharedPreferences.setMockInitialValues({
        'cached_favorite_song_ids': ['persisted-1', 'persisted-2'],
        'cached_favorite_song_uris': ['file:///music/song1.mp3'],
      });

      final cache = FavoritesCacheService.instance;
      await cache.init(await SharedPreferences.getInstance());

      expect(cache.isFavorite('persisted-1'), true);
      expect(cache.isFavorite('other-id', 'file:///music/song1.mp3'), true);
      expect(cache.isFavorite('random-id'), false);
    });
  });

  group('AppDatabase Favorites Non-Destructive Preservation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('insertSongs does not wipe is_favorite when scanning discovers raw files', () async {
      final db = AppDatabase.instance;
      await db.init();

      final song = Song(
        id: 'song-scan-test-1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 20),
        uri: 'file:///storage/music/blinding_lights.mp3',
        dateAdded: DateTime.now(),
      );

      // Favorite the song initially
      await db.toggleSongFavorite(song.id, song);

      final favsAfterToggle = await db.getFavoriteSongs();
      expect(favsAfterToggle.any((s) => s.id == song.id), true);

      // Simulate a background device scan discovering the file afresh with isFavorite: false
      final rawScannedSong = Song(
        id: 'song-scan-test-1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 20),
        uri: 'file:///storage/music/blinding_lights.mp3',
        dateAdded: DateTime.now(),
        isFavorite: false, // scanner always returns false
      );

      await db.insertSongs([rawScannedSong]);

      // Verify that favorite status was preserved!
      final favsAfterScan = await db.getFavoriteSongs();
      expect(favsAfterScan.any((s) => s.id == song.id && s.isFavorite), true);
    });
  });
}
