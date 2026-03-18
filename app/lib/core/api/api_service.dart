import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/session_summary.dart';
import '../models/session_result.dart';
import '../models/voice_query.dart';
import '../models/progress.dart';
import '../models/workout_plan.dart';
import 'client.dart';

/// All API calls — mirrors frontend/src/lib/api.ts exactly.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Dio get _dio => ApiClient.instance.dio;

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<AuthResponse> login(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(res.data!);
  }

  Future<AuthResponse> register(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(res.data!);
  }

  Future<Map<String, String>> getMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/me');
    return {
      'user_id': res.data!['user_id'] as String,
      'email':   res.data!['email']   as String,
    };
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/profile');
    return res.data!;
  }

  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> data) async {
    final res = await _dio.put<Map<String, dynamic>>('/auth/profile', data: data);
    return res.data!;
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  /// Upload a video file for analysis.
  /// [filePath] — path on mobile; [bytes] + [fileName] — for web file picker.
  Future<SessionResult> analyzeVideo({
    String? filePath,
    List<int>? bytes,
    String? fileName,
  }) async {
    final FormData form;
    if (filePath != null) {
      form = FormData.fromMap({
        'video': await MultipartFile.fromFile(filePath, filename: fileName ?? 'video.mp4'),
      });
    } else {
      form = FormData.fromMap({
        'video': MultipartFile.fromBytes(bytes!, filename: fileName ?? 'video.mp4'),
      });
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '/sessions/analyze',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return SessionResult.fromJson(res.data!);
  }

  Future<List<SessionSummary>> listSessions() async {
    final res = await _dio.get<List<dynamic>>('/sessions');
    return res.data!.map((j) => SessionSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<SessionResult> getSession(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/sessions/$id');
    return SessionResult.fromJson(res.data!);
  }

  Future<void> deleteSession(String id) async {
    await _dio.delete<void>('/sessions/$id');
  }

  Future<VoiceQueryResponse> voiceQuery(String sessionId, VoiceQueryRequest request) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/sessions/$sessionId/voice',
      data: request.toJson(),
    );
    return VoiceQueryResponse.fromJson(res.data!);
  }

  // ── Progress ────────────────────────────────────────────────────────────────

  Future<ProgressSummary> getProgressSummary() async {
    final res = await _dio.get<Map<String, dynamic>>('/progress/summary');
    return ProgressSummary.fromJson(res.data!);
  }

  Future<List<FormScorePoint>> getFormTrend({int limit = 20}) async {
    final res = await _dio.get<List<dynamic>>('/progress/form-trend', queryParameters: {'limit': limit});
    return res.data!.map((j) => FormScorePoint.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<ExerciseStat>> getExerciseStats() async {
    final res = await _dio.get<List<dynamic>>('/progress/exercise-stats');
    return res.data!.map((j) => ExerciseStat.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<WeightPoint>> getWeightHistory({int limit = 90}) async {
    final res = await _dio.get<List<dynamic>>('/progress/weight', queryParameters: {'limit': limit});
    return res.data!.map((j) => WeightPoint.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<WeightPoint> logWeight(double weightKg) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/progress/weight',
      data: {'weight_kg': weightKg},
    );
    return WeightPoint.fromJson(res.data!);
  }

  // ── Plans ───────────────────────────────────────────────────────────────────

  Future<WorkoutPlan> generatePlan() async {
    final res = await _dio.post<Map<String, dynamic>>('/plans/generate');
    return WorkoutPlan.fromJson(res.data!);
  }

  Future<List<WorkoutPlan>> listPlans() async {
    final res = await _dio.get<List<dynamic>>('/plans');
    return res.data!.map((j) => WorkoutPlan.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<WorkoutPlan> getPlan(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/plans/$id');
    return WorkoutPlan.fromJson(res.data!);
  }

  Future<Map<String, dynamic>> togglePlanExercise(String planId, String exerciseId) async {
    final res = await _dio.patch<Map<String, dynamic>>('/plans/$planId/exercises/$exerciseId/toggle');
    return res.data!;
  }

  Future<void> deletePlan(String id) async {
    await _dio.delete<void>('/plans/$id');
  }

  // ── Subscriptions ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSubscription() async {
    final res = await _dio.get<Map<String, dynamic>>('/subscriptions/me');
    return res.data!;
  }

  Future<Map<String, dynamic>> upgradeTier(String tier) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/subscriptions/upgrade',
      data: {'tier': tier},
    );
    return res.data!;
  }

  // ── Activity / Steps ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTodaySteps() async {
    final res = await _dio.get<Map<String, dynamic>>('/activity/steps/today');
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> getStepHistory({int days = 7}) async {
    final res = await _dio.get<List<dynamic>>(
      '/activity/steps/history',
      queryParameters: {'days': days},
    );
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> syncSteps({
    required int steps,
    double caloriesBurned = 0.0,
    int activeMinutes = 0,
    String? date,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/activity/steps/sync',
      data: {
        'steps': steps,
        'calories_burned': caloriesBurned,
        'active_minutes': activeMinutes,
        if (date != null) 'date': date,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> getStreak() async {
    final res = await _dio.get<Map<String, dynamic>>('/activity/streak');
    return res.data!;
  }

  Future<Map<String, dynamic>> startActivitySession(String activityType) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/activity/sessions/start',
      data: {'activity_type': activityType},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> completeActivitySession(
    String activityId, {
    required int steps,
    required double distanceM,
    required double caloriesBurned,
    double? avgPaceSPerKm,
    List<Map<String, double>>? polyline,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/activity/sessions/$activityId/complete',
      data: {
        'steps': steps,
        'distance_m': distanceM,
        'calories_burned': caloriesBurned,
        if (avgPaceSPerKm != null) 'avg_pace_s_per_km': avgPaceSPerKm,
        if (polyline != null) 'polyline': polyline,
      },
    );
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> listActivitySessions() async {
    final res = await _dio.get<List<dynamic>>('/activity/sessions');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<void> updateStepGoal(int goal) async {
    await _dio.put<void>('/activity/steps/goal', data: {'goal': goal});
  }
}
