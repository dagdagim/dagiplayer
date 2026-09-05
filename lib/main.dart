import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'data/datasources/favorites_cache_service.dart';
import 'data/database/app_database.dart';
import 'data/datasources/mock_initial_catalog.dart';
import 'providers/audio_player_provider.dart';
import 'providers/media_provider.dart';
import 'routing/app_router.dart';
import 'services/audio/audio_player_handler.dart';
import 'services/audio/headset_service.dart';
import 'services/audio/audio_player_service.dart';
import 'services/audio/quick_panel_service.dart';
import 'services/intent/media_intent_service.dart';

late final AudioPlayerService audioPlayerServiceInstance;
late final DagiAudioHandler audioHandlerInstance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce edge-to-edge style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SQLite local database and persistent favorites cache
  await AppDatabase.instance.init();

  // Initialize AudioPlayerService instance
  audioPlayerServiceInstance = AudioPlayerService.instance;

  // Initialize audio handler and headset service for earphone controls
  audioHandlerInstance = DagiAudioHandler(audioPlayerServiceInstance);

  // Initialize HeadsetService for stopping/pausing on earphone disconnect and audio interruptions
  await HeadsetService.instance.init(audioPlayerServiceInstance);

  runApp(
    const ProviderScope(
      child: DagiPlayerApp(),
    ),
  );
}

class DagiPlayerApp extends ConsumerStatefulWidget {
  const DagiPlayerApp({super.key});

  @override
  ConsumerState<DagiPlayerApp> createState() => _DagiPlayerAppState();
}

class _DagiPlayerAppState extends ConsumerState<DagiPlayerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Restore last playback session / cache or seed initial songs with favorites synced
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      MediaIntentService.instance.init(ref);
      await QuickPanelService.instance.init(audioPlayerServiceInstance);

      final restored = await audioPlayerServiceInstance.restoreLastSession();
      if (!restored) {
        final favCache = FavoritesCacheService.instance;
        final initial = MockInitialCatalog.initialSongs.map((s) {
          final isFav = s.isFavorite || favCache.isFavorite(s.id, s.uri);
          return s.copyWith(isFavorite: isFav);
        }).toList();

        ref.read(audioPlaybackNotifierProvider.notifier).updateQueue(
              initial,
              newCurrentIndex: 0,
            );
      }

      // Automatically scan device media in background on startup after UI mounts (preserves favorites)
      Future.delayed(const Duration(milliseconds: 1200), () {
        ref.read(mediaActionControllerProvider).scanDevice();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      audioPlayerServiceInstance.savePlaybackSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ref.watch(currentThemeDataProvider);

    return MaterialApp.router(
      title: 'DagiPlayer',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      routerConfig: appRouter,
    );
  }
}
