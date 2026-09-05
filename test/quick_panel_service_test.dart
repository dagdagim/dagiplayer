import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dagiplayer/domain/entities/song.dart';
import 'package:dagiplayer/services/audio/audio_player_service.dart';
import 'package:dagiplayer/services/audio/quick_panel_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickPanelService Tests', () {
    late AudioPlayerService audioService;
    late QuickPanelService quickPanelService;
    late List<MethodCall> channelCalls;
    const testChannel = MethodChannel('com.dagi.dagiplayer/media_notification');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      audioService = AudioPlayerService();
      quickPanelService = QuickPanelService.instance;
      channelCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (MethodCall call) async {
        channelCalls.add(call);
        return true;
      });
    });

    tearDown(() async {
      await audioService.dispose();
      quickPanelService.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
    });

    test('Syncs track metadata to Quick Panel notification when playing a song', () async {
      await quickPanelService.init(audioService, testChannel);

      final testSong = Song(
        id: 'quick-panel-song-1',
        title: 'Quick Panel Track',
        artist: 'Quick Artist',
        album: 'Quick Album',
        duration: const Duration(minutes: 4),
        uri: 'https://example.com/audio.mp3',
        dateAdded: DateTime.now(),
      );

      channelCalls.clear();

      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 4),
      ));

      // Wait for async artwork and stream delivery
      await Future.delayed(const Duration(milliseconds: 50));

      expect(channelCalls.any((call) => call.method == 'updateNotification'), isTrue);
      final updateCall = channelCalls.lastWhere((call) => call.method == 'updateNotification');
      expect(updateCall.arguments['title'], 'Quick Panel Track');
      expect(updateCall.arguments['artist'], 'Quick Artist');
      expect(updateCall.arguments['album'], 'Quick Album');
      expect(updateCall.arguments['isPlaying'], true);
      expect(updateCall.arguments['positionMs'], 45000);
      expect(updateCall.arguments['durationMs'], 240000);
    });

    test('Sends hideNotification when song playback stops or is cleared', () async {
      await quickPanelService.init(audioService, testChannel);

      final testSong = Song(
        id: 'quick-panel-song-2',
        title: 'Stop Song',
        artist: 'Artist',
        duration: const Duration(minutes: 3),
        uri: 'https://example.com/audio2.mp3',
        dateAdded: DateTime.now(),
      );

      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
      ));
      await Future.delayed(Duration.zero);

      channelCalls.clear();

      // Clear current song
      audioService.updateStateForTesting(const AudioPlaybackState(
        isPlaying: false,
        currentSong: null,
      ));
      await Future.delayed(Duration.zero);

      expect(channelCalls.any((call) => call.method == 'hideNotification'), isTrue);
    });

    test('Quick Panel user interaction actions trigger AudioPlayerService methods', () async {
      await quickPanelService.init(audioService, testChannel);

      final testSong = Song(
        id: 'action-test-song',
        title: 'Action Track',
        artist: 'Artist',
        duration: const Duration(minutes: 3),
        uri: 'https://example.com/audio3.mp3',
        dateAdded: DateTime.now(),
      );

      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
      ));

      // 1. User presses Pause in Quick Panel
      await quickPanelService.handleAction('pause');
      expect(audioService.state.isPlaying, false);

      // 2. User presses Play in Quick Panel
      await quickPanelService.handleAction('play');
      expect(audioService.state.isPlaying, true);

      // 3. User toggles in Quick Panel
      await quickPanelService.handleAction('toggle');
      expect(audioService.state.isPlaying, false);

      // 4. User presses Stop in Quick Panel
      await quickPanelService.handleAction('stop');
      expect(audioService.state.isPlaying, false);
      expect(audioService.state.position, Duration.zero);
    });

    test('Suppresses redundant notification updates on natural 1-second ticks but syncs on seek', () async {
      await quickPanelService.init(audioService, testChannel);

      final testSong = Song(
        id: 'tick-test-song',
        title: 'Tick Track',
        artist: 'Artist',
        duration: const Duration(minutes: 5),
        uri: 'https://example.com/tick.mp3',
        dateAdded: DateTime.now(),
      );

      // Initial playback start triggers update
      channelCalls.clear();
      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
        position: const Duration(seconds: 10),
        duration: const Duration(minutes: 5),
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(channelCalls.any((c) => c.method == 'updateNotification'), isTrue);

      // Natural 1-second ticks (positions 11s, 12s, 13s) should NOT re-emit notification updates
      channelCalls.clear();
      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
        position: const Duration(seconds: 11),
        duration: const Duration(minutes: 5),
      ));
      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
        position: const Duration(seconds: 12),
        duration: const Duration(minutes: 5),
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(channelCalls.where((c) => c.method == 'updateNotification').isEmpty, isTrue);

      // User performs a manual seek (jumps to 180 seconds): MUST trigger updateNotification
      channelCalls.clear();
      audioService.updateStateForTesting(AudioPlaybackState(
        isPlaying: true,
        currentSong: testSong,
        position: const Duration(seconds: 180),
        duration: const Duration(minutes: 5),
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(channelCalls.any((c) => c.method == 'updateNotification'), isTrue);
      final seekCall = channelCalls.lastWhere((c) => c.method == 'updateNotification');
      expect(seekCall.arguments['positionMs'], 180000);
    });
  });
}
