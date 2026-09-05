import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permissions/permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const PermissionService();
});

final permissionStatusProvider =
    FutureProvider.autoDispose<PermissionStatusSummary>((ref) async {
  final service = ref.watch(permissionServiceProvider);
  return await service.checkPermissions();
});

class PermissionNotifier extends StateNotifier<AsyncValue<PermissionStatusSummary>> {
  final PermissionService _service;

  PermissionNotifier(this._service) : super(const AsyncValue.loading()) {
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    state = const AsyncValue.loading();
    try {
      final summary = await _service.checkPermissions();
      state = AsyncValue.data(summary);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<PermissionStatusSummary> requestAll() async {
    state = const AsyncValue.loading();
    try {
      final summary = await _service.requestAllPermissions();
      state = AsyncValue.data(summary);
      return summary;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final permissionControllerProvider =
    StateNotifierProvider<PermissionNotifier, AsyncValue<PermissionStatusSummary>>((ref) {
  final service = ref.watch(permissionServiceProvider);
  return PermissionNotifier(service);
});
