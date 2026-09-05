import 'package:flutter_test/flutter_test.dart';
import 'package:dagiplayer/core/utils/formatters.dart';
import 'package:dagiplayer/domain/entities/song.dart';
import 'package:dagiplayer/domain/entities/equalizer_settings.dart';
import 'package:dagiplayer/data/datasources/mock_initial_catalog.dart';

void main() {
  group('DagiPlayer Formatters Tests', () {
    test('formatDuration formats seconds and minutes correctly', () {
      expect(Formatters.formatDuration(const Duration(seconds: 45)), '0:45');
      expect(Formatters.formatDuration(const Duration(minutes: 3, seconds: 20)), '3:20');
      expect(Formatters.formatDuration(const Duration(hours: 1, minutes: 12, seconds: 5)), '1:12:05');
      expect(Formatters.formatDuration(null), '0:00');
    });

    test('formatDurationLong formats hours and minutes correctly', () {
      expect(Formatters.formatDurationLong(const Duration(hours: 1, minutes: 32)), '1h 32m');
      expect(Formatters.formatDurationLong(const Duration(minutes: 45)), '45m');
      expect(Formatters.formatDurationLong(Duration.zero), '0m');
    });

    test('formatFileSize formats bytes to KB and MB', () {
      expect(Formatters.formatFileSize(500), '500 B');
      expect(Formatters.formatFileSize(1024 * 500), '500.0 KB');
      expect(Formatters.formatFileSize(1024 * 1024 * 8), '8.0 MB');
    });
  });

  group('DagiPlayer Domain & Catalog Tests', () {
    test('Song entity serialization and copyWith works properly', () {
      final song = Song(
        id: 'test-1',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 50),
        uri: 'https://example.com/audio.mp3',
        dateAdded: DateTime(2024, 1, 1),
      );

      final copy = song.copyWith(isFavorite: true);
      expect(copy.isFavorite, true);
      expect(copy.title, 'Starboy');

      final map = song.toMap();
      expect(map['title'], 'Starboy');
      expect(map['artist'], 'The Weeknd');
    });

    test('MockInitialCatalog contains rich initial items matching mockups', () {
      expect(MockInitialCatalog.initialSongs.isNotEmpty, true);
      expect(MockInitialCatalog.initialPlaylists.isNotEmpty, true);

      final firstSong = MockInitialCatalog.initialSongs.first;
      expect(firstSong.title, 'Starboy');
      expect(firstSong.artist, contains('The Weeknd'));
    });

    test('Equalizer default presets include standard audio curves', () {
      final presets = EqualizerPreset.defaultPresets;
      expect(presets.any((p) => p.name == 'Rock'), true);
      expect(presets.any((p) => p.name == 'Pop'), true);
      expect(presets.any((p) => p.name == 'Jazz'), true);
    });
  });
}
