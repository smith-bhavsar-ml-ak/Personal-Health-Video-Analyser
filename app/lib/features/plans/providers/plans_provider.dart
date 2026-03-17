import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/workout_plan.dart';

// ── Plans list ───────────────────────────────────────────────────────────────

final plansProvider = FutureProvider<List<WorkoutPlan>>((ref) async {
  return ApiService.instance.listPlans();
});

// ── Single plan ──────────────────────────────────────────────────────────────

final planProvider = FutureProvider.family<WorkoutPlan, String>((ref, id) async {
  return ApiService.instance.getPlan(id);
});

// ── Generate plan notifier ───────────────────────────────────────────────────

class GeneratePlanNotifier extends StateNotifier<AsyncValue<WorkoutPlan?>> {
  GeneratePlanNotifier() : super(const AsyncData(null));

  Future<WorkoutPlan?> generate(WidgetRef ref) async {
    state = const AsyncLoading();
    try {
      final plan = await ApiService.instance.generatePlan();
      ref.invalidate(plansProvider);
      state = AsyncData(plan);
      return plan;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
    }
  }
}

final generatePlanProvider =
    StateNotifierProvider<GeneratePlanNotifier, AsyncValue<WorkoutPlan?>>(
        (_) => GeneratePlanNotifier());

// ── Toggle exercise completion ────────────────────────────────────────────────

class PlanExerciseToggleNotifier extends StateNotifier<Set<String>> {
  PlanExerciseToggleNotifier() : super({});

  Future<void> toggle(String planId, String exerciseId, WidgetRef ref) async {
    try {
      await ApiService.instance.togglePlanExercise(planId, exerciseId);
      ref.invalidate(planProvider(planId));
      ref.invalidate(plansProvider);
    } catch (_) {}
  }
}

final planExerciseToggleProvider =
    StateNotifierProvider<PlanExerciseToggleNotifier, Set<String>>(
        (_) => PlanExerciseToggleNotifier());
