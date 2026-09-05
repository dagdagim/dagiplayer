import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/song.dart';
import '../../data/datasources/favorites_cache_service.dart';

enum RepeatMode { off, one, all }

class AudioPlaybackState {
  final Song? currentSong;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final bool isShuffleEnabled;
  final RepeatMode repeatMode;
  final List<Song> queue;
  final int currentIndex;
  final Duration? sleepTimerRemaining;
  final double playbackSpeed;
  final double volume;

  const AudioPlaybackState({
    this.currentSong,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.queue = const [],
    this.currentIndex = -1,
    this.sleepTimerRemaining,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
  });

  AudioPlaybackState copyWith({
    Song? currentSong,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    bool? isShuffleEnabled,
    RepeatMode? repeatMode,
    List<Song>? queue,
    int? currentIndex,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
    double? playbackSpeed,
    double? volume,
  }) {
    return AudioPlaybackState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      sleepTimerRemaining: clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volume: volume ?? this.volume,
    );
  }
}

class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService();

  final AudioPlayer _player = AudioPlayer();
  final _stateController = StreamController<AudioPlaybackState>.broadcast();

  AudioPlaybackState _state = const AudioPlaybackState();
  AudioPlaybackState get state => _state;
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  Timer? _sleepTimer;
  Timer? _countdownTimer;
  Timer? _simulationTicker;
  bool _isUsingSimulation = false;
  bool _isPlayRequested = false;

  AudioPlayerService() {
    _initListeners();
  }

  void _updateState(AudioPlaybackState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  @visibleForTesting
  void updateStateForTesting(AudioPlaybackState newState) {
    _isUsingSimulation = true;
    _isPlayRequested = newState.isPlaying;
    _updateState(newState);
  }

  void _initListeners() {
    _player.playerStateStream.listen((playerState) {
      if (_isUsingSimulation) return;

      final isPlaying = _isPlayRequested && playerState.playing;
      final isBuffering = playerState.processingState == ProcessingState.buffering ||
          playerState.processingState == ProcessingState.loading;

      if (playerState.processingState == ProcessingState.completed) {
        _isPlayRequested = false;
        _onTrackCompleted();
      } else {
        _updateState(_state.copyWith(
          isPlaying: isPlaying,
          isBuffering: isBuffering,
        ));
      }
    });

    _player.positionStream.listen((pos) {
      if (_isUsingSimulation) return;
      if (!_isPlayRequested && !_state.isPlaying) return;
      _updateState(_state.copyWith(position: pos));
    });

    _player.durationStream.listen((dur) {
      if (_isUsingSimulation) return;
      if (dur != null) {
        _updateState(_state.copyWith(duration: dur));
      }
    });

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        AudioSession.instance.then((session) {
          session.becomingNoisyEventStream.listen((_) {
            pause();
          });
        });
      } catch (_) {}
    }
  }

  void _startSimulationTicker() {
    _simulationTicker?.cancel();
    if (!_isPlayRequested) return;

    _simulationTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlayRequested || !_state.isPlaying) {
        timer.cancel();
        return;
      }

      final current = _state.position;
      final maxDuration = _state.duration.inSeconds > 0
          ? _state.duration
          : (_state.currentSong?.duration ?? const Duration(minutes: 3, seconds: 30));

      final nextPos = current + const Duration(seconds: 1);
      if (nextPos >= maxDuration) {
        _onTrackCompleted();
      } else {
        _updateState(_state.copyWith(position: nextPos));
      }
    });
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    _isPlayRequested = true;
    final newQueue = queue ?? [song];
    final songIndex = index ?? newQueue.indexWhere((s) => s.id == song.id);
    final targetIndex = songIndex >= 0 ? songIndex : 0;

    _updateState(_state.copyWith(
      currentSong: song,
      queue: newQueue,
      currentIndex: targetIndex,
      isPlaying: true,
      isBuffering: true,
      position: Duration.zero,
      duration: song.duration,
    ));

    try {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music());
          await session.setActive(true);
        } catch (e) {
          debugPrint('AudioSession activation error: $e');
        }
      }

      if (song.uri.startsWith('http://') || song.uri.startsWith('https://')) {
        await _player.setUrl(song.uri);
      } else if (song.uri.startsWith('asset://') || song.uri.startsWith('assets/')) {
        await _player.setAsset(song.uri.replaceFirst('asset://', ''));
      } else if (song.uri.startsWith('content://')) {
        try {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri)));
        } catch (_) {
          final cleanPath = song.uri.replaceFirst('file://', '');
          if (cleanPath.isNotEmpty && !cleanPath.startsWith('content://') && File(cleanPath).existsSync()) {
            await _player.setFilePath(cleanPath);
          } else {
            rethrow;
          }
        }
      } else {
        final cleanPath = song.uri.replaceFirst('file://', '');
        final fileExists = cleanPath.isNotEmpty && !cleanPath.startsWith('content://') && File(cleanPath).existsSync();

        if (fileExists) {
          try {
            await _player.setFilePath(cleanPath);
          } catch (_) {
            if (song.id.startsWith('media-')) {
              final mediaId = song.id.replaceFirst('media-', '');
              final contentUri = 'content://media/external/audio/media/$mediaId';
              await _player.setAudioSource(AudioSource.uri(Uri.parse(contentUri)));
            } else {
              rethrow;
            }
          }
        } else if (song.id.startsWith('media-')) {
          final mediaId = song.id.replaceFirst('media-', '');
          final contentUri = 'content://media/external/audio/media/$mediaId';
          try {
            await _player.setAudioSource(AudioSource.uri(Uri.parse(contentUri)));
          } catch (_) {
            if (cleanPath.isNotEmpty) {
              await _player.setFilePath(cleanPath);
            } else {
              rethrow;
            }
          }
        } else {
          await _player.setFilePath(cleanPath);
        }
      }
      _isUsingSimulation = false;
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        await _player.play().timeout(const Duration(milliseconds: 300));
      } else {
        await _player.play();
      }

      // If user requested pause while track was buffering/preparing, pause immediately!
      if (!_isPlayRequested) {
        try {
          await _player.pause();
        } catch (_) {}
        _updateState(_state.copyWith(isPlaying: false, isBuffering: false));
        return;
      }

      _updateState(_state.copyWith(isPlaying: true, isBuffering: false));
      savePlaybackSession();
    } catch (e) {
      debugPrint('Audio playback fallback to simulation: $e');
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _isUsingSimulation = true;
        if (_isPlayRequested) {
          _startSimulationTicker();
        }
      }
      _updateState(_state.copyWith(isPlaying: _isPlayRequested, isBuffering: false));
      savePlaybackSession();
    }
  }

  Future<void> play() async {
    _isPlayRequested = true;
    _updateState(_state.copyWith(isPlaying: true));
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
      } catch (_) {}
    }
    if (_isUsingSimulation) {
      _startSimulationTicker();
    } else {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          await _player.play().timeout(const Duration(milliseconds: 300));
        } else {
          await _player.play();
        }
      } catch (e) {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          _isUsingSimulation = true;
          if (_isPlayRequested) {
            _startSimulationTicker();
          }
        } else {
          debugPrint('Audio playback play error: $e');
        }
      }
    }
    if (!_isPlayRequested) {
      try {
        await _player.pause();
      } catch (_) {}
      _updateState(_state.copyWith(isPlaying: false));
      return;
    }
    _updateState(_state.copyWith(isPlaying: true));
    savePlaybackSession();
  }

  Future<void> pause() async {
    _isPlayRequested = false;
    _simulationTicker?.cancel();
    _updateState(_state.copyWith(isPlaying: false, isBuffering: false));
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
      } catch (_) {}
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        await _player.pause().timeout(const Duration(milliseconds: 300));
      } else {
        await _player.pause();
      }
    } catch (_) {}
    _updateState(_state.copyWith(isPlaying: false, isBuffering: false));
    savePlaybackSession();
  }

  Future<void> stop() async {
    _isPlayRequested = false;
    _simulationTicker?.cancel();
    _updateState(_state.copyWith(isPlaying: false, isBuffering: false, position: Duration.zero));
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(false);
      } catch (_) {}
    }
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        await _player.stop().timeout(const Duration(milliseconds: 300));
      } else {
        await _player.stop();
        await _player.seek(Duration.zero);
      }
    } catch (_) {}
    _updateState(_state.copyWith(isPlaying: false, isBuffering: false, position: Duration.zero));
    savePlaybackSession();
  }

  Future<void> togglePlayPause() async {
    if (_state.isPlaying || _isPlayRequested) {
      await pause();
    } else {
      if (_state.currentSong != null) {
        await play();
      } else if (_state.queue.isNotEmpty) {
        await playSong(_state.queue.first, queue: _state.queue, index: 0);
      }
    }
  }

  Future<void> seek(Duration position) async {
    _updateState(_state.copyWith(position: position));
    if (!_isUsingSimulation) {
      try {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          await _player.seek(position).timeout(const Duration(milliseconds: 300));
        } else {
          await _player.seek(position);
        }
      } catch (_) {}
    }
  }

  Future<void> next() async {
    if (_state.queue.isEmpty) return;

    if (_state.isShuffleEnabled) {
      final nextIndex = (_state.currentIndex + 1) % _state.queue.length;
      await playSong(_state.queue[nextIndex], queue: _state.queue, index: nextIndex);
      return;
    }

    final nextIndex = _state.currentIndex + 1;
    if (nextIndex < _state.queue.length) {
      await playSong(_state.queue[nextIndex], queue: _state.queue, index: nextIndex);
    } else if (_state.repeatMode == RepeatMode.all) {
      await playSong(_state.queue.first, queue: _state.queue, index: 0);
    }
  }

  Future<void> previous() async {
    if (_state.queue.isEmpty) return;

    // If more than 3 seconds into track, restart current song
    if (_state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final prevIndex = _state.currentIndex - 1;
    if (prevIndex >= 0) {
      await playSong(_state.queue[prevIndex], queue: _state.queue, index: prevIndex);
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _updateState(_state.copyWith(isShuffleEnabled: !_state.isShuffleEnabled));
    savePlaybackSession();
  }

  void toggleRepeat() {
    final nextRepeat = switch (_state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _updateState(_state.copyWith(repeatMode: nextRepeat));
    savePlaybackSession();
  }

  void toggleSongFavorite(String songId) {
    final isCurrent = _state.currentSong != null && _state.currentSong!.id == songId;
    final currentSong = isCurrent
        ? _state.currentSong!.copyWith(isFavorite: !_state.currentSong!.isFavorite)
        : _state.currentSong;
    final updatedQueue = _state.queue.map((s) {
      if (s.id == songId) {
        return s.copyWith(isFavorite: !s.isFavorite);
      }
      return s;
    }).toList();
    _updateState(_state.copyWith(
      currentSong: currentSong,
      queue: updatedQueue,
    ));
    savePlaybackSession();
  }

  void updateQueue(List<Song> newQueue, {int? newCurrentIndex}) {
    _updateState(_state.copyWith(
      queue: newQueue,
      currentIndex: newCurrentIndex ?? _state.currentIndex,
    ));
    savePlaybackSession();
  }

  void removeSongFromQueue(int index) {
    if (index < 0 || index >= _state.queue.length) return;
    final updated = List<Song>.from(_state.queue)..removeAt(index);
    int newIndex = _state.currentIndex;
    if (index < _state.currentIndex) {
      newIndex--;
    } else if (index == _state.currentIndex && updated.isNotEmpty) {
      newIndex = newIndex >= updated.length ? updated.length - 1 : newIndex;
    }
    _updateState(_state.copyWith(queue: updated, currentIndex: newIndex));
    savePlaybackSession();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();

    if (duration == null) {
      _updateState(_state.copyWith(clearSleepTimer: true));
      return;
    }

    var remaining = duration;
    _updateState(_state.copyWith(sleepTimerRemaining: remaining));

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining = remaining - const Duration(seconds: 1);
      if (remaining.inSeconds <= 0) {
        timer.cancel();
        pause();
        _updateState(_state.copyWith(clearSleepTimer: true));
      } else {
        _updateState(_state.copyWith(sleepTimerRemaining: remaining));
      }
    });
  }

  void _onTrackCompleted() {
    if (_state.repeatMode == RepeatMode.one) {
      seek(Duration.zero);
      play();
    } else {
      next();
    }
  }

  // Playback Session Persistence Keys
  static const String _keySessionQueue = 'playback_session_queue_v1';
  static const String _keySessionCurrentId = 'playback_session_current_id';
  static const String _keySessionIndex = 'playback_session_index';
  static const String _keySessionPositionMs = 'playback_session_position_ms';
  static const String _keySessionShuffle = 'playback_session_shuffle';
  static const String _keySessionRepeat = 'playback_session_repeat';

  Future<void> savePlaybackSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_state.queue.isNotEmpty) {
        final queueJson = jsonEncode(_state.queue.map((s) => s.toMap()).toList());
        await prefs.setString(_keySessionQueue, queueJson);
      }
      if (_state.currentSong != null) {
        await prefs.setString(_keySessionCurrentId, _state.currentSong!.id);
      }
      await prefs.setInt(_keySessionIndex, _state.currentIndex);
      await prefs.setInt(_keySessionPositionMs, _state.position.inMilliseconds);
      await prefs.setBool(_keySessionShuffle, _state.isShuffleEnabled);
      await prefs.setString(_keySessionRepeat, _state.repeatMode.name);
    } catch (e) {
      debugPrint('Error saving playback session: $e');
    }
  }

  Future<bool> restoreLastSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_keySessionQueue);
      if (queueJson == null || queueJson.isEmpty) return false;

      final decoded = jsonDecode(queueJson) as List<dynamic>;
      if (decoded.isEmpty) return false;

      final favCache = FavoritesCacheService.instance;
      await favCache.init(prefs);

      final restoredQueue = decoded.map((item) {
        final song = Song.fromMap(item as Map<String, dynamic>);
        final isFav = song.isFavorite || favCache.isFavorite(song.id, song.uri);
        return song.copyWith(isFavorite: isFav);
      }).toList();

      final currentId = prefs.getString(_keySessionCurrentId);
      final index = prefs.getInt(_keySessionIndex) ?? 0;
      final posMs = prefs.getInt(_keySessionPositionMs) ?? 0;
      final shuffle = prefs.getBool(_keySessionShuffle) ?? false;
      final repeatStr = prefs.getString(_keySessionRepeat);
      final repeat = RepeatMode.values.firstWhere(
        (r) => r.name == repeatStr,
        orElse: () => RepeatMode.off,
      );

      final validIndex = (index >= 0 && index < restoredQueue.length)
          ? index
          : (currentId != null
              ? restoredQueue.indexWhere((s) => s.id == currentId).clamp(0, restoredQueue.length - 1)
              : 0);

      final currentSong = restoredQueue[validIndex];
      final pos = Duration(milliseconds: posMs);

      _updateState(_state.copyWith(
        queue: restoredQueue,
        currentSong: currentSong,
        currentIndex: validIndex,
        position: pos,
        duration: currentSong.duration,
        isPlaying: false,
        isShuffleEnabled: shuffle,
        repeatMode: repeat,
      ));

      // Pre-set audio player source without playing
      try {
        if (currentSong.uri.startsWith('http://') || currentSong.uri.startsWith('https://')) {
          await _player.setUrl(currentSong.uri);
        } else if (currentSong.uri.startsWith('asset://') || currentSong.uri.startsWith('assets/')) {
          await _player.setAsset(currentSong.uri.replaceFirst('asset://', ''));
        } else if (currentSong.uri.startsWith('content://')) {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(currentSong.uri)));
        } else {
          try {
            await _player.setFilePath(currentSong.uri.replaceFirst('file://', ''));
          } catch (_) {
            if (currentSong.id.startsWith('media-')) {
              final mediaId = currentSong.id.replaceFirst('media-', '');
              final contentUri = 'content://media/external/audio/media/$mediaId';
              await _player.setAudioSource(AudioSource.uri(Uri.parse(contentUri)));
            }
          }
        }
        if (pos.inMilliseconds > 0 && pos < currentSong.duration) {
          await _player.seek(pos);
        }
      } catch (e) {
        debugPrint('Pre-loading audio source error: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error restoring playback session: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _simulationTicker?.cancel();
    await _player.dispose();
    await _stateController.close();
  }
}
