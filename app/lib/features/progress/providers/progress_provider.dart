import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/progress.dart';

// ── Progress summary (KPIs) ──────────────────────────────────────────────────

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  return ApiService.instance.getProgressSummary();
});

// ── Form score trend (line chart) ────────────────────────────────────────────

final formTrendProvider = FutureProvider<List<FormScorePoint>>((ref) async {
  return ApiService.instance.getFormTrend(limit: 20);
});

// ── Per-exercise stats (bar chart) ───────────────────────────────────────────

final exerciseStatsProvider = FutureProvider<List<ExerciseStat>>((ref) async {
  return ApiService.instance.getExerciseStats();
});

// ── Weight history (line chart) ──────────────────────────────────────────────

final weightHistoryProvider = FutureProvider<List<WeightPoint>>((ref) async {
  return ApiService.instance.getWeightHistory(limit: 90);
});

// ── Log weight notifier ──────────────────────────────────────────────────────

class LogWeightNotifier extends StateNotifier<AsyncValue<void>> {
  LogWeightNotifier() : super(const AsyncData(null));

  Future<bool> log(double weightKg, WidgetRef ref) async {
    state = const AsyncLoading();
    try {
      await ApiService.instance.logWeight(weightKg);
      ref.invalidate(weightHistoryProvider);
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}

final logWeightProvider =
    StateNotifierProvider<LogWeightNotifier, AsyncValue<void>>(
        (_) => LogWeightNotifier());
