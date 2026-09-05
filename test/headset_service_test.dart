import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dagiplayer/domain/entities/song.dart';
import 'package:dagiplayer/services/audio/audio_player_service.dart';
import 'package:dagiplayer/services/audio/audio_player_handler.dart';
import 'package:dagiplayer/services/audio/headset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HeadsetService & Earphone Stop Tests', () {
    late AudioPlayerService audioService;
    late HeadsetService headsetService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      audioService = AudioPlayerService();
      headsetService = HeadsetService.instance;
    });

    tearDown(() async {
      await audioService.dispose();
      headsetService.dispose();
    });

    test('HeadsetService defaults to pauseOnDisconnect = true and allows changing preference', () async {
      final prefs = await SharedPreferences.getInstance();
      await headsetService.init(audioService, prefs);

      expect(headsetService.pauseOnDisconnect, true);

      await headsetService.setPauseOnDisconnect(false);
      expect(headsetService.pauseOnDisconnect, false);

      await headsetService.setPauseOnDisconnect(true);
      expect(headsetService.pauseOnDisconnect, true);
    });

    test('Earphone disconnect event stops/pauses active music playback', () async {
      final prefs = await SharedPreferences.getInstance();
      await headsetService.init(audioService, prefs);

      final testSong = Song(
        id: 'headset-test-song-1',
        title: 'Headset Test Track',
        artist: 'Test Artist',
        duration: const Duration(minutes: 3),
        uri: 'https://example.com/test.mp3',
        dateAdded: DateTime.now(),
      );

      // Set playback state to playing
      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
      ));
      expect(audioService.state.isPlaying, true);

      // Trigger earphone disconnect
      headsetService.handleEarphoneDisconnectManual();

      // Verify music paused
      expect(audioService.state.isPlaying, false);
    });

    test('Hardware headset media button stop and toggle actions work properly', () async {
      final prefs = await SharedPreferences.getInstance();
      await headsetService.init(audioService, prefs);

      final testSong = Song(
        id: 'headset-btn-test-1',
        title: 'Hardware Button Track',
        artist: 'Artist',
        duration: const Duration(minutes: 3),
        uri: 'https://example.com/test.mp3',
        dateAdded: DateTime.now(),
      );

      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
      ));
      expect(audioService.state.isPlaying, true);

      // User presses earphone hardware button to stop
      await headsetService.handleMediaButtonAction('stop');
      expect(audioService.state.isPlaying, false);

      // User presses earphone button to toggle (resumes playback)
      await headsetService.handleMediaButtonAction('toggle');
      expect(audioService.state.isPlaying, true);

      // User presses earphone button to toggle again (pauses playback)
      await headsetService.handleMediaButtonAction('toggle');
      expect(audioService.state.isPlaying, false);
    });
  });

  group('DagiAudioHandler MediaButton Earphone Control Tests', () {
    late AudioPlayerService audioService;
    late DagiAudioHandler handler;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      audioService = AudioPlayerService();
      handler = DagiAudioHandler(audioService);
    });

    tearDown(() async {
      await audioService.dispose();
      handler.dispose();
    });

    test('Single click on earphone media button toggles play and pause', () async {
      final testSong = Song(
        id: 'earphone-btn-song-1',
        title: 'Earphone Button Song',
        artist: 'Artist',
        duration: const Duration(minutes: 3),
        uri: 'https://example.com/test.mp3',
        dateAdded: DateTime.now(),
      );

      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
      ));
      expect(audioService.state.isPlaying, true);

      // User presses earphone button to stop/pause music
      await handler.click(MediaButton.media);
      expect(audioService.state.isPlaying, false);

      // User presses earphone button again to resume music
      await handler.click(MediaButton.media);
      expect(audioService.state.isPlaying, true);
    });

    test('Earphone stop action halts audio playback and rewinds to start', () async {
      final testSong = Song(
        id: 'earphone-stop-song-1',
        title: 'Earphone Stop Song',
        artist: 'Artist',
        duration: const Duration(minutes: 3),
        uri: 'https://example.com/test.mp3',
        dateAdded: DateTime.now(),
      );

      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
        position: const Duration(seconds: 45),
      ));
      expect(audioService.state.isPlaying, true);
      expect(audioService.state.position.inSeconds, 45);

      // User stops playback via earphone
      await handler.stop();
      expect(audioService.state.isPlaying, false);
      expect(audioService.state.position, Duration.zero);
    });
  });
}
