class EqualizerBand {
  final int index;
  final String label; // "60Hz", "230Hz", "910Hz", "3.6kHz", "14kHz"
  final int centerFreq;
  final double gain; // -12.0 to +12.0 dB

  const EqualizerBand({
    required this.index,
    required this.label,
    required this.centerFreq,
    this.gain = 0.0,
  });

  EqualizerBand copyWith({
    int? index,
    String? label,
    int? centerFreq,
    double? gain,
  }) {
    return EqualizerBand(
      index: index ?? this.index,
      label: label ?? this.label,
      centerFreq: centerFreq ?? this.centerFreq,
      gain: gain ?? this.gain,
    );
  }
}

class EqualizerPreset {
  final String id;
  final String name;
  final List<double> bandGains; // 5 values for 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz

  const EqualizerPreset({
    required this.id,
    required this.name,
    required this.bandGains,
  });

  static const List<EqualizerPreset> defaultPresets = [
    EqualizerPreset(id: 'flat', name: 'Flat', bandGains: [0, 0, 0, 0, 0]),
    EqualizerPreset(id: 'rock', name: 'Rock', bandGains: [4.5, 2.0, -1.0, 3.0, 5.0]),
    EqualizerPreset(id: 'pop', name: 'Pop', bandGains: [-1.0, 1.5, 3.5, 1.5, -0.5]),
    EqualizerPreset(id: 'jazz', name: 'Jazz', bandGains: [3.0, 1.5, -1.5, 2.0, 3.0]),
    EqualizerPreset(id: 'classical', name: 'Classical', bandGains: [4.0, 2.5, -1.0, 2.5, 3.5]),
    EqualizerPreset(id: 'hiphop', name: 'Hip-Hop', bandGains: [6.0, 3.5, -0.5, 1.5, 3.0]),
    EqualizerPreset(id: 'electronic', name: 'Electronic', bandGains: [5.0, 3.0, 0.0, 2.0, 4.5]),
    EqualizerPreset(id: 'acoustic', name: 'Acoustic', bandGains: [3.5, 2.0, 0.5, 2.5, 3.0]),
    EqualizerPreset(id: 'custom', name: 'Custom', bandGains: [0, 0, 0, 0, 0]),
  ];
}

class EqualizerSettings {
  final bool isEnabled;
  final String selectedPresetId;
  final List<EqualizerBand> bands;
  final double bassBoost; // 0.0 to 1.0
  final bool isBassBoostEnabled;
  final double virtualizer; // 0.0 to 1.0
  final bool isVirtualizerEnabled;
  final bool isLoudnessEnabled;
  final double balance; // -1.0 (Left) to 1.0 (Right), 0.0 Center

  const EqualizerSettings({
    this.isEnabled = true,
    this.selectedPresetId = 'rock',
    required this.bands,
    this.bassBoost = 0.65,
    this.isBassBoostEnabled = true,
    this.virtualizer = 0.5,
    this.isVirtualizerEnabled = true,
    this.isLoudnessEnabled = false,
    this.balance = 0.0,
  });

  static EqualizerSettings defaultSettings() {
    return const EqualizerSettings(
      isEnabled: true,
      selectedPresetId: 'rock',
      bands: [
        EqualizerBand(index: 0, label: '60Hz', centerFreq: 60, gain: 4.5),
        EqualizerBand(index: 1, label: '230Hz', centerFreq: 230, gain: 2.0),
        EqualizerBand(index: 2, label: '910Hz', centerFreq: 910, gain: -1.0),
        EqualizerBand(index: 3, label: '3.6kHz', centerFreq: 3600, gain: 3.0),
        EqualizerBand(index: 4, label: '14kHz', centerFreq: 14000, gain: 5.0),
      ],
      bassBoost: 0.65,
      isBassBoostEnabled: true,
      virtualizer: 0.50,
      isVirtualizerEnabled: true,
      isLoudnessEnabled: false,
      balance: 0.0,
    );
  }

  EqualizerSettings copyWith({
    bool? isEnabled,
    String? selectedPresetId,
    List<EqualizerBand>? bands,
    double? bassBoost,
    bool? isBassBoostEnabled,
    double? virtualizer,
    bool? isVirtualizerEnabled,
    bool? isLoudnessEnabled,
    double? balance,
  }) {
    return EqualizerSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      bands: bands ?? this.bands,
      bassBoost: bassBoost ?? this.bassBoost,
      isBassBoostEnabled: isBassBoostEnabled ?? this.isBassBoostEnabled,
      virtualizer: virtualizer ?? this.virtualizer,
      isVirtualizerEnabled: isVirtualizerEnabled ?? this.isVirtualizerEnabled,
      isLoudnessEnabled: isLoudnessEnabled ?? this.isLoudnessEnabled,
      balance: balance ?? this.balance,
    );
  }
}
