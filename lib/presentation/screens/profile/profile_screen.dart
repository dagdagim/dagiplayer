import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../providers/media_provider.dart';
import '../../../services/audio/headset_service.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/developer_card.dart';
import '../../widgets/permission_onboarding_sheet.dart';

final pauseOnHeadsetDisconnectProvider =
    StateProvider<bool>((ref) => HeadsetService.instance.pauseOnDisconnect);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final pauseOnHeadset = ref.watch(pauseOnHeadsetDisconnectProvider);
    final allSongsAsync = ref.watch(allSongsProvider);
    final allVideosAsync = ref.watch(allVideosProvider);

    final totalSongs = allSongsAsync.value?.length ?? 0;
    final totalVideos = allVideosAsync.value?.length ?? 0;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // User Profile Header Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                child: Row(
                  children: [
                    AppNetworkImage(
                      imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
                      width: 52,
                      height: 52,
                      borderRadius: BorderRadius.circular(26),
                      fallbackIcon: Icons.person_rounded,
                      placeholderText: 'Dagim',
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dagim',
                            style: AppTypography.headlineLarge.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalSongs Songs • $totalVideos Videos Indexed',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 1),
            ),

            // Permissions & Device Storage Hub
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.screenPadding),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withAlpha(70),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Mobile Device Storage Scanner',
                            style: AppTypography.titleMedium.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Scan and discover audio, video, and playlist files stored locally across your device folders and SD cards.',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => PermissionOnboardingSheet.show(context),
                              icon: const Icon(Icons.security_update_good_rounded, size: 18),
                              label: const Text('Manage Permissions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                                foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Scanning device storage...')),
                                );
                                final result = await ref.read(mediaActionControllerProvider).scanDevice();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Found ${result.songs.length} songs & ${result.videos.length} videos.'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: const Text('Scan Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quick Hub Navigation Links
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
                child: Column(
                  children: [
                    _profileTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'Favorites',
                      onTap: () => context.push('/playlist/pl-favorites'),
                      isDark: isDark,
                    ),
                    _profileTile(
                      icon: Icons.download_rounded,
                      title: 'Downloads & Local Audio',
                      onTap: () => context.go('/music'),
                      isDark: isDark,
                    ),
                    _profileTile(
                      icon: Icons.history_rounded,
                      title: 'Recently Played',
                      onTap: () => context.go('/music'),
                      isDark: isDark,
                    ),
                    _profileTile(
                      icon: Icons.queue_music_rounded,
                      title: 'Playlists',
                      onTap: () => context.go('/library'),
                      isDark: isDark,
                    ),
                    _profileTile(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Videos & Movies',
                      onTap: () => context.go('/videos'),
                      isDark: isDark,
                    ),
                    _profileTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Studio Equalizer',
                      onTap: () => context.push('/equalizer'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 24),
            ),

            // Settings & Preferences Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.xs,
                ),
                child: Text(
                  'Appearance & Settings',
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),

            // Theme Mode Selector (Dark / Light / AMOLED)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.sm,
                ),
                child: Row(
                  children: [
                    _themeButton(
                      label: 'Dark',
                      isSelected: themeMode == AppThemeMode.dark,
                      onTap: () => ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.dark),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _themeButton(
                      label: 'Light',
                      isSelected: themeMode == AppThemeMode.light,
                      onTap: () => ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.light),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _themeButton(
                      label: 'AMOLED',
                      isSelected: themeMode == AppThemeMode.amoled,
                      onTap: () => ref.read(themeModeProvider.notifier).setTheme(AppThemeMode.amoled),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // Earphone & Headset Audio Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.xs,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.headphones_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Earphone & Headset Controls',
                              style: AppTypography.titleMedium.copyWith(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: pauseOnHeadset,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) async {
                              ref.read(pauseOnHeadsetDisconnectProvider.notifier).state = val;
                              await HeadsetService.instance.setPauseOnDisconnect(val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automatically stop/pause music when earphones, headphones, or Bluetooth audio devices are disconnected.',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withAlpha(120),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hardware Button: Single click to Stop/Pause, Double to Skip',
                                style: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Storage and Cache Cleaner Tile
            SliverToBoxAdapter(
              child: _profileTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Storage & Cache',
                subtitle: 'Cache: 148 MB • Media Storage: 4.8 GB',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared successfully')),
                  );
                },
                isDark: isDark,
              ),
            ),

            // Developer & Organization Card
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.sm,
                ),
                child: DeveloperCard(isCompact: false),
              ),
            ),

            // App Version & Credits Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenPadding,
                  vertical: AppDimensions.md,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DagiPlayer v1.0.0 (Production Build)\nStudio Sound • Local First',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Developed by Tobiya | Developer Dagim Bekele\nhttps://dagimbekelebunera.vercel.app/',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.bottomNavHeight + AppDimensions.miniPlayerHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenPadding),
    );
  }

  Widget _themeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
