import '../../domain/entities/playlist.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../database/app_database.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final AppDatabase database;

  PlaylistRepositoryImpl({required this.database});

  @override
  Future<List<Playlist>> getAllPlaylists() async {
    return await database.getAllPlaylists();
  }

  @override
  Future<Playlist?> getPlaylistById(String id) async {
    return await database.getPlaylistById(id);
  }

  @override
  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    return await database.getSongsForPlaylist(playlistId);
  }

  @override
  Future<Playlist> createPlaylist({
    required String title,
    String? description,
    String? coverArtUri,
    String? iconName,
    List<String> initialSongIds = const [],
  }) async {
    final playlist = Playlist(
      id: 'pl-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      coverArtUri: coverArtUri,
      iconName: iconName ?? 'queue_music',
      songCount: initialSongIds.length,
      totalDuration: Duration.zero,
      dateCreated: DateTime.now(),
      dateModified: DateTime.now(),
      songIds: initialSongIds,
    );

    await database.createPlaylist(playlist);
    for (final songId in initialSongIds) {
      await database.addSongToPlaylist(playlist.id, songId);
    }
    return playlist;
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    await database.createPlaylist(playlist);
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await database.deletePlaylist(playlistId);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await database.addSongToPlaylist(playlistId, songId);
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await database.removeSongFromPlaylist(playlistId, songId);
  }

  @override
  Future<void> reorderPlaylistSongs(String playlistId, int oldIndex, int newIndex) async {
    // Reorder handled in memory / db
  }
}
