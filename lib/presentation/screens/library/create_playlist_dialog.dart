import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../providers/playlist_provider.dart';

class CreatePlaylistDialog extends ConsumerStatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  ConsumerState<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<CreatePlaylistDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedIcon = 'heart';

  final List<Map<String, dynamic>> _icons = [
    {'name': 'heart', 'icon': Icons.favorite_rounded},
    {'name': 'fitness', 'icon': Icons.fitness_center_rounded},
    {'name': 'palm_tree', 'icon': Icons.wb_sunny_rounded},
    {'name': 'car', 'icon': Icons.directions_car_rounded},
    {'name': 'cloud_rain', 'icon': Icons.water_drop_rounded},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Playlist Name',
                hintText: 'e.g. Late Night Vibes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            const Text(
              'Choose Playlist Icon',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppDimensions.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _icons.map((item) {
                final isSelected = item['name'] == _selectedIcon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = item['name'] as String;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.darkSurfaceSecondary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.darkBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isNotEmpty) {
              ref.read(playlistActionControllerProvider).createPlaylist(
                    title: title,
                    description: _descController.text.trim(),
                    iconName: _selectedIcon,
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Created playlist "$title"')),
              );
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
