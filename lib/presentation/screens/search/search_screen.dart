import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/search_provider.dart';
import '../../widgets/album_tile.dart';
import '../../widgets/artist_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_filter_chips.dart';
import '../../widgets/section_header.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/video_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    'All',
    'Songs',
    'Albums',
    'Artists',
    'Videos',
    'Playlists',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(searchCategoryFilterProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenPadding,
                AppDimensions.sm,
                AppDimensions.screenPadding,
                AppDimensions.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: AppDimensions.searchBarHeight,
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search music, videos, artists...',
                                hintStyle: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                ref.read(searchQueryProvider.notifier).state = val;
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).state = '';
                              },
                              child: Icon(
                                Icons.cancel_rounded,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),

            // Filter Chips
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
                child: MediaFilterChips(
                  categories: _categories,
                  selectedCategory: selectedCategory,
                  onSelected: (cat) {
                    ref.read(searchCategoryFilterProvider.notifier).state = cat;
                  },
                ),
              ),

            const Divider(height: 16),

            // Content: Recent searches or Search Results
            Expanded(
              child: query.isEmpty
                  ? _buildRecentSearches(recentSearches, isDark)
                  : _buildSearchResults(searchResultsAsync, selectedCategory),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(List<String> recent, bool isDark) {
    if (recent.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search your local library',
        description: 'Find songs, artists, albums, playlists and videos instantly.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPadding,
            vertical: AppDimensions.sm,
          ),
          child: Text(
            'Recent Searches',
            style: AppTypography.labelLarge.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: recent.length,
            itemBuilder: (context, index) {
              final term = recent[index];
              return ListTile(
                leading: const Icon(Icons.history_rounded, size: 20, color: AppColors.darkTextSecondary),
                title: Text(term, style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.north_west_rounded, size: 16, color: AppColors.darkTextSecondary),
                onTap: () {
                  _searchController.text = term;
                  ref.read(searchQueryProvider.notifier).state = term;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(AsyncValue<SearchResults> resultsAsync, String category) {
    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results found',
            description: 'Try searching with a different title, artist, or keyword.',
          );
        }

        final showSongs = (category == 'All' || category == 'Songs') && results.songs.isNotEmpty;
        final showAlbums = (category == 'All' || category == 'Albums') && results.albums.isNotEmpty;
        final showArtists = (category == 'All' || category == 'Artists') && results.artists.isNotEmpty;
        final showVideos = (category == 'All' || category == 'Videos') && results.videos.isNotEmpty;

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            // Songs Section
            if (showSongs) ...[
              SectionHeader(
                title: 'Songs',
                onSeeAll: () {
                  ref.read(searchCategoryFilterProvider.notifier).state = 'Songs';
                },
              ),
              ...results.songs.take(category == 'All' ? 4 : results.songs.length).map(
                    (s) => SongTile(song: s, playlistContext: results.songs),
                  ),
              const SizedBox(height: AppDimensions.sm),
            ],

            // Albums Section
            if (showAlbums) ...[
              SectionHeader(
                title: 'Albums',
                onSeeAll: () {
                  ref.read(searchCategoryFilterProvider.notifier).state = 'Albums';
                },
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                  itemCount: results.albums.length,
                  itemBuilder: (context, index) {
                    final album = results.albums[index];
                    return AlbumTile(
                      album: album,
                      onTap: () => context.push('/album/${album.id}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
            ],

            // Artists Section
            if (showArtists) ...[
              SectionHeader(
                title: 'Artists',
                onSeeAll: () {
                  ref.read(searchCategoryFilterProvider.notifier).state = 'Artists';
                },
              ),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                  itemCount: results.artists.length,
                  itemBuilder: (context, index) {
                    final artist = results.artists[index];
                    return ArtistTile(
                      artist: artist,
                      onTap: () => context.push('/artist/${artist.id}'),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
            ],

            // Videos Section
            if (showVideos) ...[
              SectionHeader(
                title: 'Videos',
                onSeeAll: () {
                  ref.read(searchCategoryFilterProvider.notifier).state = 'Videos';
                },
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                  itemCount: results.videos.length,
                  itemBuilder: (context, index) {
                    final video = results.videos[index];
                    return VideoCard(
                      video: video,
                      onTap: () => context.push('/video-player/${video.id}', extra: video),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
            ],

            const SizedBox(height: AppDimensions.xxxl),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
