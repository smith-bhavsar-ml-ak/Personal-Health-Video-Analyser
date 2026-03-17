import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/session_result.dart';

enum AnalyzePhase { idle, uploading, processing, done, failed }

class AnalyzeState {
  final AnalyzePhase phase;
  final String? sessionId;
  final SessionResult? session;
  final String? error;

  const AnalyzeState({
    this.phase = AnalyzePhase.idle,
    this.sessionId,
    this.session,
    this.error,
  });

  AnalyzeState copyWith({
    AnalyzePhase? phase,
    String? sessionId,
    SessionResult? session,
    String? error,
    bool clearError = false,
  }) =>
      AnalyzeState(
        phase:     phase     ?? this.phase,
        sessionId: sessionId ?? this.sessionId,
        session:   session   ?? this.session,
        error:     clearError ? null : (error ?? this.error),
      );

  bool get isActive =>
      phase == AnalyzePhase.uploading || phase == AnalyzePhase.processing;
}

class AnalyzeNotifier extends StateNotifier<AnalyzeState> {
  AnalyzeNotifier() : super(const AnalyzeState());

  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Upload a video file.
  /// [filePath] on mobile; [bytes] + [fileName] on web (file picker).
  Future<void> upload({
    String? filePath,
    List<int>? bytes,
    String? fileName,
  }) async {
    state = const AnalyzeState(phase: AnalyzePhase.uploading);
    try {
      final initial = await ApiService.instance.analyzeVideo(
        filePath: filePath,
        bytes:    bytes,
        fileName: fileName,
      );
      state = state.copyWith(
        phase:     AnalyzePhase.processing,
        sessionId: initial.id,
      );
      _startPolling(initial.id);
    } on Exception catch (e) {
      state = AnalyzeState(phase: AnalyzePhase.failed, error: e.toString());
    }
  }

  void _startPolling(String id) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final s = await ApiService.instance.getSession(id);
        if (s.isCompleted || s.isFailed) {
          _pollTimer?.cancel();
          state = AnalyzeState(
            phase:     s.isCompleted ? AnalyzePhase.done : AnalyzePhase.failed,
            sessionId: id,
            session:   s,
            error:     s.isFailed ? 'Analysis failed. Please try again.' : null,
          );
        }
      } on Exception {
        // keep polling — transient network error
      }
    });
  }

  void reset() {
    _pollTimer?.cancel();
    state = const AnalyzeState();
  }
}

final analyzeProvider =
    StateNotifierProvider.autoDispose<AnalyzeNotifier, AnalyzeState>(
  (_) => AnalyzeNotifier(),
);
