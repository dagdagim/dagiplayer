import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/video.dart';
import '../../providers/audio_player_provider.dart';
import '../../routing/app_router.dart';

/// Service that handles external intents (e.g., when a user opens an audio or video file from File Manager)
class MediaIntentService {
  static const MethodChannel _channel = MethodChannel('com.dagi.dagiplayer/media_intent');

  static final MediaIntentService instance = MediaIntentService._();
  MediaIntentService._();

  WidgetRef? _ref;
  bool _initialized = false;

  void init(WidgetRef ref) {
    _ref = ref;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleNativeCall);
    _checkInitialMediaIntent();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onMediaIntentReceived') {
      final data = call.arguments;
      if (data is Map) {
        _handleMediaIntentData(Map<String, dynamic>.from(data));
      }
    }
  }

  Future<void> _checkInitialMediaIntent() async {
    try {
      final data = await _channel.invokeMethod<Map>('getInitialMediaIntent');
      if (data != null) {
        // Small delay to ensure the widget tree and router are fully mounted
        await Future.delayed(const Duration(milliseconds: 300));
        _handleMediaIntentData(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('Error getting initial media intent: $e');
    }
  }

  void _handleMediaIntentData(Map<String, dynamic> data) {
    final uri = data['uri'] as String?;
    final type = data['type'] as String? ?? 'audio';
    final title = data['title'] as String? ?? (type == 'video' ? 'External Video' : 'External Audio');

    if (uri == null || uri.isEmpty) return;

    if (type == 'video') {
      _playExternalVideo(uri, title);
    } else {
      _playExternalAudio(uri, title);
    }
  }

  void _playExternalAudio(String uri, String title) {
    final song = Song(
      id: 'ext-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: 'External Audio',
      album: 'Files',
      uri: uri,
      artworkUri: uri,
      duration: Duration.zero,
      fileSize: 0,
      dateAdded: DateTime.now(),
    );

    if (_ref != null) {
      _ref!.read(audioPlaybackNotifierProvider.notifier).playSong(
            song,
            queue: [song],
            index: 0,
          );
    }

    try {
      appRouter.push('/now-playing');
    } catch (e) {
      debugPrint('Error navigating to now playing: $e');
    }
  }

  void _playExternalVideo(String uri, String title) {
    final video = Video(
      id: 'ext-vid-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      uri: uri,
      thumbnailUri: uri,
      duration: Duration.zero,
      fileSize: 0,
      dateAdded: DateTime.now(),
    );

    try {
      appRouter.push('/video-player/${video.id}', extra: video);
    } catch (e) {
      debugPrint('Error navigating to video player: $e');
    }
  }
}
