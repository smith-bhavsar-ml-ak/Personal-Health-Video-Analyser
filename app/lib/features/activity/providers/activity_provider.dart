import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/activity.dart';

// ── Today's steps ─────────────────────────────────────────────────────────────

final todayStepsProvider = AsyncNotifierProvider<TodayStepsNotifier, DailySteps>(
  TodayStepsNotifier.new,
);

class TodayStepsNotifier extends AsyncNotifier<DailySteps> {
  @override
  Future<DailySteps> build() => _fetch();

  Future<DailySteps> _fetch() async {
    final json = await ApiService.instance.getTodaySteps();
    return DailySteps.fromJson(json);
  }

  /// Called by the pedometer listener with the latest step count.
  Future<void> syncSteps(int steps) async {
    final json = await ApiService.instance.syncSteps(steps: steps);
    state = AsyncData(DailySteps.fromJson(json));
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// ── Step history (7-day) ──────────────────────────────────────────────────────

final stepHistoryProvider =
    AsyncNotifierProvider<StepHistoryNotifier, List<StepHistoryPoint>>(
  StepHistoryNotifier.new,
);

class StepHistoryNotifier extends AsyncNotifier<List<StepHistoryPoint>> {
  @override
  Future<List<StepHistoryPoint>> build() async {
    final list = await ApiService.instance.getStepHistory(days: 7);
    return list.map(StepHistoryPoint.fromJson).toList();
  }
}

// ── Activity sessions ─────────────────────────────────────────────────────────

final activitySessionsProvider =
    AsyncNotifierProvider<ActivitySessionsNotifier, List<ActivitySessionSummary>>(
  ActivitySessionsNotifier.new,
);

class ActivitySessionsNotifier
    extends AsyncNotifier<List<ActivitySessionSummary>> {
  @override
  Future<List<ActivitySessionSummary>> build() async {
    final list = await ApiService.instance.listActivitySessions();
    return list.map(ActivitySessionSummary.fromJson).toList();
  }

  Future<void> refresh() async => ref.invalidateSelf();
}
