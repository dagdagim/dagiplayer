import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/datasources/local_media_scanner.dart';
import '../data/repositories/media_repository_impl.dart';
import '../data/repositories/playlist_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/playlist_repository.dart';
import '../domain/repositories/settings_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final localMediaScannerProvider = Provider<LocalMediaScanner>((ref) {
  return LocalMediaScanner();
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final scanner = ref.watch(localMediaScannerProvider);
  return MediaRepositoryImpl(database: db, scanner: scanner);
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PlaylistRepositoryImpl(database: db);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});
