import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/video.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import 'media_provider.dart';
import 'playlist_provider.dart';

class SearchResults {
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;
  final List<Video> videos;
  final List<Playlist> playlists;

  const SearchResults({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
    this.videos = const [],
    this.playlists = const [],
  });

  bool get isEmpty =>
      songs.isEmpty && albums.isEmpty && artists.isEmpty && videos.isEmpty && playlists.isEmpty;
}

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchCategoryFilterProvider = StateProvider<String>((ref) => 'All');

final recentSearchesProvider = StateProvider<List<String>>((ref) => [
      'The Weeknd',
      'Starboy',
      'The Mountains',
      'Chill Vibes',
      'Harry Styles',
    ]);

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const SearchResults();

  final allSongs = await ref.watch(allSongsProvider.future);
  final allAlbums = await ref.watch(allAlbumsProvider.future);
  final allArtists = await ref.watch(allArtistsProvider.future);
  final allVideos = await ref.watch(allVideosProvider.future);
  final allPlaylists = await ref.watch(allPlaylistsProvider.future);

  final matchingSongs = allSongs.where((s) {
    return s.title.toLowerCase().contains(query) ||
        s.artist.toLowerCase().contains(query) ||
        (s.album?.toLowerCase().contains(query) ?? false);
  }).toList();

  final matchingAlbums = allAlbums.where((a) {
    return a.title.toLowerCase().contains(query) || a.artist.toLowerCase().contains(query);
  }).toList();

  final matchingArtists = allArtists.where((a) {
    return a.name.toLowerCase().contains(query);
  }).toList();

  final matchingVideos = allVideos.where((v) {
    return v.title.toLowerCase().contains(query) || v.category.toLowerCase().contains(query);
  }).toList();

  final matchingPlaylists = allPlaylists.where((p) {
    return p.title.toLowerCase().contains(query) ||
        (p.description?.toLowerCase().contains(query) ?? false);
  }).toList();

  return SearchResults(
    songs: matchingSongs,
    albums: matchingAlbums,
    artists: matchingArtists,
    videos: matchingVideos,
    playlists: matchingPlaylists,
  );
});
