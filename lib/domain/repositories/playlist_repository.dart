import '../entities/playlist.dart';
import '../entities/song.dart';

abstract class PlaylistRepository {
  Future<List<Playlist>> getAllPlaylists();
  Future<Playlist?> getPlaylistById(String id);
  Future<List<Song>> getSongsForPlaylist(String playlistId);
  Future<Playlist> createPlaylist({
    required String title,
    String? description,
    String? coverArtUri,
    String? iconName,
    List<String> initialSongIds = const [],
  });
  Future<void> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String playlistId);
  Future<void> addSongToPlaylist(String playlistId, String songId);
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
  Future<void> reorderPlaylistSongs(String playlistId, int oldIndex, int newIndex);
}
