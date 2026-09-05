import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../providers/media_provider.dart';
import '../../providers/permission_provider.dart';

class PermissionOnboardingSheet extends ConsumerStatefulWidget {
  final VoidCallback? onGranted;

  const PermissionOnboardingSheet({super.key, this.onGranted});

  static Future<void> show(BuildContext context, {VoidCallback? onGranted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PermissionOnboardingSheet(onGranted: onGranted),
    );
  }

  @override
  ConsumerState<PermissionOnboardingSheet> createState() =>
      _PermissionOnboardingSheetState();
}

class _PermissionOnboardingSheetState
    extends ConsumerState<PermissionOnboardingSheet>
    with WidgetsBindingObserver {
  bool _isProcessing = false;
  bool _showSettingsButton = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showSettingsButton) {
      _checkAndScanIfGranted();
    }
  }

  Future<void> _checkAndScanIfGranted() async {
    final summary = await ref.read(permissionServiceProvider).checkPermissions();
    if (summary.canScanMedia && mounted) {
      _handleGrantPermissions();
    }
  }

  Future<void> _handleGrantPermissions() async {
    setState(() {
      _isProcessing = true;
      _showSettingsButton = false;
      _statusMessage = 'Requesting storage & media permissions...';
    });

    try {
      final summary =
          await ref.read(permissionControllerProvider.notifier).requestAll();

      setState(() {
        _statusMessage = 'Scanning device folders for videos & music...';
      });

      final result = await ref
          .read(mediaActionControllerProvider)
          .scanDevice(onProgress: (folder, count) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Scanning $folder (found $count)...';
          });
        }
      });

      if (mounted) {
        if (result.videos.isNotEmpty || result.songs.isNotEmpty || summary.canScanMedia) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Discovered ${result.videos.length} videos and ${result.songs.length} audio tracks!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 4),
            ),
          );
          widget.onGranted?.call();
        } else if (summary.isLimitedAccess) {
          setState(() {
            _isProcessing = false;
            _showSettingsButton = true;
            _statusMessage =
                'Only selected videos are accessible. To show all videos on your phone automatically, enable All Files Access in Settings.';
          });
        } else {
          setState(() {
            _isProcessing = false;
            _showSettingsButton = true;
            _statusMessage =
                'Storage permission was not granted by Android. Tap below to enable in Settings.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showSettingsButton = true;
          _statusMessage = 'Error scanning device storage: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.darkBorder, width: 1.2),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Storage Access',
                        style: AppTypography.displaySmall.copyWith(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DagiPlayer needs access to scan and display all videos and music on your phone.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Permission Items List
            _buildPermissionItem(
              icon: Icons.video_collection_rounded,
              title: 'Videos & Camera Recordings',
              description: 'Index MP4, MKV, Movies, WhatsApp, and Camera videos.',
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.audio_file_rounded,
              title: 'Music & Audio Files',
              description: 'Scan and play MP3, AAC, FLAC, WAV, and audiobooks.',
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.camera_alt_rounded,
              title: 'Camera & Artwork',
              description: 'Capture album covers and customize your playlists.',
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.notifications_active_rounded,
              title: 'Media Notifications',
              description: 'Playback controls in status bar and lock screen.',
            ),
            const SizedBox(height: 24),

            // Live status message if processing
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    if (_isProcessing) const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: AppTypography.bodySmall.copyWith(
                          color: _showSettingsButton ? Colors.redAccent : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Settings Button if needed
            if (_showSettingsButton)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_rounded, color: AppColors.primary),
                  label: const Text('Open App Settings to Allow Access', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),

            // Action Buttons
            ElevatedButton(
              onPressed: _isProcessing ? null : _handleGrantPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Allow Access & Scan Device',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Maybe Later',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.darkTextTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.darkBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
