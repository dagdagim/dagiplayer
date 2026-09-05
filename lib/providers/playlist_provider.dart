import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import 'database_provider.dart';
import 'media_provider.dart';

final playlistRefreshTriggerProvider = StateProvider<int>((ref) => 0);

final allPlaylistsProvider = FutureProvider<List<Playlist>>((ref) async {
  ref.watch(playlistRefreshTriggerProvider);
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(playlistRepositoryProvider);
  return await repo.getAllPlaylists();
});

final playlistDetailProvider = FutureProvider.family<Playlist?, String>((ref, id) async {
  ref.watch(playlistRefreshTriggerProvider);
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(playlistRepositoryProvider);
  return await repo.getPlaylistById(id);
});

final playlistSongsProvider = FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  ref.watch(playlistRefreshTriggerProvider);
  ref.watch(mediaRefreshTriggerProvider);
  final repo = ref.watch(playlistRepositoryProvider);
  return await repo.getSongsForPlaylist(playlistId);
});

class PlaylistActionController {
  final Ref _ref;
  PlaylistActionController(this._ref);

  Future<Playlist> createPlaylist({
    required String title,
    String? description,
    String? coverArtUri,
    String? iconName,
    List<String> initialSongIds = const [],
  }) async {
    final repo = _ref.read(playlistRepositoryProvider);
    final pl = await repo.createPlaylist(
      title: title,
      description: description,
      coverArtUri: coverArtUri,
      iconName: iconName,
      initialSongIds: initialSongIds,
    );
    _ref.read(playlistRefreshTriggerProvider.notifier).state++;
    return pl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.deletePlaylist(playlistId);
    _ref.read(playlistRefreshTriggerProvider.notifier).state++;
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.addSongToPlaylist(playlistId, songId);
    _ref.read(playlistRefreshTriggerProvider.notifier).state++;
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final repo = _ref.read(playlistRepositoryProvider);
    await repo.removeSongFromPlaylist(playlistId, songId);
    _ref.read(playlistRefreshTriggerProvider.notifier).state++;
  }
}

final playlistActionControllerProvider = Provider<PlaylistActionController>((ref) {
  return PlaylistActionController(ref);
});
