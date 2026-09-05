import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/audio_player_provider.dart';

class SleepTimerDialog extends ConsumerWidget {
  const SleepTimerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(audioPlaybackNotifierProvider);
    final remaining = playbackState.sleepTimerRemaining;

    return AlertDialog(
      title: const Text('Sleep Timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (remaining != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Stopping in ${Formatters.formatDuration(remaining)}',
                    style: const TextStyle(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _timerOption(context, ref, '15 Minutes', const Duration(minutes: 15)),
          _timerOption(context, ref, '30 Minutes', const Duration(minutes: 30)),
          _timerOption(context, ref, '45 Minutes', const Duration(minutes: 45)),
          _timerOption(context, ref, '60 Minutes', const Duration(minutes: 60)),
          _timerOption(context, ref, 'End of current track', const Duration(minutes: 4)),
          if (remaining != null)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined, color: AppColors.error),
              title: const Text('Turn Off Timer', style: TextStyle(color: AppColors.error)),
              onTap: () {
                ref.read(audioPlaybackNotifierProvider.notifier).setSleepTimer(null);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _timerOption(BuildContext context, WidgetRef ref, String label, Duration duration) {
    return ListTile(
      leading: const Icon(Icons.access_time_rounded),
      title: Text(label),
      onTap: () {
        ref.read(audioPlaybackNotifierProvider.notifier).setSleepTimer(duration);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep timer set for $label')),
        );
      },
    );
  }
}
