import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/shell/main_shell_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/music/music_screen.dart';
import '../presentation/screens/music/album_detail_screen.dart';
import '../presentation/screens/music/artist_detail_screen.dart';
import '../presentation/screens/now_playing/now_playing_screen.dart';
import '../presentation/screens/equalizer/equalizer_screen.dart';
import '../presentation/screens/videos/videos_screen.dart';
import '../presentation/screens/videos/video_player_screen.dart';
import '../presentation/screens/library/library_screen.dart';
import '../presentation/screens/library/playlist_detail_screen.dart';
import '../presentation/screens/search/search_screen.dart';
import '../core/constants/app_colors.dart';
import '../domain/entities/video.dart';
import '../presentation/screens/profile/profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  errorBuilder: (context, state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    });
    return const Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  },
  routes: [
    // Splash Route
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const CustomTransitionPage(
        child: SplashScreen(),
        transitionsBuilder: _fadeTransition,
      ),
    ),

    // Main Shell Navigation Route
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Branch 1: Music
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/music',
              builder: (context, state) => const MusicScreen(),
            ),
          ],
        ),

        // Branch 2: Videos
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/videos',
              builder: (context, state) => const VideosScreen(),
            ),
          ],
        ),

        // Branch 3: Library
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),

        // Branch 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Fullscreen and Modal routes pushed over shell
    GoRoute(
      path: '/now-playing',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const CustomTransitionPage(
        child: NowPlayingScreen(),
        transitionsBuilder: _slideUpTransition,
      ),
    ),
    GoRoute(
      path: '/equalizer',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EqualizerScreen(),
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/album/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AlbumDetailScreen(albumId: id);
      },
    ),
    GoRoute(
      path: '/artist/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ArtistDetailScreen(artistId: id);
      },
    ),
    GoRoute(
      path: '/playlist/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PlaylistDetailScreen(playlistId: id);
      },
    ),
    GoRoute(
      path: '/video-player/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final video = state.extra as Video?;
        return CustomTransitionPage(
          child: VideoPlayerScreen(videoId: id, initialVideo: video),
          transitionsBuilder: _fadeTransition,
        );
      },
    ),
  ],
);

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  const begin = Offset(0.0, 1.0);
  const end = Offset.zero;
  const curve = Curves.easeInOutCubic;
  final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
  return SlideTransition(position: animation.drive(tween), child: child);
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}
