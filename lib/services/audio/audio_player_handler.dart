import 'dart:async';
import 'package:audio_service/audio_service.dart';
import '../../domain/entities/song.dart';
import 'audio_player_service.dart';

/// AudioHandler integrating DagiPlayer with Android Media Session and Notification Shade controls.
class DagiAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final AudioPlayerService _audioService;
  StreamSubscription<AudioPlaybackState>? _stateSub;

  DagiAudioHandler(this._audioService) {
    _initBridge();
  }

  void _initBridge() {
    _stateSub = _audioService.stateStream.listen((state) {
      _syncPlaybackState(state);
      _syncMediaItem(state.currentSong);
      _syncQueue(state.queue);
    });

    // Initial sync
    _syncPlaybackState(_audioService.state);
    _syncMediaItem(_audioService.state.currentSong);
    _syncQueue(_audioService.state.queue);
  }

  void _syncMediaItem(Song? song) {
    if (song == null) {
      mediaItem.add(null);
      return;
    }

    Uri? artUri;
    if (song.artworkUri != null && song.artworkUri!.isNotEmpty) {
      if (song.artworkUri!.startsWith('http://') || song.artworkUri!.startsWith('https://')) {
        artUri = Uri.tryParse(song.artworkUri!);
      } else if (song.artworkUri!.startsWith('content://')) {
        artUri = Uri.tryParse(song.artworkUri!);
      } else {
        artUri = Uri.file(song.artworkUri!);
      }
    }

    mediaItem.add(MediaItem(
      id: song.id,
      album: song.album ?? 'DagiPlayer',
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: artUri,
      playable: true,
      extras: {
        'uri': song.uri,
        'isFavorite': song.isFavorite,
      },
    ));
  }

  void _syncPlaybackState(AudioPlaybackState state) {
    final isPlaying = state.isPlaying;
    final isBuffering = state.isBuffering;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: isBuffering
          ? AudioProcessingState.buffering
          : (state.currentSong != null ? AudioProcessingState.ready : AudioProcessingState.idle),
      playing: isPlaying,
      updatePosition: state.position,
      bufferedPosition: state.position,
      speed: state.playbackSpeed,
      queueIndex: state.currentIndex,
      repeatMode: switch (state.repeatMode) {
        RepeatMode.off => AudioServiceRepeatMode.none,
        RepeatMode.one => AudioServiceRepeatMode.one,
        RepeatMode.all => AudioServiceRepeatMode.all,
      },
      shuffleMode: state.isShuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
  }

  void _syncQueue(List<Song> songs) {
    queue.add(songs.map((s) => MediaItem(
      id: s.id,
      album: s.album ?? 'DagiPlayer',
      title: s.title,
      artist: s.artist,
      duration: s.duration,
    )).toList());
  }

  @override
  Future<void> play() => _audioService.play();

  @override
  Future<void> pause() => _audioService.pause();

  @override
  Future<void> stop() async {
    await _audioService.pause();
    await _audioService.seek(Duration.zero);
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) => _audioService.seek(position);

  @override
  Future<void> skipToNext() => _audioService.next();

  @override
  Future<void> skipToPrevious() => _audioService.previous();

  @override
  Future<void> skipToQueueItem(int index) async {
    final q = _audioService.state.queue;
    if (index >= 0 && index < q.length) {
      await _audioService.playSong(q[index], queue: q, index: index);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _audioService.toggleShuffle();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _audioService.toggleRepeat();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        if (_audioService.state.isPlaying) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await pause();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'stop') {
      await stop();
      return true;
    } else if (name == 'pause') {
      await pause();
      return true;
    }
    return super.customAction(name, extras);
  }

  void dispose() {
    _stateSub?.cancel();
  }
}
