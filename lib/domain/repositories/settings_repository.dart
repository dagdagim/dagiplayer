import '../../core/theme/app_theme.dart';
import '../entities/equalizer_settings.dart';
import '../entities/subtitle_track.dart';

abstract class SettingsRepository {
  Future<AppThemeMode> getThemeMode();
  Future<void> setThemeMode(AppThemeMode mode);

  Future<EqualizerSettings> getEqualizerSettings();
  Future<void> saveEqualizerSettings(EqualizerSettings settings);

  Future<SubtitleStyleSettings> getSubtitleSettings();
  Future<void> saveSubtitleSettings(SubtitleStyleSettings settings);

  Future<bool> getGaplessPlaybackEnabled();
  Future<void> setGaplessPlaybackEnabled(bool enabled);

  Future<double> getCrossfadeDuration();
  Future<void> setCrossfadeDuration(double seconds);

  Future<bool> getResumePlaybackEnabled();
  Future<void> setResumePlaybackEnabled(bool enabled);

  Future<double> getDefaultVideoSpeed();
  Future<void> setDefaultVideoSpeed(double speed);

  Future<List<String>> getScannedFolders();
  Future<void> setScannedFolders(List<String> folders);

  Future<int> getCacheSizeBytes();
  Future<void> clearCache();
}
