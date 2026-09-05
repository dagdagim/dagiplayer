import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import 'app_theme.dart';

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(AppThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final repo = _ref.read(settingsRepositoryProvider);
    final mode = await repo.getThemeMode();
    state = mode;
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.setThemeMode(mode);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

final currentThemeDataProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  switch (mode) {
    case AppThemeMode.light:
      return AppTheme.lightTheme;
    case AppThemeMode.amoled:
      return AppTheme.amoledTheme;
    case AppThemeMode.dark:
    case AppThemeMode.system:
      return AppTheme.darkTheme;
  }
});
