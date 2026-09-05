import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../widgets/mini_player.dart';

class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent Mini Player above Navigation Bar
          const MiniPlayer(),

          // Clean, quiet bottom navigation bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: AppDimensions.bottomNavHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      index: 0,
                      currentIndex: currentIndex,
                    ),
                    _navItem(
                      icon: Icons.music_note_rounded,
                      label: 'Music',
                      index: 1,
                      currentIndex: currentIndex,
                    ),
                    _navItem(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'Videos',
                      index: 2,
                      currentIndex: currentIndex,
                    ),
                    _navItem(
                      icon: Icons.library_music_rounded,
                      label: 'Library',
                      index: 3,
                      currentIndex: currentIndex,
                    ),
                    _navItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      index: 4,
                      currentIndex: currentIndex,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required int currentIndex,
  }) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.darkTextSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
