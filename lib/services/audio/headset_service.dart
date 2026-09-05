import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_player_service.dart';

import 'package:flutter/services.dart';

class HeadsetService {
  static final HeadsetService instance = HeadsetService._internal();
  HeadsetService._internal();

  static const String _keyPauseOnDisconnect = 'setting_pause_on_headset_disconnect';
  static const MethodChannel _headsetChannel = MethodChannel('com.dagi.dagiplayer/headset');

  AudioPlayerService? _audioService;
  AudioSession? _session;
  StreamSubscription<void>? _becomingNoisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  bool _pauseOnDisconnect = true;
  bool get pauseOnDisconnect => _pauseOnDisconnect;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init(AudioPlayerService audioService, [SharedPreferences? testPrefs]) async {
    _audioService = audioService;
    if (_isInitialized && testPrefs == null) return;

    try {
      final prefs = testPrefs ?? await SharedPreferences.getInstance();
      _pauseOnDisconnect = prefs.getBool(_keyPauseOnDisconnect) ?? true;

      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration.music());

      // 1. Listen for Earphones Unplugged / Bluetooth Disconnected ("Becoming Noisy")
      _becomingNoisySub?.cancel();
      _becomingNoisySub = _session!.becomingNoisyEventStream.listen((_) {
        debugPrint('🎧 Earphone disconnected / Becoming noisy detected');
        if (_pauseOnDisconnect && _audioService != null) {
          if (_audioService!.state.isPlaying) {
            debugPrint('🎧 Pausing music due to earphone disconnect');
            _audioService!.pause();
          }
        }
      });

      // 2. Listen for System Audio Interruptions (Phone Calls, Alarms)
      _interruptionSub?.cancel();
      _interruptionSub = _session!.interruptionEventStream.listen((event) {
        if (event.begin) {
          debugPrint('📞 Audio interruption began: ${event.type}');
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Lower volume or pause
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_audioService != null && _audioService!.state.isPlaying) {
                _audioService!.pause();
              }
              break;
          }
        } else {
          debugPrint('📞 Audio interruption ended: ${event.type}');
          // Stay paused or resume clean state without sudden bursts
        }
      });

      // 3. Listen for Hardware Earphone & Bluetooth Media Buttons
      _headsetChannel.setMethodCallHandler((call) async {
        if (call.method == 'onMediaButton') {
          final action = (call.arguments is Map)
              ? (call.arguments['action'] as String? ?? 'toggle')
              : 'toggle';
          debugPrint('🎧 Headset hardware media button pressed: $action');
          await handleMediaButtonAction(action);
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('HeadsetService initialization error: $e');
    }
  }

  Future<void> handleMediaButtonAction(String action) async {
    if (_audioService == null) return;
    switch (action) {
      case 'stop':
      case 'pause':
        await _audioService!.pause();
        break;
      case 'play':
        await _audioService!.play();
        break;
      case 'next':
        await _audioService!.next();
        break;
      case 'previous':
        await _audioService!.previous();
        break;
      case 'toggle':
      default:
        await _audioService!.togglePlayPause();
        break;
    }
  }

  Future<void> setPauseOnDisconnect(bool value) async {
    _pauseOnDisconnect = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPauseOnDisconnect, value);
    } catch (e) {
      debugPrint('Error saving pauseOnDisconnect setting: $e');
    }
  }

  void handleEarphoneDisconnectManual() {
    if (_pauseOnDisconnect && _audioService != null && _audioService!.state.isPlaying) {
      _audioService!.pause();
    }
  }

  void dispose() {
    _becomingNoisySub?.cancel();
    _interruptionSub?.cancel();
    _isInitialized = false;
  }
}
