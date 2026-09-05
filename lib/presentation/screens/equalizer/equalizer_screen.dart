import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/equalizer_settings.dart';
import '../../../providers/equalizer_provider.dart';
import '../../widgets/equalizer_graph.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqSettings = ref.watch(equalizerNotifierProvider);
    final eqNotifier = ref.read(equalizerNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Equalizer',
          style: AppTypography.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: eqSettings.isEnabled,
              onChanged: (_) => eqNotifier.toggleEnabled(),
              activeThumbColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preset Dropdown & Save Button Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: eqSettings.selectedPresetId,
                        isExpanded: true,
                        dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: EqualizerPreset.defaultPresets.map((preset) {
                          return DropdownMenuItem<String>(
                            value: preset.id,
                            child: Text(
                              preset.name,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: eqSettings.isEnabled
                            ? (val) {
                                if (val != null) eqNotifier.setPreset(val);
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                OutlinedButton(
                  onPressed: eqSettings.isEnabled
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom preset saved')),
                          );
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.lg),

            // Visual Curve Graph
            EqualizerGraph(
              bands: eqSettings.bands,
              isEnabled: eqSettings.isEnabled,
            ),

            const SizedBox(height: AppDimensions.lg),

            // 5-Band Vertical Sliders
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: eqSettings.bands.map((band) {
                  return _buildVerticalBandSlider(
                    band: band,
                    isEnabled: eqSettings.isEnabled,
                    onChanged: (val) => eqNotifier.setBandGain(band.index, val),
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppDimensions.xl),

            // Additional Audio Enhancements (Bass Boost, Virtualizer, Loudness)
            _buildToggleCard(
              title: 'Bass Boost',
              subtitle: 'Enhance low-end bass response',
              value: eqSettings.isBassBoostEnabled,
              sliderValue: eqSettings.bassBoost,
              onToggle: (_) => eqNotifier.toggleBassBoost(),
              onSliderChanged: (val) => eqNotifier.setBassBoost(val),
              isDark: isDark,
            ),

            const SizedBox(height: AppDimensions.md),

            _buildToggleCard(
              title: 'Virtualizer',
              subtitle: 'Simulate 3D spatial surround sound',
              value: eqSettings.isVirtualizerEnabled,
              sliderValue: eqSettings.virtualizer,
              onToggle: (_) => eqNotifier.toggleVirtualizer(),
              onSliderChanged: (val) => eqNotifier.setVirtualizer(val),
              isDark: isDark,
            ),

            const SizedBox(height: AppDimensions.md),

            // Loudness Equalization Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loudness',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Normalize track volumes',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: eqSettings.isLoudnessEnabled,
                      onChanged: (_) => eqNotifier.toggleLoudness(),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalBandSlider({
    required EqualizerBand band,
    required bool isEnabled,
    required ValueChanged<double> onChanged,
    required bool isDark,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${band.gain > 0 ? '+' : ''}${band.gain.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: isEnabled ? AppColors.primary : Colors.grey,
                inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                thumbColor: isEnabled ? AppColors.primary : Colors.grey,
                overlayColor: AppColors.primaryGlow,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: band.gain,
                min: -12.0,
                max: 12.0,
                onChanged: isEnabled ? onChanged : null,
              ),
            ),
          ),
        ),
        Text(
          band.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required double sliderValue,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onSliderChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: value,
                  onChanged: onToggle,
                  activeThumbColor: AppColors.primary,
                ),
              ),
            ],
          ),
          if (value) ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: 1.0,
                onChanged: onSliderChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
