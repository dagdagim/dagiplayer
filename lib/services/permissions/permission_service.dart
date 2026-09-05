import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionStatusSummary {
  final bool hasStoragePermission;
  final bool hasAudioPermission;
  final bool hasVideoPermission;
  final bool hasCameraPermission;
  final bool hasNotificationPermission;
  final bool isLimitedAccess;

  const PermissionStatusSummary({
    required this.hasStoragePermission,
    required this.hasAudioPermission,
    required this.hasVideoPermission,
    required this.hasCameraPermission,
    required this.hasNotificationPermission,
    this.isLimitedAccess = false,
  });

  bool get canScanMedia =>
      hasStoragePermission || hasAudioPermission || hasVideoPermission;

  bool get isFullyGranted =>
      canScanMedia && hasCameraPermission && hasNotificationPermission && !isLimitedAccess;
}

class PermissionService {
  const PermissionService();

  Future<PermissionStatusSummary> checkPermissions() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return const PermissionStatusSummary(
        hasStoragePermission: true,
        hasAudioPermission: true,
        hasVideoPermission: true,
        hasCameraPermission: true,
        hasNotificationPermission: true,
        isLimitedAccess: false,
      );
    }

    bool storageGranted = false;
    bool audioGranted = false;
    bool videoGranted = false;
    bool cameraGranted = false;
    bool notificationGranted = false;
    bool isLimited = false;

    try {
      if (Platform.isAndroid) {
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        final audioStatus = await Permission.audio.status;
        final videoStatus = await Permission.videos.status;
        final storageStatus = await Permission.storage.status;
        final cameraStatus = await Permission.camera.status;
        final notificationStatus = await Permission.notification.status;

        final isManageGranted = manageStorageStatus.isGranted;
        final isLegacyStorageGranted = storageStatus.isGranted;

        isLimited = videoStatus.isLimited;

        storageGranted = isManageGranted || isLegacyStorageGranted;
        audioGranted = audioStatus.isGranted || storageGranted;
        videoGranted = videoStatus.isGranted || storageGranted || isLimited;
        cameraGranted = cameraStatus.isGranted;
        notificationGranted = notificationStatus.isGranted;

        if (audioStatus.isGranted || videoStatus.isGranted) {
          storageGranted = true;
        }
      } else if (Platform.isIOS) {
        final photosStatus = await Permission.photos.status;
        final cameraStatus = await Permission.camera.status;
        final notificationStatus = await Permission.notification.status;

        isLimited = photosStatus.isLimited;
        storageGranted = photosStatus.isGranted || isLimited;
        audioGranted = photosStatus.isGranted || isLimited;
        videoGranted = photosStatus.isGranted || isLimited;
        cameraGranted = cameraStatus.isGranted;
        notificationGranted = notificationStatus.isGranted;
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }

    return PermissionStatusSummary(
      hasStoragePermission: storageGranted,
      hasAudioPermission: audioGranted,
      hasVideoPermission: videoGranted,
      hasCameraPermission: cameraGranted,
      hasNotificationPermission: notificationGranted,
      isLimitedAccess: isLimited,
    );
  }

  Future<PermissionStatusSummary> requestAllPermissions() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return const PermissionStatusSummary(
        hasStoragePermission: true,
        hasAudioPermission: true,
        hasVideoPermission: true,
        hasCameraPermission: true,
        hasNotificationPermission: true,
        isLimitedAccess: false,
      );
    }

    try {
      if (Platform.isAndroid) {
        // 1. Request All-Files Management access for full storage reading (prevents selective picker on Android 11+)
        bool manageStorage = false;
        try {
          final manageStatus = await Permission.manageExternalStorage.status;
          if (!manageStatus.isGranted) {
            final requestedManage = await Permission.manageExternalStorage.request();
            manageStorage = requestedManage.isGranted;
          } else {
            manageStorage = true;
          }
        } catch (_) {}

        // 2. Request Media & Storage Permissions
        final audio = await Permission.audio.request();
        final video = await Permission.videos.request();
        final photos = await Permission.photos.request();
        final storage = await Permission.storage.request();

        // 3. Request Camera & Notification
        final camera = await Permission.camera.request();
        final notification = await Permission.notification.request();

        final isLimited = video.isLimited || photos.isLimited;
        final storageOk = manageStorage ||
            storage.isGranted ||
            audio.isGranted ||
            video.isGranted ||
            photos.isGranted;

        return PermissionStatusSummary(
          hasStoragePermission: storageOk,
          hasAudioPermission: audio.isGranted || storageOk,
          hasVideoPermission: video.isGranted || storageOk || isLimited,
          hasCameraPermission: camera.isGranted,
          hasNotificationPermission: notification.isGranted,
          isLimitedAccess: isLimited && !manageStorage,
        );
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.request();
        final camera = await Permission.camera.request();
        final notification = await Permission.notification.request();
        final isLimited = photos.isLimited;

        return PermissionStatusSummary(
          hasStoragePermission: photos.isGranted || isLimited,
          hasAudioPermission: photos.isGranted || isLimited,
          hasVideoPermission: photos.isGranted || isLimited,
          hasCameraPermission: camera.isGranted,
          hasNotificationPermission: notification.isGranted,
          isLimitedAccess: isLimited,
        );
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }

    return checkPermissions();
  }

  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('Error opening settings: $e');
      return false;
    }
  }
}
