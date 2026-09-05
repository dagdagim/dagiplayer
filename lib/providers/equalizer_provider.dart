import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equalizer_settings.dart';
import 'database_provider.dart';

class EqualizerNotifier extends StateNotifier<EqualizerSettings> {
  final Ref _ref;

  EqualizerNotifier(this._ref) : super(EqualizerSettings.defaultSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = _ref.read(settingsRepositoryProvider);
    final loaded = await repo.getEqualizerSettings();
    state = loaded;
  }

  Future<void> _saveSettings() async {
    final repo = _ref.read(settingsRepositoryProvider);
    await repo.saveEqualizerSettings(state);
  }

  void toggleEnabled() {
    state = state.copyWith(isEnabled: !state.isEnabled);
    _saveSettings();
  }

  void setPreset(String presetId) {
    final preset = EqualizerPreset.defaultPresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => EqualizerPreset.defaultPresets.first,
    );

    final newBands = List<EqualizerBand>.generate(state.bands.length, (i) {
      final gain = i < preset.bandGains.length ? preset.bandGains[i] : 0.0;
      return state.bands[i].copyWith(gain: gain);
    });

    state = state.copyWith(
      selectedPresetId: presetId,
      bands: newBands,
    );
    _saveSettings();
  }

  void setBandGain(int bandIndex, double gain) {
    if (bandIndex < 0 || bandIndex >= state.bands.length) return;

    final newBands = List<EqualizerBand>.from(state.bands);
    newBands[bandIndex] = newBands[bandIndex].copyWith(gain: gain);

    state = state.copyWith(
      selectedPresetId: 'custom',
      bands: newBands,
    );
    _saveSettings();
  }

  void setBassBoost(double value) {
    state = state.copyWith(bassBoost: value);
    _saveSettings();
  }

  void toggleBassBoost() {
    state = state.copyWith(isBassBoostEnabled: !state.isBassBoostEnabled);
    _saveSettings();
  }

  void setVirtualizer(double value) {
    state = state.copyWith(virtualizer: value);
    _saveSettings();
  }

  void toggleVirtualizer() {
    state = state.copyWith(isVirtualizerEnabled: !state.isVirtualizerEnabled);
    _saveSettings();
  }

  void toggleLoudness() {
    state = state.copyWith(isLoudnessEnabled: !state.isLoudnessEnabled);
    _saveSettings();
  }

  void setBalance(double value) {
    state = state.copyWith(balance: value);
    _saveSettings();
  }
}

final equalizerNotifierProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerSettings>((ref) {
  return EqualizerNotifier(ref);
});
