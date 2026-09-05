import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/equalizer_settings.dart';
import '../../domain/entities/subtitle_track.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyEqEnabled = 'eq_enabled';
  static const String _keyEqPreset = 'eq_preset';
  static const String _keyEqBassBoost = 'eq_bass_boost';
  static const String _keyEqBassEnabled = 'eq_bass_enabled';
  static const String _keyEqVirtualizer = 'eq_virtualizer';
  static const String _keyEqVirtEnabled = 'eq_virt_enabled';
  static const String _keyEqLoudness = 'eq_loudness';
  static const String _keyGapless = 'audio_gapless';
  static const String _keyCrossfade = 'audio_crossfade';
  static const String _keyResumePlayback = 'video_resume';
  static const String _keyVideoSpeed = 'video_speed';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<AppThemeMode> getThemeMode() async {
    try {
      final prefs = await _getPrefs();
      final str = prefs.getString(_keyThemeMode);
      if (str == 'light') return AppThemeMode.light;
      if (str == 'amoled') return AppThemeMode.amoled;
      if (str == 'dark') return AppThemeMode.dark;
      return AppThemeMode.dark;
    } catch (_) {
      return AppThemeMode.dark;
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  @override
  Future<EqualizerSettings> getEqualizerSettings() async {
    try {
      final prefs = await _getPrefs();
      final isEnabled = prefs.getBool(_keyEqEnabled) ?? true;
      final presetId = prefs.getString(_keyEqPreset) ?? 'rock';
      final bassBoost = prefs.getDouble(_keyEqBassBoost) ?? 0.65;
      final isBassEnabled = prefs.getBool(_keyEqBassEnabled) ?? true;
      final virtualizer = prefs.getDouble(_keyEqVirtualizer) ?? 0.50;
      final isVirtEnabled = prefs.getBool(_keyEqVirtEnabled) ?? true;
      final isLoudness = prefs.getBool(_keyEqLoudness) ?? false;

      return EqualizerSettings(
        isEnabled: isEnabled,
        selectedPresetId: presetId,
        bands: const [
          EqualizerBand(index: 0, label: '60Hz', centerFreq: 60, gain: 4.5),
          EqualizerBand(index: 1, label: '230Hz', centerFreq: 230, gain: 2.0),
          EqualizerBand(index: 2, label: '910Hz', centerFreq: 910, gain: -1.0),
          EqualizerBand(index: 3, label: '3.6kHz', centerFreq: 3600, gain: 3.0),
          EqualizerBand(index: 4, label: '14kHz', centerFreq: 14000, gain: 5.0),
        ],
        bassBoost: bassBoost,
        isBassBoostEnabled: isBassEnabled,
        virtualizer: virtualizer,
        isVirtualizerEnabled: isVirtEnabled,
        isLoudnessEnabled: isLoudness,
      );
    } catch (_) {
      return EqualizerSettings.defaultSettings();
    }
  }

  @override
  Future<void> saveEqualizerSettings(EqualizerSettings settings) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyEqEnabled, settings.isEnabled);
    await prefs.setString(_keyEqPreset, settings.selectedPresetId);
    await prefs.setDouble(_keyEqBassBoost, settings.bassBoost);
    await prefs.setBool(_keyEqBassEnabled, settings.isBassBoostEnabled);
    await prefs.setDouble(_keyEqVirtualizer, settings.virtualizer);
    await prefs.setBool(_keyEqVirtEnabled, settings.isVirtualizerEnabled);
    await prefs.setBool(_keyEqLoudness, settings.isLoudnessEnabled);
  }

  @override
  Future<SubtitleStyleSettings> getSubtitleSettings() async {
    return const SubtitleStyleSettings();
  }

  @override
  Future<void> saveSubtitleSettings(SubtitleStyleSettings settings) async {}

  @override
  Future<bool> getGaplessPlaybackEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyGapless) ?? true;
  }

  @override
  Future<void> setGaplessPlaybackEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyGapless, enabled);
  }

  @override
  Future<double> getCrossfadeDuration() async {
    final prefs = await _getPrefs();
    return prefs.getDouble(_keyCrossfade) ?? 0.0;
  }

  @override
  Future<void> setCrossfadeDuration(double seconds) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_keyCrossfade, seconds);
  }

  @override
  Future<bool> getResumePlaybackEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyResumePlayback) ?? true;
  }

  @override
  Future<void> setResumePlaybackEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyResumePlayback, enabled);
  }

  @override
  Future<double> getDefaultVideoSpeed() async {
    final prefs = await _getPrefs();
    return prefs.getDouble(_keyVideoSpeed) ?? 1.0;
  }

  @override
  Future<void> setDefaultVideoSpeed(double speed) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_keyVideoSpeed, speed);
  }

  @override
  Future<List<String>> getScannedFolders() async {
    return [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/DCIM',
    ];
  }

  @override
  Future<void> setScannedFolders(List<String> folders) async {}

  @override
  Future<int> getCacheSizeBytes() async {
    return 148 * 1024 * 1024;
  }

  @override
  Future<void> clearCache() async {}
}
