import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/song.dart';
import 'audio_player_service.dart';
import 'song_artwork_service.dart';

/// Service managing the Android Quick Settings / Quick Panel Media Player notification.
/// Keeps media controls, track metadata, and scrubber in sync with active playback.
class QuickPanelService {
  static final QuickPanelService instance = QuickPanelService._internal();
  QuickPanelService._internal();

  static const MethodChannel _defaultChannel =
      MethodChannel('com.dagi.dagiplayer/media_notification');

  late MethodChannel _channel;
  AudioPlayerService? _audioService;
  StreamSubscription<AudioPlaybackState>? _stateSub;

  String? _lastSongId;
  bool? _lastIsPlaying;
  int _lastPositionSeconds = -1;
  DateTime? _lastUpdateTime;
  Uint8List? _cachedArtwork;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init(
    AudioPlayerService audioService, [
    MethodChannel? customChannel,
  ]) async {
    _audioService = audioService;
    _channel = customChannel ?? _defaultChannel;

    if (_isInitialized && customChannel == null) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAction') {
        final action = call.arguments?['action'] as String? ?? 'toggle';
        final positionMs = call.arguments?['positionMs'] as int?;
        await handleAction(action, positionMs);
      }
    });

    _stateSub?.cancel();
    _stateSub = _audioService!.stateStream.listen((state) {
      _syncNotification(state);
    });

    // Initial sync
    _syncNotification(_audioService!.state);
    _isInitialized = true;
  }

  Future<void> _syncNotification(AudioPlaybackState state) async {
    final song = state.currentSong;
    if (song == null) {
      if (_lastSongId != null) {
        _lastSongId = null;
        _lastIsPlaying = null;
        _lastPositionSeconds = -1;
        _lastUpdateTime = null;
        _cachedArtwork = null;
        try {
          await _channel.invokeMethod('hideNotification');
        } catch (_) {}
      }
      return;
    }

    // Do not show notification if playback has not started yet on app launch
    if (!state.isPlaying && _lastSongId == null) {
      return;
    }

    final trackChanged = _lastSongId != song.id;
    final playStateChanged = _lastIsPlaying != state.isPlaying;
    final posSeconds = state.position.inSeconds;

    // Detect if the user explicitly seeked / jumped position.
    // Android MediaSession automatically smoothly advances the scrubber
    // during continuous 1x playback, so natural 1-second ticks must not re-post.
    bool positionSeeked = false;
    if (!trackChanged && !playStateChanged && _lastPositionSeconds >= 0 && _lastUpdateTime != null) {
      final elapsedSec = DateTime.now().difference(_lastUpdateTime!).inSeconds;
      final expectedPos = _lastPositionSeconds + (state.isPlaying ? elapsedSec : 0);
      if ((posSeconds - expectedPos).abs() >= 3) {
        positionSeeked = true;
      }
    }

    if (!trackChanged && !playStateChanged && !positionSeeked) {
      return;
    }

    _lastIsPlaying = state.isPlaying;
    _lastPositionSeconds = posSeconds;
    _lastUpdateTime = DateTime.now();

    // Only fetch artwork when track changes to optimize battery and memory
    Uint8List? artworkToSend;
    if (trackChanged) {
      _lastSongId = song.id;
      _cachedArtwork = await _getArtworkForSong(song);
      artworkToSend = _cachedArtwork;
    }

    try {
      final durationMs = state.duration.inMilliseconds > 0
          ? state.duration.inMilliseconds
          : song.duration.inMilliseconds;

      await _channel.invokeMethod('updateNotification', {
        'title': song.title,
        'artist': song.artist,
        'album': song.album ?? 'DagiPlayer',
        'isPlaying': state.isPlaying,
        'positionMs': state.position.inMilliseconds,
        'durationMs': durationMs,
        'artworkBytes': artworkToSend,
      });
    } catch (_) {}
  }

  Future<Uint8List?> _getArtworkForSong(Song song) async {
    try {
      return await SongArtworkService.instance.getArtwork(
        artworkUri: song.artworkUri,
        songUri: song.uri,
      );
    } catch (_) {
      return null;
    }
  }

  /// Handles incoming actions triggered from Android Quick Panel or Lockscreen
  Future<void> handleAction(String action, [int? positionMs]) async {
    if (_audioService == null) return;
    debugPrint('📱 Quick Panel action received: $action (pos: $positionMs)');

    switch (action) {
      case 'play':
        await _audioService!.play();
        break;
      case 'pause':
        await _audioService!.pause();
        break;
      case 'toggle':
        await _audioService!.togglePlayPause();
        break;
      case 'next':
        await _audioService!.next();
        break;
      case 'previous':
        await _audioService!.previous();
        break;
      case 'seek':
        if (positionMs != null) {
          await _audioService!.seek(Duration(milliseconds: positionMs));
        }
        break;
      case 'stop':
        await _audioService!.stop();
        break;
    }
  }

  void dispose() {
    _stateSub?.cancel();
    _lastSongId = null;
    _lastIsPlaying = null;
    _lastPositionSeconds = -1;
    _lastUpdateTime = null;
    _cachedArtwork = null;
    _isInitialized = false;
  }
}
