import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service managing Picture-in-Picture (PiP) minimal floating mode.
class PipService {
  PipService._() {
    _initChannel();
  }
  static final PipService instance = PipService._();

  static const _channel = MethodChannel('com.dagi.dagiplayer/pip');

  final _pipStateController = StreamController<bool>.broadcast();
  Stream<bool> get pipStateStream => _pipStateController.stream;

  bool _isInPipMode = false;
  bool get isInPipMode => _isInPipMode;

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final inPip = call.arguments as bool? ?? false;
        _isInPipMode = inPip;
        _pipStateController.add(inPip);
      }
    });
  }

  /// Request entering PiP floating mode manually
  Future<bool> enterPip({int aspectRatioX = 16, int aspectRatioY = 9}) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('enterPip', {
        'aspectRatioX': aspectRatioX > 0 ? aspectRatioX : 16,
        'aspectRatioY': aspectRatioY > 0 ? aspectRatioY : 9,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('PipService enterPip error: $e');
      return false;
    }
  }

  /// Enable/disable auto-PiP when user presses Home or switches apps while video is playing
  Future<void> setAutoPip({
    required bool enabled,
    int aspectRatioX = 16,
    int aspectRatioY = 9,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setAutoPip', {
        'enabled': enabled,
        'aspectRatioX': aspectRatioX > 0 ? aspectRatioX : 16,
        'aspectRatioY': aspectRatioY > 0 ? aspectRatioY : 9,
      });
    } catch (e) {
      debugPrint('PipService setAutoPip error: $e');
    }
  }

  /// Check if device supports Picture-in-Picture
  Future<bool> isPipSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isPipSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
