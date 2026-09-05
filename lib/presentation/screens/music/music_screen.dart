import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/song.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/media_provider.dart';
import '../../../providers/permission_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../widgets/album_tile.dart';
import '../../widgets/artist_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/permission_onboarding_sheet.dart';
import '../../widgets/playlist_tile.dart';
import '../../widgets/song_tile.dart';

class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['Songs', 'Albums', 'Artists', 'Genres', 'Playlists'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _triggerMediaScan() async {
    final summary = await ref.read(permissionServiceProvider).checkPermissions();
    if (!mounted) return;

    if (!summary.canScanMedia) {
      PermissionOnboardingSheet.show(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning phone storage for music files...'),
          duration: Duration(seconds: 2),
        ),
      );
      final result = await ref.read(mediaActionControllerProvider).scanDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovered ${result.songs.length} songs & ${result.videos.length} videos.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSongsAsync = ref.watch(allSongsProvider);
    final allAlbumsAsync = ref.watch(allAlbumsProvider);
    final allArtistsAsync = ref.watch(allArtistsProvider);
    final allPlaylistsAsync = ref.watch(allPlaylistsProvider);
    final isScanning = ref.watch(isScanningMediaProvider);
    final scanStatus = ref.watch(scanProgressStatusProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Music',
                          style: AppTypography.displayLarge.copyWith(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (allSongsAsync.value?.isNotEmpty ?? false)
                          Text(
                            '${allSongsAsync.value!.length} audio tracks',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
                          onPressed: _triggerMediaScan,
                          tooltip: 'Scan Storage for Music',
                        ),
                        IconButton(
                          icon: const Icon(Icons.graphic_eq_rounded, color: AppColors.primary),
                          onPressed: () => context.push('/equalizer'),
                          tooltip: 'Equalizer',
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () => context.push('/search'),
                          tooltip: 'Search',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Live Media Scanner Banner (when scanning)
            if (isScanning)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.screenPadding,
                    vertical: AppDimensions.xs,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          scanStatus.isNotEmpty ? scanStatus : 'Scanning device storage for music...',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                labelStyle: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                unselectedLabelStyle: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w500),
                dividerColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1. Songs Tab
              _buildSongsTab(allSongsAsync, isDark),

              // 2. Albums Tab
              _buildAlbumsTab(allAlbumsAsync),

              // 3. Artists Tab
              _buildArtistsTab(allArtistsAsync),

              // 4. Genres Tab
              _buildGenresTab(allSongsAsync, isDark),

              // 5. Playlists Tab
              _buildPlaylistsTab(allPlaylistsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongsTab(AsyncValue<List<Song>> songsAsync, bool isDark) {
    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return EmptyState(
            icon: Icons.music_off_rounded,
            title: 'No Local Music Found Yet',
            description: 'Scan your device to find MP3, AAC, FLAC, and audio files stored on your phone.',
            actionLabel: 'Scan Device Music',
            onAction: _triggerMediaScan,
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Shuffle Play Action Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.md,
                ),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final shuffled = List<Song>.from(songs)..shuffle();
                      ref.read(audioPlaybackNotifierProvider.notifier).playSong(
                            shuffled.first,
                            queue: shuffled,
                            index: 0,
                          );
                    },
                    icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary, size: 18),
                    label: Text(
                      'Shuffle Play (${songs.length} tracks)',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = songs[index];
                  return SongTile(
                    song: song,
                    index: index,
                    playlistContext: songs,
                  );
                },
                childCount: songs.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.xxl),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error loading songs: $e')),
    );
  }

  Widget _buildAlbumsTab(AsyncValue<List<dynamic>> albumsAsync) {
    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return EmptyState(
            icon: Icons.album_outlined,
            title: 'No Albums Found',
            description: 'Scan your local storage to index music albums.',
            actionLabel: 'Scan Music',
            onAction: _triggerMediaScan,
          );
        }

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.76,
            crossAxisSpacing: AppDimensions.md,
            mainAxisSpacing: AppDimensions.md,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumTile(
              album: album,
              onTap: () => context.push('/album/${album.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildArtistsTab(AsyncValue<List<dynamic>> artistsAsync) {
    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return EmptyState(
            icon: Icons.person_outline_rounded,
            title: 'No Artists Found',
            description: 'Scan your storage to discover artist catalogs.',
            actionLabel: 'Scan Music',
            onAction: _triggerMediaScan,
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ArtistTile(
              artist: artist,
              onTap: () => context.push('/artist/${artist.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildGenresTab(AsyncValue<List<Song>> songsAsync, bool isDark) {
    return songsAsync.when(
      data: (songs) {
        final Map<String, List<Song>> genreGroups = {};
        for (final song in songs) {
          final genre = song.genre ?? 'General';
          genreGroups.putIfAbsent(genre, () => []).add(song);
        }

        if (genreGroups.isEmpty) {
          return EmptyState(
            icon: Icons.category_outlined,
            title: 'No Genres',
            description: 'Scan your files to categorize by genre.',
            actionLabel: 'Scan Music',
            onAction: _triggerMediaScan,
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: genreGroups.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: AppColors.primary),
                  ),
                ),
                title: Text(
                  entry.key,
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${entry.value.length} tracks',
                  style: AppTypography.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ref.read(audioPlaybackNotifierProvider.notifier).playSong(
                        entry.value.first,
                        queue: entry.value,
                        index: 0,
                      );
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPlaylistsTab(AsyncValue<List<dynamic>> playlistsAsync) {
    return playlistsAsync.when(
      data: (playlists) {
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return PlaylistTile(
              playlist: playlist,
              onTap: () => context.push('/playlist/${playlist.id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
