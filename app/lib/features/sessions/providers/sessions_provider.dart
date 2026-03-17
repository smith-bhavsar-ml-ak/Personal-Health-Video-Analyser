import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/session_summary.dart';
import '../../../core/models/session_result.dart';

class SessionsNotifier extends AsyncNotifier<List<SessionSummary>> {
  @override
  Future<List<SessionSummary>> build() => ApiService.instance.listSessions();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ApiService.instance.listSessions());
  }

  Future<void> delete(String id) async {
    await ApiService.instance.deleteSession(id);
    await refresh();
  }
}

final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, List<SessionSummary>>(
  SessionsNotifier.new,
);

/// Cache for individual session results (avoids re-fetching on navigation back).
final sessionResultProvider =
    FutureProvider.family<SessionResult, String>((ref, id) {
  return ApiService.instance.getSession(id);
});
