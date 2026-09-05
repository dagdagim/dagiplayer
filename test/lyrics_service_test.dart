import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dagiplayer/domain/entities/song.dart';
import 'package:dagiplayer/services/lyrics/online_lyrics_service.dart';
import 'package:dagiplayer/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnlineLyricsService Title and Artist Normalization Tests', () {
    test('cleanTitle strips track numbers, video tags, audio tags, and extensions', () {
      expect(
        OnlineLyricsService.cleanTitle('01 - Blinding Lights (Official Music Video)'),
        'Blinding Lights',
      );
      expect(
        OnlineLyricsService.cleanTitle('Starboy (feat. Daft Punk) [1080p].mp3'),
        'Starboy',
      );
      expect(
        OnlineLyricsService.cleanTitle('Someone Like You (Remastered 2021)'),
        'Someone Like You',
      );
      expect(
        OnlineLyricsService.cleanTitle('04. Shape of You [Official Audio]'),
        'Shape of You',
      );
      expect(
        OnlineLyricsService.cleanTitle('Stay (Live at the Forum)'),
        'Stay',
      );
      expect(
        OnlineLyricsService.cleanTitle('Simple Song'),
        'Simple Song',
      );
    });

    test('cleanArtist strips featured artists for query matching', () {
      expect(
        OnlineLyricsService.cleanArtist('Ed Sheeran feat. Stormzy'),
        'Ed Sheeran',
      );
      expect(
        OnlineLyricsService.cleanArtist('The Weeknd ft. Daft Punk'),
        'The Weeknd',
      );
      expect(
        OnlineLyricsService.cleanArtist('Coldplay & BTS'),
        'Coldplay',
      );
      expect(
        OnlineLyricsService.cleanArtist('Adele'),
        'Adele',
      );
    });
  });

  group('LRC Parser and Synced Playback Synchronization Tests', () {
    test('parses synced LRC timestamps and sorts lines chronologically', () {
      const rawLrc = '''
[00:05.50] First line of song
[00:12.30] Second line of song
[00:02.10] Intro music
[00:25.80] Third line of song
''';

      final parsed = OnlineLyricsService.parseLyrics(rawLrc);

      expect(parsed.isSynced, true);
      expect(parsed.lines.length, 4);

      // Verify sorted order
      expect(parsed.lines[0].text, 'Intro music');
      expect(parsed.lines[0].timestamp, const Duration(seconds: 2, milliseconds: 100));

      expect(parsed.lines[1].text, 'First line of song');
      expect(parsed.lines[1].timestamp, const Duration(seconds: 5, milliseconds: 500));

      expect(parsed.lines[2].text, 'Second line of song');
      expect(parsed.lines[2].timestamp, const Duration(seconds: 12, milliseconds: 300));

      expect(parsed.lines[3].text, 'Third line of song');
      expect(parsed.lines[3].timestamp, const Duration(seconds: 25, milliseconds: 800));
    });

    test('getActiveIndex accurately tracks active singing line as audio position advances', () {
      const rawLrc = '''
[00:00.00] Line 0
[00:10.00] Line 1
[00:20.00] Line 2
[00:30.00] Line 3
''';
      final parsed = OnlineLyricsService.parseLyrics(rawLrc);

      // At position 0s -> Line 0
      expect(parsed.getActiveIndex(Duration.zero), 0);

      // At position 5s -> still Line 0
      expect(parsed.getActiveIndex(const Duration(seconds: 5)), 0);

      // At position 10s -> Line 1
      expect(parsed.getActiveIndex(const Duration(seconds: 10)), 1);

      // At position 18s -> Line 1
      expect(parsed.getActiveIndex(const Duration(seconds: 18)), 1);

      // At position 20s -> Line 2
      expect(parsed.getActiveIndex(const Duration(seconds: 20)), 2);

      // At position 45s (past last line) -> Line 3
      expect(parsed.getActiveIndex(const Duration(seconds: 45)), 3);
    });

    test('parses multi-timestamp LRC lines', () {
      const rawLrc = '''
[00:10.00][00:30.00] Chorus repeating
''';
      final parsed = OnlineLyricsService.parseLyrics(rawLrc);
      expect(parsed.isSynced, true);
      expect(parsed.lines.length, 2);
      expect(parsed.lines[0].timestamp, const Duration(seconds: 10));
      expect(parsed.lines[0].text, 'Chorus repeating');
      expect(parsed.lines[1].timestamp, const Duration(seconds: 30));
      expect(parsed.lines[1].text, 'Chorus repeating');
    });

    test('falls back gracefully to plain lyrics when no timestamps exist', () {
      const plain = '''
Verse 1
This is a plain lyric without timestamps.
Verse 2
Another lyric line.
''';
      final parsed = OnlineLyricsService.parseLyrics(plain);
      expect(parsed.isSynced, false);
      expect(parsed.lines.length, 4);
      expect(parsed.lines[0].text, 'Verse 1');
      expect(parsed.lines[1].text, 'This is a plain lyric without timestamps.');
    });
  });

  group('Database Lyrics Persistence Tests', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.instance;
    });

    test('updateSongLyrics persists lyrics and insertSongs preserves them during scans', () async {
      await db.init();

      final testSong = Song(
        id: 'lyrics-test-song-1',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 50),
        uri: 'file:///storage/emulated/0/Music/Starboy.mp3',
        dateAdded: DateTime.now(),
      );

      // 1. Initial insert
      await db.insertSongs([testSong]);

      // 2. Fetch lyrics online and update song
      const downloadedLrc = '[00:15.71] I\'m tryna put you in the worst mood, ah';
      await db.updateSongLyrics(testSong.id, downloadedLrc);

      final songsAfterLyrics = await db.getAllSongs();
      final songWithLyrics = songsAfterLyrics.firstWhere((s) => s.id == testSong.id);
      expect(songWithLyrics.lyrics, downloadedLrc);

      // 3. Re-scan media store (which does not have lyrics embedded in raw file)
      final scannedAgain = Song(
        id: 'lyrics-test-song-1',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 50),
        uri: 'file:///storage/emulated/0/Music/Starboy.mp3',
        dateAdded: DateTime.now(),
        lyrics: null, // scanner finds no embedded tag
      );

      await db.insertSongs([scannedAgain]);

      // 4. Verify downloaded lyrics were NOT wiped out by rescan
      final finalSongs = await db.getAllSongs();
      final finalSong = finalSongs.firstWhere((s) => s.id == testSong.id);
      expect(finalSong.lyrics, downloadedLrc);
    });
  });
}
