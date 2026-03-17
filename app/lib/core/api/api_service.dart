import 'package:dio/dio.dart';
import '../models/auth_response.dart';
import '../models/session_summary.dart';
import '../models/session_result.dart';
import '../models/voice_query.dart';
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
}
