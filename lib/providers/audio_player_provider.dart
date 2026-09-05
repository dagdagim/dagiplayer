import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../services/audio/audio_player_service.dart';
import 'database_provider.dart';

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService.instance;
});

class AudioPlayerNotifier extends StateNotifier<AudioPlaybackState> {
  final AudioPlayerService _service;
  final Ref _ref;

  AudioPlayerNotifier(this._service, this._ref) : super(_service.state) {
    _service.stateStream.listen((newState) {
      state = newState;
    });
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? index}) async {
    await _service.playSong(song, queue: queue, index: index);
    final mediaRepo = _ref.read(mediaRepositoryProvider);
    await mediaRepo.updateSongPlayCount(song.id);
  }

  Future<void> togglePlayPause() async {
    await _service.togglePlayPause();
  }

  Future<void> play() async {
    await _service.play();
  }

  Future<void> pause() async {
    await _service.pause();
  }

  Future<void> seek(Duration position) async {
    await _service.seek(position);
  }

  Future<void> next() async {
    await _service.next();
  }

  Future<void> previous() async {
    await _service.previous();
  }

  void toggleShuffle() {
    _service.toggleShuffle();
  }

  void toggleRepeat() {
    _service.toggleRepeat();
  }

  void toggleFavorite(String songId) {
    _service.toggleSongFavorite(songId);
  }

  void updateQueue(List<Song> queue, {int? newCurrentIndex}) {
    _service.updateQueue(queue, newCurrentIndex: newCurrentIndex);
  }

  void removeSongFromQueue(int index) {
    _service.removeSongFromQueue(index);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final currentList = List<Song>.from(state.queue);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, item);

    int newCurrentIndex = state.currentIndex;
    if (state.currentIndex == oldIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      newCurrentIndex -= 1;
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      newCurrentIndex += 1;
    }

    _service.updateQueue(currentList, newCurrentIndex: newCurrentIndex);
  }

  void setSleepTimer(Duration? duration) {
    _service.setSleepTimer(duration);
  }
}

final audioPlaybackNotifierProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlaybackState>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return AudioPlayerNotifier(service, ref);
});
