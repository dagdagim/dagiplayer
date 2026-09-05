import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/media_provider.dart';
import '../../widgets/album_tile.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/section_header.dart';
import '../../widgets/song_tile.dart';

class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    final artistAsync = ref.watch(artistDetailProvider(widget.artistId));

    return Scaffold(
      body: artistAsync.when(
        data: (artist) {
          if (artist == null) {
            return const Center(child: Text('Artist not found'));
          }

          final allSongsAsync = ref.watch(allSongsProvider);
          final artistSongs = allSongsAsync.value?.where((s) => s.artist.contains(artist.name)).toList() ?? [];
          final displaySongs = artistSongs.isNotEmpty ? artistSongs : (allSongsAsync.value?.take(4).toList() ?? []);

          final allAlbumsAsync = ref.watch(allAlbumsProvider);
          final artistAlbums = allAlbumsAsync.value?.where((a) => a.artist.contains(artist.name)).toList() ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero Artist Header
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        imageUrl: artist.imageUri,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person_rounded,
                        placeholderText: artist.name,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(200),
                              Colors.black,
                            ],
                            stops: const [0.4, 0.8, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppDimensions.screenPadding,
                        right: AppDimensions.screenPadding,
                        bottom: AppDimensions.md,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artist.name,
                              style: AppTypography.headlineLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${artist.songCount} songs • ${artist.albumCount} albums',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isFollowing = !_isFollowing;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _isFollowing ? AppColors.primary : Colors.white60,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                    ),
                                  ),
                                  child: Text(
                                    _isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(
                                      color: _isFollowing ? AppColors.primary : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Popular Songs Section
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.md),
                    SectionHeader(
                      title: 'Popular Songs',
                      onSeeAll: () {},
                    ),
                    ...displaySongs.asMap().entries.map((entry) {
                      return SongTile(
                        song: entry.value,
                        index: entry.key,
                        playlistContext: displaySongs,
                      );
                    }),
                    const SizedBox(height: AppDimensions.md),
                  ],
                ),
              ),

              // Discography Section
              if (artistAlbums.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Discography',
                        onSeeAll: () {},
                      ),
                      SizedBox(
                        height: 185,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
                          itemCount: artistAlbums.length,
                          itemBuilder: (context, index) {
                            final album = artistAlbums[index];
                            return AlbumTile(
                              album: album,
                              onTap: () => context.push('/album/${album.id}'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppDimensions.xxl),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
